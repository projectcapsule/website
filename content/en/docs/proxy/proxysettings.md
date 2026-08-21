---
title: ProxySettings
description: >
  Configure proxy settings for your tenants
date: 2024-02-20
weight: 2
---

The configuration for the Proxy is also declarative via CRDs. This allows both Administrators and Tenant Owners to create flexible rules.

## GlobalProxySettings

`GlobalProxySettings` grants selected subjects read access to labelled, cluster-scoped resources through Capsule Proxy. A subject does not have to own a Tenant, which makes this resource useful for shared infrastructure and project-wide views of resources such as PersistentVolumes, StorageClasses, ResourcePools, and Capsule global quota resources.

The `ProxyClusterScoped` feature gate must be enabled on Capsule Proxy:

```yaml
options:
  extraArgs:
  - --feature-gates=ProxyClusterScoped=true
```

These permissions exist only when a request is sent through Capsule Proxy. `GlobalProxySettings` does not create Kubernetes `ClusterRole` or `ClusterRoleBinding` objects, so the same subject may still receive `Forbidden` when connecting directly to the Kubernetes API server.

### Subjects and resources

Every entry in `spec.rules` contains one or more `subjects` and `clusterResources`. Supported subject kinds are `User`, `Group`, and `ServiceAccount`. Subjects must also be admitted by the Capsule Proxy user and group configuration.

`apiGroups` and `resources` use plural resource names and follow the same general conventions as Kubernetes [`ClusterRole` rules](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#api-overview):

- Use an empty string (`""`) for the core Kubernetes API group.
- Use the API group name, such as `capsule.clastix.io`, for grouped APIs.
- Use `"*"` to match every discovered API group or resource.
- Only cluster-scoped resources can be selected. For example, `persistentvolumes` are supported, while namespaced `persistentvolumeclaims` are not.

### Supported operations

`GlobalProxySettings` supports only `List` and `Get`. Mutation operations such as `Create`, `Update`, `Patch`, and `Delete` must be granted with native Kubernetes RBAC and are not added by Capsule Proxy.

The effective mappings are:

| Configured `operations` | Effective Kubernetes verbs | Request shape |
| --- | --- | --- |
| Omitted | `list`, `get` | Collection and named-resource reads |
| `[List]` | `list`, `get` | Collection and named-resource reads |
| `[Get]` | `get` | Named-resource reads only |
| `[List, Get]` | `list`, `get` | Collection and named-resource reads |

`List` also includes `Get` for backward compatibility. Older `v1beta1` configurations could only specify `List`, while Capsule Proxy already intercepted both collection and named-resource routes. Existing rules therefore do not need to be rewritten to retain named-resource access.

Although both operations use the HTTP `GET` method, Kubernetes treats them as different verbs:

- `GET /api/v1/persistentvolumes` is the Kubernetes `list` verb.
- `GET /api/v1/persistentvolumes/<name>` is the Kubernetes `get` verb.
- `GET /apis/capsule.clastix.io/v1beta2/tenantowners` is `list`.
- `GET /apis/capsule.clastix.io/v1beta2/tenantowners/<name>` is `get`.

For a collection request, Capsule Proxy combines the applicable selectors and adds them to the request as a label selector. For a named-resource request, the proxy first resolves the object and grants access only when its labels match an applicable selector. A rule never grants access to objects outside its selector.

### Default LIST and GET example

When `operations` is omitted, both collection and named-resource reads are enabled. The following rule lets Alice and members of `oidc:org:platform` list solar PersistentVolumes and fetch a single matching PersistentVolume by name:

```yaml
apiVersion: capsule.clastix.io/v1beta1
kind: GlobalProxySettings
metadata:
  name: solar-proxy-settings
spec:
  rules:
  - subjects:
    - kind: User
      name: alice
    - kind: Group
      name: oidc:org:platform
    clusterResources:
    - apiGroups:
      - ""
      resources:
      - persistentvolumes
      selector:
        matchLabels:
          capsule.clastix.io/tenant: solar
```

For example, both of these requests are covered:

```bash
kubectl get persistentvolumes
kubectl get persistentvolume pvc-0574499c-f01b-4a53-85f1-ddb002de9cae
```

The PersistentVolume itself must contain the selected label:

```yaml
metadata:
  labels:
    capsule.clastix.io/tenant: solar
```

### GET-only example

Use `Get` without `List` when a subject may retrieve a known object but must not enumerate the collection:

```yaml
apiVersion: capsule.clastix.io/v1beta1
kind: GlobalProxySettings
metadata:
  name: solar-proxy-settings
spec:
  rules:
  - subjects:
    - kind: User
      name: alice
    clusterResources:
    - apiGroups:
      - capsule.clastix.io
      resources:
      - tenantowners
      operations:
      - Get
      selector:
        matchLabels:
          projectcapsule.dev/tenant: solar
```

This adds permission for `kubectl get tenantowner alice` when that object matches the selector, but it does not add permission for `kubectl get tenantowners`. Native Kubernetes RBAC may still grant additional access independently.

### Multiple resources and selectors

A rule can select several resources, and a `GlobalProxySettings` can contain several rules. The following legacy-style `List` declarations enable both LIST and GET because of the compatibility mapping described above:

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
      - capsule.clastix.io
      resources:
      - resourcepools
      - globalcustomquotas
      - globalresourcequotas
      - tenantowners
      operations:
      - List
      selector:
        matchLabels:
          projectcapsule.dev/tenant: green
    - apiGroups:
      - kyverno.io
      resources:
      - "*"
      operations:
      - List
      - Get
      selector:
        matchLabels:
          app.kubernetes.io/type: dev
```

## ProxySetting

A `ProxySetting` is created in a namespace of a tenant, if it's not in a namespace of a tenant it's not regarded as valid. With the `ProxySetting` Tenant Owners can further improve the experience for their fellow tenant users.

```yaml
apiVersion: capsule.clastix.io/v1beta1
kind: ProxySetting
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

The following operations belong to the legacy `proxySettings` field shown in this section. They are separate from the `GlobalProxySettings` `clusterResources.operations` mappings documented above.

Each Resource kind can be granted with several verbs, such as:

  * `List`
  * `Update`
  * `Delete`


### Special routes for kubectl describe

When issuing a kubectl describe node, some other endpoints are put in place:

* `api/v1/pods?fieldSelector=spec.nodeName%3D{name}`
* `/apis/coordination.k8s.io/v1/namespaces/kube-node-lease/leases/{name}`

These are mandatory to retrieve the list of the running Pods on the required node and provide info about its lease status.
