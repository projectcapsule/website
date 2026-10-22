---
title: What's New ✨
description: >
  Discover new features from the current version in one place.
weight: 1
layout: whats-new
outputs:
  - HTML
  - RSS
  - markdown
---

## Events 📅

{{< events-calendar >}}

## Security 🔒

* Advisory [GHSA-pvhj-cqh2-rpq8](https://github.com/projectcapsule/capsule-proxy/security/advisories/GHSA-pvhj-cqh2-rpq8) - **High** - Tenant Owners could grant themselves cross-tenant and cluster-scoped read access through `clusterResources` in a namespaced `ProxySetting`. Affects Capsule Proxy `<= 0.14.1`.
* **(Enterprise)**: Projectcapsule is now providing their releases on an immutable OCI registry, which allows users to verify the integrity of the images and provides a more secure way to distribute the images. Which is not possible on GHCR due to the fact that GHCR does not support immutability of images.
* [OpenShift] Added documentation showing how to prevent CapsuleUsers from modifying OpenShift-managed namespace labels and annotations, including `openshift.io/run-level`, to help prevent SecurityContextConstraints bypasses. [Read More](/docs/operating/setup/openshift/#example-tenant-and-tenantowners)

## Breaking Changes ⚠️

* **Proxy**: A namespaced [`ProxySetting`](/docs/proxy/proxysettings/#proxysetting) can no longer grant `clusterResources`. Move existing grants to a [`GlobalProxySettings`](/docs/proxy/proxysettings/#globalproxysettings), which requires the `ProxyClusterScoped` feature gate.

## Features ✨

* **Capsule**: [Resource policies](/docs/operating/concepts/managed-resources/#resource-policy) for `TenantResource` and `GlobalTenantResource` add conditional application and control over resource adoption, protection, and cleanup.

* **Capsule**: The rules API now offers more ways to configure and enforce namespace profiles:

   * [Workload Placement Mutation](/docs/rules/mutate/workloads/#placement): Configure schedulers, node selectors, tolerations, affinity, and topology spread constraints on new Pods with merge or replace actions.
   * [Workload User Namespace Mutation](/docs/rules/mutate/workloads/#host-user-namespace): Request separate user namespaces for new Pods with `security.hostUsers: false`.
   * [Workload Read-only Root Filesystem Mutation](/docs/rules/mutate/workloads/#read-only-root-filesystem): Set `security.readOnlyRootFilesystem` for selected regular, init, and newly added ephemeral containers.
   * [Workload Seccomp Mutation](/docs/rules/mutate/workloads/#seccomp): Default or replace Pod-level seccomp profiles, including node-local profile paths.
   * [Workload AppArmor Mutation](/docs/rules/mutate/workloads/#apparmor): Default or replace Pod-level AppArmor profiles, including named profiles loaded on nodes.
   * [ListenerSet Gateway Reference Mutation](/docs/rules/mutate/ingress/#listenersets): Default or replace Gateway parent references on ListenerSet creation and updates in selected namespaces, with Tenant/Namespace templates. The API group and kind default to `gateway.networking.k8s.io` and `Gateway`.
   * [Mutation Conditions](/docs/rules/#mutation-conditions): Apply individual mutation entries conditionally with CEL expressions that inspect the resource and admission request.
   * [Workload Placement Enforcement](/docs/rules/enforcement/workloads/#placement): Control which schedulers, node selectors, tolerations, affinity rules, and topology spread constraints workloads may use.
   * [Workload Type Enforcement](/docs/rules/enforcement/workloads/#select-workloads): Allow, deny, or audit selected workload kinds, such as blocking DaemonSets in application namespaces.
   * [Pod Disruption Budget Enforcement](/docs/rules/enforcement/workloads/#pod-disruption-budgets): Require room for voluntary evictions, prevent overlapping PDBs, and control unhealthy Pod eviction. Checks cover PDB and workload changes, including controller scaling.
   * [Workload Seccomp Enforcement](/docs/rules/enforcement/workloads/#seccomp): Restrict effective seccomp profile types and local profile paths across selected Pods and containers.
   * [Workload AppArmor Enforcement](/docs/rules/enforcement/workloads/#apparmor): Restrict effective AppArmor profiles, including container overrides and named profiles loaded on nodes.
   * [NetworkPolicy Ingress and Egress CIDR Enforcement](/docs/rules/enforcement/network/#policies): Allow, deny, or audit IPv4 and IPv6 ingress and egress CIDR grants in selected namespaces, accounting for overlapping ranges and `ipBlock.except`.
   * [Enforcement Conditions](/docs/rules/#enforcement-conditions): Apply an enforcement block only to resources and admission requests that match your CEL conditions.
   * [Additional PersistentVolume Access](/docs/rules/enforcement/storage/): Authorize restore handoffs and other explicit PVC bindings to PVs without a Tenant label, using namespace profiles, read-only label selectors, audiences, and CEL conditions on the referenced `volume`. Existing Tenant ownership labels remain authoritative.

## Documentation 📚

We have added new documentation for a better experience. See the following topics:

* **[Best Practices for Tenants](/docs/operating/best-practices/tenants/)**
* **[Best Practices for Networking](/docs/operating/best-practices/networking/)**
* **[Best Practices for Workloads](/docs/operating/best-practices/workloads/)**

## Ecosystem 🌐

Dedicated Addons joining the capsule ecosystem

* [Change Windows](https://change-windows.addons.projectcapsule.dev/): Change Windows helps organizations plan routine IT maintenance with fewer surprises and less manual coordination. It gives teams advance notice and can prevent conflicting changes while planned work is underway. It can also pause development environments overnight and bring them back in the morning, helping control infrastructure costs. These routines run automatically on your Kubernetes platform, so teams can spend less time coordinating maintenance and more time delivering services.

* [Resource Permits](https://resource-permits.addons.projectcapsule.dev/): Resource Permits helps platform teams offer services without handling every request manually or handing out broad administrator access. Teams request a predefined service, reviewers decide whether to approve it, and Kubernetes tracks the resources and their lifecycle. Requests can be made through the Kubernetes API, the kubectl plugin, or Headlamp.

Newly added documentation to integrate Capsule with other applications:

* [Opensearch](/ecosystem/integrations/opensearch/)
* [External Secrets Operator](/ecosystem/integrations/eso/)
* [Headlamp Plugin](/ecosystem/integrations/headlamp/#plugins)

## Roadmap 🗺️

In the upcoming releases we are planning to work on the following features:

  * Capsule: Porting more Properties to the Namespace Rule Approach.
  * Capsule: Adding `triggers` for `Global`/`TenantResources`.
  * Capsule: Adding `healthChecks` for `Global`/`TenantResources`.
  * Capsule: Adding Generic Implementation for `Global`/`TenantResources`.
  * Website: Improving the documentation with more examples and use-cases.
