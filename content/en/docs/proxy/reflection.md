---
title: Reflection
description: >
   Leverage the RoleBinding Reflector to grant LIST capabilities to non-owners across namespaces.
date: 2024-02-20
weight: 3
---

Namespace RoleBinding reflection allows users and groups to list every Namespace in which they are referenced by a RoleBinding. The user does not need to be a /docs/operating/architecture/#tenant-owners.

Enable the reflector in the Helm values:

```yaml
options:
  roleBindingReflector: true
```

Alternatively, pass the corresponding command-line argument:

```shell
  --enable-reflector=true
```

## Namespaces

The functionality of allowing access to other `Namespaces` is achieved by enabling the RoleBinding Reflector, which allows the Capsule Proxy to list the namespaces where a rolebinding mentions a user. First to make use of this feature you must enable it for the proxy:
For example, the following Role and RoleBinding allow alice to list Pods in the green-test Namespace. Because alice is referenced by the RoleBinding, Namespace reflection also allows her to see green-test when listing Namespaces through Capsule Proxy:

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: green-test
rules:
  - apiGroups:
      - ""
    resources:
      - pods
    verbs:
      - list
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: alice-pod-reader
  namespace: green-test
subjects:
  - kind: User
    name: alice
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

Namespace reflection supports the following subject kinds:

  - User
  - Group
  - ServiceAccount

The RoleBinding does not require a special label for Namespace reflection. All RoleBindings mentioning the requesting subject are considered. The label reflection.proxy.projectcapsule.dev/enabled: "true" is only required when reflecting thereferenced Role or ClusterRole permissions to other namespaced resource LIST requests.

### GlobalProxySettings

 The same behavior can be achieved by using [`GlobalProxySettings`](/docs/proxy/proxysettings/#globalproxysettings) to enable further listing of `Namespace` resources. Note that this must use the label `"kubernetes.io/metadata.name"`. This provides the user alice the ability to list the `Namespaces` `green-test` and `green-prod` without being [Tenant Owner](/docs/operating/architecture/#tenant-owners) or having any other permissions on the `Tenant`:
```yaml
apiVersion: capsule.clastix.io/v1beta1
kind: GlobalProxySettings
metadata:
  name: green-tenant-proxy-settings
spec:
  rules:
    - subjects:
        - kind: User
          name: alice
      clusterResources:
        - apiGroups:
            - ""
          resources:
            - "namespaces"
          selector:
            matchExpressions:
              - key: "kubernetes.io/metadata.name"
                operator: In
                values:
                - green-test
                - green-prod
```

## Namespaced Items

For all namespaced items it's possible to grant users `LIST` permissions within any `Tenant` namespace. They don't have to be a [Tenant Owner](/docs/operating/architecture/#tenant-owners) or anything. This is useful for example for operators, where they might also want to see all pods but are not directly owner on any `Tenant`. Reflection is resolved based on **`RoleBindings`** and the associated `Roles` and `ClusterRoles` (recommended).

The `Role` or `ClusterRole` must provide `LIST` permissions to the allowed resource(s). The `RoleBindings` considered for reflection must always use the label `reflection.proxy.projectcapsule.dev/enabled: "true"` to be considered for reflection. The following example shows how to grant a user `LIST` permissions on all pods within any `Tenant` namespace:

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: custom:pod-viewer
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    reflection.proxy.projectcapsule.dev/enabled: "true"
  name: custom-pod-viewer
  namespace: green-test
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: custom:pod-viewer
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: alice
```

This grants the user `alice` the ability to `LIST` all pods within any `Tenant's` namespace. The `RoleBinding` must be created in each namespace where you want to grant this permission, and it must reference a `Role` or `ClusterRole` that has the appropriate permissions.

With this `ClusterRole` you can grant `LIST` permission to all namespaced resources from the core API:

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: custom:proxy-viewer
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    reflection.proxy.projectcapsule.dev/enabled: "true"
  name: custom-viewer
  namespace: green-test
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: custom:proxy-viewer
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: alice
```

### Provision RoleBindings

 Provisioning the `RoleBindings` via [Tenant Rules](/docs/tenants/rules/permissions/#bindings) is the best way to ensure that the `RoleBindings` are created in all namespaces of a `Tenant` and also in any new namespace created within the `Tenant`. The following example shows how to provision a `RoleBinding` for the user `joe` in all namespaces of the `solar` tenant:
```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  rules:
    - permissions:
        bindings:
          - clusterRoleName: 'custom:proxy-viewer'
            subjects:
            - apiGroup: rbac.authorization.k8s.io
              kind: User
              name: joe
            labels:
              reflection.proxy.projectcapsule.dev/enabled: "true"
```

 By default, any user can add further `RoleBindings` with the `reflection.proxy.projectcapsule.dev/enabled: "true"` label to any `RoleBinding`. To prevent that, you can deny it with another [Enforcement rule](/docs/rules/enforcement/metadata):
```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  rules:
    - permissions:
        bindings:
          - clusterRoleName: 'custom:proxy-viewer'
            subjects:
            - apiGroup: rbac.authorization.k8s.io
              kind: User
              name: joe
            labels:
              reflection.proxy.projectcapsule.dev/enabled: "true"
      enforce:
        action: deny
        metadata:
          - apiGroups:
              - "rbac.authorization.k8s.io/v1"
            kinds:
              - "RoleBinding"
            labels:
              reflection.proxy.projectcapsule.dev/enabled:
                values:
                  - exp: ".*"
```
