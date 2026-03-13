---
title: Replications
weight: 6
description: >
  Replicate resources across tenants or namespaces
---

Capsule provides two dedicated Custom Resource Definitions for propagating Kubernetes resources across Tenant Namespaces, covering both the cluster administrator and Tenant owner personas:

- **[GlobalTenantResource](./global/)** — cluster-scoped, managed by cluster administrators. Selects Tenants by label and replicates resources into all matching Tenant Namespaces.
- **[TenantResource](./tenant/)** — namespace-scoped, managed by Tenant owners. Replicates resources across the Namespaces within a single Tenant.

Both CRDs follow the same structure: resources are defined in `spec.resources` blocks, reconciled on a configurable `resyncPeriod`, and support [Go-template-based generators](/docs/operating/templating/) for dynamic resource creation.
