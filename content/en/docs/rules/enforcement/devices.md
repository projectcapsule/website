---
title: Devices
weight: 7
description: >
  DeviceClass restrictions for Dynamic Resource Allocation claims and templates.
---

DeviceClass enforcement is configured under
`spec.rules[].enforce.devices.classes`. It controls which classes may be
referenced by ResourceClaims and ResourceClaimTemplates in selected Tenant
namespaces. DeviceClasses are cluster-scoped resources used by
[Dynamic Resource Allocation (DRA)](https://kubernetes.io/docs/concepts/resource-management/dynamic-resource-allocation/).

Rules use the shared [namespace selection](/docs/tenants/rules/),
[audiences](/docs/rules/#audience),
[conditions](/docs/rules/#enforcement-conditions), and
[actions and order](/docs/rules/enforcement/#action).
See [Reference](#reference) for a complete Tenant example.

## Rule Composition

### Actions and order

Each requested DeviceClass is evaluated independently in declaration order.
The last matching `allow` or `deny` wins for that class. If `action` is omitted,
it defaults to `deny`.

| Action | Behavior |
|---|---|
| `allow` | Creates an allow-list. A class without a matching allow or deny decision is rejected when an applicable class allow rule exists. |
| `deny` | Rejects matching classes. A later matching allow rule can override the decision. |
| `audit` | Emits `NamespaceRuleAudit` Kubernetes events for matches, without granting access or satisfying an allow-list. No admission warnings are added. |

Every class reference must pass. This includes every `firstAvailable`
alternative, even when Kubernetes could allocate the first allowed alternative.
One forbidden fallback rejects the entire claim or template.

If no class rule applies, these rules add no class restriction. An allow decision
does not bypass RBAC, other admission checks, or an existing
[Tenant-wide DeviceClass restriction](#tenant-wide-restrictions).

### Admission scope and limits

The checks apply to main-resource creation using `resource.k8s.io/v1` or
`resource.k8s.io/v1beta2`:

| Resource | Class references checked |
|---|---|
| `ResourceClaim` | `spec.devices.requests[].exactly.deviceClassName` and every `spec.devices.requests[].firstAvailable[].deviceClassName`. |
| `ResourceClaimTemplate` | The same fields under `spec.spec.devices.requests[]`. |

- Metadata updates, status updates, and deletion do not reauthorize classes.
  A resource with no device requests has no class references to evaluate.
- Namespace selection and policy changes affect subsequent admissions. Existing
  claims and allocations are not revoked or rewritten.
- Claims created by controllers are checked against the current profile of the destination
  namespace. An existing template can therefore stop producing claims
  after the profile changes. Check Kubernetes events on the Pod when claim
  creation fails.
- Class rules validate references; they do not default or replace class names,
  select an allocation, or grant administrative device access.

Class defaults are configured separately through
[Device mutations](/docs/rules/mutate/devices/). They fill missing class names;
the resulting references still have to pass the enforcement rules below.

## Device Classes {#classes}

Each entry in `devices.classes` must define `exact`, `exp`, or `selector`.
Entries are alternatives: any matching entry matches that enforcement rule.
Within an entry, the name criterion and label selector are also alternatives.

| Field | Matching behavior |
|---|---|
| `exact` | Matches one of the supplied DeviceClass names. Names must be valid Kubernetes DNS subdomain names. |
| `exp` | Matches the DeviceClass name using the shared regular-expression matching behavior. Use `^` and `$` when the entire name must match. |
| `negate` | Inverts the combined `exact`/`exp` name match. It does not invert `selector`, and requires a name criterion when set to `true`. |
| `selector.matchLabels` | Matches labels on the referenced DeviceClass. All specified labels must match. |
| `selector.matchExpressions` | Adds standard Kubernetes label-selector requirements, combined with `matchLabels`. |

An omitted or `null` selector adds no label criterion. An explicit
`selector: {}` matches every existing DeviceClass, including classes with no
labels. Claim labels and namespace labels cannot satisfy a DeviceClass selector.
Namespace labels select the profile through `namespaceSelector` instead.

A class list supports up to 64 entries. An `exact` list supports up to 64 names,
and an `exp` supports up to 4096 characters. An omitted class list adds no class
restriction; an explicit empty list is invalid.

### Missing classes and label changes

If any applicable class `allow` or `deny` rule uses a selector, every referenced
DeviceClass must exist, including classes that also match by name. Missing
classes are rejected before rule ordering can grant access. A missing class
does not itself cause an audit-only selector rule to deny admission.

Name-only rules match the requested name without requiring an existing
DeviceClass. They can authorize a name before its class is created. Kubernetes
and the DRA driver must still be able to satisfy the claim. The Tenant-wide
setting described below continues to require existing classes.

Selectors use the class's current labels during admission. Changing class labels
affects subsequent admissions, without revoking existing claims or allocations.

### Conditions and audiences

Use `enforce.conditions` to inspect the incoming claim or template through
`object` and admission metadata through `request`. There is no DeviceClass CEL
variable; use `selector` to match class labels. A false condition skips that
enforcement block, including its allow-list contribution.

With no audience, a rule applies to every caller in the selected namespace,
including controllers and administrators. An audience restricted to Tenant owners
does not cover claims created by Kubernetes controllers on their behalf. Keep
mandatory class restrictions free of caller-specific audiences and conditions
that would exempt those controllers.

### Tenant-wide restrictions {#tenant-wide-restrictions}

The existing `Tenant.spec.deviceClasses` setting remains supported. When it is
configured alongside namespace rules, each reference must pass both policies.
A namespace rule cannot widen the Tenant-wide allow-list. Its current syntax
and behavior are documented under
[Tenant enforcement](/docs/tenants/enforcement/#dynamic-resource-allocation-dra).

### Multi-tenant security

Keep DeviceClass creation, updates, and policy labels under administrator or
trusted infrastructure control. A class name or label does not establish device
ownership; administrators must configure the device selectors on the class and
the DRA driver for the intended access and isolation.

Keep namespace labels that select more permissive profiles under platform
control. A rule scoped to `device-profile: gpu` does not constrain other
namespaces unless another rule covers them. The reference example below denies
all class references first, then grants access in selected namespaces.

Class restrictions do not prevent administrative DRA requests. Apply the
[DRA administrative access baseline](/docs/operating/best-practices/tenants/#dra-administrative-access)
separately to keep administrative access disabled in application namespaces.

## Reference

### Grant GPU classes in selected namespaces

This Tenant denies all class references by default. Namespaces labeled
`device-profile: gpu` receive a later grant for exact names, a name pattern, or
administrator-controlled class labels. A final deny excludes quarantined classes
from that grant.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - kind: User
      name: alice
  rules:
    - enforce:
        action: deny
        devices:
          classes:
            - exp: ".*"
    - namespaceSelector:
        matchLabels:
          device-profile: gpu
      enforce:
        action: allow
        devices:
          classes:
            - exact:
                - solar-gpu
            - exp: "^solar-gpu-[a-z0-9-]+$"
            - selector:
                matchLabels:
                  devices.example.com/tenant: solar
                  devices.example.com/pool: gpu
    - namespaceSelector:
        matchLabels:
          device-profile: gpu
      enforce:
        action: deny
        devices:
          classes:
            - selector:
                matchLabels:
                  devices.example.com/quarantined: "true"
```

The namespace selector matches namespace labels. The nested class selectors
match DeviceClass labels. This example assumes administrators have created the
referenced DeviceClasses with appropriate device selectors. An empty class label
set does not satisfy either class selector.

| Namespace or request | Result with this example |
|---|---|
| Namespace without `device-profile: gpu` | Every class reference is denied by the first rule. |
| Selected namespace, existing `solar-gpu`, not quarantined | Allowed by the exact-name grant. |
| Selected namespace, existing `solar-gpu-h100`, not quarantined | Allowed by the name-expression grant. |
| Selected namespace, another existing class with both `tenant: solar` and `pool: gpu` labels under `devices.example.com/`, not quarantined | Allowed by the class selector. |
| Selected namespace, class with `devices.example.com/quarantined: "true"` | Denied by the final rule, even if its name matches a grant. |
| Selected namespace, unapproved class in any fallback | The entire claim or template is denied. |
| Another Tenant's namespace | This Tenant's rules do not apply there. |

For example, this ResourceClaim is rejected in a selected namespace when
`other-gpu` is an existing class that matches none of the grants, even though
`solar-gpu` is allowed:

```yaml
apiVersion: resource.k8s.io/v1
kind: ResourceClaim
metadata:
  name: gpu
  namespace: solar-production
spec:
  devices:
    requests:
      - name: accelerator
        firstAvailable:
          - name: preferred
            deviceClassName: solar-gpu
          - name: fallback
            deviceClassName: other-gpu
```

Both alternatives must be allowed. For a ResourceClaimTemplate, place the same
device requests under `spec.spec.devices.requests`. Claims subsequently generated
from an admitted template are checked again against the current namespace profile.
