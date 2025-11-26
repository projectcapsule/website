---
title: What's New ✨
description: >
  Discover new features from the current version in one place.
weight: 1
---

## Features

* All namespaced items, which belong to a Capsule Tenant, are now labeled with the Tenant name (eg. `capsule.clastix.io/tenant: solar`). This allows easier filtering and querying of resources belonging to a specific Tenant or Namespace. **Note**: This happens at admission, not in the background. If you want your existing resources to be labeled, you need to reapply them or patch them manually to get the labels added.

* Delegate Administrators for capsule tenants. Administrators have full control (ownership) over all tenants and their namespaces. [Read More](/docs/tenants/permissions/#administrators)

* All available Classes for a tenant (StorageClasses, GatewayClasses, RuntimeClasses, PriorityClasses) are now reported in the Tenant Status. These values can be used by Admission to integrate other resources validation or by external systems for reporting purposes.

```yaml
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

* Owners can promote ServiceAccounts from their Tenant namespaces to Owners of the Tenant [Read More](/docs/tenants/permissions/#serviceaccount-promotion)

* Reworked Metrics based on improved Tenant state management via Conditions. [Read More](/docs/operating/monitoring/#metrics-1)

* Includes a new approach to how Resources (ResourceQuotas) should be handled across multiple namespaces. With this release, we are introducing the concept of ResourcePools and ResourcePoolClaims. Essentially, you can now define Resources and the audience (namespaces) that can claim these Resources from a ResourcePool. This introduces a shift-left in resource management, where Tenant Owners themselves are responsible for organizing their resources. Comes with a Queuing-Mechanism already in place. This new feature works with all namespaces — not just exclusive Capsule namespaces. [Read More](/docs/resourcepools/)

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
