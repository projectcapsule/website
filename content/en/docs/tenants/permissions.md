---
title: Permissions
weight: 3
description: >
  Grant permissions for tenants
---

## Ownership

Capsule introduces the principal, that tenants must have owners ([Tenant Owners](/docs/operating/architecture/#tenant-owners)). The owner of a tenant is a user or a group of users that have the right to create, delete, and manage the [tenant's namespaces](/docs/tenants/namespaces) and other tenant resources. However an owner does not have the permissions to manage the tenants they are owner of. This is still done by cluster-administrators.

At any time you are able to verify which users or groups are owners of a tenant by checking the `owners` field of the Tenant status subresource:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
...
status:
  owners:
  - clusterRoles:
    - admin
    - capsule-namespace-deleter
    kind: Group
    name: oidc:org:devops:a
  - clusterRoles:
    - admin
    - capsule-namespace-deleter
    - mega-admin
    - controller
    kind: ServiceAccount
    name: system:serviceaccount:capsule:controller
  - clusterRoles:
    - admin
    - capsule-namespace-deleter
    kind: User
    name: alice
```

To explain these entries, let's inspect one of them:

* `kind`: It can be [User](#users), [Group](#groups) or [ServiceAccount](#serviceaccounts)
* `name`: Is the reference name of the user, group or serviceaccount we want to bind
* `clusterRoles`: ClusterRoles which are bound for each namespace of teh tenant to the owner. By default, Capsule assigns `admin` and `capsule-namespace-deleter` roles to each owner, but you can customize them as explained in [Owner Roles](#owner-roles) section.

With this information available you


### Tenant Owners

Tenant Owners can be declared as dedicated cluster scoped Resources called `TenantOwner`. This allows the cluster admin to manage the ownership of tenants in a more flexible way, for example by adding labels and annotations to the `TenantOwner` resources.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: TenantOwner
metadata:
  labels:
    team: devops
  name: devops
spec:
  kind: Group
  name: "oidc:org:devops:a"
```

This `TenantOwner` can now be matched by any tenant. Essentially we define on a per tenant basis which `TenantOwners` should be owners of the tenant (Each item under `spec.permissions.matchOwners` is understood as `OR` selection.):

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  labels:
    kubernetes.io/metadata.name: solar
  name: solar
spec:
  permissions:
    matchOwners:
    - matchLabels:
        team: devops
    - matchLabels:
        customer: x
```

Since the ownership is now loosely coupled, all `TenantOwners` matching the given labels will be owners of the tenant. We can verify this via the `.status.owners` field of the Tenant resource:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
...
status:
  owners:
  - clusterRoles:
    - admin
    - capsule-namespace-deleter
    kind: Group
    name: oidc:org:devops:a
  - clusterRoles:
    - admin
    - capsule-namespace-deleter
    kind: User
    name: alice
```

This can also be combined with direct owner declarations. In the example, both `alice` user and all `TenantOwners` with label `team: devops` and `TenantOwners` with label `customer: x` will be owners of the `solar` tenant.

```yaml
```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  labels:
    kubernetes.io/metadata.name: oil
  name: solar
spec:
  owners:
  - clusterRoles:
    - admin
    - capsule-namespace-deleter
    kind: User
    name: alice
  - clusterRoles:
    - admin
    - capsule-namespace-deleter
    kind: ServiceAccount
    name: system:serviceaccount:capsule:controller
  permissions:
    matchOwners:
    - matchLabels:
        team: devops
    - matchLabels:
        customer: x
```

If we create a `TenantOwner` where the `.spec.name` and `.spec.kind` matches one of the `owners` declared in the tenant, the entries wille be merged. That's mainly relevant for the [clusterRoles](#owner-roles):

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: TenantOwner
metadata:
  labels:
    customer: x
  name: controller
spec:
  kind: ServiceAccount
  name: "system:serviceaccount:capsule:controller"
  clusterRoles:
    - "mega-admin"
    - "controller"
```

Again we can verify the resulting owners via the `.status.owners` field of the Tenant resource:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
...
status:
  owners:
  - clusterRoles:
    - admin
    - capsule-namespace-deleter
    kind: Group
    name: oidc:org:devops:a
  - clusterRoles:
    - admin
    - capsule-namespace-deleter
    - mega-admin
    - controller
    kind: ServiceAccount
    name: system:serviceaccount:capsule:controller
  - clusterRoles:
    - admin
    - capsule-namespace-deleter
    kind: User
    name: alice
```

We. can see that the `system:serviceaccount:capsule:controller` ServiceAccount now has additional `mega-admin` and `controller` roles assigned.

### Users

**Bill**, the cluster admin, receives a new request from Acme Corp's CTO asking for a new `Tenant` to be onboarded and Alice user will be the `TenantOwner`. Bill then assigns Alice's identity of alice in the Acme Corp. identity management system. Since Alice is a `TenantOwner`, Bill needs to assign alice the Capsule group defined by --capsule-user-group option, which defaults to `projectcapsule.dev`.

To keep things simple, we assume that Bill just creates a client certificate for authentication using X.509 Certificate Signing Request, so Alice's certificate has `"/CN=alice/O=projectcapsule.dev"`.

**Bill** creates a new `Tenant` solar in the CaaS management portal according to the `Tenant`'s profile:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
```

**Bill** checks if the new `Tenant` is created and operational:

```bash
kubectl get tenant solar
NAME   STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR   AGE
solar    Active                     0                                 33m
```

> Note that namespaces are not yet assigned to the new `Tenant`. The `Tenant` owners are free to create their namespaces in a self-service fashion and without any intervention from Bill.

Once the new `Tenant` solar is in place, Bill sends the login credentials to Alice. Alice can log in using her credentials and check if she can create a namespace

```bash
kubectl auth can-i create namespaces
yes
```

or even delete the namespace

```bash
kubectl auth can-i delete ns -n solar-production
yes
```

However, cluster resources are not accessible to Alice

```bash
kubectl auth can-i get namespaces
no

kubectl auth can-i get nodes
no

kubectl auth can-i get persistentvolumes
no
```

including the `Tenant` resources


```
kubectl auth can-i get tenants
no
```

### Groups

In the example above, Bill assigned the ownership of solar `Tenant` to alice user. If another user, e.g. Bob needs to administer the solar `Tenant`, Bill can assign the ownership of solar `Tenant` to such user too:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  - name: bob
    kind: User
```

However, it's more likely that Bill assigns the ownership of the solar `Tenant` to a group of users instead of a single one, especially if you use [OIDC Authentication](/docs/operating/authentication/#oidc). Bill creates a new group account solar-users in the Acme Corp. identity management system and then he assigns Alice and Bob identities to the solar-users group.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: solar-users
    kind: Group
```

With the configuration above, any user belonging to the `solar-users` group will be the owner of the solar `Tenant` with the same permissions of Alice. For example, Bob can log in with his credentials and issue

```bash
kubectl auth can-i create namespaces
yes
```

All the groups you want to promot to `TenantOwners` must be part of the Group Scope. You have to add `solar-users` to the CapsuleConfiguration [Group Scope](#group-scope) to make it work.

### ServiceAccounts

You can use the Group subject to grant ServiceAccounts the ownership of a `Tenant`. For example, you can create a group of ServiceAccounts and assign it to the `Tenant`:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: system:serviceaccount:tenant-system:robot
    kind: ServiceAccount
```

Bill can create a ServiceAccount called robot, for example, in the `tenant-system` namespace and leave it to act as `TenantOwner` of the solar `Tenant`

```shell
kubectl --as system:serviceaccount:tenant-system:robot --as-group projectcapsule.dev auth can-i create namespaces
yes
```

since each service account in a namespace is a member of following group:

```shell
system:serviceaccounts:{service-account-namespace}
```

You have to add `system:serviceaccounts:{service-account-namespace}` to the CapsuleConfiguration [Group Scope](/docs/operating/setup/configuration/#usergroups) or `system:serviceaccounts:{service-account-namespace}:{service-account-name}` to the CapsuleConfiguration [User Scope](/docs/operating/setup/configuration/#usergroups) to make it work.

### ServiceAccount Promotion

Within a `Tenant`, a ServiceAccount can be promoted to a `TenantOwner`. For example, Alice can create a ServiceAccount called robot in the solar `Tenant` and promote it to be a `TenantOwner` (This requires Alice to be an owner of the `Tenant` as well):

```yaml
kubectl label sa gitops-reconcile -n green-test owner.projectcapsule.dev/promote=true --as alice --as-group projectcapsule.dev
```

Now the ServiceAccount robot can create namespaces in the solar `Tenant`:

```bash
kubectl create ns green-valkey--as system:serviceaccount:green-test:gitops-reconcile
```

To revoke the promotion, Alice can just remove the label:

```yaml
kubectl label sa gitops-reconcile -n green-test owner.projectcapsule.dev/promote-  --as alice --as-group projectcapsule.dev
```

This feature must be enabled in the [CapsuleConfiguration](/docs/operating/setup/configuration/#allowserviceaccountpromotion).

### Owner Roles

By default, all `TenantOwners` will be granted with two ClusterRole resources using the RoleBinding API:

1. `admin`: the Kubernetes default one, admin, that grants most of the namespace scoped resources
2. `capsule-namespace-deleter`: a custom clusterrole, created by Capsule, allowing to delete the created namespaces

You can observe this behavior when you get the `Tenant` solar:

```yaml
$ kubectl get tnt solar -o yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  labels:
    kubernetes.io/metadata.name: solar
  name: solar
spec:
  ingressOptions:
    hostnameCollisionScope: Disabled
  limitRanges: {}
  networkPolicies: {}
  owners:
  # -- HERE -- #
  - clusterRoles:
    - admin
    - capsule-namespace-deleter
    kind: User
    name: alice
    labels:
      projectcapsule.dev/sample: "true"
    annotations:
      projectcapsule.dev/sample: "true"
  resourceQuotas:
    scope: Tenant
status:
  namespaces:
  - solar-production
  - solar-system
  size: 2
  state: Active
```

In the example below, assuming the `TenantOwner` creates a namespace solar-production in `Tenant` solar, you'll see the Role Bindings giving the `TenantOwner` full permissions on the `Tenant` namespaces:

```bash
$ kubectl get rolebinding -n solar-production
NAME                                        ROLE                                    AGE
capsule-solar-0-admin                       ClusterRole/admin                       111m
capsule-solar-1-capsule-namespace-deleter   ClusterRole/capsule-namespace-deleter   111m
```

When Alice creates the namespaces, the Capsule controller assigns to Alice the following permissions, so that Alice can act as the admin of all the `Tenant` namespaces:

```bash
$ kubectl get rolebinding -n solar-production -o yaml
apiVersion: v1
items:
- apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    creationTimestamp: "2024-02-25T14:02:36Z"
    labels:
      capsule.clastix.io/role-binding: 8fb969aaa7a67b71
      capsule.clastix.io/tenant: solar
      projectcapsule.dev/sample: "true"
    annotations:
      projectcapsule.dev/sample: "true"
    name: capsule-solar-0-admin
    namespace: solar-production
    ownerReferences:
    - apiVersion: capsule.clastix.io/v1beta2
      blockOwnerDeletion: true
      controller: true
      kind: Tenant
      name: solar
      uid: 1e6f11b9-960b-4fdd-82ee-7cd91a2db052
    resourceVersion: "2980"
    uid: 939da5ae-7fec-4300-8db2-223d3049b43f
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: admin
  subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: alice
- apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    creationTimestamp: "2024-02-25T14:02:36Z"
    labels:
      capsule.clastix.io/role-binding: b8822dde20953fb1
      capsule.clastix.io/tenant: solar
      projectcapsule.dev/sample: "true"
    annotations:
      projectcapsule.dev/sample: "true"
    name: capsule-solar-1-capsule-namespace-deleter
    namespace: solar-production
    ownerReferences:
    - apiVersion: capsule.clastix.io/v1beta2
      blockOwnerDeletion: true
      controller: true
      kind: Tenant
      name: solar
      uid: 1e6f11b9-960b-4fdd-82ee-7cd91a2db052
    resourceVersion: "2982"
    uid: bbb4cd79-ce0d-41b0-a52d-dbed71a9b48a
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: capsule-namespace-deleter
  subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: alice
kind: List
metadata:
  resourceVersion: ""
```

In some cases, the cluster admin needs to narrow the range of permissions assigned to `TenantOwners` by assigning a Cluster Role with less permissions than above. Capsule supports the dynamic assignment of any ClusterRole resources for each `TenantOwner`.

For example, assign user Joe the `Tenant` ownership with only [view](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) permissions on `Tenant` namespaces:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  - name: joe
    kind: User
    clusterRoles:
      - view
```

you'll see the new Role Bindings assigned to Joe:

```bash
$ kubectl get rolebinding -n solar-production
NAME                                        ROLE                                    AGE
capsule-solar-0-admin                       ClusterRole/admin                       114m
capsule-solar-1-capsule-namespace-deleter   ClusterRole/capsule-namespace-deleter   114m
capsule-solar-2-view                        ClusterRole/view                        1s
```

so that Joe can only view resources in the `Tenant` namespaces:

```bash
kubectl --as joe --as-group projectcapsule.dev auth can-i delete pods -n solar-production
no
```

> Please, note that, despite created with more restricted permissions, a `TenantOwner` can still create namespaces in the `Tenant` because he belongs to the `projectcapsule.dev` group. If you want a user not acting as `TenantOwner`, but still operating in the `Tenant`, you can assign [additional RoleBindings](#additional-rolebindings) without assigning him the `Tenant` ownership.

Custom ClusterRoles are also supported. Assuming the cluster admin creates:

```yaml
kubectl apply -f - << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tenant-resources
rules:
- apiGroups: ["capsule.clastix.io"]
  resources: ["tenantresources"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF
```

These permissions can be granted to Joe

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  - name: joe
    kind: User
    clusterRoles:
      - view
      - tenant-resources
```

For the given configuration, the resulting RoleBinding resources are the following ones:

```bash
$ kubectl -n solar-production get rolebindings
NAME                                              ROLE                                            AGE
capsule-solar-0-admin                               ClusterRole/admin                               90s
capsule-solar-1-capsule-namespace-deleter           ClusterRole/capsule-namespace-deleter           90s
capsule-solar-2-view                                ClusterRole/view                                90s
capsule-solar-3-tenant-resources                    ClusterRole/prometheus-servicemonitors-viewer   25s
```

#### Role Aggregation

Sometimes the `admin` role is missing certain permissions. You can [aggregate](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#aggregated-clusterroles) the `admin` role with a custom role, for example, `gateway-resources`:

```yaml
kubectl apply -f - << EOF
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: gateway-resources
  labels:
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
rules:
- apiGroups: ["gateway.networking.k8s.io"]
  resources: ["gateways"]
  verbs: ["*"]
EOF
```

### Proxy Owner Authorization

> This feature will be deprecated in a future release of Capsule. Instead use [ProxySettings](docs/proxy/proxysettings/)


When you are using the [Capsule Proxy](/docs/proxy/proxysettings/#proxysettings), the tenant owner can list the cluster-scoped resources. You can control the permissions to cluster scoped resources by defining `proxySettings` for a tenant owner.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: joe
    kind: User
    clusterRoles:
      - view
      - tenant-resources
```

## Additional Rolebindings

With `Tenant` rolebindings you can distribute namespaced rolebindings to all namespaces which are assigned to a namespace. Essentially it is then ensured the defined rolebindings are present and reconciled in all namespaces of the `Tenant`. This is useful if users should have more insights on `Tenant` basis. Let's look at an example.

Assuming a cluster-administrator creates the following clusterRole:

```yaml
kubectl apply -f - << EOF
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: prometheus-servicemonitors-viewer
rules:
- apiGroups: ["monitoring.coreos.com"]
  resources: ["servicemonitors"]
  verbs: ["get", "list", "watch"]
EOF
```

Now the cluster-administrator creates wants to bind this clusterRole in each namespace of the solar `Tenant`. He creates a tenantRoleBinding:

```yaml
kubectl apply -f - << EOF
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  additionalRoleBindings:
  - clusterRoleName: 'prometheus-servicemonitors-viewer'
    subjects:
    - apiGroup: rbac.authorization.k8s.io
      kind: User
      name: joe
    labels:
      projectcapsule.dev/sample: "true"
    annotations:
      projectcapsule.dev/sample: "true"
EOF
```

As you can see the subjects is a classic [rolebinding subject](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#referring-to-subjects). This way you grant permissions to the subject user **Joe**, who only can list and watch servicemonitors in the solar tenant namespaces, but has no other permissions.

### Custom Resources

Capsule grants admin permissions to the `TenantOwners` but is only limited to their namespaces. To achieve that, it assigns the ClusterRole [admin](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) to the `TenantOwner`. This ClusterRole does not permit the installation of custom resources in the namespaces.

In order to leave the `TenantOwner` to create Custom Resources in their namespaces, the cluster admin defines a proper Cluster Role. For example:

```yaml
kubectl apply -f - << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argoproj-provisioner
rules:
- apiGroups:
  - argoproj.io
  resources:
  - applications
  - appprojects
  verbs:
  - create
  - get
  - list
  - watch
  - update
  - patch
  - delete
EOF
```

Bill can assign this role to any namespace in the Alice's `Tenant` by setting it in the `Tenant` manifest:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  - name: joe
    kind: User
  additionalRoleBindings:
    - clusterRoleName: 'argoproj-provisioner'
      subjects:
        - apiGroup: rbac.authorization.k8s.io
          kind: User
          name: alice
        - apiGroup: rbac.authorization.k8s.io
          kind: User
          name: joe
```

With the given specification, Capsule will ensure that all Alice's namespaces will contain a RoleBinding for the specified Cluster Role. For example, in the `solar-production` namespace, Alice will see:

```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: capsule-solar-argoproj-provisioner
  namespace: solar-production
subjects:
  - kind: User
    apiGroup: rbac.authorization.k8s.io
    name: alice
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argoproj-provisioner
```

With the above example, Capsule is leaving the `TenantOwner` to create namespaced custom resources.

> Take Note: a `TenantOwner` having the admin scope on its namespaces only, does not have the permission to create Custom Resources Definitions (CRDs) because this requires a cluster admin permission level. Only Bill, the cluster admin, can create CRDs. This is a known limitation of any multi-tenancy environment based on a single shared control plane.

## Administrators

Administrators are users that have full control over all `Tenants` and their namespaces. They are typically cluster administrators or operators who need to manage the entire cluster and all its `Tenants`. However as administrator you are automatically Owner of all `Tenants`.`Tenants` This means that administrators can create, delete, and manage namespaces and other resources within any `Tenant`, given you are using [label assignments for tenants](/docs/tenants/namespaces/#label).

