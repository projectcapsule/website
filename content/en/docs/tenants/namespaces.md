---
title: Namespaces
weight: 2
description: >
  Assign Namespace to tenants
---

Alice, once logged with her credentials, can create a new namespace in her tenant, as simply issuing:

```bash
kubectl create ns solar-production
```

Alice started the name of the namespace prepended by the name of the tenant: this is not a strict requirement but it is highly suggested because it is likely that many different tenants would like to call their namespaces production, test, or demo, etc.

The enforcement of this naming convention is optional and can be controlled by the cluster administrator with [forceTenantPrefix](/docs/tenants/configuration/#forcetenantprefix) option.

Alice can deploy any resource in any of the namespaces

```bash
kubectl -n solar-development run nginx --image=docker.io/nginx 
kubectl -n solar-development get pods
```

## Multiple Tenants

A single team is likely responsible for multiple lines of business. For example, in our sample organization Acme Corp., Alice is responsible for both the Solar and Green lines of business. It's more likely that Alice requires two different tenants, for example, solar and green to keep things isolated.

By design, the Capsule operator does not permit a hierarchy of tenants, since all tenants are at the same levels. However, we can assign the ownership of multiple tenants to the same user or group of users.

Bill, the cluster admin, creates multiple tenants having alice as owner:

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

and 

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: green
spec:
  owners:
  - name: alice
    kind: User
```

Alternatively, the ownership can be assigned to a group called solar-and-green for both tenants:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: solar-and-green
    kind: Group
```

> See [Ownership](/docs/tenants/permissions#ownership) for more details on how to assign ownership to a group of users.

The two tenants remain isolated from each other in terms of resources assignments, e.g. `ResourceQuotas`, `Nodes`, `StorageClasses` and `IngressClasses`, and in terms of governance, e.g. `NetworkPolicies`, `PodSecurityPolicies`, `Trusted Registries`, etc.

When Alice logs in, she has access to all namespaces belonging to both the solar and green tenants.




### Tenant Prefix

> We recommend to use the [forceTenantPrefix](/docs/tenants/configuration/#forcetenantprefix) for production environments.

If the [forceTenantPrefix](/docs/tenants/configuration/#forcetenantprefix) option is enabled, which is **not** the case by default, the namespaces are automatically assigned to the right tenant by Capsule because the operator does a lookup on the tenant names. 

For example, Alice creates a namespace called `solar-production` and `green-production`:

```bash
kubectl create ns solar-production
kubectl create ns green-production
```

And they are assigned to the tenant based on their prefix:

```bash
$ kubectl get tnt
NAME    STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR   AGE
green   Active                     1                                 3m26s
solar   Active                     1                                 3m26s
```

However alice can create any namespace, which does not have a prefix of any of the tenants she owns, for example `production`:

```bash
$ kubectl create ns production
Error from server (Forbidden): admission webhook "owner.namespace.capsule.clastix.io" denied the request: The Namespace prefix used doesn't match any available Tenant
```

### Label

The default behavior, if the [forceTenantPrefix](/docs/tenants/configuration/#forcetenantprefix) option is not enabled, Alice needs to specify the tenant name as a label capsule.`clastix.io/tenant=<desired_tenant>` in the namespace manifest:

```yaml
kind: Namespace
apiVersion: v1
metadata:
  name: solar-production
  labels:
    capsule.clastix.io/tenant: solar
```

If not specified, Capsule will deny with the following message: Unable to assign namespace to tenant: 

```bash
$ kubectl create ns solar-production
Error from server (Forbidden): admission webhook "owner.namespace.capsule.clastix.io" denied the request: Please use capsule.clastix.io/tenant label when creating a namespace
```
