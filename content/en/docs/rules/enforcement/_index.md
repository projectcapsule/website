---
title: Enforce
weight: 5
description: >
  Enforcement policies and restrictions on a per-Namespace basis with Rules
---


Namespace rules can enforce admission behavior for selected resources in Tenant namespaces. Each `enforce` block can define an `action` and one or more matchers.

See [Order and scope](/docs/rules/#order-and-scope) for how mutation precedes
enforcement, and [Conditions](/docs/rules/#enforcement-conditions) for conditional enforcement.
[Audience](/docs/rules/#audience) and [match expressions](/docs/rules/#match-expressions)
are documented under Rules.

Rules are evaluated in declaration order. If multiple `allow` or `deny` rules match the same request, the **last matching allow or deny rule wins**. If at least one `allow` rule is configured for a workload matcher and no `allow` or `deny` rule matches the evaluated value, Capsule denies the request. In other words, `allow` rules create an allow-list for that matcher. `audit` rules are purely observational: they never influence the allow/deny decision, but all matching audit rules emit Kubernetes events and add admission warnings.

## Action

Each `enforce` block supports an `action` field:

| Action | Behavior |
|---|---|
| `allow` | Allows the matching request and enables allow-list behavior for the matcher. If at least one allow rule exists and no allow or deny rule matches a value, Capsule denies that value. Additional constraints, such as image pull policy, must also be satisfied. |
| `deny` | Denies the matching request. A later matching `allow` rule can override it. |
| `audit` | Emits a Kubernetes event and returns an admission warning when it matches. It does not allow or deny the request. |

If `action` is omitted, Capsule treats the rule as `deny`.

Allow-list behavior is evaluated per workload matcher and per evaluated value. For example, if a registry allow rule exists for `harbor/.*`, a Pod image from `docker.io/library/nginx:latest` is denied unless another later or earlier allow rule also matches that image. Audit rules do not satisfy this allow-list requirement.

This precedence model allows both broad defaults and specific exceptions. For example, you can allow all Harbor images but deny a customer path afterwards:

```yaml
rules:
  - enforce:
      action: allow
      workloads:
        registries:
          - exp: "harbor/.*"

  - enforce:
      action: deny
      workloads:
        registries:
          - exp: "harbor/customer/.*"
```

In this example, `harbor/nginx:1.14.2` is allowed, while `harbor/customer/app:1.0.0` is denied because the later, more specific deny rule also matches.

You can also deny broadly and allow a more specific exception afterwards:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        registries:
          - exp: "harbor/customer/.*"

  - enforce:
      action: allow
      workloads:
        registries:
          - exp: "harbor/customer/prod-image/.*"
```

In this example, `harbor/customer/test-image/app:1.0.0` is denied, while `harbor/customer/prod-image/app:1.0.0` is allowed.

### Audit

Use `action: audit` to observe workload usage without directly blocking the request. Audit rules emit Kubernetes events and add warnings to the admission response, but they do not allow or deny the request. If an allow-list is active for the same matcher and no allow rule matches the evaluated value, the request is still denied even when an audit rule matches.

For registry enforcement:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  ...
  rules:
    - enforce:
        action: audit
        workloads:
          targets:
            - pod/containers
          registries:
            - exp: "docker.io/.*"
```

Applying a Pod with `docker.io/library/nginx:latest` succeeds in this audit-only example because no registry allow-list is configured. The API server response contains an admission warning and Capsule emits a related event for the Pod.

For QoS enforcement:

```yaml
rules:
  - enforce:
      action: audit
      workloads:
        qosClasses:
          - Burstable
```

Applying a `Burstable` Pod succeeds in this audit-only example because no QoS allow-list is configured. Capsule emits an event and returns an admission warning.

For scheduler enforcement:

```yaml
rules:
  - enforce:
      action: audit
      workloads:
        placement:
          schedulers:
            - exact:
                - custom-scheduler
```

Applying a Pod with `spec.schedulerName: custom-scheduler` succeeds in this audit-only example because no scheduler allow-list is configured. Capsule emits an audit event and returns an admission warning.

When audit rules are used together with allow rules, the matching value must still be allowed explicitly. For example, an audited registry reference that does not match any registry `allow` rule is denied by the allow-list, but Capsule still emits the audit event before denying the request.
