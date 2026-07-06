---
title: Overview
weight: 2
description: Run multiple teams on a single Kubernetes cluster with strong isolation, self-service, and zero cluster sprawl.
---

Capsule is a Kubernetes Operator that turns a single cluster into a shared, multi-tenant platform. Teams get their own isolated space: a **Tenant**. Within their Tenant they own namespaces, resource budgets, and policies. Cluster administrators maintain full control, while teams work autonomously without stepping on each other.

No custom Kubernetes distribution. No extra tooling your users need to learn. Just plain Kubernetes, made shareable.

## The Problem

Kubernetes namespaces provide a basic level of isolation, but they have no hierarchy. As soon as multiple teams or customers need to share a cluster, you face hard choices:

- **Isolation is all-or-nothing** - there is no native way to group namespaces per team or enforce consistent policies across them.
- **Namespace sprawl** - cluster admins become a bottleneck, manually creating and configuring every namespace.
- **Cluster sprawl** - organizations spin up a separate cluster per team to achieve proper isolation, multiplying operational overhead across the board.

## How Capsule Works

Capsule introduces the **Tenant**: a lightweight, cluster-scoped resource that groups one or more Kubernetes namespaces under a shared set of boundaries.

Everything defined on a Tenant is automatically inherited by all its namespaces:

- **RBAC bindings** - roles are propagated to every namespace without manual setup.
- **Resource quotas & limits** - CPU, memory, and storage budgets managed at the tenant level via [Resource Pools](/docs/resource-management/resourcepools/) or [Custom Quotas](/docs/resource-management/customquotas/).
- **Admission rules** - allowed image registries, pull policies, security contexts, and more.
- **Templated resource distribution** - using [Replications](/docs/replications/), resources such as NetworkPolicies, ImagePullSecrets, and LimitRanges are automatically distributed into all namespaces a Tenant Owner creates, using Go templates for dynamic values like namespace name or tenant name.

![capsule-workflow](/images/content/capsule-architecture.drawio.png)

## Who Does What

| Role | Responsibility |
|---|---|
| **Cluster Admin** | Installs Capsule, creates Tenants, sets resource budgets and policies. Never a bottleneck for day-to-day namespace work. |
| **Tenant Owner** | Creates and manages namespaces within their Tenant. Assigns access to team members. No cluster-level permissions needed. |
| **Tenant User** | Deploys workloads inside tenant namespaces, within the limits the owner has set. |

This shift-left model means Tenant Owners handle day-to-day namespace operations themselves, freeing cluster admins from repetitive provisioning work.

## Key Features

- **[Tenants & Namespaces](/docs/tenants/)**: Group namespaces into logical units per team, product, or customer. Policy inheritance is automatic.
- **[Resource Management](/docs/resource-management/)**: Distribute CPU, memory, and storage budgets across namespaces with flexible claiming rather than fixed per-namespace quotas.
- **[Replications](/docs/replications/)**: Propagate Kubernetes resources (Secrets, ConfigMaps, etc.) across tenant namespaces automatically.
- **[Policy Rules](/docs/tenants/rules/)**: Enforce allowed registries, pull policies, and namespace metadata requirements on a per-tenant basis.
- **[Capsule Proxy](/docs/proxy/)**: Let users run `kubectl get namespaces` and see only their own, without granting cluster-wide LIST permissions. Also works for other cluster-wide requests, like `kubectl get pods -A`, or listing Persistent Volumes that are used by a Persistent Volume Claim inside the tenant.

## Capsule Controller

The Capsule controller is a Kubernetes operator that continuously watches Tenant resources and reconciles the desired state across all namespaces that belong to a tenant. When a Tenant is created or updated, the controller automatically propagates the configured policies to every namespace in that tenant.

When a Tenant Owner creates a new namespace, the controller detects it and immediately applies all inherited policies. This means tenants are always in a consistent, compliant state, even as they grow.

![capsule-operator](/images/content/capsule-operator.png)

## Get Started

- [**Quickstart** - create your first Tenant in minutes](/docs/tenants/quickstart/)
- [**Tenant Docs** - explore everything Tenants can do](/docs/tenants/)
