---
title: Architecture
weight: 10
description: Architecture references and considerations
---


## Ownership

In Capsule, we introduce a new persona called the `Tenant Owner`. The goal is to enable Cluster Administrators to delegate tenant management responsibilities to Tenant Owners. Here’s how it works:

* `Tenant Owners`: They manage the namespaces within their tenants and perform administrative tasks confined to their tenant boundaries. This delegation allows teams to operate more autonomously while still adhering to organizational policies.
* `Cluster Administrators`: They provision tenants, essentially determining the size and resource allocation of each tenant within the entire cluster. Think of it as defining how big each piece of cake (Tenant) should be within the whole cake (Cluster).

Capsule provides robust tools to strictly enforce tenant boundaries, ensuring that each tenant operates within its defined limits. This separation of duties promotes both security and efficient resource management.

## Scheduling

Workload distribution across your compute infrastructure can be approached in various ways, depending on your specific priorities. Regardless of the use case, it's essential to preserve maximum flexibility for your platform administrators. This means ensuring that:

  - Nodes can be drained or deleted at any time.
  - Cluster updates can be performed at any time.
  - The number of worker nodes can be scaled up or down as needed.

If your cluster architecture prevents any of these capabilities, or if certain applications block the enforcement of these policies, you should reconsider your approach.

### Dedicated

Strong tenant isolation, ensuring that any noisy neighbor effects remain confined within individual tenants (tenant responsibility). This approach may involve higher administrative overhead and costs compared to shared compute. It also provides enhanced security by dedicating nodes to a single customer/application. It is recommended, at a minimum, to separate the cluster’s operator workload from customer workloads.

![Dedicated Nodepool](/images/content/node-schedule-dedicated.gif)

### Shared

With this approach you share the nodes amongst all Tenants, therefor giving you more potential for optimizing resources on a node level. It's a common pattern to separate the controllers needed to power your distro (operators) form the actual workload. This ensures smooth operations for the clust

**Overview**:

- ✅ Designed for cost efficiency .
- ✅ Suitable for applications that typically experience low resource fluctuations and run with multiple replicas. 
- ❌ Not ideal for applications that are not cloud-native ready, as they may adversely affect the operation of other applications or the maintenance of node pools.
- ❌ Not ideal if strong isolation is required
  
![Shared Nodepool](/images/content/node-schedule-shared.gif)

There's some further aspects you must think about with shared approaches:

  * [PriorityClasses](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)
  * [ResourceQuotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
  * [LimitRanges](https://kubernetes.io/docs/concepts/policy/limit-range/)
  * [Descheduling/Rebalancing](https://github.com/kubernetes-sigs/descheduler)
