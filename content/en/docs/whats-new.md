---
title: What's New ✨
description: >
  Discover new features from the current version in one place.
weight: 1
---

## Security

* Advisory [GHSA-2ww6-hf35-mfjm](https://github.com/projectcapsule/capsule/security/advisories/GHSA-2ww6-hf35-mfjm) - **Moderate** - Users may hijack namespaces via `namespaces/status` privileges. These privileges must have been explicitly granted by Platform Administrators through RBAC rules to be affected. Requests for the `namespaces/status` subresource are now sent to the Capsule admission webhook as well.

## Breaking Changes

* By default, Capsule now uses self-signed cert-manager certificates for its admission webhooks. This used to be an optional setting and has now become the default. If you don't have cert-manager installed, you must explicitly re-enable the Capsule TLS controller as [documented here](/docs/operating/setup/installation/#certificate-management).

## Features

* Added `RequiredMetadata` for `Namespaces` created in a `Tenant`. For details, see the [Required metadata documentation](/docs/tenants/metadata/#requiredmetadata).
* Added implicit assignment of `TenantOwner`. For details, see [Implicit tenant assignment](/docs/tenants/permissions/#implicit-tenant-assignment).
* Added aggregation of `TenantOwner`. For details, see [Tenant owner aggregation](/docs/tenants/permissions/#aggregation).
* Introduced the new `RuleStatus` CRD. For details, see the [Rules documentation](/docs/tenants/rules/).
* Introduced new OCI registry enforcement. For details, see [Registry rules](/docs/tenants/rules/#registries).
* Added the `projectcapsule.dev/tenant` label to all namespaced resources belonging to a `Tenant`. For details, see [Managed metadata](/docs/tenants/metadata/#managed).
* Added configuration options for managed RBAC. For details, see [RBAC configuration](/docs/operating/setup/configuration/#rbac).
* Added configuration options for impersonation. For details, see [Impersonation configuration](/docs/operating/setup/configuration/#impersonation).
* Added configuration options for cache invalidation. For details, see [Cache invalidation configuration](/docs/operating/setup/configuration/#cacheinvalidation).
* Added configuration options for dynamic admission webhooks. For details, see [Admission configuration](/docs/operating/setup/configuration/#admission).

## Fixes

* Fixed `ResourcePool` resource quota calculation when multiple `ResourcePoolClaim`s are present in a namespace but not everything is used. For details, see [ResourcePools bound behavior](/docs/resourcepools/#bound).

* Improved `matchConditions` for admission webhooks that intercept all namespaced items, to avoid processing subresource requests and Events, improving performance and reducing log noise.

## Documentation

We have added new documentation for a better experience. See the following topics:

* **[Improved installation overview](/docs/operating/setup/installation/)**
* **[Capsule strict RBAC installation](/docs/operating/setup/installation/#strict-rbac)**

## Ecosystem

Newly added documentation to integrate Capsule with other applications:

* [CoreDNS Plugin](https://github.com/CorentinPtrl/capsule_coredns) (Community Contribution)
* [Argo CD](/ecosystem/integrations/argocd/)
* [Flux CD](/ecosystem/integrations/fluxcd/)
