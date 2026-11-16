---
title: Audiences
weight: 7
description: >
  Select request identities for namespace rules.
---

An `audience` selects the request identities to which a
[namespace rule](/docs/rules/#audience) applies.
[Replication resource watches](/docs/replications/triggers/) do not carry request
identities and cannot use audiences.

## Matching

An audience is a list of `kind` and `name` entries:

```yaml
audience:
  - kind: User
    name: alice@example.com
  - kind: Group
    name: oidc:engineering
  - kind: ServiceAccount
    name: system:serviceaccount:delivery:deployer
```

An omitted or empty audience matches every request selected by the containing
rule. A nonempty audience matches when **at least one entry** matches:
entries use logical **OR**. In this example, Alice, members of
`oidc:engineering`, and the `delivery/deployer` service account all qualify.

Namespace selection, resource selection, conditions, and other feature-specific
checks must also qualify. An audience does not grant Kubernetes RBAC permissions,
change tenant ownership, or bypass managed-resource protection.

| Used by | Field | Effect when the audience does not match |
| --- | --- | --- |
| Namespace rules | `Tenant.spec.rules[].audience` | Skip that rule's admission mutation and enforcement. Other applicable rules still apply. |

## Standard audiences

| Kind | Matching behavior | Example `name` |
| --- | --- | --- |
| `User` | Exact match against the requesting username. | `alice@example.com` |
| `Group` | Match when the request includes the named group. | `oidc:engineering` |
| `ServiceAccount` | Exact match against the service account's canonical Kubernetes username. | `system:serviceaccount:delivery:deployer` |

Names are literal, case-sensitive values. They do not support wildcards or
regular expressions. A service account name includes both its namespace and name:

```text
system:serviceaccount:<namespace>:<service-account-name>
```

## Custom audiences

Use `kind: Custom` with one of these supported names:

| Name | Matching behavior |
| --- | --- |
| `CapsuleUser` | Capsule's effective user membership, including configured and aggregated subjects and service accounts in tenant namespaces. Ignored groups are excluded. |
| `Administrator` | A subject matching `CapsuleConfiguration.spec.administrators`. |
| `TenantOwner` | An owner of the tenant resolved for this request, from `Tenant.spec.owners` or effective `Tenant.status.owners`. It does not match when no tenant is resolved. |
| `Controller` | The service account used by the Capsule controller. Other Kubernetes controllers do not match this category. |

`CapsuleUser` follows Capsule's membership checks. The Capsule controller service
account and service accounts in `kube-system` are excluded from this category.
See [Capsule Users](/docs/operating/concepts/architecture/#capsule-users) and
[administrator configuration](/docs/operating/setup/configuration/#administrators)
for the underlying identity configuration.

Custom and standard entries can be combined. This audience matches either a
tenant owner or a member of `platform-operators`:

```yaml
audience:
  - kind: Custom
    name: TenantOwner
  - kind: Group
    name: platform-operators
```

OR semantics also apply when combining custom entries. For example, combining
`CapsuleUser` and `TenantOwner` includes any matching Capsule user, even if that
subject is not an owner of the current tenant.

### Tenant context

`TenantOwner` uses the tenant associated with the request being evaluated:

| Used by | Tenant checked |
| --- | --- |
| Namespace rules | The tenant resolved for the namespace being evaluated. |

## Request identity

Audience matching uses the authenticated identity carried by the Kubernetes
admission request. For example, when a workload controller creates a Pod, the
request normally comes from that controller's service account. An audience
matching the user who created the Deployment or Job will not automatically match
that subsequent Pod request.

Account for this distinction when selecting audiences for workload mutation
or enforcement. `Controller` identifies Capsule's own
service account; it does not match every actor creating resources through a
controller.

Capsule evaluates audiences in its admission handlers.

Unknown kinds, unsupported `Custom` names, and empty names are rejected when the
containing rule is admitted.
