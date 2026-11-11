---
title: Audiences
weight: 7
description: >
  Select request identities for namespace rules and replication admission triggers.
---

An `audience` selects the request identities to which a Capsule rule or trigger
applies. [Namespace rules](/docs/rules/#audience) and
[replication admission triggers](/docs/replications/triggers/#audience) use the
same audience kinds and matching semantics.

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
rule or trigger. A nonempty audience matches when **at least one entry** matches:
entries use logical **OR**. In this example, Alice, members of
`oidc:engineering`, and the `delivery/deployer` service account all qualify.

Namespace selection, resource selection, conditions, and other feature-specific
checks must also qualify. An audience does not grant Kubernetes RBAC permissions,
change tenant ownership, or bypass managed-resource protection.

| Used by | Field | Effect when the audience does not match |
| --- | --- | --- |
| Namespace rules | `Tenant.spec.rules[].audience` | Skip that rule's admission mutation and enforcement. Other applicable rules still apply. |
| Replication admission triggers | `spec.triggers[].audience` on a TenantResource or GlobalTenantResource | Skip the reconciliation notification. The trigger does not reject the original request. |

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
| TenantResource triggers | The tenant owning the event source namespace, which is the namespace containing the TenantResource. |
| GlobalTenantResource triggers | The tenant owning the event source namespace. Replication destination tenants do not determine this audience. |

A GlobalTenantResource can select sources outside its destination tenants. If a
source namespace has no tenant, its requests do not match `TenantOwner`.

## Request identity

Audience matching uses the authenticated identity carried by the Kubernetes
admission request. For example, when a workload controller creates a Pod, the
request normally comes from that controller's service account. An audience
matching the user who created the Deployment or Job will not automatically match
that subsequent Pod request.

Account for this distinction when selecting audiences for workload mutation,
enforcement, or replication triggers. `Controller` identifies Capsule's own
service account; it does not match every actor creating resources through a
controller.

Capsule evaluates audiences in its admission handlers. For replication triggers,
the API server first evaluates native operation/resource filters, selectors, and
CEL match conditions; Capsule then checks the audience before queuing a
notification. An audience mismatch can therefore still result in a notification
webhook call.

Unknown kinds, unsupported `Custom` names, and empty names are rejected when the
containing rule or trigger is admitted.
