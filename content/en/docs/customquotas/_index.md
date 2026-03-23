---
title: Custom Quotas
weight: 6
description: >
  CustomQuotas let you define and enforce arbitrary, label-scoped limits for any Kubernetes resource kind or CRD, at namespace or cluster scope.
---

## Concept

CustomQuotas complement ResourceQuotas by enforcing limits on "custom" usage metrics that are extracted from objects themselves. They work for any namespaced resource kind (Pods, PVCs, Services, Deployments, or your own CRDs) and support both namespace-scoped and cluster-scoped configurations:

- `CustomQuota`: namespaced CRD that limits usage within a single namespace, matching objects by labels.
- `ClusterCustomQuota`: cluster-scoped CRD that aggregates usage across a set of namespaces selected by label selectors.

Under the hood, an admission webhook tracks object lifecycle and updates the quota status. If an operation would push usage above the defined limit, it's denied.

## How usage is calculated

For any create, update, or delete of an object matching the quota, the controller reads the value at `spec.source.path` from the object, parses it as a kubernetes Quantity, and adjusts the `status.used` accordingly:

- On create: used += newUsage; claim is added.
- On update: used += (newUsage - oldUsage); claim is added if this is the first time the object matches.
- On delete: used -= oldUsage; claim is removed.

If used + delta would exceed `spec.limit`, the admission webhook denies the operation.

Notes:

- Non-parsable values default to 0 and are ignored.
- Only objects whose GVK (group, version, kind) matches `spec.source` are considered.
- For `CustomQuota`, scopeSelectors are evaluated against the object labels; only matching objects count.
- For `ClusterCustomQuota`, both the namespace must match selectors and the object labels must match scopeSelectors.

## Examples

### Limit total PVC storage per team

This enforces a 200Gi cap on total storage requested by `PersistentVolumeClaims` in the namespace, counting only claims labeled with `team=platform`.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: CustomQuota
metadata:
  name: pvc-storage-limit
  namespace: team-a
spec:
  limit: "200Gi"
  source:
    version: v1
    kind: PersistentVolumeClaim
    path: .spec.resources.requests.storage
  scopeSelectors:
    - matchLabels:
        team: platform
```

### Limit total max storage across bucket claims for selected namespaces

This enforces a 500Gi cap on max storage requested by `ObjectBucketClaims` in all namespaces labeled with `capsule.clastix.io/tenant=solar`, but only counting those claims with the storage class label `objectbucket.io/storage-class=gold`.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: ClusterCustomQuota
metadata:
  name: object-bucket-claim-storage
spec:
  limit: "500Gi"
  source:
    version: v1
    kind: ObjectBucketClaim
    path: .spec.additionalConfig.maxSize
  selectors:
    - matchLabels:
        capsule.clastix.io/tenant: solar
  scopeSelectors:
    - matchLabels:
        objectbucket.io/storage-class: gold
```

## Admission behavior and immutability

- Deny on limit breach: If an object creation or update would cause used to exceed limit, the request is denied.
- Live tracking: The webhook updates `status.used` and `status.available` during admission; controllers recompute aggregates on spec changes.
- Claims lifecycle: The `status.claims` list is the authoritative set of objects currently counted. It's updated on create/update/delete.

## Selection

- Object selection: scopeSelectors use standard Kubernetes LabelSelectors applied to the object labels.
- Namespace selection (`ClusterCustomQuota`): selectors use standard LabelSelectors applied to namespaces; only those namespaces contribute objects.

## Observability

You can list quotas and see usage directly via kubectl:

```shell
kubectl get customquota -n team-a
NAME                USED   LIMIT   AVAILABLE
pvc-storage-limit   100Gi  200Gi   100Gi

kubectl get clustercustomquota
NAME                          USED   LIMIT   AVAILABLE
object-bucket-claim-storage   100Gi  500Gi   400Gi
```

Each quota also shows the claims list in the status for debugging:

```shell
kubectl get customquota pvc-storage-limit -n team-a -o yaml | yq '.status'
```

## Common patterns

- Storage governance: Sum requested storage on PVCs by storage class, team, or environment.
- CRD-specific quotas: Point to your CRD GVK and a numeric/quantity field to enforce caps.

## Edge cases and notes

- Zero values: If limit is 0, all matching operations are denied unless used is also 0; useful for temporary freezes.
- Missing fields: If the path doesn't exist on an object, it contributes 0.
- Path value type: The path must resolve to a string that can be parsed as a Quantity (e.g., "3", "500Mi", "1Gi"). Non-numeric strings are treated as 0.

## Migration and coexistence

CustomQuotas are independent of Kubernetes core ResourceQuotas. You can use them side-by-side: ResourceQuotas gate core resource consumption at the namespace boundary, while CustomQuotas enforce domain-specific caps derived from object fields.

When introducing CustomQuotas:

- Start with read-only observation by setting a high limit and watching status.used.
- Lower limits gradually and observe denied operations in admission logs.
- Keep selectors narrow to avoid accidental broad impact.