---
title: GlobalResourceQuota
description: Share one atomic Kubernetes resource budget across multiple namespaces.
weight: 1
---

`GlobalResourceQuota` provides a single Kubernetes `ResourceQuota` budget shared by a selected set of namespaces.

A standard Kubernetes `ResourceQuota` is namespaced. Copying the same quota into multiple namespaces gives every namespace the full limit, so the combined usage can grow with the number of namespaces. `GlobalResourceQuota` keeps the familiar Kubernetes quota API while enforcing one aggregate hard limit across all selected namespaces.

The resource is cluster-scoped and can select any namespace. Selected namespaces do not have to belong to a Capsule Tenant.

## Concept

A `GlobalResourceQuota` consists of:

- One or more namespace label selectors.
- One native Kubernetes `ResourceQuotaSpec`.
- Aggregate usage and availability in its status.
- Per-namespace usage in its status.
- An internal `QuantityLedger` used to serialize concurrent admission.

Capsule creates a managed native `ResourceQuota` in every selected namespace. The native quotas provide Kubernetes-compatible accounting and status. Capsule's validating admission webhook evaluates all matching `GlobalResourceQuota` objects and reserves new usage atomically before allowing the request.

This combination prevents concurrent requests in different namespaces from exceeding the shared limit.

### Benefits

- Share one hard limit across any number of namespaces.
- Use native Kubernetes resource names, scopes, and scope selectors.
- Select Tenant namespaces, application namespaces, environments, or arbitrary namespace groups.
- Prevent oversubscription during concurrent admission.
- Inspect aggregate and per-namespace usage from one cluster-scoped resource.
- Monitor limits, usage, availability, conditions, and namespace consumption with Prometheus.
- Generate quotas from Capsule Tenant rules where desired.

## GlobalResourceQuota

The following quota shares CPU and memory across all namespaces belonging to the `green` Tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalResourceQuota
metadata:
  name: green-shared-compute
spec:
  namespaceSelectors:
    - matchLabels:
        capsule.clastix.io/tenant: green
  quota:
    hard:
      limits.cpu: "8"
      limits.memory: 16Gi
      requests.cpu: "8"
      requests.memory: 16Gi
```

Each `GlobalResourceQuota` represents one native `ResourceQuotaSpec`. Create multiple `GlobalResourceQuota` objects when different scopes, selectors, or independently managed limits are required.

## Namespace selection

Namespaces are selected through `.spec.namespaceSelectors`.

Requirements inside one selector are combined with AND. Multiple entries in `namespaceSelectors` are combined with OR. A namespace matching any entry is included only once.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalResourceQuota
metadata:
  name: production-and-staging
spec:
  namespaceSelectors:
    - matchLabels:
        company.example/environment: production
      matchExpressions:
        - key: company.example/quota-enabled
          operator: In
          values: ["true"]
    - matchLabels:
        company.example/environment: staging
  quota:
    hard:
      requests.cpu: "20"
      requests.memory: 40Gi
```

Selection behavior:

- Omitting `namespaceSelectors` selects no namespaces.
- A selector entry containing an empty `matchLabels`/`matchExpressions` selector matches every namespace.
- A selector with a `nil` label selector is ignored.
- Terminating namespaces are not included.
- Namespace membership is recalculated when namespace labels or the quota selectors change.






### Non-Tenant Namespaces

While you can define `namespaceSelectors` to select any namespace, by default only namespaced resources in `Namespaces` which are part of a `Tenant` are only sent to admission. If you want to use `GlobalResourceQuota` for `Namespaces` that are not part of a `Tenant`, you must mainly change the admission configuration to also sent namespaced resources to the `GlobalResourceQuota` webhook:

```yaml
webhooks:
  hooks:
    globalresourcequotas:
      enabled: true
      namespaceSelector:
        matchExpressions:
          - key: capsule.clastix.io/tenant
            operator: Exists
          - key: kubernetes.io/metadata.name
            operator: In
            values:
              - tenants-shared-system
```

While this may be cumbersome, it was the best solution to avoid implementing a potential cluster DoS attack vector. Only then calculations are sent to the admission webhook for `Namespaces` that are not part of a `Tenant`.

```yaml
spec:
  namespaceSelectors:
    - matchExpressions:
        - key: kubernetes.io/metadata.name
          operator: In
          values:
            - tenants-shared-system
```

### Selecting Tenant namespaces

Capsule labels Tenant namespaces with the Tenant name. The compatibility label can be used directly:

```yaml
spec:
  namespaceSelectors:
    - matchLabels:
        capsule.clastix.io/tenant: solar
```

Multiple Tenants can share one quota:

```yaml
spec:
  namespaceSelectors:
    - matchLabels:
        capsule.clastix.io/tenant: solar
    - matchLabels:
        capsule.clastix.io/tenant: wind
```

## Quota resources

`.spec.quota` is a Kubernetes `ResourceQuotaSpec`. The same hard-resource names and scope rules used by Kubernetes apply.

### Compute resources

```yaml
spec:
  namespaceSelectors:
    - matchLabels:
        company.example/team: payments
  quota:
    hard:
      requests.cpu: "16"
      requests.memory: 32Gi
      limits.cpu: "32"
      limits.memory: 64Gi
      pods: "100"
```

Pod requests and limits are calculated using the Kubernetes pod resource helpers. This includes:

- Regular containers.
- Init containers, including restartable sidecars.
- Pod overhead.
- Pod-level CPU and memory resources when supported by the Kubernetes API server.
- Pod lifecycle behavior, such as excluding terminal Pods from compute usage while retaining `count/pods`.

Pod-level resources can be placed on a Pod template:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: solar-production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: "1"
          memory: 1Gi
      containers:
        - name: nginx
          image: nginx:1.27
```

Kubernetes must support and enable Pod-level resources. If the API server removes the field because the feature is unavailable, quota validation falls back to Kubernetes' historical per-container CPU and memory requirements.

### Ephemeral storage

Ephemeral-storage requests and limits are accounted like native Kubernetes Pod quotas:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalResourceQuota
metadata:
  name: shared-ephemeral-storage
spec:
  namespaceSelectors:
    - matchLabels:
        company.example/storage-budget: shared
  quota:
    hard:
      ephemeral-storage: 100Gi
      requests.ephemeral-storage: 100Gi
      limits.ephemeral-storage: 200Gi
```

Define ephemeral-storage requests and limits on containers:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: worker
  namespace: solar-production
spec:
  containers:
    - name: worker
      image: example.com/worker:latest
      resources:
        requests:
          ephemeral-storage: 2Gi
        limits:
          ephemeral-storage: 4Gi
      volumeMounts:
        - name: cache
          mountPath: /cache
  volumes:
    - name: cache
      emptyDir:
        sizeLimit: 8Gi
```

An `emptyDir.sizeLimit` is a volume limit, not a Pod resource request. It does not add `8Gi` to ResourceQuota usage. Configure container `requests.ephemeral-storage` when storage must be reserved and counted.

### Object counts

Both legacy core-resource names and generic object-count names are supported.

```yaml
spec:
  quota:
    hard:
      pods: "100"
      services: "20"
      secrets: "50"
      count/configmaps: "50"
      count/deployments.apps: "30"
      count/horizontalpodautoscalers.autoscaling: "10"
```

Generic count syntax is:

```text
count/<plural-resource-name>.<api-group>
```

The API group is omitted for core resources:

```text
count/configmaps
count/pods
```

For grouped or custom resources, include the group:

```text
count/deployments.apps
count/jobs.batch
count/widgets.platform.example.com
```

Object creation is reserved through the same atomic ledger as compute resources. For example, if `services: 5` is shared by two namespaces and ten Services are created concurrently, only five admissions can succeed.

### Persistent storage

PVC accounting includes the native Kubernetes quota resource names:

```yaml
spec:
  quota:
    hard:
      persistentvolumeclaims: "20"
      requests.storage: 500Gi
      fast.storageclass.storage.k8s.io/persistentvolumeclaims: "10"
      fast.storageclass.storage.k8s.io/requests.storage: 250Gi
```

PVC storage-class resources, allocated storage, resize status, and supported `VolumeAttributesClass` scopes follow Kubernetes ResourceQuota behavior.

### Scopes and scope selectors

Native quota scopes can be used without Capsule-specific syntax:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalResourceQuota
metadata:
  name: high-priority-compute
spec:
  namespaceSelectors:
    - matchExpressions:
        - key: capsule.clastix.io/tenant
          operator: Exists
  quota:
    hard:
      requests.cpu: "20"
      requests.memory: 40Gi
    scopeSelector:
      matchExpressions:
        - scopeName: PriorityClass
          operator: In
          values: ["high"]
```

Pod scopes such as `Terminating`, `NotTerminating`, `BestEffort`, `NotBestEffort`, `PriorityClass`, and `CrossNamespacePodAffinity` are evaluated before usage is reserved.

## Operating

### Status

The status exposes the selected namespaces and observed usage:

```yaml
status:
  observedGeneration: 1
  namespaceCount: 2
  namespaces:
    - solar-production
    - solar-staging
  total:
    hard:
      requests.cpu: "8"
      requests.memory: 16Gi
    used:
      requests.cpu: "3"
      requests.memory: 6Gi
    available:
      requests.cpu: "5"
      requests.memory: 10Gi
  namespaceUsage:
    solar-production:
      used:
        requests.cpu: "2"
        requests.memory: 4Gi
    solar-staging:
      used:
        requests.cpu: "1"
        requests.memory: 2Gi
  conditions:
    - type: Ready
      status: "True"
      reason: Succeeded
      message: reconciled
```

`status.total.used` is observed native usage. Very recent admissions may still exist only as ledger reservations, so admission can correctly reject new work before the observed status or metrics reach the hard limit.

Useful commands:

```shell
kubectl get globalresourcequotas
kubectl get globalquota green-shared-compute -o yaml
kubectl get resourcequotas -A \
  -l projectcapsule.dev/global-resource-quota=green-shared-compute
kubectl get quantityledgers -n capsule-system \
  -l projectcapsule.dev/global-resource-quota=green-shared-compute \
  -o yaml
```

Managed native ResourceQuota objects and QuantityLedgers are implementation details. Do not edit or delete them directly.


### Atomic admission

Native `ResourceQuota.status.used` is eventually consistent. Reading the status and then allowing a request is insufficient because multiple requests can observe the same available capacity.

Global quota admission uses reservations:

1. The webhook finds every `GlobalResourceQuota` matching the request namespace.
2. The incoming object is decoded and evaluated once.
3. Only resources present in each quota's `hard` list are considered.
4. For updates, only the positive usage delta is reserved.
5. The webhook atomically adds the delta to the quota's `QuantityLedger` using Kubernetes optimistic concurrency.
6. Admission is denied if observed usage plus active reservations would exceed any hard limit.
7. The controller removes reservations as native `ResourceQuota.status.used` catches up.

This process is applied to every matching `GlobalResourceQuota`. If any matching quota rejects the request, admission is denied and reservations already made for that request are rolled back.

Dry-run requests are evaluated but do not persist reservations.

#### Readiness and failure behavior

Admission fails closed while a matching quota is not ready. The ledger must:

- Refer to the current `GlobalResourceQuota` UID.
- Have observed the current quota generation.
- Contain the request namespace.
- Be initialized from every selected native ResourceQuota.

The chart enables the webhook with `failurePolicy: Fail` by default:

```yaml
webhooks:
  hooks:
    globalresourcequotas:
      enabled: true
      failurePolicy: Fail
```

The webhook must observe namespaced create and update requests across API groups. Narrowing its webhook rules, namespace selector, object selector, or match conditions can create accounting gaps.

Reservations expire after two minutes if native usage never appears, for example when a later admission plugin rejects the object. A ledger accepts at most 1024 active reservations at one time.


### Updating a quota

Hard limits can be increased normally.

A hard resource cannot be reduced below currently allocated usage. It also cannot be removed while observed usage or active reservations for that resource are non-zero. Release the resources first, wait for status reconciliation, and then reduce or remove the limit.

When selectors or hard limits change, admission waits for the ledger to observe the new generation and selected namespace set. This prevents requests from being admitted against stale quota state.

If several `GlobalResourceQuota` objects select the same namespace, all matching quotas apply. A request must satisfy every matching hard limit and scope.

### Monitoring

The following Prometheus metrics are exposed:

| Metric | Labels | Description |
| --- | --- | --- |
| `capsule_global_resource_quota_condition` | `global_resource_quota`, `condition` | Current condition status, where true is `1`. |
| `capsule_global_resource_quota_limit` | `global_resource_quota`, `resource` | Shared hard limit. |
| `capsule_global_resource_quota_usage` | `global_resource_quota`, `resource` | Observed aggregate usage. |
| `capsule_global_resource_quota_available` | `global_resource_quota`, `resource` | Observed available capacity. |
| `capsule_global_resource_quota_usage_percentage` | `global_resource_quota`, `resource` | Aggregate usage as a percentage of the hard limit. |
| `capsule_global_resource_quota_namespace_usage` | `global_resource_quota`, `target_namespace`, `resource` | Observed usage per namespace. |
| `capsule_global_resource_quota_namespace_usage_percentage` | `global_resource_quota`, `target_namespace`, `resource` | Namespace usage as a percentage of the shared limit. |

Example alerts:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: capsule-global-resource-quota-alerts
spec:
  groups:
    - name: capsule-global-resource-quotas.rules
      rules:
        - alert: CapsuleGlobalResourceQuotaHighUsage
          expr: capsule_global_resource_quota_usage_percentage > 90
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: Global resource quota usage is high
            description: >-
              Resource {{ $labels.resource }} in GlobalResourceQuota
              {{ $labels.global_resource_quota }} is at {{ $value }} percent.

        - alert: CapsuleGlobalResourceQuotaNotReady
          expr: >-
            capsule_global_resource_quota_condition{condition="Ready"} == 0
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: Global resource quota is not ready
            description: >-
              GlobalResourceQuota {{ $labels.global_resource_quota }}
              has not been ready for ten minutes.
```


### Migration

### Troubleshooting

#### `QuantityLedger ... is not initialized`

The controller is waiting for every selected native ResourceQuota to report its hard and used status. Check:

```shell
kubectl get globalquota <name> -o yaml
kubectl get resourcequotas -A \
  -l projectcapsule.dev/global-resource-quota=<name>
kubectl get quantityledgers -n capsule-system \
  -l projectcapsule.dev/global-resource-quota=<name> \
  -o yaml
```

Also verify that Capsule can list the selected namespaces and reconcile ResourceQuota status.

#### `resource exceeds GlobalResourceQuota`

The denial lists only the resource limits that the request would exceed. Quantities use the same canonical formatting as Kubernetes, for example:

```text
resource exceeds GlobalResourceQuota "solar-shared-compute": limits.cpu (requested=1, current=8, projected=9, hard=8, exceededBy=1)
```

- `requested` is the additional usage introduced by this admission request.
- `current` is the usage already accounted for, including active admission reservations.
- `projected` is `current + requested`.
- `hard` is the configured limit.
- `exceededBy` is `projected - hard`.

Because `current` includes in-flight reservations, it can temporarily be higher than `status.total.used`.

#### `must specify requests.cpu ... for: <container>`

Kubernetes historically requires every regular and init container to declare CPU or memory resources when those resources are tracked by quota.

When supported Pod-level resources are present, Capsule follows Kubernetes and skips that legacy per-container requirement. Inspect the Pod or the controller's stored Pod template:

```shell
kubectl get deployment <name> -n <namespace> -o yaml
kubectl get replicaset -n <namespace> -l app=<label> -o yaml
```

An older ReplicaSet can continue reporting failed Pod creation events after a Deployment is updated with Pod-level resources. Confirm that the ReplicaSet named in the event actually contains `.spec.template.spec.resources`.

#### A deleted object still appears in usage

Deletes release capacity after native ResourceQuota status observes the deletion. The delay is normally short but is eventually consistent.

#### A namespace is unexpectedly selected

Inspect all entries under `namespaceSelectors`. Entries are ORed, and an empty label selector matches every namespace.
