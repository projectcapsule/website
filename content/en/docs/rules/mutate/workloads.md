---
title: Workloads
weight: 1
aliases:
  - /docs/rules/mutate/placement-example/
description: >
  Configure Pod placement and security settings with ordered mutations
---

Workload mutations set Pod properties under `spec.rules[].mutate[].workloads`
using native Kubernetes Pod syntax. Use [placement settings](#placement) to
select schedulers, assign node pools, add tolerations, spread workloads across topology domains,
and configure affinity. Use [security settings](#security) to configure Pod user
namespaces, seccomp/AppArmor profiles, and read-only container root filesystems. [Placement enforcement](/docs/rules/enforcement/workloads/#placement)
validates the resulting placement settings using matchers.

This page covers configuration and mutation behavior. The
[Reference](#reference) provides a complete Tenant combining all workload
mutation properties with placement and security-profile enforcement.

| Property | Pod field | Enforcement |
|---|---|---|
| [Scheduler](#scheduler) | `spec.schedulerName` | [Scheduler matchers](/docs/rules/enforcement/workloads/#scheduler-names) |
| [Node selectors](#node-selectors) | `spec.nodeSelector` | [Node-selector matchers](/docs/rules/enforcement/workloads/#node-selectors) |
| [Tolerations](#tolerations) | `spec.tolerations` | [Toleration matchers](/docs/rules/enforcement/workloads/#tolerations) |
| [Topology spread constraints](#topology-spread-constraints) | `spec.topologySpreadConstraints` | [Spread matchers](/docs/rules/enforcement/workloads/#topology-spread-constraints) |
| [Affinity](#affinity) | `spec.affinity` | [Affinity matchers](/docs/rules/enforcement/workloads/#affinity) |
| [Seccomp](#seccomp) | `spec.securityContext.seccompProfile` | [Seccomp matchers](/docs/rules/enforcement/workloads/#seccomp) |
| [AppArmor](#apparmor) | `spec.securityContext.appArmorProfile` | [AppArmor matchers](/docs/rules/enforcement/workloads/#apparmor) |
| [Read-only root filesystem](#read-only-root-filesystem) | Selected containers: `securityContext.readOnlyRootFilesystem` | Mutation only. |
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

Workload mutations apply on Pod creation. `readOnlyRootFilesystem` also applies
to newly added ephemeral containers. See
[Order and scope](/docs/rules/#order-and-scope) for the mutate-then-enforce
sequence, rule selection, and supported operations.

## Targets

Set `mutate[].workloads.targets` to select where the entry applies. Omitting
`targets`, using `targets: []`, or selecting `pod` includes all compatible
locations. **For mutation, `pod` includes every regular, init, and ephemeral
container.** Native sidecars belong to the init-container group.

The table lists supported mutation targets. ✅ indicates mutation support;
❌ means that property cannot be mutated through that target. Controller and
volume targets are supported by [enforcement](/docs/rules/enforcement/workloads/#workload-targets)
but are rejected by the mutation API.

{{% alert title="Pods created by controllers are still mutated" color="info" %}}
Every new Pod is evaluated against the applicable Pod mutation rules, whether
created directly or by a Deployment, StatefulSet, DaemonSet, Job, CronJob, or
another controller. Stored controller templates remain unchanged.
**The resulting Pods still receive applicable mutations when they are created.**

Namespace selection, mutation targets, conditions, and [audience](/docs/rules/#audience)
still determine which mutations apply. Audience matching uses the identity
creating the Pod, usually the controller's service account.
{{% /alert %}}

| Target | [Placement](#placement) | [`hostUsers`](#host-user-namespace) | [Seccomp](#seccomp) / [AppArmor](#apparmor) | [`readOnlyRootFilesystem`](#read-only-root-filesystem) |
|---|---|---|---|---|
| Omitted, `[]`, or `pod` | ✅ Pod placement fields | ✅ Pod user namespace | ✅ Pod-level profiles only | ✅ All container groups |
| `pod/containers` | ❌ | ❌ | ❌ | ✅ Regular containers |
| `pod/initcontainers` | ❌ | ❌ | ❌ | ✅ Init containers and native sidecars |
| `pod/ephemeralcontainers` | ❌ | ❌ | ❌ | ✅ Newly added ephemeral containers |

Placement includes `scheduler`, `nodeSelector`, `tolerations`,
`topologySpreadConstraints`, and `affinity`. These properties, `hostUsers`,
`seccompProfile`, and `appArmorProfile` require `pod` or omitted/empty targets.
Seccomp and AppArmor mutation preserves explicit container profiles with both
`merge` and `replace`; container-specific profile mutation is not supported.

Only `readOnlyRootFilesystem` currently supports container-specific mutation
targets. Use separate mutation entries to combine Pod-level settings with a
narrower container selection. Controller and volume targets are not supported
for typed workload mutations.

Targets combine by inclusion: listing `pod` alongside a narrower target still
selects all groups. A targets-only mutation is invalid because it has no property
to set. [Enforcement targets](/docs/rules/enforcement/workloads/#pod-targets)
are configured independently and have property-specific matching semantics.

Regular and init containers are mutated on Pod creation. Ephemeral containers
are mutated only when newly added through `UPDATE pods/ephemeralcontainers`.
An existing ephemeral container is left unchanged, even if the rule changed
since it was added. Other Pod updates, deletes, and subresources do not apply
these mutations. On an ephemeral update, the entry's conditions see the full
current Pod, including earlier mutations, but only the new ephemeral containers'
`readOnlyRootFilesystem` values can change.

## Placement

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

See [Reference](#reference) for a complete Tenant combining placement mutations,
security defaults, conditional scheduler selection, and enforcement.

## Security

Seccomp and AppArmor mutations set only the **Pod-level** profile on creation.
Use `targets: [pod]` or omit mutation targets for these Pod-level properties.
`enforce.workloads.targets` selects enforcement locations independently. Both `merge` and `replace`
preserve explicit regular, init, and ephemeral container profiles. Containers
without an override inherit the Pod default. See the
[Pod targets table](/docs/rules/enforcement/workloads/#pod-targets) and
[profile target example](/docs/rules/enforcement/workloads/#target-security-profiles)
for how enforcement checks those defaults and overrides.

### Read-only root filesystem

`readOnlyRootFilesystem` sets the Boolean on every selected container's
`securityContext`. Like `hostUsers`, **both `merge` and `replace` set the supplied
value**, including an explicit `false`. Omitted or `null` leaves the value
unchanged. Later matching entries can overwrite earlier values; all other
container security-context fields are preserved.

This full Tenant makes all container root filesystems read-only in namespaces
labeled `filesystem-profile: readonly`. Namespaces labeled
`filesystem-profile: init-only` apply the setting only to init containers,
including native sidecars. Other namespaces keep their submitted values.

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
          filesystem-profile: readonly
      mutate:
        - action: merge
          workloads:
            targets: [pod]
            readOnlyRootFilesystem: true
    - namespaceSelector:
        matchLabels:
          filesystem-profile: init-only
      mutate:
        - action: replace
          workloads:
            targets: [pod/initcontainers]
            readOnlyRootFilesystem: true
```

In the first profile, `pod` also selects new ephemeral containers. Choose
`pod/containers` for regular containers only or `pod/ephemeralcontainers` for
new debug containers only. Neither the rule nor a namespace-label change
rewrites existing containers. Pods declaring `spec.os.name: windows` are skipped.

A read-only root filesystem does not make mounted volumes read-only. Applications
that write to paths such as `/tmp` need suitable writable volume mounts. See the
[Kubernetes security-context documentation](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/).
This field is a mutation setting; there is no corresponding
`enforce.workloads.readOnlyRootFilesystem` matcher.

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

### Seccomp

`seccompProfile` sets `spec.securityContext.seccompProfile` on new Linux Pods.
Containers inherit this Pod default unless their own security context supplies
a seccomp profile. This includes regular, init, and ephemeral containers.

| Property | Meaning |
|---|---|
| `type: RuntimeDefault` | Use the container runtime's default seccomp profile. Omit `localhostProfile`. |
| `type: Localhost` | Use a seccomp profile file on the node. Set `localhostProfile` to its relative path. |
| `type: Unconfined` | Disable seccomp filtering. Omit `localhostProfile`. |

#### Seccomp mutation behavior

| Action | Behavior |
|---|---|
| `merge` | Set the configured profile only when the Pod has no `seccompProfile`. Preserve any supplied profile, including its localhost path. |
| `replace` | Replace the complete Pod profile with the configured type and localhost path. |
| Property omitted | Preserve the Pod's seccomp profile. |

Merge treats the profile as one property: it does not fill a missing
`localhostProfile` inside an already supplied profile. A Localhost profile must
include its path. Replacing Localhost with RuntimeDefault removes the old path.

Other security-context fields and explicit container profiles are preserved.
Use [seccomp enforcement](/docs/rules/enforcement/workloads/#seccomp) to prevent
container overrides from bypassing the intended profile. Mutations use the
existing [conditions and order](/docs/rules/#mutation-conditions), run only on
Pod creation, and skip Pods declaring `spec.os.name: windows`. They do not
change running Pods or controller templates.

#### Default to RuntimeDefault

This complete Tenant defaults seccomp in namespaces labeled
`security-profile: confined`. The allow rule requires every container's
effective profile to be RuntimeDefault, including containers added later
through `pods/ephemeralcontainers`.

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
          security-profile: confined
      mutate:
        - action: merge
          workloads:
            seccompProfile:
              type: RuntimeDefault
      enforce:
        action: allow
        workloads:
          seccompProfiles:
            - types: [RuntimeDefault]
```

An explicit container-level Unconfined profile remains unchanged by mutation
and is rejected by enforcement. Namespaces without the selector label do not
receive either rule effect.

#### Set a local seccomp path

Set `type: Localhost` together with `localhostProfile`. The path is relative to
the kubelet's seccomp directory and must not be absolute or contain `..` path
segments. For example, `profiles/solar.json` refers to
`/var/lib/kubelet/seccomp/profiles/solar.json` when the kubelet uses its default
root directory. It is a file on the node, independent of the container's
filesystem. See the [Kubernetes seccomp tutorial](https://kubernetes.io/docs/tutorials/security/seccomp/).

This Tenant replaces the Pod default with that local profile and allows only
that profile for the effective container checks:

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
          security-profile: local-seccomp
      mutate:
        - action: replace
          workloads:
            seccompProfile:
              type: Localhost
              localhostProfile: profiles/solar.json
      enforce:
        action: allow
        workloads:
          seccompProfiles:
            - types: [Localhost]
              localhostProfiles:
                - exact: [profiles/solar.json]
```

Use `action: merge` instead to supply this profile only when the Pod profile
is absent. With the allow-list above, an existing different profile is then
preserved by merge and rejected by enforcement.

Install the file on every eligible node before using the rule, or combine the
rule with [placement](#placement) that selects prepared nodes. Capsule writes
the profile reference; it does not distribute or inspect the file. A Pod can
pass admission and still fail to start if the profile is unavailable on its node.

### AppArmor

`appArmorProfile` sets `spec.securityContext.appArmorProfile` on new Linux Pods.
The Pod value supplies the default for containers that have no AppArmor
override. Use this mutation only for workloads placed on nodes with AppArmor
support. Explicit RuntimeDefault can prevent a Pod from starting on a node
without that support. See the [AppArmor prerequisites](https://kubernetes.io/docs/tutorials/security/apparmor/#before-you-begin).

| Property | Meaning |
|---|---|
| `type: RuntimeDefault` | Use the container runtime's default AppArmor profile. Omit `localhostProfile`. |
| `type: Localhost` | Use an AppArmor profile already loaded on the node. Set `localhostProfile` to its loaded name. |
| `type: Unconfined` | Disable AppArmor confinement. Omit `localhostProfile`. |

#### AppArmor mutation behavior

| Action | Behavior |
|---|---|
| `merge` | Set the configured profile only when the Pod has no `appArmorProfile`. Preserve any supplied profile, including its localhost name. |
| `replace` | Replace the complete Pod profile with the configured type and localhost name. |
| Property omitted | Preserve the Pod's AppArmor profile. |

Merge does not complete a partially supplied Localhost profile. Replacing a
Localhost profile with RuntimeDefault removes the old `localhostProfile`.
Other security-context fields and container overrides, including legacy
AppArmor annotations, remain unchanged. Pair mutation with
[AppArmor enforcement](/docs/rules/enforcement/workloads/#apparmor) to validate
these effective container choices.

The existing [conditions and order](/docs/rules/#mutation-conditions) apply.
Mutations run only on Pod creation and skip Pods declaring
`spec.os.name: windows`; they do not change running Pods or controller templates.

#### Default the AppArmor profile

This Tenant supplies RuntimeDefault and requires it for every effective
container profile in the selected namespaces:

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
          security-profile: apparmor
      mutate:
        - action: merge
          workloads:
            appArmorProfile:
              type: RuntimeDefault
      enforce:
        action: allow
        workloads:
          appArmorProfiles:
            - types: [RuntimeDefault]
```

#### Set a local AppArmor profile

For AppArmor, `localhostProfile` is the **loaded profile name**, such as
`solar-confined`. It is not a filesystem path to the profile definition.
The name must match the profile loaded on the node. See
[Specifying AppArmor confinement](https://kubernetes.io/docs/tutorials/security/apparmor/#specifying-apparmor-confinement).

This Tenant replaces the Pod default with that name and restricts effective
container profiles to the same choice:

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
          security-profile: local-apparmor
      mutate:
        - action: replace
          workloads:
            appArmorProfile:
              type: Localhost
              localhostProfile: solar-confined
      enforce:
        action: allow
        workloads:
          appArmorProfiles:
            - types: [Localhost]
              localhostProfiles:
                - exact: [solar-confined]
```

Use `action: merge` to preserve an existing Pod profile instead of replacing
it; the enforcement rule still rejects any different effective profile.
Load `solar-confined` on every eligible node before applying the rule, or
restrict placement to prepared nodes. Capsule does not load AppArmor profiles
or verify that their definitions are consistent across nodes.

## Reference

This complete Tenant combines every supported workload mutation property with
placement and security-profile enforcement. It selects namespaces labeled
`example.com/application: checkout` and configures workloads for Linux nodes.

The `tenant-scheduler` scheduler, node pool, and zone labels must exist in the
cluster. Eligible nodes must support [user namespaces](#host-user-namespace)
and [AppArmor](#apparmor). Application Pods should carry
`app.kubernetes.io/part-of: checkout` so the spread and Pod-affinity selectors
describe the intended workload.

The first mutation entry replaces the built-in scheduler default while
preserving custom scheduler names. The second entry independently applies the
remaining placement settings, supplies missing Pod-level security profiles, and
sets all selected container root filesystems read-only. Provide writable volume
mounts for application paths that need them.

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
        - action: replace
          conditions:
            - name: default-scheduler
              expression: >-
                !has(object.spec.schedulerName) ||
                object.spec.schedulerName in ['', 'default-scheduler']
          workloads:
            scheduler: tenant-scheduler
        - action: merge
          workloads:
            targets: [pod]
            readOnlyRootFilesystem: true
            hostUsers: false
            seccompProfile:
              type: RuntimeDefault
            appArmorProfile:
              type: RuntimeDefault
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
          targets:
            - pod
            - pod/containers
            - pod/initcontainers
            - pod/ephemeralcontainers
          seccompProfiles:
            - types: [RuntimeDefault]
          appArmorProfiles:
            - types: [RuntimeDefault]
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

| Submitted value or scope | Result |
|---|---|
| Scheduler omitted or `default-scheduler` | Replaced with `tenant-scheduler`. |
| Custom scheduler name | Preserved; the placement and security mutations still apply. |
| Root filesystem flag omitted or `false` | Set to `true` on regular/init containers at creation and newly added ephemeral containers. |
| Pod seccomp or AppArmor profile omitted | Defaulted to RuntimeDefault. |
| Explicit Pod or container profile | Preserved by mutation, then rejected unless its effective type is RuntimeDefault. |
| Existing node selector or required affinity | Combined with the configured restrictions, then checked by the placement allowlists. |
| Namespace without `example.com/application: checkout` | These rules do not apply. |

Under `enforce`, the `pod` target validates placement and Pod-level profile defaults. The three
container targets validate effective profiles for regular, init, and ephemeral
containers, including container overrides. Under `mutate`, `targets: [pod]`
selects all container groups for the root filesystem flag and Pod-level fields
for the other properties; profile mutation still writes only Pod-level profiles. An Unconfined override or privileged
container is rejected after mutation.

The toleration allowlist includes common Kubernetes-injected tolerations.
Controllers such as DaemonSets may add others; include the entries needed by
the workloads selected by your rule. The affinity validation uses one flat list
for node affinity, Pod affinity, and Pod anti-affinity.

See the [placement matcher reference](/docs/rules/enforcement/workloads/#placement)
for regular expressions, empty matchers, durations, selector operators, and
namespace scope.

These mutations run on Pod creation. The root filesystem flag also applies to
new ephemeral containers; the other properties are skipped on that subresource.
Controller templates and existing containers are not rewritten. Profile enforcement also applies on subsequent Pod updates and
`pods/ephemeralcontainers` updates. See [Order and scope](/docs/rules/#order-and-scope)
for rule composition and admission order.
