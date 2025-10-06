---
title: Permissions
weight: 3
description: >
  Grant permissions for tenants
---

## Ownership

Capsule introduces the principal, that tenants must have owners. The owner of a tenant is a user or a group of users that have the right to create, delete, and manage the [tenant's namespaces](/docs/tenants/namespaces) and other tenant resources. However an owner does not have the permissions to manage the tenants they are owner of. This is still done by cluster-administrators.

### Group Scope

Capsule selects users, which are eligable to be considered for tenancy by their group. To define the group of users that can be considered for tenancy, you can use the `userGroups` option in the CapsuleConfiguration.

Another commonly used example if you want to promote serviceaccount to tenant-owners, their group must be present:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: CapsuleConfiguration
metadata:
  name: default
spec:
  userGroups:
  - solar-users
  - system:serviceaccounts:tenant-system
```

All serviceAccounts in the `tenant-system` namespace will be considered for tenancy and can be promoted to tenant owners.

### Assignment

Learn how to assign ownership to users, groups and serviceaccounts.

#### Assigning Ownership to Users

**Bill**, the cluster admin, receives a new request from Acme Corp's CTO asking for a new tenant to be onboarded and Alice user will be the tenant owner. Bill then assigns Alice's identity of alice in the Acme Corp. identity management system. Since Alice is a tenant owner, Bill needs to assign alice the Capsule group defined by --capsule-user-group option, which defaults to `projectcapsule.dev`.

To keep things simple, we assume that Bill just creates a client certificate for authentication using X.509 Certificate Signing Request, so Alice's certificate has `"/CN=alice/O=projectcapsule.dev"`.

**Bill** creates a new tenant solar in the CaaS management portal according to the tenant's profile:

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

**Bill** checks if the new tenant is created and operational:

```bash
kubectl get tenant solar
NAME   STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR   AGE
solar    Active                     0                                 33m
```

> Note that namespaces are not yet assigned to the new tenant. The tenant owners are free to create their namespaces in a self-service fashion and without any intervention from Bill.

Once the new tenant solar is in place, Bill sends the login credentials to Alice. Alice can log in using her credentials and check if she can create a namespace

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

including the Tenant resources


```
kubectl auth can-i get tenants
no
```

#### Group of subjects as tenant owner

In the example above, Bill assigned the ownership of solar tenant to alice user. If another user, e.g. Bob needs to administer the solar tenant, Bill can assign the ownership of solar tenant to such user too:

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

However, it's more likely that Bill assigns the ownership of the solar tenant to a group of users instead of a single one, especially if you use [OIDC Authentication](/docs/guides/authentication#oidc). Bill creates a new group account solar-users in the Acme Corp. identity management system and then he assigns Alice and Bob identities to the solar-users group.

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

With the configuration above, any user belonging to the `solar-users` group will be the owner of the solar tenant with the same permissions of Alice. For example, Bob can log in with his credentials and issue

```bash
kubectl auth can-i create namespaces
yes
```

All the groups you want to promot to Tenant Owners must be part of the Group Scope. You have to add `solar-users` to the CapsuleConfiguration [Group Scope](#group-scope) to make it work.

#### ServiceAccounts

You can use the Group subject to grant ServiceAccounts the ownership of a tenant. For example, you can create a group of ServiceAccounts and assign it to the tenant:

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

Bill can create a ServiceAccount called robot, for example, in the `tenant-system` namespace and leave it to act as Tenant Owner of the solar tenant

```bash
kubectl --as system:serviceaccount:tenant-system:robot --as-group projectcapsule.dev auth can-i create namespaces
yes
```
since each service account in a namespace is a member of following group:

```
system:serviceaccounts:{service-account-namespace}
```

You have to add `system:serviceaccounts:{service-account-namespace}` to the CapsuleConfiguration [Group Scope](#group-scope) to make it work.

### ServiceAccount Promotion

Within a tenant, a ServiceAccount can be promoted to a Tenant Owner. For example, Alice can create a ServiceAccount called robot in the solar tenant and promote it to be a Tenant Owner (This requires Alice to be an owner of the tenant as well):

```yaml
kubectl label sa gitops-reconcile -n green-test owner.projectcapsule.dev/promote=true --as alice --as-group projectcapsule.dev
```

Now the ServiceAccount robot can create namespaces in the solar tenant:

```bash
kubectl create ns green-valkey--as system:serviceaccount:green-test:gitops-reconcile
```

To revoke the promotion, Alice can just remove the label:

```yaml
kubectl label sa gitops-reconcile -n green-test owner.projectcapsule.dev/promote-  --as alice --as-group projectcapsule.dev
```

This feature must be enabled in the [CapsuleConfiguration](/docs/operating/setup/configuration/#allowserviceaccountpromotion).


### Owner Roles

By default, all Tenant Owners will be granted with two ClusterRole resources using the RoleBinding API:

1. `admin`: the Kubernetes default one, admin, that grants most of the namespace scoped resources
2. `capsule-namespace-deleter`: a custom clusterrole, created by Capsule, allowing to delete the created namespaces

You can observe this behavior when you get the tenant solar:

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
  resourceQuotas:
    scope: Tenant
status:
  namespaces:
  - solar-production
  - solar-system
  size: 2
  state: Active
```

In the example below, assuming the tenant owner creates a namespace solar-production in Tenant solar, you'll see the Role Bindings giving the tenant owner full permissions on the tenant namespaces:

```bash
$ kubectl get rolebinding -n solar-production
NAME                                        ROLE                                    AGE
capsule-solar-0-admin                       ClusterRole/admin                       111m
capsule-solar-1-capsule-namespace-deleter   ClusterRole/capsule-namespace-deleter   111m
```

When Alice creates the namespaces, the Capsule controller assigns to Alice the following permissions, so that Alice can act as the admin of all the tenant namespaces:

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

In some cases, the cluster admin needs to narrow the range of permissions assigned to tenant owners by assigning a Cluster Role with less permissions than above. Capsule supports the dynamic assignment of any ClusterRole resources for each Tenant Owner.

For example, assign user Joe the tenant ownership with only [view](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) permissions on tenant namespaces:

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

so that Joe can only view resources in the tenant namespaces:

```bash
kubectl --as joe --as-group projectcapsule.dev auth can-i delete pods -n solar-production
no
```

> Please, note that, despite created with more restricted permissions, a tenant owner can still create namespaces in the tenant because he belongs to the `projectcapsule.dev` group. If you want a user not acting as tenant owner, but still operating in the tenant, you can assign [additional RoleBindings](#additional-rolebindings) without assigning him the tenant ownership.

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


When you are using the [Capsule Proxy](/docs/integrations/addons/capsule-proxy), the tenant owner can list the cluster-scoped resources. You can control the permissions to cluster scoped resources by defining `proxySettings` for a tenant owner.

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

With tenant rolebindings you can distribute namespaced rolebindings to all namespaces which are assigned to a namespace. Essentially it is then ensured the defined rolebindings are present and reconciled in all namespaces of the tenant. This is useful if users should have more insights on tenant basis. Let's look at an example.

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

Now the cluster-administrator creates wants to bind this clusterRole in each namespace of the solar tenant. He creates a tenantRoleBinding:

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
EOF
```

As you can see the subjects is a classic [rolebinding subject](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#referring-to-subjects). This way you grant permissions to the subject user **Joe**, who only can list and watch servicemonitors in the solar tenant namespaces, but has no other permissions.

### Custom Resources

Capsule grants admin permissions to the tenant owners but is only limited to their namespaces. To achieve that, it assigns the ClusterRole [admin](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) to the tenant owner. This ClusterRole does not permit the installation of custom resources in the namespaces.

In order to leave the tenant owner to create Custom Resources in their namespaces, the cluster admin defines a proper Cluster Role. For example:

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

Bill can assign this role to any namespace in the Alice's tenant by setting it in the tenant manifest:

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

With the above example, Capsule is leaving the tenant owner to create namespaced custom resources.

> Take Note: a tenant owner having the admin scope on its namespaces only, does not have the permission to create Custom Resources Definitions (CRDs) because this requires a cluster admin permission level. Only Bill, the cluster admin, can create CRDs. This is a known limitation of any multi-tenancy environment based on a single shared control plane.





