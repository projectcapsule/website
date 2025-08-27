---
title: What's New ✨
description: >
  Discover new features from the current version in one place.
weight: 1
---


## Features

* includes a new approach to how Resources (ResourceQuotas) should be handled across multiple namespaces. With this release, we are introducing the concept of ResourcePools and ResourcePoolClaims. Essentially, you can now define Resources and the audience (namespaces) that can claim these Resources from a ResourcePool. This introduces a shift-left in resource management, where Tenant Owners themselves are responsible for organizing their resources. Comes with a Queuing-Mechanism already in place. This new feature works with all namespaces — not just exclusive Capsule namespaces. [Read More](/docs/resourcepools/)

* Added support for GatewayAPI v1 (Gateway-Class control). [Read More](/docs/tenants/enforcement/#gatewayclasses)

- Added a more sophisticated way to control metadata for namespaces within a tenant. This allows you to distribute labels and annotations to namespaces based on more specific conditions. It's now also possible so use simple templating to assign metadata. [Read More](/docs/tenants/enforcement/#namespaces)


## Documentation

We have added new documentation for a better experience. See the following Topics:

* **[Best Practices](/docs/operating/best-practices/)**
* **[Installation](/docs/operating/setup/installation/)**

## Ecosystem

Newly added documentation to integrate Capsule with other applications:

* [OpenCost](/ecosystem/integrations/opencost/)
* [Headlamp](/ecosystem/integrations/headlamp/)
* [Gangplank](/ecosystem/integrations/gangplank/)
* [Openshift](/docs/operating/setup/openshift/)