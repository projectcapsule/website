---
title: Rules
weight: 5
aliases:
  - /docs/tenants/rules/
  - /docs/rules/conditions/
description: >
  Configure policies and restrictions on a per-Namespace basis with Rules
---

Namespace rules let administrators configure behavior for resources in Tenant
namespaces. Use namespace selectors to give namespaces within the same Tenant
different profiles. Rules can set workload properties during admission and
validate the resulting resources.

Rules cover two areas:

- **[Mutate](/docs/rules/mutate/)**: apply typed workload settings to new Pods in selected namespaces.

- **[Enforcement](/docs/rules/enforcement/)**: control allowed workloads, ingress hostnames, service types, and namespace metadata.

See [Conditions](#conditions) for conditional mutation and enforcement.

## Order and scope

Capsule first **mutates** the admission object, then **enforces** policies against
the result. Both phases use the rules selected for the namespace and requesting
subject.

A Tenant rule's `namespaceSelector` selects its namespaces; omitting it selects
all namespaces in that Tenant. Matching Tenant rules retain their declaration
order in the namespace's effective RuleStatus, including rules containing only
`mutate`. Tenant/Namespace templating and [audience](#audience) filtering apply
to both mutation and enforcement.

### Admission order

1. **Mutate.** Apply applicable
   [metadata mutations](/docs/rules/enforcement/metadata/), then
   [resource request/limit mutations](/docs/rules/enforcement/workloads/#requests-and-limits),
   then `mutate` entries in list order within the effective rule order. Each
   entry and its conditions see the object after preceding mutations. When
   entries change the same property, its merge or replacement behavior determines
   the result.
2. **Enforce.** Evaluate applicable policies against the resulting admission
   object, including mutated values and values injected by Kubernetes. A mutation
   must satisfy the applicable enforcement policies; an incompatible combination
   rejects the request.

Mutation runs across the applicable rules before enforcement. Capsule does not
alternate mutation and enforcement for each rule. `mutate` and `enforce` are
independent sibling blocks; `enforce.action` does not select or disable mutations.

Some settings under `enforce`, such as managed metadata and resource defaults,
produce mutations in the first phase. Their `enforce.conditions` are checked
before those changes and evaluated again during enforcement. See
[Enforcement conditions](#enforcement-conditions) for which object each phase
uses.

### Resource scope

`mutate[].workloads` applies when a Pod is created, including Pods created by
Deployments, StatefulSets, and other controllers.
[`security.readOnlyRootFilesystem`](/docs/rules/mutate/workloads/#read-only-root-filesystem)
and [`registries.imagePullPolicy`](/docs/rules/mutate/workloads/#image-pull-policy)
also apply to newly added ephemeral containers on `UPDATE
pods/ephemeralcontainers`; all other workload mutation properties are skipped
on that subresource. Controller templates and existing containers are not
rewritten. Other Pod updates, deletes, and subresources do not run workload
mutations. Rule or namespace-label changes affect new Pods and new ephemeral
containers within the property's supported scope.
Each rule supports up to 64 mutation entries. Placement mutations do not
accumulate duplicate entries when admission is reinvoked.

Enforcement runs for the resource types and operations supported by each policy.
[`enforce.workloads.targets`](/docs/rules/enforcement/workloads/#workload-targets)
selects native workload kinds and policy locations. Targets-only entries apply
the action to the kind; entries with workload policies scope those checks.
Controller targets explicitly enable template validation and resource
request/limit mutation on controller creation and updates. Omitted targets
preserve Pod-only defaults. Enforcement targets do not control
`mutate[].workloads.targets`, whose separate
[selection rules](/docs/rules/mutate/workloads/#targets) include all container
groups when `pod` is selected. [Conditions](#conditions)
can narrow a policy's scope but cannot expand its supported operations.

## Audience

Use `audience` to restrict a rule to requests made by specific users, groups,
service accounts, or Capsule-defined subject categories. The property belongs to
the root of a rule, alongside `mutate` and `enforce`:

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

When `audience` is omitted or empty, the rule applies to every request selected
by the rule.

When an audience is configured, the rule applies if the requesting subject
matches **at least one** entry. In other words, entries are combined with logical
OR semantics. Audience matching is performed consistently for both validation
and mutation, so a subject excluded from a rule is neither validated nor mutated
by that rule.

Audience filtering uses the actual identity on the Pod admission request. Pods
created by a workload controller are normally submitted by that controller's
service account, not by the user who originally created the Deployment or Job.
Account for that distinction when combining `audience` with mutation or enforcement.

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

Rule fields that accept match expressions use a common structure. A matcher must define at least one of `exact` or `exp`. Both fields may be set together; in that case, the matcher succeeds when either the exact list or the regular expression matches.

```yaml
exact:
  - value-a
  - value-b
exp: "value-[0-9]+"
```

| Field | Description |
|---|---|
| `exact` | Up to **64 exact values** per matcher. The matcher succeeds when the evaluated value equals one of the listed values. |
| `exp` | A Go regular expression of up to **4,096 Unicode characters**, matched against the evaluated value. |
| `negate` | Negates the final match result. This applies to both `exact` and `exp`. |

These limits apply wherever match expressions are used, including placement and localhost profile matchers. Policies exceeding either limit are rejected when saved. Both limits still apply when `exact` and `exp` are used together or `negate` is enabled. Existing policies exceeding these limits must be reduced before they can be updated.

Anchor regular expressions with `^` and `$` to match the whole string.

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

## Conditions

Conditions determine whether a mutation entry or enforcement rule applies to
the current admission request. They are optional and belong alongside `action`
at `mutate[].conditions` or `enforce.conditions`.

| Location | Scope |
|---|---|
| `mutate[].conditions` | The entire mutation entry, within the property's supported targets and operations. |
| `enforce.conditions` | The entire `enforce` block: workloads, Services, metadata, and ingress, including metadata and resource request/limit mutations. |

A false mutation condition skips only its mutation entry. A false enforcement
condition skips that `enforce` block, while sibling `mutate` entries and other
rules continue. Namespace selection and audience filtering apply first.

Conditions are evaluated only when the entry or enforcement policy applies to
the resource and operation. A workload-only rule does not evaluate its conditions
for a Service request. If the same `enforce` block also contains Service policies,
those policies use the same conditions. Use separate rules when resource types
need different conditions.

### Expressions

Each entry has an `expression` containing one Boolean CEL expression and an
optional `name` used in error messages. Names must be unique within a mutation
entry or `enforce` block and use a DNS label of up to 63 characters. Each entry
or block supports up to 64 conditions; each expression can contain up to 4096
characters and has a bounded evaluation cost. Expressions are compiled when
rules are validated and cached for reuse.

| Variable | Meaning |
|---|---|
| `object` | The current resource, using its Kubernetes field structure. Metadata conditions can inspect the full object, including fields such as `spec` or ConfigMap `data`. |
| `request` | Admission metadata, such as `operation`, `namespace`, `name`, `userInfo`, `kind`, `resource`, `subResource`, and `dryRun`. Raw objects and admission options are not exposed here. |

Check absent fields with `has(...)` and map membership with `in`. The
[missing-value example](#set-a-value-only-when-it-is-missing) demonstrates both.
The Pod node selector is at `object.spec.nodeSelector`; it is not a container
property. Use `request.userInfo` for request identity, while keeping existing
[audience](#audience) settings for straightforward subject selection.

### Evaluation

- No conditions means the mutation entry or `enforce` block applies within its supported scope.
- All conditions must return true for it to apply. Use `||` within an expression for alternatives.
- Any false condition skips the entry or block, including when another condition produces an error.
- If none is false, an evaluation error rejects admission and identifies the condition.
- Invalid syntax and non-Boolean expressions are rejected when saving the rule. Templated expressions are checked after rendering into the namespace's RuleStatus.

### Mutation conditions

Without conditions, a workload mutation applies to every Pod selected by the
rule. Add `conditions` to the mutation entry, alongside `action` and `workloads`,
to apply its changes only when all Boolean CEL expressions return true. A false
condition skips that entry; later entries and other rules continue. Conditions
on the sibling `enforce` block do not control these mutations.

Conditions see the current Pod immediately before the mutation entry runs,
including changes from preceding mutations. They do not see changes from their
own entry. Conditions run on Pod creation and, for applicable
`security.readOnlyRootFilesystem` and `registries.imagePullPolicy` mutations, when adding
ephemeral containers. They cannot
expand a property's supported targets or operations. They select mutations; mutation values are supplied by the
workload properties.

#### Set a value only when it is missing

`merge` can overwrite an existing map value. To use a setting as a default,
check whether that specific key is absent:

```yaml
mutate:
  - action: merge
    conditions:
      - name: missing-os-selector
        expression: >-
          !has(object.spec.nodeSelector) || !('kubernetes.io/os' in object.spec.nodeSelector)
    workloads:
      placement:
        nodeSelector:
          kubernetes.io/os: linux
```

A Pod with `kubernetes.io/os: windows` keeps its value. A Pod with only another
selector key receives the Linux selector and retains the other key. If an
earlier mutation already set the OS selector, this entry is skipped.

A condition gates every property in its mutation entry. For example, adding
`placement.tolerations` beside `placement.nodeSelector` above would make those tolerations depend on
the OS selector being absent too. Put unconditional changes or changes with
different conditions in separate entries.

For a field Kubernetes fills before admission, see
[default a scheduler with a condition](/docs/rules/mutate/workloads/#default-a-scheduler-with-a-condition).
That example uses conditional `replace` to override `default-scheduler` while
preserving custom scheduler names.

### Enforcement conditions

`enforce.conditions` applies to every applicable policy in the enforcement
block. For ingress policies, the conditions are evaluated only when the incoming
resource kind is selected by `ingress.types`. Metadata policies can inspect the
full resource, including its `spec` or `data`.

Conditions under `enforce` also gate metadata defaults, managed metadata, and
[resource request/limit mutations](/docs/rules/enforcement/workloads/#requests-and-limits).
On Pod creation, applicable enforcement conditions are evaluated against the
same object before metadata and resource mutations run. Capsule then applies
metadata mutations, resource policies, and the ordered `mutate` entries.
During enforcement, conditions are evaluated again against the resulting
admission object. A condition based on a mutated field can therefore have a
different result in the two phases.

On Pod updates, conditional placement enforcement is reevaluated even when only
labels or another condition input changes. Typed workload mutations apply on
creation, with the additional `security.readOnlyRootFilesystem` and
`registries.imagePullPolicy` scope for new ephemeral containers. Conditions do not expand a policy's supported operations or
subresources.

#### Managed metadata

[Managed metadata](/docs/rules/enforcement/metadata/#managed) sets labels or
annotations during admission, overwriting existing values. For rules without
conditions, the `RuleStatus` controller also reconciles these values onto
existing objects.

When `enforce.conditions` is nonempty, managed metadata is applied only on
admission requests that satisfy those conditions. The `RuleStatus` controller
skips background reconciliation for that rule, even if its expression is `true`.
Keep managed metadata in an unconditional rule when existing objects must be
kept in sync.

#### Independent resource conditions

Split resource policies into separate rules when they need independent
conditions. Repeat any namespace selector or audience settings that should
apply to both rules:

```yaml
rules:
  - enforce:
      action: deny
      conditions:
        - name: restricted-pods
          expression: |
            has(object.metadata.labels) &&
            'example.com/restricted' in object.metadata.labels &&
            object.metadata.labels['example.com/restricted'] == 'true'
      workloads:
        placement:
          nodeSelector:
            - key: {exact: [infrastructure.example.com/pool]}
              values: {exact: [dedicated]}
  - enforce:
      action: deny
      conditions:
        - name: external-traffic
          expression: object.spec.type == 'NodePort'
      services:
        types: [NodePort]
```

The first rule denies the selected node-selector entry on matching Pods. The
second denies NodePort Services independently. The Service-specific expression
is evaluated only for Service requests because its rule has only Service
policies. When sharing an `enforce` block across resource types, write conditions
that handle every selected type, using `has(...)` or `request.kind` as needed.

Skipping an `enforce` block removes it from the ordered allow/deny/audit
evaluation, including any allow-list requirement it would otherwise introduce.

### Find the failing condition

A mutation condition error includes its location and optional condition name:

```text
rules[0].mutate[1]: conditions[0] ("shared-pool"): ...
```

Indices are zero-based within the effective rules and mutation entries evaluated
for this request. Inspect the namespace's effective RuleStatus and its audience
selection when tracing a rendered rule back to its source. A mutation condition
gates every property in that entry.

Mutation errors identify the affected property where applicable. For example,
an affinity merge that exceeds the term limit identifies
`affinity: nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution` together
with the rule and mutation indices. Enforcement validation condition errors
identify the `enforce` block, rule index, and condition:

```text
enforce: enforcement rule[0]: conditions[0] ("restricted-pods"): ...
```

Condition errors during metadata or resource mutation instead identify
`rules[0].enforce` before the condition index and name.
