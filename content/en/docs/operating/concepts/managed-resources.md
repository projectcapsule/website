---
title: Managed Resources and Server-Side Apply
weight: 9
aliases:
  - /docs/resource-permits/managed-resources/
  - /docs/resource-permits/server-side-apply/
  - /docs/resource-leases/managed-resources/
  - /docs/resource-leases/server-side-apply/
<<<<<<< HEAD
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

=======
description: >
  Ownership, server-side apply, resource policies, and status for TenantResource
  and GlobalTenantResource replications.
---

Capsule [replications](/docs/replications/) use a shared resource manager to apply
Kubernetes objects, track their ownership, and clean them up when they leave scope.
Both [TenantResource](/docs/replications/tenant/) and
[GlobalTenantResource](/docs/replications/global/) configure this behavior through
`spec.resources[].policy`.

Each resource block has its own policy, which applies to every destination produced
by its `rawItems`, `namespacedItems`, and `generators`. Use separate blocks when
different resources or namespaces need different ownership, protection, or cleanup
behavior.

## Apply and ownership model

Capsule uses Kubernetes server-side apply (SSA) to manage the fields declared by a
replication. Stable field managers distinguish the replication and destination, so
different replications can contribute fields to the same object. Inspect the
destination's `metadata.managedFields` to see which manager owns each field:

```bash
kubectl get configmap namespace-profile -n solar-uat -o json \
  | jq '.metadata.managedFields[] | {manager, operation, fieldsV1}'
```

SSA allows Capsule and another manager to own different fields on the same object.
Changing a field owned by another manager causes an apply conflict unless Capsule
is configured to force ownership.

During reconciliation, Capsule gathers source objects, renders templates, and applies
the resulting resources to the selected destinations. Changes to the replication
trigger reconciliation, and `spec.resyncPeriod` controls periodic refreshes. Update
the replication's source objects, templates, or policy to change managed content.
Fields previously owned by Capsule can be removed when omitted from a later apply;
include them in subsequent rendered resources when they must be retained.

## Resource policy

This `GlobalTenantResource` distributes a ConfigMap to production namespaces of
Tenants labelled `energy: renewable`. Its policy applies to each replicated
ConfigMap:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: namespace-profile
spec:
  tenantSelector:
    matchLabels:
      energy: renewable
  resyncPeriod: 60s
  resources:
    - namespaceSelector:
        matchLabels:
          environment: production
      policy:
        creation: Owner
        protect: true
        force: false
        deletion: Remove
      rawItems:
        - apiVersion: v1
          kind: ConfigMap
          metadata:
            name: namespace-profile
          data:
            environment: production
```

The same resource block can be used in a `TenantResource` to distribute the
ConfigMap within a single Tenant.

>>>>>>> 69f84ecda17339f5b199618ab341bc084082143e
| Field | Values | Default | Behavior |
| --- | --- | --- | --- |
| `creation` | `Owner`, `Merge` | `Owner` | Whether an existing object may be adopted |
| `protect` | `true`, `false` | `true` | Whether admission blocks direct changes while managed |
| `force` | `true`, `false` | `false` | Whether SSA may take conflicting field ownership |
| `deletion` | `Remove`, `Orphan` | `Remove` | What happens when the parent stops managing the object |
| `condition` | CEL boolean expression | Omitted | Whether to apply rendered content to each destination |

<<<<<<< HEAD
`Owner` requires Capsule to have created the target. If an object with the same
identity already exists and was not created for the managing API, reconciliation
fails. `Merge` adopts an existing object when possible and creates it otherwise. Use
`Merge` only when the workflow intentionally manages fields on pre-existing objects.
=======
`Owner` creates an absent target and manages objects created by the applying
controller. An unrelated existing object with the same identity causes an ownership
error. `Merge` adopts an existing object when possible and creates it otherwise. Use
`Merge` when the replication should manage fields on existing objects.
>>>>>>> 69f84ecda17339f5b199618ab341bc084082143e

`force: true` resolves SSA conflicts by taking ownership of the rendered fields. It
does not bypass Kubernetes RBAC, admission, or schema validation, and can displace
another controller's ownership.

With `protect: true`, Capsule marks the object as protected. The generic Capsule
admission webhook rejects direct updates and deletion while the parent manages it,
except for the controller and the resolved execution ServiceAccount. Disable
protection only when another actor must modify the object during its managed lifetime.

With `deletion: Remove`, when multiple Capsule resource managers share an adopted
<<<<<<< HEAD
target, removing one manager preserves the shared tracking and protection metadata while another
Capsule resource manager remains. The final departing manager removes that
metadata without deleting fields owned by external managers.
=======
target, removing one manager preserves the shared tracking and protection metadata
while another Capsule resource manager remains. The final departing manager removes
that metadata without deleting fields owned by external managers.
>>>>>>> 69f84ecda17339f5b199618ab341bc084082143e

Cleanup depends on both the deletion policy and whether Capsule created or adopted the
object:

| Policy | Object created by Capsule | Existing object adopted with `Merge` |
| --- | --- | --- |
| `Remove` | Delete the object | Relinquish managed fields and tracking |
| `Orphan` | Keep the object and remove tracking/protection | Keep the object and applied fields, then remove tracking/protection |

<<<<<<< HEAD
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
=======
Cleanup runs when a target leaves the desired replication output, including
namespace or Tenant deselection, resource block removal, or deletion of the
replication. It uses the last successfully reconciled policy recorded for that
target. A false apply condition does not prevent cleanup.

`Orphan` leaves configuration behind after the replication stops managing it. Choose
it when those resources must survive independently of the replication. For existing
manifests using `spec.settings` or `spec.pruningOnDelete`, see the
[policy migration guide](/docs/replications/#deprecated-settings-and-migration).

## Apply conditions

Set `spec.resources[].policy.condition` on a `TenantResource` or
`GlobalTenantResource` to decide when rendered content is applied. One expression
is evaluated independently for every destination produced by that resource block;
separate blocks can use different conditions. The expression must return a boolean
and may contain up to 4096 characters. Omit the field to keep unconditional apply;
a blank expression is invalid.

| Input | Meaning |
| --- | --- |
| `object` | The existing destination resource, read using the replication's execution identity; `null` if it does not exist. It is not the rendered candidate. |
| `now` | The UTC timestamp at evaluation time. Use `timestamp(...)` and `duration(...)` for time comparisons. |

Apply conditions use CEL directly. There is no `self`, `.self`, Go-template
expansion, or access to template context in this expression. Load context and
render the desired resource through [generators](/docs/operating/concepts/templating/).
Rendering happens before condition evaluation, so a condition cannot suppress
context-loading or template errors.
>>>>>>> 69f84ecda17339f5b199618ab341bc084082143e

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

Both replication APIs render and evaluate conditions during reconciliation,
including periodic resync. This makes conditions suitable for recurring namespace
configuration and key rotation. Time passing alone does not trigger an apply; the
condition is checked the next time the replication reconciles. Choose a
`spec.resyncPeriod` that suits the required refresh interval.

## Scope, tracking, and cleanup

For namespaced targets in the default Namespace scope, Capsule uses the selected
destination Namespace, which can differ from the Namespace containing a
`TenantResource`. A `TenantResource` is restricted to namespaced resources within
its own Tenant. A `GlobalTenantResource` can also manage cluster-scoped resources
and use `spec.scope` to control whether resources are rendered per Namespace, per
Tenant, or once. See [replication scope](/docs/replications/global/#scope) for those
options. Cluster-scoped resources are applied without a namespace.

Capsule records processed targets in the replication's `.status.processedItems`,
including whether they were created or adopted and the policy used for cleanup.
Successful targets remain recorded if a later target fails, so subsequent
reconciliation can retry failures and clean up resources that leave scope.

Replicated objects may carry tracking labels such as:

```yaml
metadata:
  labels:
    projectcapsule.dev/created-by: resources
    projectcapsule.dev/managed-by: resources
```

`created-by` identifies resources Capsule created; `managed-by` identifies resources
under management, including adopted objects. Capsule sets tracking metadata
independently of the rendered manifest, so a template cannot forge whether an
object was created or adopted. Use processed-item status to inspect a particular
replication's relationship to a target.

## Status and failures

Both replication APIs report their managed resources through `.status.processedItems`.
For example, the `namespace-profile` GlobalTenantResource can report successful
ConfigMap replication into two namespaces of the `solar` Tenant:

```yaml
status:
  size: 2
  selectedTenants:
    - solar
  processedItems:
    - version: v1
      kind: ConfigMap
      namespace: solar-uat
      name: namespace-profile
      tenant: solar
      status:
        clusterScoped: false
        created: true
        lastApply: "2026-08-31T10:02:13Z"
        type: Ready
        status: "True"
        policy:
          creation: Owner
          protect: true
          force: false
          deletion: Remove
    - version: v1
      kind: ConfigMap
      namespace: solar-prod
      name: namespace-profile
      tenant: solar
      status:
        clusterScoped: false
        created: true
        lastApply: "2026-08-31T10:02:14Z"
        type: Ready
        status: "True"
        policy:
          creation: Owner
          protect: true
          force: false
          deletion: Remove
```

Each item identifies the target's API group, version, kind, name, namespace, Tenant,
and scope, whether it was created or adopted, its last apply time, and its latest
condition or error. Skipped targets report `ConditionNotMet: apply skipped`. A
previously applied target keeps its last successful apply time; a never-applied
target has none. The retained policy records the last successful policy
reconciliation and determines subsequent cleanup; the
condition expression is evaluated from the source block and is not stored in that
snapshot. Ownership violations, SSA conflicts, RBAC denials, unavailable resource
kinds, invalid manifests, and admission failures are reported through processed-item
status and the replication's conditions. `.status.serviceAccount` identifies the
ServiceAccount used to execute the replication.

```bash
kubectl get globaltenantresource namespace-profile -o json \
  | jq '.status | {size, selectedTenants, serviceAccount, processedItems, conditions}'

kubectl get tenantresource namespace-profile -n solar-system -o json \
  | jq '.status | {size, serviceAccount, processedItems, conditions}'
```

To recover from a failure, correct the source object, permissions, template, or
policy and let reconciliation retry. Update the replication rather than editing
its processed-item status or making direct changes to protected destination objects.
