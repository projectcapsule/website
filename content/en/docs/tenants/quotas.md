---
title: Quotas
weight: 4
description: >
  Strategies on granting quotas on tenant-basis
---

With help of Capsule, Bill, the cluster admin, can set and enforce resources quota and limits for Alice's tenant.

There are different elements, where quotas can be defined.

## Resource Quota

{{% alert title="Deprecated" color="info" %}}
This feature will be deprecated in a future release of Capsule. Instead use [Resource Pools](../resourcepools/) to handle any cases around distributed ResourceQuotas
{{% /alert %}}

With help of Capsule, Bill, the cluster admin, can set and enforce resources quota and limits for Alice's tenant.Set resources quota for each namespace in the Alice's tenant by defining them in the tenant spec:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  namespaceOptions:
    quota: 3
  resourceQuotas:
    scope: Tenant
    items:
    - hard:
        limits.cpu: "8"
        limits.memory: 16Gi
        requests.cpu: "8"
        requests.memory: 16Gi
    - hard:
        pods: "10"
```

The resource quotas above will be inherited by all the namespaces created by Alice. In our case, when Alice creates the namespace `solar-production`, Capsule creates the following resource quotas:

```yaml
kind: ResourceQuota
apiVersion: v1
metadata:
  name: capsule-solar-0
  namespace: solar-production
  labels:
    tenant: solar
spec:
  hard:
    limits.cpu: "8"
    limits.memory: 16Gi
    requests.cpu: "8"
    requests.memory: 16Gi
---
kind: ResourceQuota
apiVersion: v1
metadata:
  name: capsule-oil-1
  namespace: solar-production
  labels:
    tenant: solar
spec:
  hard:
    pods : "10"
```

Alice can create any resource according to the assigned quotas:

```bash
kubectl -n solar-production create deployment nginx --image nginx:latest --replicas 4
```

At namespace `solar-production` level, Alice can see the used resources by inspecting the status in ResourceQuota:

```bash
kubectl -n solar-production get resourcequota capsule-solar-1 -o yaml
...
status:
  hard:
    pods: "10"
    services: "50"
  used:
    pods: "4"
```

When defining ResourceQuotas you might want to consider distributing [LimitRanges](https://kubernetes.io/docs/concepts/policy/limit-range/) via [Tenant Replications](/docs/replications):

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: solar-limitranges
  namespace: solar-system
spec:
  resyncPeriod: 60s
  resources:
    - namespaceSelector:
        matchLabels:
          capsule.clastix.io/tenant: solar
      rawItems:
        - apiVersion: v1
          kind: LimitRange
          metadata:
            name: cpu-resource-constraint
          spec:
            limits:
            - default: # this section defines default limits
                cpu: 500m
              defaultRequest: # this section defines default requests
                cpu: 500m
              max: # max and min define the limit range
                cpu: "1"
              min:
                cpu: 100m
              type: Container
```

### Tenant Scope

> This approach might lead to resource over consumption. Currently we don't have a way to consistently assure the resource quota at tenant level. See issues [issue/49](https://github.com/projectcapsule/capsule/issues/49)


By setting enforcement at tenant level, i.e. `spec.resourceQuotas`.scope=Tenant, Capsule aggregates resources usage for all namespaces in the tenant and adjusts all the `ResourceQuota` usage as aggregate. In such case, Alice can check the used resources at the tenant level by inspecting the annotations in ResourceQuota object of any namespace in the tenant:

```bash
kubectl -n solar-production get resourcequotas capsule-solar-1 -o yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  annotations:
    quota.capsule.clastix.io/used-pods: "4"
    quota.capsule.clastix.io/hard-pods: "10"
...
```

or

```bash
kubectl -n solar-development get resourcequotas capsule-solar-1 -o yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  annotations:
    quota.capsule.clastix.io/used-pods: "4"
    quota.capsule.clastix.io/hard-pods: "10"
...
```

When the aggregate usage for all namespaces crosses the hard quota, then the native ResourceQuota Admission Controller in Kubernetes denies Alice's request to create resources exceeding the quota:

```bash
kubectl -n solar-development create deployment nginx --image nginx:latest --replicas 10
```

Alice cannot schedule more pods than the admitted at tenant aggregate level.

```bash
kubectl -n solar-development get pods
NAME                     READY   STATUS    RESTARTS   AGE
nginx-55649fd747-6fzcx   1/1     Running   0          12s
nginx-55649fd747-7q6x6   1/1     Running   0          12s
nginx-55649fd747-86wr5   1/1     Running   0          12s
nginx-55649fd747-h6kbs   1/1     Running   0          12s
nginx-55649fd747-mlhlq   1/1     Running   0          12s
nginx-55649fd747-t48s5   1/1     Running   0          7s
```

and

```bash
kubectl -n solar-production get pods
NAME                     READY   STATUS    RESTARTS   AGE
nginx-55649fd747-52fsq   1/1     Running   0          22m
nginx-55649fd747-9q8n5   1/1     Running   0          22m
nginx-55649fd747-r8vzr   1/1     Running   0          22m
nginx-55649fd747-tkv7m   1/1     Running   0          22m

```

### Namespace Scope

By setting enforcement at the namespace level, i.e. `spec.resourceQuotas.scope=Namespace`, Capsule does not aggregate the resources usage and all enforcement is done at the namespace level.


## Namespace Quotas

The cluster admin, can control how many namespaces Alice, creates by setting a quota in the tenant manifest `spec.namespaceOptions.quota`:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  namespaceOptions:
    quota: 3
```

Alice can create additional namespaces according to the quota:

```bash
kubectl create ns solar-development
kubectl create ns solar-test
```

While Alice creates namespaces, the Capsule controller updates the status of the tenant so Bill, the cluster admin, can check the status:

```bash
$ kubectl describe tenant solar
...
status:
  Namespaces:
    solar-development
    solar-production
    solar-test
  Size:   3 # current namespace count
  State:  Active
...
```

Once the namespace quota assigned to the tenant has been reached, Alice cannot create further namespaces:

```bash
$ kubectl create ns solar-training
Error from server (Cannot exceed Namespace quota: please, reach out to the system administrators):
admission webhook "namespace.capsule.clastix.io" denied the request.
```

The enforcement on the maximum number of namespaces per Tenant is the responsibility of the Capsule controller via its Dynamic Admission Webhook capability.



## Custom Resources

> This feature is still in an alpha stage and requires a high amount of computing resources due to the dynamic client requests.

Kubernetes offers by default `ResourceQuota` resources, aimed to limit the number of basic primitives in a Namespace.

Capsule already provides the sharing of these constraints across the Tenant Namespaces, however, limiting the amount of namespaced Custom Resources instances is not upstream-supported.

Starting from Capsule v0.1.1, this can be done using a special annotation in the Tenant manifest.

Imagine the case where a Custom Resource named `mysqls` in the API group `databases.acme.corp/v1` usage must be limited in the Tenant `solar`: this can be done as follows.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
  annotations:
    quota.resources.capsule.clastix.io/mysqls.databases.acme.corp_v1: "3"
spec:
  additionalRoleBindings:
  - clusterRoleName: mysql-namespace-admin
    subjects:
      - kind: User
        name: alice
  owners:
  - name: alice
    kind: User
```

The Additional Role Binding referring to the Cluster Role mysql-namespace-admin is required to let Alice [manage their Custom Resource instances](/docs/tenants/permissions/#custom-resources).

The pattern for the quota.resources.capsule.clastix.io annotation is the following: 

* `quota.resources.capsule.clastix.io/${PLURAL_NAME}.${API_GROUP}_${API_VERSION}`

You can figure out the required fields using `kubectl api-resources`.

When alice will create a MySQL instance in one of their Tenant Namespace, the Cluster Administrator can easily retrieve the overall usage.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
  annotations:
    quota.resources.capsule.clastix.io/mysqls.databases.acme.corp_v1: "3"
    used.resources.capsule.clastix.io/mysqls.databases.acme.corp_v1: "1"
spec:
  owners:
  - name: alice
    kind: User
```




## Node Pools

Bill, the cluster admin, can dedicate a pool of worker nodes to the oil tenant, to isolate the tenant applications from other noisy neighbors. To achieve this approach use [NodeSelectors](/docs/tenants/enforcement#node-selectors).
```yaml
