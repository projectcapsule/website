---
title: Workloads
weight: 1
aliases:
  - /docs/rules/mutate/placement-example/
description: >
  Configure Pod scheduling and security settings with ordered mutations
---

Workload mutations set Pod properties under `spec.rules[].mutate[].workloads`
using native Kubernetes Pod syntax. Use [scheduling settings](#scheduling) to
select schedulers, assign node pools, add tolerations, spread workloads across topology domains,
and configure affinity. Use [security settings](#security) to configure Pod user
namespaces. [Placement enforcement](/docs/rules/enforcement/workloads/#placement)
validates the resulting scheduling settings using matchers.

This page covers configuration, mutation behavior, and a
[complete Tenant example](#complete-placement-example) that combines mutation
and enforcement.

| Property | Pod field | Enforcement |
|---|---|---|
| [Scheduler](#scheduler) | `spec.schedulerName` | [Scheduler matchers](/docs/rules/enforcement/workloads/#scheduler-names) |
| [Node selectors](#node-selectors) | `spec.nodeSelector` | [Node-selector matchers](/docs/rules/enforcement/workloads/#node-selectors) |
| [Tolerations](#tolerations) | `spec.tolerations` | [Toleration matchers](/docs/rules/enforcement/workloads/#tolerations) |
| [Topology spread constraints](#topology-spread-constraints) | `spec.topologySpreadConstraints` | [Spread matchers](/docs/rules/enforcement/workloads/#topology-spread-constraints) |
| [Affinity](#affinity) | `spec.affinity` | [Affinity matchers](/docs/rules/enforcement/workloads/#affinity) |
| [Host user namespace](#host-user-namespace) | `spec.hostUsers` | Mutation only. |

## Configure workload mutations

Each mutation entry has an optional [action](/docs/rules/mutate/#action) and a
`workloads` block containing at least one property to set. For conditional
mutations, see [Conditions](/docs/rules/#mutation-conditions).

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - kind: User
      name: solar-owner
  rules:
    - namespaceSelector:
        matchLabels:
          environment: production
      mutate:
        - action: merge
          workloads:
            nodeSelector:
              kubernetes.io/os: linux
      enforce:
        action: allow
        workloads:
          nodeSelector:
            - key:
                exact: [kubernetes.io/os]
              values:
                exact: [linux]
```

In selected namespaces, this rule sets the Linux node selector. The allow rule
then rejects any additional node-selector entries. `mutate` and `enforce` are
sibling keys and can be used independently. `enforce.action` does not select or
disable mutations.

Workload mutations apply only on Pod creation. See
[Order and scope](/docs/rules/#order-and-scope) for the mutate-then-enforce
sequence, rule selection, and supported operations.

## Scheduling

### Scheduler

`scheduler` sets the Pod's `spec.schedulerName`. Use the name of a scheduler
configured in your cluster; Capsule selects the scheduler but does not deploy it.
See [Kubernetes multiple schedulers](https://kubernetes.io/docs/tasks/extend-kubernetes/configure-multiple-schedulers/).

To select a scheduler for every new Pod covered by the rule, use `replace`:

```yaml
mutate:
  - action: replace
    workloads:
      scheduler: tenant-scheduler
```

| Action | Behavior |
|---|---|
| `merge` | Fill an empty `spec.schedulerName`. Preserve every non-empty value, including `default-scheduler`. |
| `replace` | Set `spec.schedulerName` to the configured value when the entry's conditions match. |

Omitting `scheduler` or setting it to `null` leaves the current value unchanged.
An empty or blank configured name is invalid. To select the built-in scheduler,
set `scheduler: default-scheduler` explicitly.

#### Default a scheduler with a condition

Kubernetes fills an omitted or empty `spec.schedulerName` with `default-scheduler`
before Capsule receives the admission request. To use a tenant scheduler as the
default while preserving custom scheduler names, combine `replace` with a
[mutation condition](/docs/rules/#mutation-conditions):

```yaml
mutate:
  - action: replace
    conditions:
      - name: default-scheduler
        expression: >-
          !has(object.spec.schedulerName) ||
          object.spec.schedulerName in ['', 'default-scheduler']
    workloads:
      scheduler: tenant-scheduler
```

| Scheduler in the submitted Pod | Result with this condition |
|---|---|
| Omitted or empty | `tenant-scheduler` |
| `default-scheduler` | `tenant-scheduler` |
| `batch-scheduler` | `batch-scheduler` |

The condition cannot distinguish an omitted value from an explicitly selected
`default-scheduler`: both reach admission with the built-in name. This rule
deliberately replaces both. A custom scheduler supplied by the user or an earlier
mutation makes the condition false and is retained.

Keep this scheduler default in its own mutation entry. Conditions gate every
property in an entry, so adding node selectors or tolerations to it would make
those changes depend on the scheduler condition too. Namespace selection and
audience still determine which rules apply. Only new Pods are changed; existing
Pods and controller templates retain their settings.

The final scheduler name remains subject to
[scheduler enforcement](/docs/rules/enforcement/workloads/#scheduler-names).
Allow the configured default in any applicable scheduler allow-list, or admission
will reject the mutated Pod.

### Node selectors

`nodeSelector` is a map of node-label keys and values. Every entry must match a
node for the Pod to be scheduled there.

```yaml
mutate:
  - action: merge
    workloads:
      nodeSelector:
        infrastructure.example.com/pool: shared
```

| Action | Behavior |
|---|---|
| `merge` | Set the supplied keys, overwriting their existing values. Retain other keys. |
| `replace` | Replace the entire map. Use `nodeSelector: {}` to clear it. |

For a Pod whose selector is
`{infrastructure.example.com/pool: private, disk: ssd}`, the example produces:

| Action | Resulting node selector |
|---|---|
| `merge` | `{infrastructure.example.com/pool: shared, disk: ssd}` |
| `replace` | `{infrastructure.example.com/pool: shared}` |

Later mutations can overwrite the same key. For defaults, see
[set a value only when it is missing](/docs/rules/#set-a-value-only-when-it-is-missing).
Use [node-selector enforcement](/docs/rules/enforcement/workloads/#node-selectors)
to restrict which keys and values remain on the admitted Pod.

### Tolerations

`tolerations` is a list of native Pod tolerations. A toleration permits scheduling
onto a node with a matching taint; it does not require that node. Use a node
selector or required node affinity to restrict placement to a node pool.

```yaml
mutate:
  - action: merge
    workloads:
      tolerations:
        - key: infrastructure.example.com/dedicated
          operator: Equal
          value: shared
          effect: NoExecute
          tolerationSeconds: 60
```

| Action | Behavior |
|---|---|
| `merge` | Add or update the toleration identified by **key + operator + value + effect**. An omitted operator means `Equal`. |
| `replace` | Replace the entire list, including tolerations with other identities. Use `tolerations: []` to clear it. |

The duration is not part of the merge identity. A matching toleration receives
the supplied `tolerationSeconds`. Omitting the duration removes an existing
limit and makes the toleration unlimited.

| Existing toleration | Supplied toleration | Result with `merge` |
|---|---|---|
| `pool=private`, `Equal`, `NoSchedule` | `pool=shared`, `Equal`, `NoSchedule` | Both remain because their values differ. |
| `pool=shared`, `Equal`, `NoExecute`, 30 seconds | Same identity, 60 seconds | One toleration with a 60-second duration. |
| `pool=shared`, `Equal`, `NoExecute`, 30 seconds | Same identity, no duration | One toleration with unlimited duration. |

Changing a key, operator, value, or effect adds another toleration under `merge`.
Use `replace` when only the supplied list should remain. Other admission
controllers may subsequently inject additional tolerations. All final entries
are subject to [toleration enforcement](/docs/rules/enforcement/workloads/#tolerations),
including Kubernetes-injected entries.

### Topology spread constraints

`topologySpreadConstraints` is a list of native Pod spread constraints. Each
constraint specifies a topology domain and the Pods to count when spreading.

```yaml
mutate:
  - action: merge
    workloads:
      topologySpreadConstraints:
        - topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          maxSkew: 1
          labelSelector:
            matchLabels:
              app: checkout
```

This expresses a preference to spread Pods labeled `app: checkout` across hosts.
Use `DoNotSchedule` when the spread constraint must prevent scheduling that
would violate it.

| Action | Behavior |
|---|---|
| `merge` | Add or replace the **entire constraint** identified by `topologyKey` + `whenUnsatisfiable`. Retain constraints with other identities. |
| `replace` | Replace the entire list. Use `topologySpreadConstraints: []` to clear it. |

If the Pod already has a `kubernetes.io/hostname / ScheduleAnyway` constraint
with `maxSkew: 3`, the example replaces it with `maxSkew: 1` and the supplied
selector. Old selector fields and optional fields are not carried forward.
An existing `topology.kubernetes.io/zone / DoNotSchedule` constraint remains with
`merge` and is removed with `replace` unless it is also supplied.

Changing `whenUnsatisfiable` creates a different merge identity, even if the
topology key is unchanged. For allowed topology keys, skew ranges, and selector
operators, see [spread enforcement](/docs/rules/enforcement/workloads/#topology-spread-constraints).

### Affinity

`affinity` uses the native Pod structure with three branches: `nodeAffinity`,
`podAffinity`, and `podAntiAffinity`. Each can contain required and preferred
terms.

```yaml
mutate:
  - action: merge
    workloads:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: topology.kubernetes.io/zone
                    operator: In
                    values: [zone-a, zone-b]
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 50
              podAffinityTerm:
                topologyKey: kubernetes.io/hostname
                labelSelector:
                  matchLabels:
                    app: cache
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                topologyKey: kubernetes.io/hostname
                labelSelector:
                  matchLabels:
                    app: checkout
```

This requires a node in `zone-a` or `zone-b`, prefers a host with cache Pods, and
prefers to separate checkout Pods across hosts. The referenced node labels must
exist on the intended nodes. Omitting namespace selection in these Pod-affinity
terms limits their Pod matching to the incoming Pod's namespace.

#### Merge

| Affinity term | Behavior with `merge` |
|---|---|
| Required node affinity | Require both the existing restrictions and the supplied restrictions. Combine existing and supplied alternatives to preserve that AND relationship. |
| Required Pod affinity or anti-affinity | Add distinct complete terms. All required terms remain required; identical terms are retained once. |
| Preferred affinity of any type | Add distinct complete terms or replace the weight of a matching term. |

For example, existing node alternatives `(disk=ssd OR arch=arm64)` combined with
supplied `zone=a` become `(disk=ssd AND zone=a) OR (arch=arm64 AND zone=a)`.
Required restrictions accumulate across applicable mutations. Capsule rejects
combinations that would produce more than 256 node-selector alternatives.
An empty node-selector term matches no nodes.

Preferred-term identity includes the complete node preference or Pod-affinity
term, excluding its weight. Requirement and selector-value order are normalized
for matching. Supplying the same term with weight 80 updates an existing weight
50; changing the selector adds a distinct preferred term.

#### Replace

`replace` replaces **all of `affinity`**, including branches omitted from the
mutation. Supplying only `nodeAffinity` also removes existing `podAffinity` and
`podAntiAffinity`. Use `affinity: {}` to clear all three branches.

For allowed types, required/preferred modes, selector requirements, and namespace
scope, see [affinity enforcement](/docs/rules/enforcement/workloads/#affinity).
Its matcher syntax uses one flat list across all three affinity types.

### Complete placement example

This Tenant combines scheduling and security settings with
[placement enforcement](/docs/rules/enforcement/workloads/#placement). Mutations
establish the settings, while allow matchers constrain any placement entries
that remain on the admitted Pod.

The node pool and zone labels used below must exist on the intended nodes.
`hostUsers: false` also requires
[user namespace support](#host-user-namespace).

This Tenant applies placement settings to namespaces labeled
`example.com/application: checkout`, then allows only the configured placement
shapes. Application Pods should carry `app.kubernetes.io/part-of: checkout` so
the spread and Pod-affinity selectors describe the intended workload.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: checkout
spec:
  owners:
    - kind: User
      name: checkout-owner
  rules:
    - namespaceSelector:
        matchLabels:
          example.com/application: checkout
      mutate:
        - action: merge
          workloads:
            hostUsers: false
            nodeSelector:
              kubernetes.io/os: linux
              infrastructure.example.com/pool: shared
            tolerations:
              - key: infrastructure.example.com/dedicated
                operator: Equal
                value: shared
                effect: NoSchedule
            # Application Pods must carry app.kubernetes.io/part-of: checkout.
            topologySpreadConstraints:
              - topologyKey: topology.kubernetes.io/zone
                whenUnsatisfiable: DoNotSchedule
                maxSkew: 1
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/part-of: checkout
            affinity:
              nodeAffinity:
                requiredDuringSchedulingIgnoredDuringExecution:
                  nodeSelectorTerms:
                    - matchExpressions:
                        - key: topology.kubernetes.io/zone
                          operator: In
                          values: [zone-a, zone-b]
              podAffinity:
                preferredDuringSchedulingIgnoredDuringExecution:
                  - weight: 50
                    podAffinityTerm:
                      topologyKey: topology.kubernetes.io/zone
                      labelSelector:
                        matchLabels:
                          app.kubernetes.io/part-of: checkout
                          app.kubernetes.io/component: cache
              podAntiAffinity:
                preferredDuringSchedulingIgnoredDuringExecution:
                  - weight: 100
                    podAffinityTerm:
                      topologyKey: kubernetes.io/hostname
                      labelSelector:
                        matchLabels:
                          app.kubernetes.io/part-of: checkout
      enforce:
        action: allow
        workloads:
          targets: [pod]
          nodeSelector:
            - key: {exact: [kubernetes.io/os]}
              values: {exact: [linux]}
            - key: {exact: [infrastructure.example.com/pool]}
              values: {exact: [shared]}
            - key: {exp: '^placement\.example\.com/[a-z0-9-]+$'}
              values: {exp: '^[a-z0-9-]+$'}
          tolerations:
            - key: {exact: [infrastructure.example.com/dedicated]}
              operators: [Equal]
              values: {exact: [shared]}
              effects: [NoSchedule]
            - key:
                exact:
                  - node.kubernetes.io/not-ready
                  - node.kubernetes.io/unreachable
              operators: [Exists]
              effects: [NoExecute]
              tolerationSeconds:
                max: 600
                allowUnlimited: false
            - key: {exact: [node.kubernetes.io/memory-pressure]}
              operators: [Exists]
              effects: [NoSchedule]
          topologySpreadConstraints:
            - topologyKey:
                exact: [topology.kubernetes.io/zone, kubernetes.io/hostname]
              whenUnsatisfiable: [DoNotSchedule, ScheduleAnyway]
              maxSkew: {min: 1, max: 3}
              labelSelector:
                required: true
                requirements:
                  - key: {exact: [app.kubernetes.io/part-of]}
                    operators: [In]
                    values: {exact: [checkout]}
          affinity:
            - types: [nodeAffinity]
              modes: [required]
              requirements:
                - key: {exact: [topology.kubernetes.io/zone]}
                  operators: [In]
                  values: {exact: [zone-a, zone-b]}
            - types: [nodeAffinity]
              modes: [preferred]
              weight: {min: 1, max: 100}
              requirements:
                - key: {exact: [kubernetes.io/arch]}
                  operators: [In]
                  values: {exact: [amd64, arm64]}
            - types: [podAffinity, podAntiAffinity]
              modes: [preferred]
              topologyKey:
                exact: [topology.kubernetes.io/zone, kubernetes.io/hostname]
              namespaceScope: SameNamespace
              weight: {min: 1, max: 100}
              labelSelector:
                required: true
                requirements:
                  - key: {exact: [app.kubernetes.io/part-of]}
                    operators: [In]
                    values: {exact: [checkout]}
                  - key: {exact: [app.kubernetes.io/component]}
                    operators: [In, NotIn]
                    values: {exact: [api, worker, cache]}
```

The toleration allowlist includes common Kubernetes-injected tolerations.
Controllers such as DaemonSets may add others; include the entries needed by
the workloads selected by your rule. The affinity validation uses one flat list
for node affinity, Pod affinity, and Pod anti-affinity.

See the [placement matcher reference](/docs/rules/enforcement/workloads/#placement)
for regular expressions, empty matchers, durations, selector operators, and
namespace scope.

## Security

### Host user namespace

`hostUsers` selects whether the Pod uses the host user namespace.

```yaml
mutate:
  - action: merge
    workloads:
      hostUsers: false
```

| Supplied value | Behavior with `merge` or `replace` |
|---|---|
| `false` | Request a separate user namespace for the Pod. |
| `true` | Use the host user namespace. |

Both actions overwrite an existing Boolean. A later entry can change `false`
to `true` or the reverse. This property is independent of a container's
`runAsUser` and has no corresponding `enforce.workloads.hostUsers` matcher.

The Kubernetes version, operating system, and container runtime must support
the requested setting. Kubernetes validates incompatible Pod settings; Capsule
does not adjust other security or host-namespace fields. See
[Kubernetes user namespaces](https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/).
