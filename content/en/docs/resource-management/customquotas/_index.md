---
title: Custom Quotas
weight: 6
description: >
  CustomQuotas let you define and enforce arbitrary, label-scoped limits for any Kubernetes resource kind or CRD, at namespace or cluster scope.
---

## Concept

CustomQuotas complement Kubernetes `ResourceQuota` by enforcing limits on **custom usage metrics extracted from objects themselves**.

Capsule provides two quota resources:

- `CustomQuota`: namespaced CRD that limits usage **inside one namespace**. It can only target **namespaced resources**.
- `GlobalCustomQuota`: cluster-scoped CRD that aggregates usage across a set of namespaces selected by label selectors.

A quota is defined by:

- a `limit`
- one or more `sources`
- optional selectors to restrict which objects are counted

Each matching object contributes a quantity to the quota. Capsule persists the current aggregate in `status.usage.used` and keeps the list of counted objects in `status.claims`.

## Calculation

CustomQuotas are calculated in two cooperating parts:

- **Admission webhook**: performs enforcement during `CREATE`, `UPDATE`, and `DELETE`
- **Controller reconcile loop**: rebuilds the quota status from the actual cluster state and keeps it authoritative

### Admission

The admission webhook intercepts operations for the configured resource kinds and evaluates whether the change would violate any matching quota.

For each matching quota it:

1. matches the object against the quota source `GVK`
2. evaluates source selectors
3. computes the requested usage for the operation
4. creates or updates a short-lived **reservation** in the corresponding `QuantityLedger`
5. denies the request if `persistedUsed + inflightReserved + requested > limit`

This makes quota enforcement safe even during bursts of concurrent requests.

> **Without the Admission Webhook enabled, CustomQuotas are observational only.**
> The controllers still rebuild and report usage, but requests are not denied.

By default, no objects are sent to this webhook. You must explicitly enable it and configure matching rules.

Example: enable calculations for all Pod create/update/delete operations in tenant namespaces:

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
        # Execlude Event and Subresource requests to avoid performance issues and disruptions in case of issues with the webhook (Example).
        - name: ignore-subresources
          expression: '!has(request.subResource) || request.subResource == ""'
        - name: ignore-events
          expression: 'request.resource.resource != "events"'

        # Execlude Entities which never count towards quotas to avoid performance issues and disruptions in case of issues with the webhook (Example).
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
  * Missing fields are resulting in an error, as it's assumed that if a path requires calculation it should force the targeted sources to define these paths. Meaning if you eg define this JP `.spec.initContainers[*].resources.limits.cpu` on a Pod that has no initContainers, it will error. If you want to only calculate the path if it exists, you can use a [fielselector](#fieldselectors) to only match objects where the path exists, for example with `.spec.initContainers` as fieldSelector.

#### Matching Strategies

Implemententations how JSONPath expressions are evaluated and how their results are interpreted for conditional matching.

#### Truthy

When a `fieldSelectors` entry does not contain a top-level `=` or `==`, Capsule treats it as a JSONPath expression.

The selector matches when the JSONPath result is truthy.

Truthy evaluation rules:

* empty result: false
* `false`, case-insensitive: false
* `0`: false
* any other non-empty result: true

Example:

```yaml
spec:
  sources:
    - apiVersion: v1
      kind: PersistentVolumeClaim
      op: add
      path: .spec.resources.requests.storage
      selectors:
        - fieldSelectors:
            - '.spec.accessModes[?(@=="ReadWriteOnce")]'
            - '.status.phase'
```

This selector matches only if:

* `.spec.accessModes[?(@=="ReadWriteOnce")]` returns a non-empty result
* `.status.phase returns a non-empty result`

For example, this matches a PVC with:

```yaml
spec:
  accessModes:
    - ReadWriteOnce
status:
  phase: Bound
```

#### Equality

When an entry contains a top-level `=` or `==` (not nested JP expressions), Capsule treats it as an equality comparison. The left side is evaluated as a JSONPath expression. The right side is compared as a **string**.

```yaml
spec:
  sources:
    - apiVersion: v1
      kind: Service
      op: count
      selectors:
        - fieldSelectors:
            - '.spec.type=ClusterIP'
```

The following forms are equivalent:

```yaml
fieldSelectors:
  - '.spec.type=ClusterIP'
  - '.spec.type==ClusterIP'
  - '.spec.type=="ClusterIP"'
  - ".spec.type=='ClusterIP'"
```

A `==` inside a JSONPath filter is still treated as part of the JSONPath expression, not as Capsule equals matching.

For example:

```yaml
fieldSelectors:
  - '.spec.accessModes[?(@=="ReadWriteOnce")]'
```

This is interpreted as a truthy JSONPath selector, not as an equals selector. 


**Use JSONPath filters for arrays:**

```yaml
fieldSelectors:
  - '.spec.accessModes[?(@=="ReadWriteOnce")]'
```

**Use equals matching for scalar fields:**

```yaml
fieldSelectors:
  - '.spec.type=ClusterIP'
```

### Quota Matches

As it's the case with native [ResourceQuotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/#how-resource-quota-works), when a request is made, Capsule evaluates all existing CustomQuotas and GlobalCustomQuotas to determine which ones match the request. Always the smallest quantity of quotas is enforced, meaning that if multiple quotas match a request, the one with the least available capacity will be the one that determines whether the request is allowed or denied.

Let's look at this example. We have a `GlobalCustomQuota` targeting all namespaces of the tenant `solar` with a limit of 6 Pods, and a `CustomQuota` in the namespace `solar-test` (part of tenant solar) with a limit of 3 Pods:

```
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalCustomQuota
metadata:
  name: pod-count-limit
spec:
  limit: 6
  namespaceSelectors:
  - matchLabels:
      capsule.clastix.io/tenant: solar
  sources:
  - group: ""
    kind: Pod
    op: count
    version: v1
---
apiVersion: capsule.clastix.io/v1beta2
kind: CustomQuota
metadata:
  name: pod-count-limit
  namespace: solar-test
spec:
  limit: 3
  sources:
  - group: ""
    kind: Pod
    op: count
    version: v1
```

When we now try to create 6 `Pods` in the namespace `solar-test`, we can observe that the `GlobalCustomQuota` allows only 6 Pods in total across all namespaces of the tenant, while the `CustomQuota` allows only 3 Pods in the `solar-test` namespace:

```yaml
kubectl get pod -n solar-test

NAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-6ff89574f8-2jbvp   1/1     Running   0          4m20s
nginx-deployment-6ff89574f8-sdzvr   1/1     Running   0          4m20s
nginx-deployment-6ff89574f8-tvk74   1/1     Running   0          4m20s
```

We can see that requests are blocked because of the limits by the `CustomQuota` first, as it has the least available capacity (3 available vs 6 available in the `GlobalCustomQuota`):

```
115s        Warning   FailedCreate        replicaset/nginx-deployment-6ff89574f8   Error creating: admission webhook "calculation.custom-quotas.projectcapsule.dev" denied the request: creating resource exceeds limit for CustomQuota "pod-count-limit" (requested=1, currentUsed=4, available=0, limit=3, inflightReserved=1)
```

### Namespace Scope

[`GlobalCustomQuota`](#globalcustomquota) and [`CustomQuota`](#customquota) can operate in any namespace, they don't have to be part of a capsule tenant. This means that you can define a `CustomQuota` in any namespace, even if it's not part of a tenant, and it will still be enforced for objects in that namespace. Similarly, you can define a `GlobalCustomQuota` that selects namespaces based on labels, regardless of whether those namespaces are part of a tenant or not.

### Race Conditions

`GlobalCustomQuotas` and `CustomQuotas` are designed are considered when the target GVK has been posted to their status. If you quickly create workloads that match the GVK of a quota before the quota has been fully reconciled and posted to status, there is a possibility that those workloads are not counted towards the quota usage until the next reconciliation loop. This is because the admission webhook relies on the quota status to determine which quotas to enforce, and if the quota has not yet been reconciled and posted to status, it may not be considered during admission.

## Sources

A quota may define one or many sources. Each source describes:

  * which objects are candidates (`group`, `version`, `kind`)
  * what value is extracted from them ([`path`](#path), if applicable)
  * how that value contributes to usage ([`op`](#operations))
  * optional additional source-level selectors

In practice, a source answers:

 > “For objects of this kind, what should count toward the quota?”

Sources are evaluated independently and then aggregated into one total.

### GVK

Each source must identify a Kubernetes resource type by Group / Version / Kind. Example for a core Kubernetes Pod:

```yaml
group: ""
version: v1
kind: Pod
```

Example for CRDs:

```yaml
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
```

```yaml
apiVersion: s3.aws.upbound.io/v1beta1
kind: Bucket
```

How matching works:

* only objects whose GVK exactly matches the source are considered
* for [`CustomQuota`](#customquota), the target resource must be namespaced
* for [`GlobalCustomQuota`](#globalcustomquota), both namespaced Kubernetes resources and namespaced CRDs are supported across all selected namespaces
if a source refers to a GVK that is not installed or not discoverable, the controller reports a reconcile failure in the quota condition

A source does not automatically follow subresources, versions, or related objects. If you want to count two kinds, define two sources.

For example, to count both Pods and PVCs, use two sources:

```yaml
spec:
  sources:
    - apiVersion: v1
      kind: Pod
      op: count
    - apiVersion: v1
      kind: PersistentVolumeClaim
      op: count
```

### Path

path defines which value is extracted from a matching object.

Use path when the operation is [`add`](#add) or [`sub`](#sub) and you want to sum up numeric fields from the objects, such as CPU requests or storage sizes. **You can not use path with [`count`](#count)**.

The path expression leverages [JSONPath](#jsonpath) syntax and must resolve to a numeric value or an array of numeric values. The resulting number is added to the quota usage according to the defined operation. Here some examples of paths:


Count requested PVC storage:

```yaml
path: .spec.resources.requests.storage
```

Sum all container CPU requests in a Pod:

```yaml
path: .spec.containers[*].resources.requests.cpu
```

Sum ephemeral volume claim sizes declared inside a Pod:

```yaml
path: .spec.volumes[*].ephemeral.volumeClaimTemplate.spec.resources.requests.storage
```

Important notes:

* the extracted value must be parseable as a Kubernetes Quantity
* if the expression resolves to multiple values, Capsule sums them
* missing fields contribute 0

### Operations

Each source has an `op` (operation) field. For every matching object, the controller rebuild determines the effective usage contribution per source:

  * `add`: used += value
  * `sub`: used -= value
  * `count`: used += 1

On updates, usage is recalculated from the current object state and the authoritative quota status is rebuilt from scratch from all matching objects.

#### `add`

Adds the extracted quantity to the quota usage. Typical use cases:

  * CPU requests
  * memory limits
  * PVC storage
  * emptyDir or ephemeral storage sizes

This is the default behavior.

Example:

```yaml
spec:
  sources:
    - apiVersion: v1
      kind: PersistentVolumeClaim
      op: add
      path: .spec.resources.requests.storage
```

#### `sub`

Subtracts the extracted quantity from the quota usage. This is useful when you want a source to offset or discount usage from another source.

#### `count`

Counts matching objects as 1 each. Rules for count:

  * `path` must not be set
  * each matching object contributes exactly 1

Example:

```yaml
spec:
  sources:
    - apiVersion: v1
      kind: Pod
      op: count
```

### Selectors

Each source can optionally include extra selectors to further restrict which objects contribute to usage. Capsule evaluates selectors after the object already matched the source GVK. Each entry will be aggregated with OR semantics, meaning that if an object matches any of the selector entries, it is counted. [LabelSelectors](#labelselectors) and [FieldSelectors](#fieldselectors) can be combined within the same selector entry with AND semantics, meaning that an object must match both to be counted.

#### LabelSelectors

A source selector may contain Kubernetes-style matchLabels / matchExpressions against the object labels.

```yaml
spec:
  sources:
    - apiVersion: v1
      kind: PersistentVolumeClaim
      op: add
      path: .spec.resources.requests.storage
      selectors:
        - matchExpressions:
            - key: "team"
              operator: In
              values: ["platform", "dev"]
        - matchLabels:
            - key: "team"
              operator: In
              values: ["platform", "dev"]
```

#### FieldSelectors

fieldSelectors are additional per-source filters. Each entry is a JSONPath expression evaluated against the candidate object.

[View the available matching semantics](#matching-strategies) for fieldSelectors.

```yaml
spec:
  sources:
    - apiVersion: v1
      kind: PersistentVolumeClaim
      op: add
      path: .spec.resources.requests.storage
      selectors:
        - fieldSelectors:
          - '.spec.accessModes[?(@=="ReadWriteOnce")]'
          - '.status.phase'
```

the selector matches only if:

  * the label selector matches, and
  * `.spec.accessModes[?(@=="ReadWriteMany")]` returns a non-empty result, and
  * `.status.phase` returns a non-empty result

Within one `selectors` entry:

* labelSelector AND all `fieldSelectors`

Across multiple selectors entries:

* OR semantics

`FieldSelectors` are **not** Kubernetes API field selectors. They are evaluated by Capsule using JSONPath after the object has been listed.

##### Examples

Match PVCs that contain ReadWriteMany

```yaml
selectors:
  - fieldSelectors:
      - '.spec.accessModes[?(@=="ReadWriteMany")]'
```

Match objects where a field exists

```yaml
selectors:
  - fieldSelectors:
      - '.spec.storageClassName'
```

Match objects where a boolean field is true

```yaml
selectors:
  - fieldSelectors:
      - '.spec.suspend'
```

If `.spec.suspend` resolves to true, it matches.
If it resolves to false or is missing, it does not match.

Match objects with a specific condition present in an array

```yaml
selectors:
  - fieldSelectors:
      - '.status.conditions[?(@.type=="Ready")]'
```

This matches if at least one Ready condition exists.

## GlobalCustomQuota

`GlobalCustomQuota` aggregates usage across multiple namespaces.

### Sources

Sources can be distributed across many namespaces. Other than that, they follow the same [Sources rules](#sources).

### Selectors

Selectors preevaluated items considered for the quota. Only items matching the selectors are counted towards usage. [Selectors from Sources](#selectors) are applied after the source GVK is matched, so they can be used to further filter which objects are counted based on their labels or fields. However they can't select items which are not selected by the selectors on `GlobalCustomQuota` level. This means that if you want to select items across multiple namespaces, you need to use `namespaceSelectors` and not `selectors`.

#### NamespaceSelectors

Definition of `spec.namespaceSelectors` determines which namespaces are in scope. Only objects from matching namespaces are considered This enforces a 500Gi cap on ObjectBucketClaim storage in namespaces labeled with `capsule.clastix.io/tenant=solar`:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalCustomQuota
metadata:
  name: object-bucket-claim-storage
spec:
  limit: "500Gi"
  namespaceSelectors:
    - matchLabels:
        capsule.clastix.io/tenant: solar
  sources:
    - apiVersion: objectbucket.io/v1alpha1
      kind: ObjectBucketClaim
      op: add
      path: .spec.additionalConfig.maxSize
```

The collected namespaces are also reported in `status.namespaces` and can be used for informational purposes or by external systems to understand which namespaces are contributing to the quota usage.

```yaml
kubectl get globalcustomquota pod-count-limit -o yaml

apiVersion: capsule.clastix.io/v1beta2
kind: GlobalCustomQuota
metadata:
  name: object-bucket-claim-storage
spec:
  limit: "500Gi"
  namespaceSelectors:
    - matchLabels:
        capsule.clastix.io/tenant: solar
  sources:
    - apiVersion: objectbucket.io/v1alpha1
      kind: ObjectBucketClaim
      op: add
      path: .spec.additionalConfig.maxSize
status:
  conditions:
  - lastTransitionTime: "2026-04-17T08:13:17Z"
    message: reconciled
    reason: Succeeded
    status: "True"
    type: Ready
  namespaces:
  - solar-prod
  targets:
    - version: v1alpha1
      kind: ObjectBucketClaim
      group: objectbucket.io
      op: add
      path: .spec.additionalConfig.maxSize
  usage:
    available: "500Gi"
    used: "0"
```

#### ScopeSelectors

Sources can be distributed across multiple namespaces. Other than that follow [#sources](#sources) rules. This enforces a 500Gi cap on ObjectBucketClaim storage in namespaces labeled with `capsule.clastix.io/tenant=solar`, counting only claims labeled with `objectbucket.io/storage-class=gold`:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalCustomQuota
metadata:
  name: object-bucket-claim-storage
spec:
  limit: "500Gi"
  namespaceSelectors:
    - matchLabels:
        capsule.clastix.io/tenant: solar
  scopeSelectors:
    - matchLabels:
        objectbucket.io/storage-class: gold
  sources:
    - apiVersion: objectbucket.io/v1alpha1
      kind: ObjectBucketClaim
      op: add
      path: .spec.additionalConfig.maxSize
```

### Options

Additional options available for `GlobalCustomQuota`.

#### emitMetricPerClaimUsage

Additionaly expose usage metrics for each claim contributing to the quota. This is disabled by default to avoid high cardinality in the metrics, but can be enabled for more granular monitoring and alerting. By default this option is disabled.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalCustomQuota
metadata:
  name: object-bucket-claim-storage
spec:
  options:
    emitMetricPerClaimUsage: true
  ...
```

Example metrics:

```
# HELP capsule_global_custom_quota_resource_item_usage Claimed resources from given item
# TYPE capsule_global_custom_quota_resource_item_usage gauge
capsule_global_custom_quota_resource_item_usage{custom_quota="cpu-limits",group="",kind="Pod",name="nginx-deployment-6ff89574f8-299zf",target_namespace="solar-test"} 0.25
capsule_global_custom_quota_resource_item_usage{custom_quota="cpu-limits",group="",kind="Pod",name="nginx-deployment-6ff89574f8-5hzp9",target_namespace="solar-test"} 0.25
capsule_global_custom_quota_resource_item_usage{custom_quota="cpu-limits",group="",kind="Pod",name="nginx-deployment-6ff89574f8-9zzzw",target_namespace="solar-test"} 0.25
capsule_global_custom_quota_resource_item_usage{custom_quota="cpu-limits",group="",kind="Pod",name="nginx-deployment-6ff89574f8-gnf8f",target_namespace="solar-test"} 0.25
capsule_global_custom_quota_resource_item_usage{custom_quota="cpu-limits",group="",kind="Pod",name="nginx-deployment-6ff89574f8-l68c5",target_namespace="solar-test"} 0.25
capsule_global_custom_quota_resource_item_usage{custom_quota="cpu-limits",group="",kind="Pod",name="nginx-deployment-6ff89574f8-lrzvd",target_namespace="solar-test"} 0.25
```

### Examples

Feel free to contribute examples if you have found interesting use cases!

#### Limit total max storage across bucket claims for selected namespaces

This enforces a 500Gi cap on max storage requested by `ObjectBucketClaims` in all namespaces labeled with `capsule.clastix.io/tenant=solar`, but only counting those claims with the storage class label `objectbucket.io/storage-class=gold`.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: ClusterCustomQuota
metadata:
  name: object-bucket-claim-storage
spec:
  limit: "500Gi"
  sources:
    - apiVersion: objectbucket.io/v1alpha1
      kind: ObjectBucketClaim
      op: add
      path: .spec.additionalConfig.maxSize
  selectors:
    - matchLabels:
        capsule.clastix.io/tenant: solar
  scopeSelectors:
    - matchLabels:
        objectbucket.io/storage-class: gold
```

#### Limit the number of LoadBalancer Services across tenant namespaces

This limits the total number of Services of type LoadBalancer across all namespaces of one tenant.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalCustomQuota
metadata:
  name: customer-a-loadbalancers
spec:
  limit: 3
  namespaceSelectors:
    - matchLabels:
        customer: a
  sources:
    - apiVersion: v1
      kind: Service
      op: count
      selectors:
        - fieldSelectors:
            - '.spec.type[?(@=="LoadBalancer")]'
```

#### Aggregate ephemeral and persistent storage

This policy combines:

* storage requested by Pod ephemeral volume claim templates
* storage requested by PVCs

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalCustomQuota
metadata:
  name: solar-storage-aggregate
spec:
  limit: 5Gi
  namespaceSelectors:
  - matchLabels:
      capsule.clastix.io/tenant: solar
  sources:
    - apiVersion: v1
      kind: Pod
      op: add
      path: ".spec.volumes[*].ephemeral.volumeClaimTemplate.spec.resources.requests.storage"
    - apiVersion: v1
      kind: PersistentVolumeClaim
      op: add
      path: ".spec.resources.requests.storage"
      selectors:
        - fieldSelectors:
            - '.spec.accessModes[?(@=="ReadWriteOnce")]'
```


#### Count Crossplane Buckets across tenant namespaces

This limits how many Crossplane S3 buckets may exist across a tenant.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalCustomQuota
metadata:
  name: tenant-crossplane-buckets
spec:
  limit: 5
  namespaceSelectors:
    - matchLabels:
        capsule.clastix.io/tenant: solar
  sources:
    - apiVersion: s3.aws.upbound.io/v1beta1
      kind: Bucket
      op: count
```

### Monitoring

See how you can monitor `GlobalCustomQuota` usage via Prometheus metrics. The example metrics are based on this `GlobalCustomQuota` definition:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalCustomQuota
metadata:
  name: cpu-limits
spec:
  limit: 5
  namespaceSelectors:
  - matchLabels:
      capsule.clastix.io/tenant: solar
  sources:
  - apiVersion: v1
    kind: Pod
    op: add
    path: .spec.containers[*].resources.limits.cpu
  - apiVersion: v1
    kind: Pod
    op: add
    path: .spec.initContainers[*].resources.limits.cpu
status:
  claims:
  - group: ""
    kind: Pod
    name: nginx-deployment-6ff89574f8-299zf
    namespace: solar-test
    uid: f7ff7d7c-7128-4f44-ad13-3c44882420f8
    usage: 250m
    version: v1
  - group: ""
    kind: Pod
    name: nginx-deployment-6ff89574f8-9zzzw
    namespace: solar-test
    uid: 24c1bdea-000d-4e10-8af6-eb23c44ceaa3
    usage: 250m
    version: v1
  - group: ""
    kind: Pod
    name: nginx-deployment-6ff89574f8-gnf8f
    namespace: solar-test
    uid: 25368dd6-b3e7-4cbd-9fc8-9082db50372e
    usage: 250m
    version: v1
  - group: ""
    kind: Pod
    name: nginx-deployment-6ff89574f8-l68c5
    namespace: solar-test
    uid: bb697ba6-6512-4d63-acf8-6d058364c9d4
    usage: 250m
    version: v1
  - group: ""
    kind: Pod
    name: nginx-deployment-6ff89574f8-lrzvd
    namespace: solar-test
    uid: 50556db5-0134-4f0a-a0b8-56235f2bdc59
    usage: 250m
    version: v1
  - group: ""
    kind: Pod
    name: nginx-deployment-6ff89574f8-5hzp9
    namespace: solar-test
    uid: 7c6d1252-f649-4106-bfae-22c558c798df
    usage: 250m
    version: v1
  conditions:
  - lastTransitionTime: "2026-04-17T08:29:15Z"
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
    available: 3500m
    used: 1500m
```

#### Metrics

The following metrics are exposed for each `GlobalCustomQuota`:

```shell
# HELP capsule_global_custom_quota_condition Provides per global custom quota condition status
# TYPE capsule_global_custom_quota_condition gauge
capsule_global_custom_quota_condition{condition="Ready",custom_quota="cpu-limits"} 1

# TYPE capsule_global_custom_quota_resource_limit gauge
capsule_global_custom_quota_resource_limit{custom_quota="cpu-limits"} 5

# TYPE capsule_global_custom_quota_resource_available gauge
capsule_global_custom_quota_resource_available{custom_quota="cpu-limits"} 3.5

# TYPE capsule_global_custom_quota_resource_usage gauge
capsule_global_custom_quota_resource_usage{custom_quota="cpu-limits"} 1.5

## -- Requires .spec.options.emitMetricPerClaimUsage to be enabled
## May cause high cardinality if many claims are present, use with caution.

# HELP capsule_global_custom_quota_resource_item_usage Claimed resources from given item
# TYPE capsule_global_custom_quota_resource_item_usage gauge
capsule_global_custom_quota_resource_item_usage{custom_quota="cpu-limits",group="",kind="Pod",name="nginx-deployment-6ff89574f8-299zf",target_namespace="solar-test"} 0.25
capsule_global_custom_quota_resource_item_usage{custom_quota="cpu-limits",group="",kind="Pod",name="nginx-deployment-6ff89574f8-5hzp9",target_namespace="solar-test"} 0.25
capsule_global_custom_quota_resource_item_usage{custom_quota="cpu-limits",group="",kind="Pod",name="nginx-deployment-6ff89574f8-9zzzw",target_namespace="solar-test"} 0.25
capsule_global_custom_quota_resource_item_usage{custom_quota="cpu-limits",group="",kind="Pod",name="nginx-deployment-6ff89574f8-gnf8f",target_namespace="solar-test"} 0.25
capsule_global_custom_quota_resource_item_usage{custom_quota="cpu-limits",group="",kind="Pod",name="nginx-deployment-6ff89574f8-l68c5",target_namespace="solar-test"} 0.25
capsule_global_custom_quota_resource_item_usage{custom_quota="cpu-limits",group="",kind="Pod",name="nginx-deployment-6ff89574f8-lrzvd",target_namespace="solar-test"} 0.25

```

## CustomQuota

`CustomQuota` is namespaced and only counts resources in the same namespace as the quota.

### Sources

Sources can originate in the same Namespace as the `CustomQuota` is deployed in. Other than that, they follow the same [Sources rules](#sources).

### Selectors

Selectors preevaluated items considered for the quota. Only items matching the selectors are counted towards usage. [Selectors from Sources](#selectors) are applied after the source GVK is matched, so they can be used to further filter which objects are counted based on their labels or fields. However they can't select items which are not selected by the selectors on `CustomQuota` level.

#### ScopeSelectors

Sources can be distributed across multiple namespaces. Other than that follow [#sources](#sources) rules. This enforces a 500Gi cap on ObjectBucketClaim storage  counting only claims labeled with `objectbucket.io/storage-class=gold`:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: CustomQuota
metadata:
  name: object-bucket-claim-storage
  namespace: solar-test
spec:
  limit: "500Gi"
  scopeSelectors:
    - matchLabels:
        objectbucket.io/storage-class: gold
  sources:
    - apiVersion: objectbucket.io/v1alpha1
      kind: ObjectBucketClaim
      op: add
      path: .spec.additionalConfig.maxSize
```


### Options

Additional options available for `CustomQuota`.

#### emitMetricPerClaimUsage

Additionaly expose usage metrics for each claim contributing to the quota. This is disabled by default to avoid high cardinality in the metrics, but can be enabled for more granular monitoring and alerting. By default this option is disabled.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: CustomQuota
metadata:
  name: pod-count-limit
  namespace: wind-test
spec:
  options:
    emitMetricPerClaimUsage: true
  ...
```

Example metrics:

```
# HELP capsule_custom_quota_resource_item_usage Claimed resources from given item
# TYPE capsule_custom_quota_resource_item_usage gauge
capsule_custom_quota_resource_item_usage{custom_quota="pod-count-limit",group="",kind="Pod",name="nginx-deployment-77bc6bd484-4qm4h",target_namespace="wind-test"} 1
capsule_custom_quota_resource_item_usage{custom_quota="pod-count-limit",group="",kind="Pod",name="nginx-deployment-77bc6bd484-bsnfz",target_namespace="wind-test"} 1
capsule_custom_quota_resource_item_usage{custom_quota="pod-count-limit",group="",kind="Pod",name="nginx-deployment-77bc6bd484-f8qcv",target_namespace="wind-test"} 1
```

### Examples

Feel free to contribute examples if you have found interesting use cases!

#### Limit total PVC storage in one namespace

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: CustomQuota
metadata:
  name: pvc-storage-limit
  namespace: team-a
spec:
  limit: "200Gi"
  scopeSelectors:
    - matchLabels:
        team: platform
  sources:
    - apiVersion: v1
      kind: PersistentVolumeClaim
      op: add
      path: .spec.resources.requests.storage
```

#### Limit the number of LoadBalancer Services in one namespace

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: CustomQuota
metadata:
  name: namespace-loadbalancers
  namespace: team-a
spec:
  limit: 2
  sources:
    - apiVersion: v1
      kind: Service
      op: count
      selectors:
        - fieldSelectors:
            - '.spec.type[?(@=="LoadBalancer")]'
```

#### Limit total memory requests of Pods in one namespace

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: CustomQuota
metadata:
  name: pod-memory-requests
  namespace: team-a
spec:
  limit: 16Gi
  sources:
    - apiVersion: v1
      kind: Pod
      op: add
      path: .spec.containers[*].resources.requests.memory
    - apiVersion: v1
      kind: Pod
      op: add
      path: .spec.initContainers[*].resources.requests.memory
```

#### Count Crossplane SQL instances in one namespace

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: CustomQuota
metadata:
  name: sql-instances
  namespace: team-a
spec:
  limit: 3
  sources:
    - apiVersion: database.gcp.upbound.io/v1beta1
      kind: SQLDatabaseInstance
      op: count
```

#### Count only suspended CronJobs

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: CustomQuota
metadata:
  name: suspended-cronjobs
  namespace: team-a
spec:
  limit: 5
  sources:
    - apiVersion: batch/v1
      kind: CronJob
      op: count
      selectors:
        - fieldSelectors:
            - '.spec.suspend'
```

### Monitoring

See how you can monitor `CustomQuota` usage via Prometheus metrics. The example metrics are based on this `CustomQuota` definition:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: CustomQuota
metadata:
  name: pod-count-limit
  namespace: wind-test
spec:
  limit: 3
  options:
    emitMetricPerClaimUsage: false
  sources:
  - apiVersion: "v1"
    kind: Pod
    op: count
status:
  claims:
  - group: ""
    kind: Pod
    name: nginx-deployment-77bc6bd484-4qm4h
    namespace: wind-test
    uid: c6df70ce-f483-4b02-af65-c8c150d22ed2
    usage: "1"
    version: v1
  - group: ""
    kind: Pod
    name: nginx-deployment-77bc6bd484-f8qcv
    namespace: wind-test
    uid: eeae006b-5ce8-442b-b6c3-f208387545a7
    usage: "1"
    version: v1
  - group: ""
    kind: Pod
    name: nginx-deployment-77bc6bd484-bsnfz
    namespace: wind-test
    uid: 9e1135a7-b286-4768-becd-147b37c999f8
    usage: "1"
    version: v1
  conditions:
  - lastTransitionTime: "2026-04-23T09:21:29Z"
    message: reconciled
    reason: Succeeded
    status: "True"
    type: Ready
  targets:
  - group: ""
    kind: Pod
    op: count
    scope: namespace
    version: v1
  usage:
    available: "0"
    used: "3"
```

#### Metrics

The following metrics are exposed for each `CustomQuota`:

```
# HELP capsule_custom_quota_condition Provides per custom quota condition status
# TYPE capsule_custom_quota_condition gauge
capsule_custom_quota_condition{condition="Ready",custom_quota="pod-count-limit",target_namespace="wind-test"} 1

# HELP capsule_custom_quota_resource_available Available resources for given custom quota
# TYPE capsule_custom_quota_resource_available gauge
capsule_custom_quota_resource_available{custom_quota="pod-count-limit",target_namespace="wind-test"} 0

# HELP capsule_custom_quota_resource_limit Current resource limit for given custom quota
# TYPE capsule_custom_quota_resource_limit gauge
capsule_custom_quota_resource_limit{custom_quota="pod-count-limit",target_namespace="wind-test"} 3

# HELP capsule_custom_quota_resource_usage Current resource usage for given custom quota
# TYPE capsule_custom_quota_resource_usage gauge
capsule_custom_quota_resource_usage{custom_quota="pod-count-limit",target_namespace="wind-test"} 3


## -- Requires .spec.options.emitMetricPerClaimUsage to be enabled
## May cause high cardinality if many claims are present, use with caution.

# HELP capsule_custom_quota_resource_item_usage Claimed resources from given item
# TYPE capsule_custom_quota_resource_item_usage gauge
capsule_custom_quota_resource_item_usage{custom_quota="pod-count-limit",group="",kind="Pod",name="nginx-deployment-77bc6bd484-4qm4h",target_namespace="wind-test"} 1
capsule_custom_quota_resource_item_usage{custom_quota="pod-count-limit",group="",kind="Pod",name="nginx-deployment-77bc6bd484-bsnfz",target_namespace="wind-test"} 1
capsule_custom_quota_resource_item_usage{custom_quota="pod-count-limit",group="",kind="Pod",name="nginx-deployment-77bc6bd484-f8qcv",target_namespace="wind-test"} 1
```
