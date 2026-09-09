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
ownership, and prune them when they leave scope. ResourcePermit templates expose these
choices as a policy on each resource group; Capsule's resource-distribution APIs use
the same apply and processed-item foundations.

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

Cleanup depends on both the deletion policy and whether Capsule created or adopted the
object:

| Policy | Object created by Capsule | Existing object adopted with `Merge` |
| --- | --- | --- |
| `Remove` | Delete the object | Relinquish managed fields and tracking |
| `Orphan` | Keep the object and remove tracking/protection | Keep the object and applied fields, then remove tracking/protection |

`Orphan` can leave privileges or configuration behind after the parent expires, so it
should be an explicit design choice.

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
      clusterScoped: false
      created: true
      lastApply: "2026-08-31T10:02:13Z"
      type: Ready
      status: "True"
    - group: rbac.authorization.k8s.io
      version: v1
      kind: ClusterRole
      name: incident-1042-cluster-reader
      clusterScoped: true
      created: true
      lastApply: "2026-08-31T10:02:14Z"
      type: Ready
      status: "True"
```

Each item identifies its GVK, name, namespace and scope, whether it was created or
adopted, its last apply time, and its latest condition or error. Ownership violations,
SSA conflicts, RBAC denials, unavailable GVKs, invalid manifests, and admission
failures are reported through this status and the parent conditions.

```bash
kubectl get resourcepermit REQUEST -n NAMESPACE -o json \
  | jq '.status | {size, processedItems, conditions}'
```

Do not edit controller-owned rendered manifests or processed-item status to recover
from a failure. Correct the underlying object, permissions, template, or policy and let
reconciliation retry.
