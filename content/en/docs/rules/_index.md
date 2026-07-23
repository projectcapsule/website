---
title: Rules
weight: 5
description: >
  Configure policies and restrictions on a per-Namespace basis with Rules
---

Enforcement rules allow Bill, the cluster administrator, to set policies and restrictions on a per-`Tenant` basis. These rules are enforced by Capsule admission webhooks when Alice, the `TenantOwner`, creates or modifies resources in her `Namespaces`. With the rule construct, namespaces within the same tenant can be profiled differently depending on their metadata.

Rules cover two areas:

- **[Enforcement](/docs/rules/enforcement/)**: control allowed workloads, ingress hostnames, service types, and namespace metadata.
- **[Permissions](/docs/rules/permissions/)**: distribute RoleBindings and promote ServiceAccounts across Tenant namespaces.
