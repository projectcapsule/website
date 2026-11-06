---
title: Tenants
weight: 1
aliases:
  - /docs/operating/best-practices/images/
description: A complete Tenant combining the workload and networking best-practice baseline
---

Use this complete Tenant as a starting point for application namespaces. It
combines the compatible baseline policies from [Workloads](/docs/operating/best-practices/workloads/)
and [Networking](/docs/operating/best-practices/networking/) into one ordered
`spec.rules` list. All namespaces in this Tenant receive the same baseline.

## Included Policies

| Area | Combined configuration |
|---|---|
| Resources | Default CPU, memory, and ephemeral-storage requests; remove CPU limits; match memory limits to requests; default ephemeral-storage limits. |
| Capacity | Share one illustrative quota across all Tenant namespaces. |
| QoS | Deny `BestEffort` after resource mutation. |
| Placement | Use the default scheduler, exclude control-plane nodes, deny control-plane and wildcard tolerations, and reject Pods created with `nodeName`. |
| Workload types | Deny DaemonSets. |
| Pod isolation | Set `hostUsers: false` and manage the namespace's Pod Security labels at `restricted`. |
| Images | Allow the approved registry path and require `Always` pull policy. |
| Priority | Default to and allow only `tenant-standard`. |
| Services | Allow only `ClusterIP` and deny every external IP. |
| Namespace trust | Deny adding or changing `company.com/system` on Tenant namespaces. |
| DRA admin access | Keep administrative device access disabled by denying `resource.kubernetes.io/admin-access: "true"` on Tenant namespaces. |

## Before Applying

* Replace `solar`, `solar-owner`, and `registry.example.com/solar` with your
  Tenant, owner, and approved registry path. Publish immutable image references
  in that registry; the example's registry matcher does not require a digest.
* Size requests, storage defaults, and the shared quota from measured usage and
  available capacity. The numbers below illustrate a profile, not a universal
  production budget. There is deliberately no CPU-limit quota.
* Create the [non-preempting `tenant-standard` PriorityClass](/docs/operating/best-practices/workloads/#priorityclasses)
  before admitting workloads that use this Tenant. The Tenant references the
  class; it does not create it.
* Use Linux nodes with [user namespace support](/docs/operating/best-practices/workloads/#user-namespaces).
  Review kernel, runtime, and volume support before enabling `hostUsers: false`.
  For incompatible workloads, define a separate, reviewed namespace profile.
* Set all three Pod Security version labels to a version supported by your
  cluster. This example pins them to `v1.36`. Applications must supply security
  contexts that satisfy `restricted`; these rules do not generate those fields.
* On OpenShift, also block tenant users from changing OpenShift-managed
  namespace labels and annotations, such as `openshift.io/run-level`, to
  prevent SecurityContextConstraints bypasses. See
  [Example Tenant and TenantOwners](/docs/operating/setup/openshift/#example-tenant-and-tenantowners)
  in the OpenShift guide. OpenShift manages the `pod-security.kubernetes.io/*`
  labels based on the SCCs, so review the Pod Security rules of this baseline
  before applying it there.

## Reference

Explore the ordered rules below. Select a card to open its documentation, or
view, copy, and download the complete Tenant YAML, including ownership and
PriorityClass settings.

{{< tenant-example src="tenants.yaml" >}}
- comment: "One shared budget across all namespaces in this Tenant."
  title: Shared resource budget
  url: /docs/tenants/rules/#quotas
- comment: "Apply placement and user-namespace settings on Pod creation."
  title: Placement and user namespaces
  url: /docs/rules/mutate/workloads/#reference
- comment: "Defaults for application containers, sidecars, and init containers."
  title: Container resource defaults
  url: /docs/rules/enforcement/workloads/#requests-and-limits
- comment: "Normalize limits when a workload supplies Pod-level resources."
  title: Pod-level resource limits
  url: /docs/rules/enforcement/workloads/#targeting-resource-locations
- comment: "Deny BestEffort Pods after resource mutation."
  title: Reject BestEffort Pods
  url: /docs/rules/enforcement/workloads/#qos-classes
- comment: "Reject control-plane and wildcard tolerations."
  title: Control-plane tolerations
  url: /docs/rules/enforcement/workloads/#tolerations
- comment: "Check direct assignment only at creation; allow scheduler-bound updates."
  title: Prevent direct node assignment
  url: /docs/rules/#enforcement-conditions
- comment: "Keep kind-level denials separate from workload property checks."
  title: Block DaemonSets
  url: /docs/rules/enforcement/workloads/#deny-daemonsets
- comment: "Allow approved images with Always pull policy."
  title: Approved image registries
  url: /docs/rules/enforcement/workloads/#registries
- comment: "Allow only ClusterIP Services."
  title: ClusterIP Services only
  url: /docs/rules/enforcement/network/#types
- comment: "Deny all Service external IPs."
  title: Block external IPs
  url: /docs/rules/enforcement/network/#denying-all-external-ips
- comment: "Apply and reconcile Pod Security labels on the Namespace itself."
  title: Restricted Pod Security labels
  url: /docs/rules/enforcement/metadata/#managed
- comment: "Reserve this trusted-platform label for administrator-managed namespaces."
  title: Protect platform trust labels
  url: /docs/rules/enforcement/metadata/#deny-metadata-values
- comment: "Keep DRA administrative access disabled in application namespaces."
  title: Disable DRA admin access
  url: /docs/operating/best-practices/tenants/#dra-administrative-access
{{< /tenant-example >}}

## How the Policies Combine

Capsule applies mutations before validation. On Pod creation, the resource
rules supply missing requests and storage limits, remove CPU limits, and align
memory limits with requests. Explicit requests and storage limits survive the
`Default` policies. Placement mutation adds the control-plane exclusions and
sets `hostUsers: false`; enforcement then checks the resulting Pod.

The workload policies target Pods, including controller-created Pods. The
DaemonSet rule separately rejects the controller itself. Add explicit
[controller targets](/docs/rules/enforcement/workloads/#workload-targets) if
you also want resource or image checks on saved controller templates. Keep the
DaemonSet denial and conditional direct-assignment denial separate: adding
workload properties to a targets-only rule changes its meaning.

The quota rule generates `solar-application-budget`, a
[GlobalResourceQuota](/docs/resource-management/globalresourcequota/) shared
across this Tenant's namespaces. It bounds aggregate consumption; the resource
defaults do not impose maximum requests or reserve node capacity by themselves.
Retain capacity for failover and system services as described in
[capacity planning](/docs/operating/best-practices/workloads/#eviction-and-capacity-planning).

The restricted Pod Security labels are managed values. The platform-label
denial checks added or changed metadata; unchanged existing values are skipped
on updates. Remove any existing tenant-controlled `company.com/system` labels
before using them as a network trust boundary.

The memory-overcommit and ExternalName examples on the individual pages are
deliberate exceptions. Add them only under reviewed namespace selectors, with
the selecting labels under platform control. Review [rule order and scope](/docs/rules/#order-and-scope)
when composing further rules so a later decision does not unintentionally
relax the baseline.

## DRA Administrative Access

Keep [Dynamic Resource Allocation (DRA) administrative access](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/#admin-access)
disabled by default in application Tenant namespaces. A ResourceClaim or
ResourceClaimTemplate with `adminAccess: true` can access devices already in
use by other workloads and may receive additional permissions from the device
driver. Restricting DeviceClasses alone does not prevent this privileged mode.

Kubernetes permits these requests in namespaces labeled
`resource.kubernetes.io/admin-access: "true"`. Keep that label absent and prevent
Tenant users from enabling it. The example's final metadata rule denies the
`"true"` value on namespace creation and on updates that add or change the
label. Namespaces without the label, the value `"false"`, and updates removing
the label remain allowed. Ordinary DRA requests remain available, subject to
any configured DeviceClass restrictions.

Apply this rule to every application Tenant without namespace selectors,
audiences, or conditions, so the restriction covers every namespace and caller.
Review later rules and managed metadata to ensure they do not enable the label.
Reserve administrative device access for separately reviewed namespaces under
platform control.

Before applying the baseline, remove any existing
`resource.kubernetes.io/admin-access: "true"` labels. Metadata validation skips
unchanged values on updates, so the denial does not clean up existing labels.
Also review existing claims and running workloads with `adminAccess: true`;
removing the label does not revoke device access from running workloads.

## Complete the Platform Setup

Apply the [native NetworkPolicy GlobalTenantResource](/docs/operating/best-practices/networking/#native-networkpolicies-with-globaltenantresource)
alongside this Tenant. It distributes default-deny, same-Tenant, DNS, and
platform-ingress policies; NetworkPolicies are not embedded in this Tenant
manifest. Review its CNI requirements and the permissions needed to prevent
tenants from adding policies that widen access.

Use the [additional admission policies](/docs/operating/best-practices/admission-policies/)
for requirements such as PDB validation, `emptyDir.sizeLimit`, debugging access,
and certificate issuer restrictions. Those examples require their respective
admission mechanisms and are not installed by this Tenant.

Configure [authentication, registry mirrors, and secret management](/docs/operating/best-practices/)
at platform level. Review existing workloads and Services before rollout;
admission policies do not remove previously admitted resources.
