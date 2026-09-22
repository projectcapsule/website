---
title: Replications
weight: 6
description: >
  Replicate resources across tenants or namespaces
---

Capsule provides two dedicated Custom Resource Definitions for propagating Kubernetes resources across Tenant Namespaces, covering both the cluster administrator and Tenant owner personas:

- **[GlobalTenantResource](./global/)**: cluster-scoped, managed by cluster administrators. Selects Tenants by label and replicates resources into all matching Tenant Namespaces.
- **[TenantResource](./tenant/)**: namespace-scoped, managed by Tenant owners. Replicates resources across the Namespaces within a single Tenant.

Both CRDs follow the same structure: resources are defined in `spec.resources` blocks, reconciled on a configurable `resyncPeriod`, and support [Go-template-based generators](/docs/operating/concepts/templating/) for dynamic resource creation.

## Per-resource policies

Each `spec.resources[]` block accepts the same policy as a ResourcePermit template.
The policy applies to every `rawItems`, `namespacedItems`, and `generators` result
in that block. These are the defaults:

```yaml
spec:
  resources:
    - policy:
        creation: Owner
        force: false
        protect: true
        deletion: Remove
      rawItems:
        - apiVersion: v1
          kind: ConfigMap
          metadata:
            name: namespace-profile
          data:
            environment: production
```

An optional `policy.condition` gates content apply for each destination using CEL.
A false condition keeps existing content while policy updates still reconcile on
managed targets. See the [shared policy reference](/docs/operating/concepts/managed-resources/)
for ownership, protection, cleanup, conditions, and status, and the
[age-key rotation example](./global/#conditional-age-key-rotation) for recurring
updates that retain old data.

## Deprecated settings and migration

`spec.settings.adopt`, `spec.settings.force`, and `spec.pruningOnDelete` remain
accepted for compatibility but are deprecated. The `replicationDefaults` admission
hook converts them on create and update, adding a policy only to blocks that do not
already have one:

| Deprecated setting | Per-resource policy |
| --- | --- |
| `settings.adopt: true` | `creation: Merge` |
| `settings.adopt: false` or omitted | `creation: Owner` |
| `settings.force` | `force`, defaulting to `false` |
| `pruningOnDelete: false` | `deletion: Orphan` |
| `pruningOnDelete: true` or omitted | `deletion: Remove` |

Conversion uses the shared `protect: true` default, including adopted resources.
Set `protect: false` explicitly when another actor must modify a managed target.
The deprecated fields remain on the object; conversion does not remove them.

An explicit policy replaces the deprecated settings for its entire block. After
conversion, change `spec.resources[].policy` to update behavior: changing the old
settings does not overwrite an existing policy. Defaults fill omitted fields in an
explicit policy rather than inheriting those fields from `spec.settings`.

Stored objects that have not passed through admission again keep a runtime fallback
to their legacy settings, including legacy protection and pruning behavior. Their
missing policies are converted the next time they are admitted. Cleanup uses the
last successfully reconciled policy even after a block or its parent is removed.
