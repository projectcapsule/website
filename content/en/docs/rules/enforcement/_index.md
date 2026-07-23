---
title: Enforcement
weight: 5
description: >
  Enforcement policies and restrictions on a per-Namespace basis with Rules
---


Namespace rules can enforce admission behavior for selected resources in Tenant namespaces. Each `enforce` block can define an `action` and one or more matchers.

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

## Audience

Use `audience` to restrict a rule to requests made by specific users, groups,
service accounts, or Capsule-defined subject categories. The property belongs to
the root of a rule, alongside `enforce`:

```yaml
spec:
  rules:
    - audience:
        - kind: Group
          name: system:authenticated
      enforce:
        action: allow
        metadata:
          - kinds:
              - ConfigMap
            annotations:
              example.corp/cost-center:
                required: true
                values:
                  - exp: "^INV-[0-9]{4}$"
```

When `audience` is omitted or empty, the rule applies to every request, which is
the same behavior as rules created before audience filtering was introduced.

When an audience is configured, the rule applies if the requesting subject
matches **at least one** entry. In other words, entries are combined with logical
OR semantics. Audience matching is performed consistently for both validation
and mutation, so a subject excluded from a rule is neither validated nor mutated
by that rule.

The supported standard audience kinds are `User`, `Group`, and
`ServiceAccount`:

```yaml
spec:
  rules:
    - audience:
        # Match one exact Kubernetes username.
        - kind: User
          name: alice@example.com

        # Match any request carrying this group.
        - kind: Group
          name: oidc:engineering

        # Match one Kubernetes service account.
        - kind: ServiceAccount
          name: system:serviceaccount:delivery:deployer
      enforce:
        action: deny
        metadata:
          - apiGroups:
              - v1
            kinds:
              - Namespace
            labels:
              pod-security.kubernetes.io/enforce:
                managed: restricted
```

For `User`, `Group`, and `ServiceAccount`, `name` is compared with the identity
information provided in the Kubernetes admission request. A service account is
represented by its canonical Kubernetes username:

```text
system:serviceaccount:<namespace>:<service-account-name>
```

For example, a request from the `deployer` service account in the `delivery`
namespace has the username
`system:serviceaccount:delivery:deployer`.

### Custom

The `Custom` kind exposes audiences based on Capsule's internal identity and
tenant resolution. Its `name` must be one of the supported values below.

| **name** | **description** |
|:---|:---|
| `CapsuleUser` | Matches subjects listed by `configuration.Users()`. |
| `Administrator` | Matches subjects listed by `configuration.Administrators()`. |
| `TenantOwner` | Matches an owner of the tenant resolved for the current request. A request cannot match when no tenant can be resolved. |
| `Controller` | Matches the service account used by the Capsule controller. |

Custom audiences can be combined with standard audiences. The following rule
applies to Capsule users, Capsule administrators, tenant owners, the Capsule
controller, or members of the Kubernetes `system:masters` group:

```yaml
spec:
  rules:
    - audience:
        - kind: Custom
          name: CapsuleUser
        - kind: Custom
          name: Administrator
        - kind: Custom
          name: TenantOwner
        - kind: Custom
          name: Controller
        - kind: Group
          name: system:masters
      enforce:
        action: allow
        metadata:
          - apiGroups:
              - v1
            kinds:
              - Namespace
            annotations:
              example.corp/cost-center:
                default: II-1
```

`TenantOwner` is request-scoped. Capsule first resolves the tenant associated
with the admission request and then checks the requesting subject against that
tenant's owners. This makes it suitable for rules that should affect tenant
owners but not unrelated Capsule users:

```yaml
spec:
  rules:
    - audience:
        - kind: Custom
          name: TenantOwner
      enforce:
        action: allow
        metadata:
          - kinds:
              - ConfigMap
            labels:
              owner-managed:
                default: "true"
```

`Controller` specifically identifies the Capsule controller service account. It
is useful when internal reconciliation requests need different policy behavior
from requests made by ordinary users:

```yaml
spec:
  rules:
    - audience:
        - kind: Custom
          name: Controller
      enforce:
        action: allow
        metadata:
          - kinds:
              - Secret
            labels:
              capsule.clastix.io/reconciled:
                managed: "true"
```

Unknown audience kinds and unsupported `Custom` names are rejected when the
rule is admitted. This catches spelling mistakes and prevents a rule from being
silently configured with an audience that can never match.


## Match expressions

Several workload rule types use a common match expression structure. A matcher must define at least one of `exact` or `exp`. Both fields may be set together; in that case, the matcher succeeds when either the exact list or the regular expression matches.

```yaml
exact:
  - value-a
  - value-b
exp: "value-[0-9]+"
```

| Field | Description |
|---|---|
| `exact` | A list of exact values. The matcher succeeds when the evaluated value equals one of the listed values. |
| `exp` | A regular expression matched against the evaluated value. |
| `negate` | Negates the final match result. This applies to both `exact` and `exp`. |

For example, this matcher matches `registry.local/team-a/app:1.0.0`, `registry.local/team-b/app:1.0.0`, or any reference under `registry.local/shared/*`:

```yaml
exact:
  - registry.local/team-a/app:1.0.0
  - registry.local/team-b/app:1.0.0
exp: "registry.local/shared/.*"
```

With `negate: true`, the final match result is inverted. This means negation applies to exact values as well as regular expressions:

```yaml
exact:
  - registry.local/blocked/app:1.0.0
exp: "registry.local/deprecated/.*"
negate: true
```

This matcher succeeds for every value except `registry.local/blocked/app:1.0.0` and values matching `registry.local/deprecated/.*`.

## Audit

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
        schedulers:
          - exact:
              - custom-scheduler
```

Applying a Pod with `spec.schedulerName: custom-scheduler` succeeds in this audit-only example because no scheduler allow-list is configured. Capsule emits an audit event and returns an admission warning.

When audit rules are used together with allow rules, the matching value must still be allowed explicitly. For example, an audited registry reference that does not match any registry `allow` rule is denied by the allow-list, but Capsule still emits the audit event before denying the request.