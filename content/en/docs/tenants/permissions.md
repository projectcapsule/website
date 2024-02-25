---
title: Permissions
weight: 1
description: >
  Grant permissions for tenants
---

## Ownership

Capsule introduces the principal, that tenants must have owners. The owner of a tenant is a user or a group of users that have the right to create, delete, and manage the [tenant's namespaces](/docs/tenants/namespaces) and other tenant resources. However an owner does not have the permissions to manage the tenants they are owner of. This is still done by cluster-administrators.

### Group Scope

Capsule selects users, which are eligable to be considered for tenancy by their group.




### Assignment

Learn how to assign ownership to users, groups and serviceaccounts.

#### Assigning Ownership to Users

**Bill**, the cluster admin, receives a new request from Acme Corp's CTO asking for a new tenant to be onboarded and Alice user will be the tenant owner. Bill then assigns Alice's identity of alice in the Acme Corp. identity management system. Since Alice is a tenant owner, Bill needs to assign alice the Capsule group defined by --capsule-user-group option, which defaults to capsule.clastix.io.

To keep things simple, we assume that Bill just creates a client certificate for authentication using X.509 Certificate Signing Request, so Alice's certificate has `"/CN=alice/O=capsule.clastix.io"`.

**Bill** creates a new tenant oil in the CaaS management portal according to the tenant's profile:

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


### Group of subjects as tenant owner

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

However, it's more likely that Bill assigns the ownership of the solar tenant to a group of users instead of a single one, especially if you use [OIDC AUthentication](/docs/guides/authentication#oidc). Bill creates a new group account solar-users in the Acme Corp. identity management system and then he assigns Alice and Bob identities to the solar-users group.

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

With the configuration above, any user belonging to the `solar-users` group will be the owner of the oil tenant with the same permissions of Alice. For example, Bob can log in with his credentials and issue

```bash
kubectl auth can-i create namespaces
yes
```

#### Group of ServiceAccounts

You can use the Group subject to grant serviceaccounts the ownership of a tenant. For example, you can create a group of serviceaccounts and assign it to the tenant:

```bash

```

### Owner Roles

By default, all Tenant Owners will be granted with two ClusterRole resources using the RoleBinding API:

1. `admin`: the Kubernetes default one, admin, that grants most of the namespace scoped resources
2. `capsule-namespace-deleter`: a custom clusterrole, created by Capsule, allowing to delete the created namespaces

You can observe this behavior when you get the tenant solar:

```yaml

```

In the example below, assuming the tenant owner creates a namespace oil-production in Tenant oil, you'll see the Role Bindings giving the tenant owner full permissions on the tenant namespaces:



#### Role Aggregation

Sometimes the `admin` role is missing certain permissions. You can [aggregate](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#aggregated-clusterroles) the `admin` role with a custom role, for example, `prometheus-viewer`:

```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: prometheus-viewer
  labels:
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
rules:
- apiGroups: ["monitoring.coreos.com"]
  resources: ["servicemonitors"]
  verbs: ["get", "watch"]
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











