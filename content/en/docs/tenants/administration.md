---
title: Administration
weight: 6
description: >
  Administrative controls on tenants
---

## Cordoning

Bill needs to cordon a `Tenant` and its `Namespaces` for several reasons:

  * Avoid accidental resource modification(s) including deletion during a Production Freeze Window
  * During the Kubernetes upgrade, to prevent any workload updates
  * During incidents or outages
  * During planned maintenance of a dedicated nodes pool in a BYOD scenario

With this said, the `TenantOwner` and the related Service Account living into managed `Namespaces`, cannot proceed to any update, create or delete action.

This is possible by just toggling the specific `Tenant` specification:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  cordoned: true
  owners:
  - kind: User
    name: alice
```

Any operation performed by Alice, the `TenantOwner`, will be rejected by the Admission controller.

Uncordoning can be done by removing the said specification key:

```bash
$ cat <<EOF | kubectl apply -f -
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  cordoned: false
  owners:
  - kind: User
    name: alice
EOF

$ kubectl --as alice --as-group projectcapsule.dev -n solar-dev create deployment nginx --image nginx
deployment.apps/nginx created
```

Status of cordoning is also reported in the state of the `Tenant`:

```bash
kubectl get tenants
NAME     STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR    AGE
bronze   Active                     2                                  3d13h
gold     Active                     2                                  3d13h
solar    Cordoned                   4                                  2d11h
silver   Active                     2                                  3d13h
```

## Force Tenant-Prefix

Use this if you want to disable/enable the `Tenant` name prefix to specific `Tenants`, overriding global `forceTenantPrefix` in [CapsuleConfiguration](/docs/operating/setup/configuration/#forcetenantprefix). When set to 'true', it enforces `Namespaces` created for this `Tenant` to be named with the `Tenant` name prefix, separated by a dash (i.e. for `Tenant` 'foo', `Namespace` names must be prefixed with 'foo-'), this is useful to avoid `Namespace` name collision. When set to 'false', it allows `Namespaces` created for this `Tenant` to be named anything. Overrides CapsuleConfiguration global `forceTenantPrefix` for the `Tenant` only. If unset, `Tenant` uses CapsuleConfiguration's `forceTenantPrefix`

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  forceTenantPrefix: true
```

## Deletion Protection

Sometimes it is important to protect business critical `Tenants` from accidental deletion. This can be achieved by toggling preventDeletion specification key on the `Tenant`:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  preventDeletion: true
```
