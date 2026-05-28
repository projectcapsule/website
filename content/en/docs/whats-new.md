---
title: What's New ✨
description: >
  Discover new features from the current version in one place.
weight: 1
---

## Security 🔒

* Advisory [GHSA-qjjm-7j9w-pw72](https://github.com/projectcapsule/capsule/security/advisories/GHSA-qjjm-7j9w-pw72) - **High** - Users can create cluster scoped resources anywhere in the cluster if they are allowed to create `TenantResources`. To immediately mitigate this, make sure to use [Impersonation](/docs/replications/tenant/#impersonation) for `TenantResources`.

* Advisory [GHSA-2ww6-hf35-mfjm](https://github.com/projectcapsule/capsule/security/advisories/GHSA-2ww6-hf35-mfjm) - **Moderate** - Users may hijack namespaces via `namespaces/status` privileges. These privileges must have been explicitly granted by Platform Administrators through RBAC rules to be affected. Requests for the `namespaces/status` subresource are now sent to the Capsule admission webhook as well.

* **(Enterprise)**: Projectcapsule is now providing their releases on an immutable OCI registry, which allows users to verify the integrity of the images and provides a more secure way to distribute the images. Which is not possible on GHCR due to the fact that GHCR does not support immutability of images.

## Breaking Changes ⚠️

* By default, Capsule now uses self-signed cert-manager certificates for its admission webhooks. This used to be an optional setting and has now become the default. If you don't have cert-manager installed, you must explicitly re-enable the Capsule TLS controller as [documented here](/docs/operating/setup/installation/#certificate-management).

## Features ✨

* Add new Quota System with `GlobalCustomQuotas` and `CustomQuotas`. [Read More](/docs/resource-management/customquotas/).
* Complete Renovation of Replications [Read More](/docs/replications/).
* Introducing new rule approach for tenant enforcement [Read More](/docs/tenants/rules/).
* Added `RequiredMetadata` for `Namespaces` created in a `Tenant` [Read More](/docs/tenants/metadata/#requiredmetadata).
* [Additional Metadata](/docs/tenants/metadata/#additionalmetadata) is now validated at admission.
* Introducing new OCI Registry enforcement [Read More](/docs/tenants/rules/#registries)
* Added rule-based promotions for `ServiceAccounts` in `Tenants` [Read More](/docs/tenants/rules/#promotions).
* Added Implicit Assignment of `TenantOwner` [Read More](/docs/tenants/permissions/#implicit-tenant-assignment).
* Added Aggregation of `TenantOwner` [Read More](/docs/tenants/permissions/#aggregation).
* Introducing `data` field for `Tenants` [Read More](/docs/operating/templating/#data).
* Added new label `projectcapsule.dev/tenant` which is added for all namespaced resources belonging to a `Tenant` [Read More](/docs/tenants/metadata/#managed).
* Resources labeled with `projectcapsule.dev/managed-by=controller` can only be created, updated or deleted by the Capsule controller and [administrators](/docs/tenants/permissions/#administrators), and are rejected for all other operations. This prevents deletion of managed resources by users, which are not identified as capsule users (current behavior).
* Added configuration options for managed RBAC [Read More](/docs/operating/setup/configuration/#rbac)
* Added configuration options for Impersonation [Read More](/docs/operating/setup/configuration/#impersonation)
* Added configuration options for Cache invalidation [Read More](/docs/operating/setup/configuration/#cacheinvalidation)
* Added configuration options for Dynamic Admission Webhooks [Read More](/docs/operating/setup/configuration/#admission)
* Migrated event emissions to `events.k8s.io/v1` from legacy `core/v1`.
* Proxy: Added Built-In Installation for Gangplank [Read More](/docs/proxy/gangplank/)
* Proxy: Added support for Forwarded Client Certificate Authentication (XFCC) [Read More](/docs/proxy/setup/installation/#forwarded-client-certificate-authentication-xfcc)
* Proxy: Added trusted source configuration [Read More](/docs/proxy/setup/installation/#trusted-sources)

## Fixes 🐛

* Fixed `ResourcePool` resource quota calculation when multiple `ResourcePoolClaim`s are present in a namespace but not everything is used. For details, see [ResourcePools bound behavior](/docs/resource-management/resourcepools/#bound).
* Improved `matchConditions` for admission webhooks that intercept all namespaced items, to avoid processing subresource requests and Events, improving performance and reducing log noise.
* `Namespaces` are considered active until all unmanaged namespaced resources are deleted. [Read More](/docs/tenants/namespaces/#termination)
* `PersistentVolumeClaims` support now providing `.spec.selector`. When `.spec.selector` is provided we always aggregate a custom `matchExpressions` for the `PersistentVolumeClaims` to ensure that only the `PersistentVolumeClaims` created in the `Tenant` can mount `PersistentVolumes` provisioned from/for the same `Tenant` [Read More](/docs/resource-management/customquotas/#persistentvolumeclaims)
* Regex-Selectors were not considered on classes driven Tenant status reconciles.
* A single Unready namespace could cause the entire Tenant reconcilation to be incomplete. Now unready or terminating namespaces are ignored for further processing ensuring that ready/new namespaces get their required contents.
* When a Tenant is cordoned, namespaces can no longer be deleted.
* When classes issue a reconcile for a tenant, only the tenant.status.classes spec is updated instead of the entire tenant.status, to avoid conflicts with other controllers and reduce the risk of losing changes made by other controllers.
* Our E2E-Testing has been changed to be highly concurrent to simulate large scale setups and uncover potential race conditions or performance issues that may arise in such environments. This has led to the discovery and fixing of several issues related to concurrency and performance, which has improved the overall stability and reliability of Capsule.
* TLS controller correctly patches all the webhooks with the same CA Bundle, to avoid issues with multiple webhooks and ensure that all webhooks are correctly secured, if enabled. [Read More](/docs/operating/setup/installation/#certificate-management)

## Documentation 📚

We have added new documentation for a better experience. See the following topics:

* **[Improved installation overview](/docs/operating/setup/installation/)**
* **[Capsule strict RBAC installation](/docs/operating/setup/installation/#strict-rbac)**

## Ecosystem 🌐

Newly added documentation to integrate Capsule with other applications:

* [CoreDNS Plugin](https://github.com/CorentinPtrl/capsule_coredns) (Community Contribution)
* [Argo CD](/ecosystem/integrations/argocd/)
* [Flux CD](/ecosystem/integrations/fluxcd/)

## Project Updates 💫

  * Incubating [Sander (ODC Noord)](https://github.com/sandert-k8s) as Maintainer for documentation and website improvements.

## Roadmap 🗺️

In the upcoming releases we are planning to work on the following features:

  * Capsule: Porting more Properties to the Namespace Rule Approach.
  * Capsule: Adding `transformers` for `Global`/`TenantResources`.
  * Capsule: Adding `healthChecks` for `Global`/`TenantResources`.
  * Capsule: Introducing Break-The-Glass to allow temporary elevation of permissions for Tenant Owners, with an approval process by Platform Administrators.
  * Capsule: Adding custom health checks for ArgoCD to upstream
  * Capsule: Adding Generic Implementation for `Global`/`TenantResources`.
  * Website: Improving the documentation with more examples and use-cases.
  * Capsule-Proxy: Bringing back RBAC reflection to Capsule-Proxy (Generic Namespaced List Permissions)
  * Capsule-Proxy: Deprecating ProxySettings on Tenants in favour of GlobalProxySettings


## Events 📅

* **Capsule Roundtable Summer 2026 🇨🇭**
    * We are planning to host a Capsule Roundtable in Summer 2026 in Switzerland (**28. Mai 2026**). The exact date and location will be announced soon, but we are looking forward to meeting the community in person and discussing the future of Capsule. If you are interested in attending or want to know more about the event, [feel free to reach out to us](https://peakscale.ch/en/contact/). The event is intended for users to present their use-cases and share their experiences with the project, as well as for us to present the roadmap and gather feedback from the community (Not a sales event).