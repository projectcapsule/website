---
title: Custom Quotas
weight: 6
description: >
  CustomQuotas let you define and enforce arbitrary, label-scoped limits for any Kubernetes resource kind or CRD, at namespace or cluster scope.
---

## Concept

CustomQuotas complement ResourceQuotas by enforcing limits on "custom" usage metrics that are extracted from objects themselves:

- `CustomQuota`: namespaced CRD that limits usage within a single namespace, matching objects by labels. **Can only be used for namespaced resources**.
- `ClusterCustomQuota`: cluster-scoped CRD that aggregates usage across a set of namespaces selected by label selectors.

Under the hood, an admission webhook tracks object lifecycle and updates the quota status. If an operation would push usage above the defined limit, it's denied.

## Calculation



### Admission

In order to enforce the quotas, an admission webhook is used. The webhook intercepts create, update, and delete operations on objects matching the quota's source criteria. It calculates the new usage based on the defined JSONPath and updates the quota status accordingly (It's also cached to avoid racing conditions). If the new usage would exceed the defined limit, the webhook denies the operation.

By default, no objects are sent to this webhook. **You must explicitly enable it and configure the matching criteria** (e.g., by GVK or namespace labels) to have it enforce your quotas. This allows you to roll out CustomQuotas gradually and avoid unintended disruptions. Here's a basic example where we enable the webhook for all operations on `Pods` in namespaces labeled with `capsule.clastix.io/tenant=solar` via the helm chart:

```yaml
webhooks:
  hooks:
    calculations:
      enabled: true
      namespaceSelector:
        matchExpressions:
          - key: capsule.clastix.io/tenant
            operator: Exists
      rules:
          - apiGroups:
              - ""
            apiVersions:
              - ""
            operations:
              - CREATE
              - UPDATE
              - DELETE
            resources:
              - "pods"
            scope: Namespaced
```

Make sure to configure this webhook carefully, as it can impact cluster performance and availability if it matches a large number of operations. Start with a narrow scope (e.g., specific GVKs and namespace labels) and monitor the impact before expanding it. Also make sure to exclude system critical components or namespaces to avoid accidental disruptions.

```yaml
webhooks:
  hooks:
    calculations:
      enabled: true
      namespaceSelector:
        matchExpressions:
          - key: name
            operator: NotIn
            values: ["kube-system", "kube-public", "kube-node-lease"]
      rules:
        - apiGroups:
            - ""
          apiVersions:
            - ""
          operations:
            - CREATE
            - UPDATE
            - DELETE
          resources:
            - "pods"
          scope: Namespaced
      matchConditions:
      - name: 'exclude-kubelet-requests'
        expression: '!("system:nodes" in request.userInfo.groups)'
      - name: 'exclude-kube-system'
        expression: '!("system:serviceaccounts:kube-system" in request.userInfo.groups)'
```

**Without the Admission Webhook enabled, CustomQuotas are purely observational and do not enforce limits.** You can use this mode to monitor usage and understand the impact before enabling enforcement.

### JSONPath

The Custom Quota system relies on JSONPath expressions to extract numeric values from objects. The `spec.sources[*].path` field defines the JSONPath to the value that should be counted towards the quota. This allows you to define quotas based on any numeric field in any Kubernetes resource, including custom resources.

The following constraints apply to the JSONPath:

  * Expressions must start with a dot (`.`) and use standard JSONPath syntax. (valid `.spec.storage.usage`).
  * Paths can not be empty.
  * The maximum length of the path is `1024` characters.
  * Expressions can not contain any of the following characters: 
    * `\n` (newline)
    * `\r` (carriage return) 
    * `\t` (tab)
  * Values can resolve to array results, which are then summed up. (For example, `.spec.containers[*].resources.limits.cpu` would sum the CPU limits of all containers in a Pod.)
  * Missing fields are treated as zero (`0`). We allow Keys to be missing be default. Meaning if you eg define this JP `.spec.initContainers[*].resources.limits.cpu` on a Pod that has no initContainers, it will simply contribute 0 to the usage instead of causing an error. This is useful for flexibility and to avoid unintended disruptions, but it also means that you need to be careful when defining your JSONPaths to ensure they accurately capture the intended usage.

### Operations





### How usage is calculated

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

## GlobalCustomQuota






### Monitoring

See how you can monitor `GlobalCustomQuota` usage via Prometheus metrics. The example metrics are based on this `GlobalCustomQuota` definition:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalCustomQuota
metadata:
  name: cpu-limit
spec:
  limit: "5"
  namespaceSelectors:
  - matchLabels:
      capsule.clastix.io/tenant: solar
  sources:
  - group: ""
    kind: Pod
    op: add
    path: .spec.containers[*].resources.limits.cpu
    version: v1
  - group: ""
    kind: Pod
    op: add
    path: .spec.initContainers[*].resources.limits.cpu
    version: v1
status:
  claims:
  - group: ""
    kind: Pod
    name: netshoot
    namespace: solar-test
    uid: 0086632e-c49e-4453-b622-310918908d00
    usage: "3"
    version: v1
  conditions:
  - lastTransitionTime: "2026-03-31T18:12:02Z"
    message: reconciled
    reason: Succeeded
    status: "True"
    type: Ready
  namespaces:
  - solar-prod
  - solar-test
  targets:
  - group: ""
    kind: Pod
    op: add
    path: .spec.containers[*].resources.limits.cpu
    scope: namespace
    version: v1
  - group: ""
    kind: Pod
    op: add
    path: .spec.initContainers[*].resources.limits.cpu
    scope: namespace
    version: v1
  usage:
    available: "1"
    used: "4"
```

#### Metrics

The following metrics are exposed for each `GlobalCustomQuota`:

```shell
# TYPE capsule_global_custom_quota_condition gauge
capsule_global_custom_quota_condition{condition="Ready",custom_quota="cpu-limit"} 1

# HELP capsule_global_custom_quota_resource_available Available resources for given global_custom quota
# TYPE capsule_global_custom_quota_resource_available gauge
capsule_global_custom_quota_resource_available{custom_quota="cpu-limit"} 1

# HELP capsule_global_custom_quota_resource_item_usage Claimed resources from given item
# TYPE capsule_global_custom_quota_resource_item_usage gauge
capsule_global_custom_quota_resource_item_usage{custom_quota="cpu-limit",group="",kind="Pod",name="netshoot",target_namespace="solar-test"} 3

# HELP capsule_global_custom_quota_resource_limit Current resource limit for given global custom quota
# TYPE capsule_global_custom_quota_resource_limit gauge
capsule_global_custom_quota_resource_limit{custom_quota="cpu-limit"} 5

# HELP capsule_global_custom_quota_resource_usage Current resource usage for given global custom quota
# TYPE capsule_global_custom_quota_resource_usage gauge
capsule_global_custom_quota_resource_usage{custom_quota="cpu-limit"} 4
```

#### Rules



## Examples

### Limit total max storage across bucket claims for selected namespaces

This enforces a 500Gi cap on max storage requested by `ObjectBucketClaims` in all namespaces labeled with `capsule.clastix.io/tenant=solar`, but only counting those claims with the storage class label `objectbucket.io/storage-class=gold`.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: ClusterCustomQuota
metadata:
  name: object-bucket-claim-storage
spec:
  limit: "500Gi"
  sources:
    - version: v1alpha1
      kind: ObjectBucketClaim
      group: objectbucket.io
      path: .spec.additionalConfig.maxSize
  selectors:
    - matchLabels:
        capsule.clastix.io/tenant: solar
  scopeSelectors:
    - matchLabels:
        objectbucket.io/storage-class: gold
```




## CustomQuota



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