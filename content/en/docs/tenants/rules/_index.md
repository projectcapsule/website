---
title: Rules
weight: 1
description: >
  Configure policies and restrictions on a per-Namespace basis with Rules
---

Enforcement rules allow Bill, the cluster administrator, to set policies and restrictions on a per-`Tenant` basis. These rules are enforced by Capsule admission webhooks when Alice, the `TenantOwner`, creates or modifies resources in her `Namespaces`. With the rule construct, namespaces within the same tenant can be profiled differently depending on their metadata.

## Namespace Selector

By default, a rule applies to all namespaces within a `Tenant`. To apply a rule only to a subset of namespaces, use `namespaceSelector`. The selector follows the standard Kubernetes label selector semantics.

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  ...
  rules:
    # Matches all Namespaces and enforces the rule for all of them.
    - enforce:
        action: allow
        workloads:
          registries:
            - exact:
                - harbor/v2/customer-registry/debian:latest
              policy: ["IfNotPresent"]

    # Selects a subset of namespaces (environment=prod) to allow additional registries.
    - namespaceSelector:
        matchExpressions:
          - key: environment
            operator: In
            values: ["prod"]
      enforce:
        action: allow
        workloads:
          registries:
            - exp: "harbor/v2/prod-registry/.*"
              policy: ["IfNotPresent"]
```

Rules are combined together. In this example, all namespaces within the `solar` tenant can use the exact `harbor/v2/customer-registry/debian:latest` image, while namespaces labeled with `environment=prod` can also use images from `harbor/v2/prod-registry/*`.

## Templating

Namespace rule bodies are rendered as Go templates before they are written into the per-namespace `RuleStatus`. This allows administrators to define generic Tenant rules that are rendered differently for each Namespace. Templates can use the `tenant` and `namespace` objects as context, including metadata such as names, labels, and annotations.

For example, the following rule allows an image reference based on the current Tenant and Namespace name:

```yaml
rules:
  - enforce:
      action: allow
      workloads:
        registries:
          - exact:
              - "{{ .tenant.metadata.name }}/{{ .namespace.metadata.name }}/app:1"
```

For a Tenant named `solar` and a Namespace named `solar-prod`, this rule is rendered into an exact registry reference of `solar/solar-prod/app:1`.

Labels and annotations can also be used. Because many Kubernetes label and annotation keys contain dashes, dots, or slashes, use the `index` function when accessing them:

```yaml
rules:
  - enforce:
      action: allow
      workloads:
        registries:
          - exact:
              - "{{ index .namespace.metadata.labels \"registry-prefix\" }}/app:1"
```

If the Namespace has the label `registry-prefix=harbor/team-a`, the rendered registry rule becomes `harbor/team-a/app:1`.

Templates are rendered after `namespaceSelector` matching and before rule evaluation. This means a selected rule can use the concrete Namespace context while preserving the original rule order. Rule order remains important because the last matching `allow` or `deny` rule wins.

If a template references a missing key, Capsule marks the Tenant as not ready and reports the rendering error in the Tenant status. This prevents partially rendered or ambiguous rules from being applied silently.