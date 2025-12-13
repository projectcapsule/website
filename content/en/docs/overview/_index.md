---
title: Overview
weight: 2
description: Understand the problem Capsule is attempting to solve and how it works
---

Capsule implements a multi-tenant, policy-based environment in your Kubernetes cluster. It is designed as a microservices-based ecosystem with a minimalist approach, leveraging only upstream Kubernetes.

With Capsule, you have an ecosystem that addresses the challenges of hosting multiple parties on a shared Kubernetes cluster. Let's look at a typical scenario for using Capsule.

<br>

![capsule-workflow](/images/content/capsule-architecture.drawio.png)

As shown, we can create a new boundary between Kubernetes (cluster) administrators and tenant audiences. While Kubernetes administrators define the boundaries of a tenant, the tenant audience can act within the namespaces of that tenant. For the tenant audience, we differentiate between Tenant Owners and Tenant Users. The main advantage Tenant Owners are granted is the ability to create namespaces within the tenants they own. This achieves a shift-left approach: instead of depending on Kubernetes administrators to create namespaces, Tenant Owners can manage this themselves, thereby granting them greater autonomy within strictly defined boundaries.


## What's the problem with the current status?

Kubernetes introduces the Namespace object type to create logical partitions of the cluster as isolated slices. However, when implementing advanced multi-tenancy scenarios, this soon becomes complicated because of the flat structure of Kubernetes namespaces and the impossibility of sharing resources among namespaces belonging to the same tenant. To overcome this, cluster admins tend to provision a dedicated cluster for each group of users, teams, or departments. As an organization grows, the number of clusters to manage and keep aligned becomes an operational nightmare, described as the well-known phenomenon of cluster sprawl.

## Entering Capsule

Capsule takes a different approach. In a single cluster, the Capsule Controller aggregates multiple namespaces in a lightweight abstraction called a Tenant—basically a grouping of Kubernetes namespaces. Within each tenant, users are free to create their namespaces and share all the assigned resources.

On the other side, the Capsule Policy Engine keeps the different tenants isolated from each other. Network and security policies, resource quotas, limit ranges, RBAC, and other policies defined at the tenant level are automatically inherited by all the namespaces in the tenant. Users are then free to operate their tenants autonomously, without intervention from the cluster administrator.

<br>

![capsule-operator](/images/content/capsule-operator.svg)


## What problems are out of scope

Capsule does not aim to solve the following problems:

* Handling of Custom Resource Definition management. Capsule does not aim to manage the control of Custom Resource Definition. Users have to implement their own solution.
