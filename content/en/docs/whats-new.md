---
title: What's New ✨
description: >
  Discover new features from the current version in one place.
weight: 1
---

## Features

* Owners can promote ServiceAccounts from their Tenant namespaces to Owners of the Tenant [Read More](/docs/tenants/permissions/#serviceaccount-promotion)

* Reworked Metrics based on improved Tenant state management via Conditions. [Read More](/docs/operating/monitoring/#metrics-1)

* Includes a new approach to how Resources (ResourceQuotas) should be handled across multiple namespaces. With this release, we are introducing the concept of ResourcePools and ResourcePoolClaims. Essentially, you can now define Resources and the audience (namespaces) that can claim these Resources from a ResourcePool. This introduces a shift-left in resource management, where Tenant Owners themselves are responsible for organizing their resources. Comes with a Queuing-Mechanism already in place. This new feature works with all namespaces — not just exclusive Capsule namespaces. [Read More](/docs/resourcepools/)

## Documentation

We have added new documentation for a better experience. See the following Topics:

* **[Best Practices](/docs/operating/best-practices/)**
* **[Installation](/docs/operating/setup/installation/)**
* **[Admission Policy Recommendations](/docs/operating/setup/admission-policies/)**

## Ecosystem

Newly added documentation to integrate Capsule with other applications:

* [OpenCost](/ecosystem/integrations/opencost/)
* [Headlamp](/ecosystem/integrations/headlamp/)
* [Gangplank](/ecosystem/integrations/gangplank/)
* [Teleport](/ecosystem/integrations/teleport/)
* [Openshift](/docs/operating/setup/openshift/)
