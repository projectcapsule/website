---
title: What's New ✨
description: >
  Discover new features from the current version in one place.
weight: 1
layout: whats-new
outputs:
  - HTML
  - RSS
---

## Events 📅

{{< events-calendar >}}

## Security 🔒

* **(Enterprise)**: Projectcapsule is now providing their releases on an immutable OCI registry, which allows users to verify the integrity of the images and provides a more secure way to distribute the images. Which is not possible on GHCR due to the fact that GHCR does not support immutability of images.

## Breaking Changes ⚠️

* For [`TenantResource`](/docs/replications/tenant/) the [impersonation](/docs/replications/tenant/#impersonation) is now configured by default, always using the `default` `ServiceAccount` of the target namespace. This change is to ensure that the `TenantResource` can be used in a more secure way, without the need to configure impersonation manually. If you are using `TenantResource` with impersonation, you will need to update your configuration to use the `default` `ServiceAccount` of the target namespace.

## Features ✨

* **Capsule**: Ships with diverese improvements to Admission-Time and reconcile time for all components. We are continuing to improve the performance and stability of Capsule, and we are always looking for ways to make it easier to use and more powerful.
* **Capsule**: Added 1:1 compatible Quota-System for direct migration and functional replacement of the deprecated ResourceQuotas. [Read More](/docs/tenants/rules/#migration)
* **Capsule**: Added new capabilites to Rules-API:
   * [Metadata Enforcement](/docs/rules/enforcement/metadata/)
   * [Service Enforcement](/docs/rules/enforcement/services/)
   * [Ingress Enforcement](/docs/rules/enforcement/ingress/)
   * [Workload Enforcement](/docs/rules/enforcement/workloads/)
* **Proxy**: Added RBAC-Reflection for non Tenant-Owners. [Read More](/docs/proxy/reflection/)

### Deprecations

  * Announcing deprecation of the legacy Quota-System. The legacy Quota-System will be removed in a future release. Please migrate to the new Quota-System as soon as possible. [Read More](/docs/tenants/rules/#migration)

  * Announcing deprecation of the  [Custom Resources (CRD Quantities)](/docs/tenants/quotas/#custom-resources). The legacy CustomQuotas will be removed in a future release. Please migrate to the new [`GlobalCustomQuotas`/`CustomQuotas`](/docs/resource-management/customquotas/) as soon as possible. [Read More](/docs/tenants/rules/#migration)

  * Announcing deprecation of the [Pod Metadata Options](/docs/tenants/metadata/#pods). Please migrate to the new [`Metadata Rules`](/docs/rules/enforcement/metadata/#migrate-pod-metadata) as soon as possible.

  * Announcing deprecation of the [Service Metadata Options](/docs/tenants/metadata/#services). Please migrate to the new [`Metadata Rules`](/docs/rules/enforcement/metadata/#migrate-service-metadata) as soon as possible.

  * Announcing deprecation of certain [Namespace Metadata Options](/docs/tenants/metadata/#namespaces). Please migrate to the new [`Metadata Rules`](/docs/rules/enforcement/metadata/#migrate-namespace-metadata) as soon as possible.

## Fixes 🐛

* Fixed PVC-Controller mutating `PersistentVolumes` with empty tenant label value
* Fixed Helm-Values for [Strict Mode](/docs/operating/setup/installation/#strict-rbac)

## Documentation 📚

We have added new documentation for a better experience. See the following topics:

* **[Resource Management decision table](/docs/resource-management/)**
* **[Resource Management for workloads](/docs/operating/best-practices/workloads/#resource-management)**

## Ecosystem 🌐

Newly added documentation to integrate Capsule with other applications:

* [Headlamp Plugin](/ecosystem/integrations/headlamp/#plugins)
* [Argo CD](/ecosystem/integrations/argocd/)

## Roadmap 🗺️

In the upcoming releases we are planning to work on the following features:

  * Capsule: Porting more Properties to the Namespace Rule Approach.
  * Capsule: Adding `transformers` for `Global`/`TenantResources`.
  * Capsule: Adding `healthChecks` for `Global`/`TenantResources`.
  * Capsule: Introducing Break-The-Glass to allow temporary elevation of permissions for Tenant Owners, with an approval process by Platform Administrators.
  * Capsule: Adding custom health checks for ArgoCD to upstream
  * Capsule: Adding Generic Implementation for `Global`/`TenantResources`.
  * Website: Improving the documentation with more examples and use-cases.
