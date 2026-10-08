---
title: Enforce
weight: 5
description: >
  Enforcement policies and restrictions on a per-Namespace basis with Rules
---


Namespace rules can enforce admission behavior for selected resources in Tenant namespaces. Each `enforce` block can define an `action` and one or more matchers.

Each policy chapter identifies its API configuration path, then opens with
**Rule Composition**: **Actions and order**, followed by **Admission scope and
limits**. Policy sections explain configuration and examples. The final
**Reference** section provides complete Tenant examples. Use the
[policy reference](#reference) to choose a chapter.

See [Order and scope](/docs/rules/#order-and-scope) for how mutation precedes
enforcement, and [Conditions](/docs/rules/#enforcement-conditions) for conditional enforcement.
[Audience](/docs/rules/#audience) and [match expressions](/docs/rules/#match-expressions)
are documented under Rules.

## Rule Composition

### Actions and order

<span id="action"></span>

Rules are evaluated in declaration order. If multiple `allow` or `deny` rules match the same evaluated value, the **last matching allow or deny rule wins**. If at least one `allow` rule is configured for a matcher and no `allow` or `deny` rule matches the evaluated value, Capsule denies the request. In other words, `allow` rules create an allow-list for that matcher. `audit` rules are purely observational: they never influence the allow/deny decision, and report matches through Kubernetes events. Some policies also add admission warnings; see the reporting behavior documented for each policy.

Each `enforce` block supports an `action` field:

| Action | Behavior |
|---|---|
| `allow` | Allows the matching request and enables allow-list behavior for the matcher. If at least one allow rule exists and no allow or deny rule matches a value, Capsule denies that value. Additional constraints, such as image pull policy, must also be satisfied. |
| `deny` | Denies the matching request. A later matching `allow` rule can override it. |
| `audit` | Reports matching values without allowing or denying the request. NetworkPolicy CIDR rules emit Kubernetes events; other policies may also return admission warnings. |

If `action` is omitted, Capsule treats the rule as `deny`.

[Storage volume rules](/docs/rules/enforcement/storage/) use these actions only
for additional access to PVs without a Tenant ownership label. They preserve
existing Tenant-owned volume access, and cannot override another Tenant's PV
label. A storage `audit` match never grants access.

Allow-list behavior is evaluated per matcher and per evaluated value. For example, if a registry allow rule exists for `harbor/.*`, a Pod image from `docker.io/library/nginx:latest` is denied unless another later or earlier allow rule also matches that image. Audit rules do not satisfy this allow-list requirement.

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

#### Audit

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

### Admission scope and limits

Enforcement runs during admission for resources in the namespaces selected by
the rule. [Audience](/docs/rules/#audience) filters the caller, and
[conditions](/docs/rules/#enforcement-conditions) decide whether an enforcement
block participates. Each policy chapter lists its supported resources,
operations, subresources, and handling of missing values.

Mutation runs before validation. An `allow` decision applies to its evaluated
policy and value; other applicable checks, RBAC, and Kubernetes API validation
must still pass. In particular, an enclosing `action: audit` does not disable
resource defaulting or mutation.

Enforcement evaluates incoming writes. Changing a rule or namespace profile
does not by itself repair existing resources or revoke established bindings.
Storage ownership, resource mutation, and checks involving related resources
have specific limits documented in their chapters.

## Reference

The following fields belong to `spec.rules[].enforce`. Each policy page includes
a complete Tenant example and explains its supported resources, matching
behavior, and admission scope.

| Policy | Field under `enforce` | Complete Tenant example |
|---|---|---|
| [Workloads](/docs/rules/enforcement/workloads/) | `workloads` | [Workload reference](/docs/rules/enforcement/workloads/#reference) |
| [Metadata](/docs/rules/enforcement/metadata/) | `metadata` | [Metadata reference](/docs/rules/enforcement/metadata/#reference) |
| [Services](/docs/rules/enforcement/network/#services) | `services` | [Service reference](/docs/rules/enforcement/network/#service-reference) |
| [Ingress](/docs/rules/enforcement/network/#ingress) | `ingress` | [Ingress reference](/docs/rules/enforcement/network/#ingress-reference) |
| [Network Policies](/docs/rules/enforcement/network/#policies) | `network.policies.ingress.cidrs`, `network.policies.egress.cidrs` | [NetworkPolicy reference](/docs/rules/enforcement/network/#policies-reference) |
| [Storage](/docs/rules/enforcement/storage/) | `storage.volumes` | [Storage reference](/docs/rules/enforcement/storage/#reference) |

To disallow CIDR-based ingress and egress grants in every namespace of a Tenant:

```yaml
rules:
  - enforce:
      action: deny
      network:
        policies:
          ingress:
            cidrs:
              - 0.0.0.0/0
              - ::/0
          egress:
            cidrs:
              - 0.0.0.0/0
              - ::/0
```

Place this `rules` block under `Tenant.spec`. The rule rejects grants from or to any
IPv4 or IPv6 CIDR, as well as unrestricted ingress or egress rules with omitted
peers. Selector-based peers and empty grant lists pass their CIDR check.
Each direction is independent; omit `ingress` or `egress` to leave that direction
unconstrained.
The [NetworkPolicy reference](/docs/rules/enforcement/network/#policies-reference)
shows how later rules can permit approved ranges in selected namespaces.
