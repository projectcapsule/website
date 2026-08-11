---
title: Resource Management
description: >
  Manage resources across tenants and namespaces, including replication, quotas, and limits with custom quota mechanisms.
weight: 6
---

Capsule provides three complementary resource-management systems. Choose the system based on whether you want to limit actual usage, allocate capacity before it is used, or calculate a custom quantity from Kubernetes objects.

| | [GlobalResourceQuota](globalresourcequota/) | [ResourcePool](resourcepools/) | [CustomQuota / GlobalCustomQuota](customquotas/) |
| --- | --- | --- | --- |
| Main purpose | Enforce one immediate, shared ceiling on actual usage. | Allocate a fixed amount of capacity to namespaces through claims. | Enforce a limit on a custom quantity calculated from selected objects. |
| Accounting model | Native Kubernetes `ResourceQuotaSpec`, including compute, storage, object counts, scopes, and scope selectors. | Native Kubernetes resource quantities distributed through `ResourcePoolClaim` objects. | One or more sources using `add`, `sub`, or `count`; values can be extracted with JSONPath and filtered with selectors. |
| Namespace distribution | Dynamic. All selected namespaces compete for the same available budget. | Explicit. Each namespace receives the capacity assigned by its claims. | `CustomQuota` covers one namespace; `GlobalCustomQuota` aggregates across selected namespaces. |
| Admission behavior | Atomically reserves usage and denies requests that would exceed the shared hard limit. | Claims reserve pool capacity; the resulting native `ResourceQuota` enforces workload usage in the namespace. | Atomically reserves the calculated usage when the calculation webhook is enabled; otherwise it is observational only. |
| Best fit | Kubernetes-native compute, memory, storage, and object-count quotas shared across namespaces. | Delegated self-service allocation where teams claim and release portions of platform capacity. | Quantities not covered by native ResourceQuota accounting, custom resource fields, or advanced calculations across multiple sources. |

Start with `GlobalResourceQuota` when the requirement can be expressed with Kubernetes `ResourceQuota` resources and semantics. It directly limits aggregate usage and safely handles concurrent requests across namespaces.

Use `ResourcePool` when capacity allocation should be separate from workload consumption. Platform administrators define the available pool, while namespace users claim and release their portion of it.

Use `CustomQuota` or `GlobalCustomQuota` when the quantity cannot be represented by native `ResourceQuota`, or when you need a custom calculation. Custom quotas can extract Kubernetes quantities from arbitrary namespaced resources or CRDs through JSONPath, combine multiple sources, and apply `add`, `sub`, or `count` operations. Use `CustomQuota` for one namespace and `GlobalCustomQuota` for an aggregate limit across selected namespaces.
