---
title: ProxySettings
description: >
  Configure proxy settings for your tenants
date: 2024-02-20
weight: 2
---

The configuration for the Proxy is also declarative via CRDs. This allows both Administrators and Tenant Owners to create flexible rules.

## GlobalProxysettings

As an administrator, you might have the requirement to allow users to query cluster-scoped resources which are not directly linked to a tenant or anything like that. In that case you grant cluster-scoped `LIST` privileges to any subject, no matter what their tenant association is. For example:

```yaml 
apiVersion: capsule.clastix.io/v1beta1
kind: GlobalProxySettings
metadata:
  name: global-proxy-settings
spec:
  rules:
  - subjects:
    - kind: User
      name: alice
    clusterResources:
    - apiGroups:
      - "*"
      resources:
      - "*"
      operations:
      - List
      selector:
        matchLabels:
          app.kubernetes.io/type: dev
```

With this rule the `User` `alice` can list any cluster-scoped resource which match the `selector` condition. The `apiGroups` and `resources` work the same as known from Kubernetes [`ClusterRoles`](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#api-overview). All of these are valid expressions:


```yaml 
apiVersion: capsule.clastix.io/v1beta1
kind: GlobalProxySettings
metadata:
  name: global-proxy-settings
spec:
  rules:
  - subjects:
    - kind: User
      name: alice
    clusterResources:
    - apiGroups:
      - ""
      resources:
      - "pods"
      operations:
      - List
      selector:
        matchLabels:
          app.kubernetes.io/type: dev
    - apiGroups:
      - "kyverno.io/v1"
      resources:
      - "*"
      operations:
      - List
      selector:
        matchLabels:
          app.kubernetes.io/type: dev
```

A powerful tool to enhance the user-experience for all your users.

## Proxysettings

`ProxySettings` are created in a namespace of a tenant, if it's not in a namespace of a tenant it's not regarded as valid. With the `ProxySettings` Tenant Owners can further improve the experience for their fellow tenant users.


```yaml
apiVersion: capsule.clastix.io/v1beta1
kind: ProxySettings
metadata:
  name: solar-proxy
  namespace: solar-prod
spec:
  subjects:
  - kind: User
    name: alice
    proxySettings:
    - kind: IngressClasses
      operations:
      - List
```

### Primitives

> This will be refactored

> Namespaces are treated specially. A users can list the namespaces they own, but they cannot list all the namespaces in the cluster. You can't define additional selectors.

The proxy setting kind is an enum accepting the supported resources:

  * **Nodes**: Based on the [NodeSelector](/docs/tenants/enforcement/#nodeselector) and the Scheduling Expressions nodes can be listed
  * **[StorageClasses](/docs/tenants/enforcement/#storageclasses)**: Perform actions on the allowed StorageClasses for the tenant
  * **[IngressClasses](/docs/tenants/enforcement/#ingressclasses)**: Perform actions on the allowed IngressClasses for the tenant
  * **[PriorityClasses](/docs/tenants/enforcement/#priorityclasses)**: Perform actions on the allowed PriorityClasses for the tenant
  PriorityClasses
  * **[RuntimeClasses](/docs/tenants/enforcement/#runtimeclasses)**: Perform actions on the allowed RuntimeClasses for the tenant
  * **[PersistentVolumes](/docs/tenants/enforcement/#persistentvolumes)**: Perform actions on the PersistentVolumes owned by the tenant

Each Resource kind can be granted with several verbs, such as:

  * `List`
  * `Update`
  * `Delete`


### Special routes for kubectl describe

When issuing a kubectl describe node, some other endpoints are put in place:

* `api/v1/pods?fieldSelector=spec.nodeName%3D{name}`
* `/apis/coordination.k8s.io/v1/namespaces/kube-node-lease/leases/{name}`

These are mandatory to retrieve the list of the running Pods on the required node and provide info about its lease status.
