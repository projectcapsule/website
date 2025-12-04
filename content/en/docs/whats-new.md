---
title: What's New ✨
description: >
  Discover new features from the current version in one place.
weight: 1
---

## Features

* Admission Webhooks return warnings for deprecated fields in Capsule resources. You are encouraged to update your resources accordingly.

* Added `--enable-pprof` flag to enable pprof endpoint for profiling Capsule controller performance. Not recommended for production environments. [Read More](/docs/operating/setup/configuration/#controller-options).
  
* Added `--workers` flag to define the `MaxConcurrentReconciles` for relevant controllers [Read More](/docs/operating/setup/configuration/#controller-options).

* Combined [Capsule Users](/docs/operating/architecture/#capsule-users) Configuration for defining all users and groups which should be considered for Capsule tenancy. This simplifies the configuration and avoids confusion between users and groups. [Read More](/docs/operating/setup/configuration/#users)

* All namespaced items, which belong to a Capsule Tenant, are now labeled with the Tenant name (eg. `capsule.clastix.io/tenant: solar`). This allows easier filtering and querying of resources belonging to a specific Tenant or Namespace. **Note**: This happens at admission, not in the background. If you want your existing resources to be labeled, you need to reapply them or patch them manually to get the labels added.

* Delegate Administrators for capsule tenants. Administrators have full control (ownership) over all tenants and their namespaces. [Read More](/docs/operating/architecture/#capsule-administrators)

* All available Classes for a tenant (StorageClasses, GatewayClasses, RuntimeClasses, PriorityClasses, DeviceClasses) are now reported in the Tenant Status. These values can be used by Admission to integrate other resources validation or by external systems for reporting purposes ([Example](/docs/operating/admission-policies/#class-validation)).

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
...
status:
  classes:
    priority:
    - system-cluster-critical
    - system-node-critical
    runtime:
    - customer-containerd
    - customer-runu
    - customer-virt
    - default-runtime
    - disallowed
    - legacy
    storage:
    - standard
```

* All available Owners for a tenant are now reported in the Tenant Status. This allows external systems to query the Tenant resource for its owners instead of querying the RBAC system.

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

* Introduction of the `TenantOwner` CRD. [Read More](/docs/tenants/permissions/#tenant-owners)

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
  clusterRoles:
    - "mega-admin"
    - "controller"
```

## Fixes

* Admission Webhooks for namespaces had certain dependencies on the first reconcile of a tenant (namespace being allocated to this tenant). This bug has been fixed and now namespaces are correctly assigned to the tenant (at admission) even if the tenant has not yet been reconciled.

* The entire core package and admission webhooks have been majorly refactored to improve maintainability and extensibility of Capsule.

## Documentation

We have added new documentation for a better experience. See the following Topics:

* **[Extended Admission Policy Recommendations](/docs/operating/admission-policies/)**
* **[Personas](/docs/operating/admission-policies/)**

## Ecosystem

Newly added documentation to integrate Capsule with other applications:

* [OpenCost](/ecosystem/integrations/opencost/)
* [Headlamp](/ecosystem/integrations/headlamp/)
* [Gangplank](/ecosystem/integrations/gangplank/)
* [Teleport](/ecosystem/integrations/teleport/)
* [Openshift](/docs/operating/setup/openshift/)
