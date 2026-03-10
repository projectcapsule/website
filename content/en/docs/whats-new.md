---
title: What's New ✨
description: >
  Discover new features from the current version in one place.
weight: 1
---

## Security 🔒

* Advisory [GHSA-qjjm-7j9w-pw72](https://github.com/projectcapsule/capsule/security/advisories/GHSA-qjjm-7j9w-pw72) - **High** - Users can create cluster scoped resources anywhere in the cluster if they are allowed to create `TenantResources`. To immidiatly mitigate this, make sure to use [Impersonation](/docs/replications/tenant/#impersonation) for `TenantResources`.

* Advisory [GHSA-2ww6-hf35-mfjm](https://github.com/projectcapsule/capsule/security/advisories/GHSA-2ww6-hf35-mfjm) - **Moderate** - Users may hijack namespaces via `namespaces/status` privileges. These privileges must have been explicitly granted by Platform Administrators through RBAC rules to be affected. Requests for the `namespaces/status` subresource are now sent to the Capsule admission webhook as well.

## Breaking Changes ⚠️

* By default, Capsule now uses self-signed cert-manager certificates for its admission webhooks. This used to be an optional setting and has now become the default. If you don't have cert-manager installed, you must explicitly re-enable the Capsule TLS controller as [documented here](/docs/operating/setup/installation/#certificate-management).

## Features ✨

* Complete Renovation of Replications [Read More](/docs/replications/).
* Added `RequiredMetadata` for `Namespaces` created in a `Tenant` [Read More](/docs/tenants/metadata/#requiredmetadata).
* Added rule-based promotions for `ServiceAccounts` in `Tenants` [Read More](/docs/tenants/permissions/#rule-promotion).
* Added Implicit Assignment of `TenantOwner` [Read More](/docs/tenants/permissions/#implicit-tenant-assignment).
* Added Aggregation of `TenantOwner` [Read More](/docs/tenants/permissions/#aggregation).
* Introducing new CRD `RuleStatus` [Read More](/docs/tenants/rules/)
* Introducing `data` field for `Tenants` [Read More](/docs/operating/templating/#data)
* Introducing new OCI Registry enforcement [Read More](/docs/tenants/rules/#registries)
* Added new label `projectcapsule.dev/tenant` which is added for all namespaced resources belonging to a `Tenant` [Read More](/docs/tenants/metadata/#managed).
* Added configuration options for managed RBAC [Read More](docs/operating/setup/configuration/#rbac)
* Added configuration options for Impersonation [Read More](/docs/operating/setup/configuration/#impersonation)
* Added configuration options for Cache invalidation [Read More](/docs/operating/setup/configuration/#cacheinvalidation)
* Added configuration options for Dynamic Admission Webhooks [Read More](/docs/operating/setup/configuration/#admission)
* Added Built-In Installation for Gangplank with the Capsule Proxy [Read More](/docs/proxy/gangplank/)
* `Namespace` admission requests are now only sent to the Capsule admission webhook if the user is considered a capsule user (eg. all ServiceAccounts are considered capsule users). This makes Capsule less disruptive in Outage/Incident scenarios.

## Fixes 🐛

* Fixed `ResourcePool` resource quota calculation when multiple `ResourcePoolClaim`s are present in a namespace but not everything is used. For details, see [ResourcePools bound behavior](/docs/resourcepools/#bound).

* Improved `matchConditions` for admission webhooks that intercept all namespaced items, to avoid processing subresource requests and Events, improving performance and reducing log noise.

* `Namespaces` are considered active until the Condition `ContentHasNoFinalizers` is `True`. This means that if a `Namespace` has Finalizers, it will be considered active until the Finalizers are removed. This is a more accurate representation of the state of the `Namespace`, as it can still be active even if it has Finalizers. During this all capsule managed resources are still kept and their deletion is blocked until the Finalizers are removed.

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

  * Incubating [Sandert (ODC Noord)](https://github.com/sandert-k8s) as Maintainer for documentation and website improvements.
  * Incubating [Corentin (CCL Consulting)](https://github.com/CorentinPtrl) as Maintainer as core maintainer.
  * Incubating [Lucakuendig (Peak Scale)](https://github.com/lucakuendig) as Community Organizer and Openshift efforts.

## Roadmap 🗺️

In the upcoming releases we are planning to work on the following features:

  * Announcing Capsule Swag (Contribution Rewards) 🎁
  * Capsule: [Custom Resource Quotas](https://github.com/projectcapsule/capsule/issues/1745): A Quota implementation which allows to define custom quota constraints (Enterprise Request).
  * Capsule: Porting more Properties to the Namespace Rule Approach.
  * Capsule: Adding `transformers` for `Global`/`TenantResources`.
  * Capsule: Adding `healthChecks` for `Global`/`TenantResources`.
  * Capsule: Using Dynamic Admission to measure Resource Quota Usage at Admission (For Tenant Scope ResourceQuotas and JIT Claiming for ResourcePools)
  * Capsule: Introducing Break-The-Glass to allow temporary elevation of permissions for Tenant Owners, with an approval process by Platform Administrators.
  * Capsule: Adding custom health checks for ArgoCD to upstream
  * Capsule: Adding Generic Implementation for `Global`/`TenantResources`.
  * Website: Improving the documentation with more examples and use-cases.
  * Capsule-Proxy: Bringing back RBAC reflection to Capsule-Proxy (Generic Namespaced List Permissions)
  * Capsule-Proxy: Deprecating ProxySettings on Tenants in favour of GlobalProxySettings


## Events 📅

* **KubeCon 2026**
   * **Project Pavilion**: We will be present again at the [Project Pavilion](https://events.linuxfoundation.org/kubecon-cloudnativecon-europe/features-add-ons/project-engagement/#project-pavilion) at KubeCon 2026. The exact schedule has not been announced yet, but we will be hosting a booth and look forward to meeting the community in person again. Feel free to reach out to us if you want to meet us there or have any questions about the project.

   * **Lightning Talk** - Histro Histrov, part of the maintainer team, will be speaking about Capsule at KubeCon 2026 in Amsterdam in a Lightning Talk. [Mark the Session](https://kccnceu2026.sched.com/event/2EFxh/project-lightning-talk-namespace-multi-tenancy-but-all-the-problems-related-to-it-hristo-hristov-maintainer)

* **Capsule Roundtable Summer 2026 🇨🇭**
    * We are planning to host a Capsule Roundtable in Summer 2026 in Switzerland. The exact date and location will be announced soon, but we are looking forward to meeting the community in person and discussing the future of Capsule. If you are interested in attending or want to know more about the event, [feel free to reach out to us](https://peakscale.ch/en/contact/). The event is intended for users to present their use-cases and share their experiences with the project, as well as for us to present the roadmap and gather feedback from the community (Not a sales event).


* **CNCF Security Slam 2026** 
   * Capsule will once again be present at the CNCF and accept contributions from the community to improve the security of the project. [Security Slam 2026](https://securityslam.com/slam26/participating-projects). Recap of the award we received in 2023:

  ![capsule-cncf-secslam](/images/blog/security-slam-2023/receiver.jpg)
