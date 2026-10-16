---
title: Managed Resources and Server-Side Apply
weight: 9
aliases:
  - /docs/resource-permits/managed-resources/
  - /docs/resource-permits/server-side-apply/
  - /docs/resource-leases/managed-resources/
  - /docs/resource-leases/server-side-apply/
description: Resource ownership, server-side apply, protection, cleanup policies, and status.
---

Capsule uses a shared resource manager to apply Kubernetes objects, track their
ownership, and prune them when they leave scope. `TenantResource`,
`GlobalTenantResource`, `ResourcePermitTemplate`, and
`GlobalResourcePermitTemplate` share `spec.resources[].policy`. Each block controls
its generated resources, allowing namespaces within a tenant to receive different
configuration and lifecycle behavior.

## Apply and ownership model

Capsule uses Kubernetes server-side apply (SSA) with a stable field manager for each
managing parent. A ResourcePermit manager is derived from the request UID:

```text
projectcapsule.dev/resource/resourcepermit/<request-uid>
```

SSA allows Capsule and another manager to own different fields on the same object.
When both managers claim the same field, Kubernetes reports an apply conflict unless
Capsule is configured to force ownership.

For Resource Permits, Capsule renders every target before approval and stores the concrete
manifests and their policies in `.status.request.resources`. That snapshot—not the
mutable source template—is the source of truth for review, apply, and cleanup.

## Resource policy

One policy applies to every target in a resource group:

```yaml
resources:
  - policy:
      creation: Owner
      protect: true
      force: false
      deletion: Remove
    targets:
      - apiVersion: v1
        kind: ConfigMap
        metadata:
          name: temporary-settings
```

| Field | Values | Default | Behavior |
| --- | --- | --- | --- |
| `creation` | `Owner`, `Merge` | `Owner` | Whether an existing object may be adopted |
| `protect` | `true`, `false` | `true` | Whether admission blocks direct changes while managed |
| `force` | `true`, `false` | `false` | Whether SSA may take conflicting field ownership |
| `deletion` | `Remove`, `Orphan` | `Remove` | What happens when the parent stops managing the object |
| `condition` | CEL boolean expression | Omitted | Whether to apply rendered content to each destination |

`Owner` requires Capsule to have created the target. If an object with the same
identity already exists and was not created for the managing API, reconciliation
fails. `Merge` adopts an existing object when possible and creates it otherwise. Use
`Merge` only when the workflow intentionally manages fields on pre-existing objects.

`force: true` resolves SSA conflicts by taking ownership of the rendered fields. It
does not bypass Kubernetes RBAC, admission, or schema validation, and can displace
another controller's ownership.

With `protect: true`, Capsule marks the object as protected. The generic Capsule
admission webhook rejects direct updates and deletion while the parent manages it,
except for the controller and the resolved execution ServiceAccount. Disable
protection only when another actor must modify the object during its managed lifetime.

With `deletion: Remove`, when multiple Capsule resource managers share an adopted
target, removing one manager preserves the shared tracking and protection metadata while another
Capsule resource manager remains. The final departing manager removes that
metadata without deleting fields owned by external managers.

Cleanup depends on both the deletion policy and whether Capsule created or adopted the
object:

| Policy | Object created by Capsule | Existing object adopted with `Merge` |
| --- | --- | --- |
| `Remove` | Delete the object | Relinquish managed fields and tracking |
| `Orphan` | Keep the object and remove tracking/protection | Keep the object and applied fields, then remove tracking/protection |

`Orphan` can leave privileges or configuration behind after the parent expires, so it
should be an explicit design choice.

## Apply conditions

Set `spec.resources[].policy.condition` on `TenantResource`,
`GlobalTenantResource`, `ResourcePermitTemplate`, or
`GlobalResourcePermitTemplate`. One expression applies independently to every
destination produced by that resource block; separate blocks can use different
conditions. The expression must return a boolean and may contain up to 4096
characters. Omit the field to keep unconditional apply; an empty or whitespace-only
expression is not a substitute for omitting it.

| Input | Meaning |
| --- | --- |
| `object` | The existing destination resource, read using the execution identity; `null` if it does not exist. It is not the rendered candidate. |
| `now` | The UTC timestamp at evaluation time. Use `timestamp(...)` and `duration(...)` for time comparisons. |

Apply conditions use CEL directly. There is no `self`, `.self`, Go-template
expansion, or access to template parameters/context in this expression. Load
context and render the desired resource through the existing template API. The
condition then decides whether that rendered resource may be applied.

For example, create a target only when it is absent:

```yaml
policy:
  condition: "object == null"
```

To initialize a target and then allow a refresh after five minutes:

```yaml
policy:
  condition: |
    object == null ||
    !has(object.metadata.annotations) ||
    !('keys.example.org/rotated-at' in object.metadata.annotations) ||
    now >= timestamp(object.metadata.annotations['keys.example.org/rotated-at']) + duration('5m')
```

The generator must write the `keys.example.org/rotated-at` annotation on each
successful refresh. Guard missing objects and fields before accessing them;
use bracket notation for annotation keys containing dots or slashes. A missing
timestamp initializes this example, while a malformed timestamp causes an
evaluation error. See the complete [rotation example](/docs/replications/global/#conditional-age-key-rotation)
for the template, retention behavior, and verification steps.

| Outcome | Apply behavior |
| --- | --- |
| Condition omitted | Existing unconditional apply behavior. |
| `true` | Apply using the block's creation, force, and protection policies; normal authorization and ownership checks still apply. |
| `false` | Skip rendered content and preserve its last-apply timestamp. Reconcile protection and retain the current policy for already managed targets. A never-applied target is not adopted, protected, or modified. |
| Invalid syntax or non-boolean result type | Admission rejects the expression at `spec.resources[i].policy.condition`. |
| Evaluation or target-read error | The target is not written; the failure is reported through existing status. A forbidden read is not treated as an absent object. |

There is no configurable action for a false result. Conditions do not provide
an all-or-nothing transaction across targets: each target is evaluated separately.
They also do not change SSA retention. To preserve old fields owned by Capsule,
include them in subsequent rendered resources, as the age-key example does.

For example, changing `protect: true` to `protect: false` removes protection on
an already managed target even while its condition is false, provided no other
Capsule resource manager still shares the target. Protection is also reconciled
when the condition becomes true or is removed; protection established during a
skipped apply does not persist after a sole manager disables it. Changing
`deletion: Remove` to `deletion: Orphan` takes effect for subsequent cleanup.
`creation` and `force` govern the next permitted content apply; changing them
does not override a false condition. Rendered labels, annotations, and data
remain unchanged, including key material and rotation timestamps. Capsule may
patch its own protection metadata, so the target's resource version can change.
When that metadata already matches, a skipped reconciliation performs no target
write. Policy changes that fail to reconcile are reported through existing status.

### Evaluation lifecycle

| Resource | Evaluation lifecycle | Suitable use |
| --- | --- | --- |
| `TenantResource` / `GlobalTenantResource` | Render and evaluate during reconciliation, including periodic resync. | Recurring namespace configuration and key rotation. |
| `ResourcePermitTemplate` / `GlobalResourcePermitTemplate` | Render a request snapshot, then evaluate against live targets during preflight, activation, and explicit failure retries. Active permits do not periodically reevaluate. | Conditional provisioning during an approved permit's activation. |

Permit approval conditions (`spec.approvals.conditions`) control approval
eligibility. Apply conditions control target writes after those approval rules
are satisfied. In particular, an Active permit may contain skipped targets;
use approval conditions when the entire permit must be gated. The
[permit guide](/docs/permits/templates/#conditional-resources)
provides namespaced/global examples, required permissions, and status diagnostics.

## Scope, tracking, and cleanup

For namespaced targets, Capsule normally defaults an omitted namespace to the parent
workflow's namespace. An explicitly rendered namespace is preserved when the workflow
is trusted to operate across namespaces. Cluster-scoped GVKs are applied without a
namespace.

A namespaced parent cannot own a cluster-scoped object through a Kubernetes owner
reference. APIs such as ResourcePermit therefore record every processed target and use a
finalizer for explicit cascading cleanup. Successful targets remain recorded even if
a later target fails, allowing retries and finalization to handle partial application.

Managed objects may carry labels and annotations such as:

```yaml
metadata:
  labels:
    projectcapsule.dev/created-by: resource-permit
    projectcapsule.dev/managed-by: resource-permit
    projectcapsule.dev/protected-by: resource-permit
  annotations:
    projectcapsule.dev/active-until: "2026-08-31T11:00:00Z"
    projectcapsule.dev/resourcepermit-service-account: system:serviceaccount:capsule-system:resource-permit-runner
```

The exact metadata depends on the parent API, policy, and lifecycle stage. Capsule
sets tracking metadata independently of the rendered manifest, so a template cannot
forge whether an object was created or adopted.

## Status and failures

Managed APIs use a shared processed-resource status shape. A ResourcePermit example is:

```yaml
status:
  size: 2
  processedItems:
    - group: rbac.authorization.k8s.io
      version: v1
      kind: Role
      namespace: solar-uat
      name: incident-1042-editor
      status:
        clusterScoped: false
        created: true
        lastApply: "2026-08-31T10:02:13Z"
        type: Ready
        status: "True"
    - group: rbac.authorization.k8s.io
      version: v1
      kind: ClusterRole
      name: incident-1042-cluster-reader
      status:
        clusterScoped: true
        created: true
        lastApply: "2026-08-31T10:02:14Z"
        type: Ready
        status: "True"
```

Each item identifies its GVK, name, namespace and scope, whether it was created or
adopted, its last apply time, and its latest condition or error. Skipped targets
report `ConditionNotMet: apply skipped`. A previously applied target keeps its last
successful apply time; a never-applied target has none. The retained policy records
the last successful policy reconciliation and determines subsequent cleanup. Ownership violations,
SSA conflicts, RBAC denials, unavailable GVKs, invalid manifests, and admission
failures are reported through this status and the parent conditions.

```bash
kubectl get resourcepermit REQUEST -n NAMESPACE -o json \
  | jq '.status | {size, processedItems, conditions}'
```

Do not edit controller-owned rendered manifests or processed-item status to recover
from a failure. Correct the underlying object, permissions, template, or policy and let
reconciliation retry.
