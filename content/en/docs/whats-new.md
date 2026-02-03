---
title: What's New ✨
description: >
  Discover new features from the current version in one place.
weight: 1
---



## Security

* Advisory [GHSA-2ww6-hf35-mfjm](https://github.com/projectcapsule/capsule/security/advisories/GHSA-2ww6-hf35-mfjm) - **Moderate** - Users may hijack namespaces. via `namespaces/status` privileges. These privileges must have been explicitly granted by Platform Administrators through RBAC rules to be affected. Requests for the `namespaces/status` subresource are now sent to the capsule admission as well.



## Breaking Changes

* By default capsule now uses self-signed cert-manager certificates for it's admission webhook. This used to be an optional setting, which has now become default. If you don't have cert-manager available you must explicitly enable the capsule TLS-Controller as [documented here](docs/operating/setup/installation/#certificate-management)

## Features

* Added `RequiredMetadata` for `Namespaces` created in a `Tenant` [Read More](/docs/tenants/metadata/#requiredmetadata).

* Added Implicit Assignment of `TenantOwner` [Read More](/docs/tenants/permissions/#implicit-tenant-assignment).

* Added Aggregation of `TenantOwner` [Read More](/docs/tenants/permissions/#aggregation).

* Introducing new CRD `RuleStatus` [Read More](/docs/tenants/rules/)

* Introducing new OCI Registry enforcement [Read More](/docs/tenants/rules/#registries)

* Added new label `projectcapsule.dev/tenant` which is added for all namespaced resources belonging to a `Tenant` [Read More](/docs/tenants/metadata/#managed).

* Added Configuration Options for managed RBAC [Read More](docs/operating/setup/configuration/#rbac)

* Added Configuration Options for Impersonation [Read More](/docs/operating/setup/configuration/#impersonation)

* Added Configuration Options for Cache invalidation [Read More](/docs/operating/setup/configuration/#cacheinvalidation)

* Added Configuration Options for Dynamic Admission Webhooks [Read More](/docs/operating/setup/configuration/#admission)
 

## Fixes

* Introduced fix for `ResourcePool` resource quota calculation when multiple `ResourcePoolClaim`s are present in a namespace but not everything is used. [Read More](/docs/resourcepools/#bound)

* Improved `matchConditions` for Admission Webhooks, which intercept all namespaced items, to avoid processing subresource requests and Events, improving performance and reducing log noise.



## Documentation

We have added new documentation for a better experience. See the following Topics:

* **[Improved Installation Overview](/docs/operating/setup/installation/)**
* **[Capsule Strict RBAC Installation](/docs/operating/setup/installation/#strict-rbac)**

## Ecosystem

Newly added documentation to integrate Capsule with other applications:

* [CoreDNS Plugin](https://github.com/CorentinPtrl/capsule_coredns) (Community Contribution)
* [Argo CD](/ecosystem/integrations/argocd/)
* [Flux CD](/ecosystem/integrations/fluxcd/)
