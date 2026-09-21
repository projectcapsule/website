---
title: Workloads
weight: 1
description: >
  Mutate hostUsers, node selectors, tolerations, topology spread, and affinity
---

Configure Pod properties under `spec.rules[].mutate[].workloads`. The fields use
native Kubernetes Pod syntax, so existing configurations can be copied
directly into a rule:

```yaml
mutate:
  - action: merge
    workloads:
      hostUsers: false
      nodeSelector:
        kubernetes.io/os: linux
      tolerations:
        - key: infrastructure.example.com/dedicated
          operator: Equal
          value: shared
          effect: NoSchedule
      topologySpreadConstraints:
        - topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          maxSkew: 1
          labelSelector:
            matchLabels:
              app: checkout
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: topology.kubernetes.io/zone
                    operator: In
                    values: [zone-a, zone-b]
```

The four placement keys (`nodeSelector`, `tolerations`,
`topologySpreadConstraints`, and `affinity`) are also available under
[`enforce.workloads`](/docs/rules/enforcement/workloads/#placement). There they
contain matchers describing which placement entries are allowed, denied, or
audited. `hostUsers` is available only under mutation.

## When settings apply

Capsule applies these settings on Pod creation, including Pods created by
Deployments, StatefulSets, and other controllers. It does not rewrite controller
templates or reconcile existing Pods. A namespace label or rule change therefore
affects newly created Pods; it does not move running workloads.

Placement mutation runs before enforcement. An incompatible `mutate` and
`enforce` combination rejects the final Pod. Admission reinvocation does not
accumulate duplicate entries.

## Choose an action

Each entry accepts `action: merge` (the default) or `action: replace`. Examples
spell out the action so its intent is visible. The action applies to every
property supplied in that entry; use separate entries for different actions.

**Replacement happens at the workload-property boundary**, not at each nested
field. Those boundaries are `hostUsers`, `nodeSelector`, `tolerations`,
`topologySpreadConstraints`, and `affinity`.

| Supplied property with `replace` | Result |
|---|---|
| `hostUsers: false` or `true` | Set that Boolean; both values are explicit. |
| `nodeSelector: {pool: shared}` | Replace the map with only `pool: shared`; other selector keys are removed. |
| `tolerations: [...]` | Replace the entire list, including tolerations with different keys. |
| `topologySpreadConstraints: [...]` | Replace the entire list, including constraints for other topology keys. |
| `affinity: {nodeAffinity: ...}` | Replace all affinity. Existing Pod affinity and anti-affinity are removed. |
| `nodeSelector: {}`, `tolerations: []`, `topologySpreadConstraints: []`, or `affinity: {}` | Clear the corresponding property. |
| Property omitted or `null` | Leave the Pod's existing value unchanged. |

For example, given a Pod with `pool: private` and `disk: ssd` in its node selector,
this mutation leaves only `pool: shared`. Its affinity and tolerations are retained:

```yaml
mutate:
  - action: replace
    workloads:
      nodeSelector:
        pool: shared
```

With `action: merge`, the same example produces `pool: shared` and `disk: ssd`.
Other Kubernetes admission controllers can subsequently inject values, including
default tolerations; enforcement evaluates the resulting Pod.

## Merge behavior

| Property | Behavior |
|---|---|
| `hostUsers` | Set the supplied Boolean, just as with `replace`; omission retains the existing value. |
| `nodeSelector` | Set configured keys, replacing their existing values and retaining unrelated keys. |
| `tolerations` | Add or update by key, operator, value, and effect. Replace the matching duration, including removing it when the rule omits it. An omitted operator means `Equal`. |
| `topologySpreadConstraints` | Add or replace the entire constraint identified by `topologyKey` and `whenUnsatisfiable`. |
| Required node affinity | Require both the existing affinity and the configured affinity. Alternatives are distributed to preserve this AND relationship. |
| Required Pod affinity or anti-affinity | Add distinct terms. All required terms remain required. |
| Preferred affinity | Add distinct terms or update the weight of the same term. The term identity excludes weight and includes the complete node preference or Pod affinity term; node requirement order and selector-value order are normalized. |

With `merge`, later entries and rules win for `hostUsers`, colliding node-selector
keys, toleration durations, topology-spread constraints, and preferred-affinity weights. Required affinity restrictions
compose across rules.

For example, a Pod that requires `disk=ssd` and a rule that requires
`zone In [zone-a, zone-b]` must satisfy both. Appending the rule as another node
selector alternative would weaken the requirement, so Capsule combines the
expressions instead. Multiple alternatives can produce a larger set of combined
terms; admission rejects a combination that would exceed 256 alternatives.

Adding a toleration permits scheduling onto a matching tainted node; it does
not require that node. Use a node selector or required node affinity when placement
must be restricted to a node pool.

### List examples

Tolerations match by **key + operator + value + effect**, with an omitted operator
normalized to `Equal`. The duration is not part of the identity:

| Existing toleration | Supplied toleration | Result with `merge` |
|---|---|---|
| `pool=private`, `Equal`, `NoSchedule` | `pool=shared`, `Equal`, `NoSchedule` | Both tolerations remain: changing the value creates another entry. |
| `pool=shared`, `Equal`, `NoExecute`, 30 seconds | Same identity, 60 seconds | One matching toleration, now 60 seconds. |
| `pool=shared`, `Equal`, `NoExecute`, 30 seconds | Same identity, no duration | One matching toleration with unlimited duration. |

Use `replace` when only the supplied tolerations should remain.

Topology-spread constraints match by **topologyKey + whenUnsatisfiable**. For
example, a supplied `zone / DoNotSchedule` constraint with `maxSkew: 1` replaces
an existing `zone / DoNotSchedule` constraint with `maxSkew: 3`. The entire matching
constraint is replaced: its old selector and optional fields are not carried
forward. A `hostname / ScheduleAnyway` constraint remains with `merge` and is
removed with `replace` unless also supplied.

### Affinity examples

With required node affinity, existing alternatives `(disk=ssd OR arch=arm64)`
and supplied `zone=a` become `(disk=ssd AND zone=a) OR (arch=arm64 AND zone=a)`
under `merge`. With `replace`, only the supplied `zone=a` restriction remains,
and any existing Pod affinity and anti-affinity are removed.

For required Pod affinity or anti-affinity, distinct complete terms are appended;
identical terms are retained once. For preferred affinity, supplying the same
term with weight 80 changes an existing weight 50 to 80. Changing the term's
selector creates a distinct preferred term instead.

## Host user namespace

```yaml
mutate:
  - action: merge
    workloads:
      hostUsers: false
```

`hostUsers: false` requests a separate user namespace for the Pod.
`hostUsers: true` uses the host user namespace. Both actions overwrite an
existing Boolean when this property is supplied; an omitted or `null` value
leaves the Pod value unchanged. This is independent of a container's `runAsUser`.

The cluster's Kubernetes version, operating system, and container runtime must
support the requested setting. Kubernetes validates incompatible Pod settings;
Capsule does not change other security or host-namespace fields to accommodate
`hostUsers`. See [Kubernetes user namespaces](https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/).

## Optional conditions

Conditions are not required for the examples above. Add them inside `workloads`
when an entry should depend on the current Pod. For example:

```yaml
mutate:
  - action: merge
    workloads:
      nodeSelector:
        kubernetes.io/os: linux
  - action: replace
    workloads:
      conditions:
        - name: shared-pool
          expression: |
            has(object.spec.nodeSelector) &&
            'infrastructure.example.com/pool' in object.spec.nodeSelector &&
            object.spec.nodeSelector['infrastructure.example.com/pool'] == 'shared'
      tolerations:
        - key: infrastructure.example.com/dedicated
          operator: Equal
          value: shared
          effect: NoSchedule
```

Conditions are optional Boolean CEL expressions inside `workloads`. Capsule
evaluates them immediately before their entry, using the Pod after preceding
entries. A false condition skips only that block. See
[conditions](/docs/rules/conditions/) for variables, error behavior, and examples.

## Complete placement example

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
