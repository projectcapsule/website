---
title: Workloads
weight: 1
aliases:
  - /docs/rules/mutate/placement-example/
description: >
  Configure Pod placement, security, and image pull policies with ordered mutations
---

Workload mutations set Pod properties under `spec.rules[].mutate[].workloads`
using native Kubernetes Pod syntax. Use [placement settings](#placement) to
select schedulers, assign node pools, add tolerations, spread workloads across topology domains,
and configure affinity. Use [security settings](#security) to configure Pod user
namespaces, seccomp/AppArmor profiles, and read-only container root filesystems.
Use [registry settings](#registries) to configure container image pull policies
and Pod image pull secret references. [Placement enforcement](/docs/rules/enforcement/workloads/#placement)
validates the resulting placement settings using matchers.

This page covers configuration and mutation behavior. The
[Reference](#reference) provides a complete Tenant combining all workload
mutation properties with placement, security-profile, and image pull policy enforcement.

| Property | Field under `workloads` | Pod field | Enforcement |
|---|---|---|---|
| [Scheduler](#scheduler) | `placement.scheduler` | `spec.schedulerName` | [Scheduler matchers](/docs/rules/enforcement/workloads/#scheduler-names) |
| [Node selectors](#node-selectors) | `placement.nodeSelector` | `spec.nodeSelector` | [Node-selector matchers](/docs/rules/enforcement/workloads/#node-selectors) |
| [Tolerations](#tolerations) | `placement.tolerations` | `spec.tolerations` | [Toleration matchers](/docs/rules/enforcement/workloads/#tolerations) |
| [Topology spread constraints](#topology-spread-constraints) | `placement.topologySpreadConstraints` | `spec.topologySpreadConstraints` | [Spread matchers](/docs/rules/enforcement/workloads/#topology-spread-constraints) |
| [Affinity](#affinity) | `placement.affinity` | `spec.affinity` | [Affinity matchers](/docs/rules/enforcement/workloads/#affinity) |
| [Seccomp](#seccomp) | `security.seccompProfile` | `spec.securityContext.seccompProfile` | [Seccomp matchers](/docs/rules/enforcement/workloads/#seccomp) |
| [AppArmor](#apparmor) | `security.appArmorProfile` | `spec.securityContext.appArmorProfile` | [AppArmor matchers](/docs/rules/enforcement/workloads/#apparmor) |
| [Read-only root filesystem](#read-only-root-filesystem) | `security.readOnlyRootFilesystem` | Selected containers: `securityContext.readOnlyRootFilesystem` | Mutation only. |
| [Image pull secrets](#image-pull-secrets) | `registries.imagePullSecrets` | `spec.imagePullSecrets` | Mutation only. |
| [Image pull policy](#image-pull-policy) | `registries.imagePullPolicy` | Selected containers: `imagePullPolicy` | [Registry pull policies](/docs/rules/enforcement/workloads/#pullpolicy) |
| [Host user namespace](#host-user-namespace) | `security.hostUsers` | `spec.hostUsers` | Mutation only. |

## Configure workload mutations

Each mutation entry has an optional [action](/docs/rules/mutate/#action) and a
`workloads` block containing at least one property to set. Scheduling fields live
under `workloads.placement`; security fields live under `workloads.security`.
`targets` stays directly under `workloads` and applies to all configured groups.
The action applies to each supplied field inside a group: replacing
`placement.scheduler` preserves an omitted `placement.nodeSelector` and all
omitted security fields. Empty `placement: {}` or `security: {}` groups supply
no mutations; use an explicit empty map or list on a supported field to clear it. For conditional
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
            placement:
              nodeSelector:
                kubernetes.io/os: linux
      enforce:
        action: allow
        workloads:
          placement:
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

Workload mutations apply on Pod creation. `security.readOnlyRootFilesystem` and
`registries.imagePullPolicy` also apply to newly added ephemeral containers. See
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

| Target | [Placement](#placement) / [Image pull secrets](#image-pull-secrets) | [`security.hostUsers`](#host-user-namespace) | [Seccomp](#seccomp) / [AppArmor](#apparmor) | [`security.readOnlyRootFilesystem`](#read-only-root-filesystem) / [`registries.imagePullPolicy`](#image-pull-policy) |
|---|---|---|---|---|
| Omitted, `[]`, or `pod` | ✅ Pod-level fields | ✅ Pod user namespace | ✅ Pod-level profiles only | ✅ All container groups |
| `pod/containers` | ❌ | ❌ | ❌ | ✅ Regular containers |
| `pod/initcontainers` | ❌ | ❌ | ❌ | ✅ Init containers and native sidecars |
| `pod/ephemeralcontainers` | ❌ | ❌ | ❌ | ✅ Newly added ephemeral containers |

Placement includes `placement.scheduler`, `placement.nodeSelector`, `placement.tolerations`,
`placement.topologySpreadConstraints`, and `placement.affinity`. These properties, `security.hostUsers`,
`security.seccompProfile`, `security.appArmorProfile`, and `registries.imagePullSecrets` require
`pod` or omitted/empty targets.
Seccomp and AppArmor mutation preserves explicit container profiles with both
`merge` and `replace`; container-specific profile mutation is not supported.

`security.readOnlyRootFilesystem` and `registries.imagePullPolicy` support container-specific
mutation targets. Use separate mutation entries to combine Pod-level settings with a
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
`securityContext.readOnlyRootFilesystem` and `imagePullPolicy` values can change.

## Placement

### Scheduler

`placement.scheduler` sets the Pod's `spec.schedulerName`. Use the name of a scheduler
configured in your cluster; Capsule selects the scheduler but does not deploy it.
See [Kubernetes multiple schedulers](https://kubernetes.io/docs/tasks/extend-kubernetes/configure-multiple-schedulers/).

To select a scheduler for every new Pod covered by the rule, use `replace`:

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
    - mutate:
        - action: replace
          workloads:
            placement:
              scheduler: tenant-scheduler
```

| Action | Behavior |
|---|---|
| `merge` | Fill an empty `spec.schedulerName`. Preserve every non-empty value, including `default-scheduler`. |
| `replace` | Set `spec.schedulerName` to the configured value when the entry's conditions match. |

Omitting `placement.scheduler` or setting it to `null` leaves the current value unchanged.
An empty or blank configured name is invalid. To select the built-in scheduler,
set `scheduler: default-scheduler` explicitly.

#### Default a scheduler with a condition

Kubernetes fills an omitted or empty `spec.schedulerName` with `default-scheduler`
before Capsule receives the admission request. To use a tenant scheduler as the
default while preserving custom scheduler names, combine `replace` with a
[mutation condition](/docs/rules/#mutation-conditions):

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
    - mutate:
        - action: replace
          conditions:
            - name: default-scheduler
              expression: >-
                !has(object.spec.schedulerName) || object.spec.schedulerName in ['', 'default-scheduler']
          workloads:
            placement:
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

`placement.nodeSelector` is a map of node-label keys and values. Every entry must match a
node for the Pod to be scheduled there.

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
    - mutate:
        - action: merge
          workloads:
            placement:
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

`placement.tolerations` is a list of native Pod tolerations. A toleration permits scheduling
onto a node with a matching taint; it does not require that node. Use a node
selector or required node affinity to restrict placement to a node pool.

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
    - mutate:
        - action: merge
          workloads:
            placement:
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

`placement.topologySpreadConstraints` is a list of native Pod spread constraints. Each
constraint specifies a topology domain and the Pods to count when spreading.

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
    - mutate:
        - action: merge
          workloads:
            placement:
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

`placement.affinity` uses the native Pod structure with three branches: `nodeAffinity`,
`podAffinity`, and `podAntiAffinity`. Each can contain required and preferred
terms.

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
    - mutate:
        - action: merge
          workloads:
            placement:
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

`replace` replaces **all of `placement.affinity`**, including branches omitted from the
mutation. Supplying only `nodeAffinity` also removes existing `podAffinity` and
`podAntiAffinity`. Use `affinity: {}` to clear all three branches.

For allowed types, required/preferred modes, selector requirements, and namespace
scope, see [affinity enforcement](/docs/rules/enforcement/workloads/#affinity).
Its matcher syntax uses one flat list across all three affinity types.

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

`security.readOnlyRootFilesystem` sets the Boolean on every selected container's
`securityContext`. Like `security.hostUsers`, **both `merge` and `replace` set the supplied
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
            security:
              readOnlyRootFilesystem: true
    - namespaceSelector:
        matchLabels:
          filesystem-profile: init-only
      mutate:
        - action: replace
          workloads:
            targets: [pod/initcontainers]
            security:
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
`enforce.workloads.security.readOnlyRootFilesystem` matcher.

### Host user namespace

`security.hostUsers` selects whether the Pod uses the host user namespace.

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
    - mutate:
        - action: merge
          workloads:
            security:
              hostUsers: false
```

| Supplied value | Behavior with `merge` or `replace` |
|---|---|
| `false` | Request a separate user namespace for the Pod. |
| `true` | Use the host user namespace. |

Both actions overwrite an existing Boolean. A later entry can change `false`
to `true` or the reverse. This property is independent of a container's
`runAsUser` and has no corresponding `enforce.workloads.security.hostUsers` matcher.

The Kubernetes version, operating system, and container runtime must support
the requested setting. Kubernetes validates incompatible Pod settings; Capsule
does not adjust other security or host-namespace fields. See
[Kubernetes user namespaces](https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/).

### Seccomp

`security.seccompProfile` sets `spec.securityContext.seccompProfile` on new Linux Pods.
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
| `merge` | Set the configured profile only when the Pod has no `spec.securityContext.seccompProfile`. Preserve any supplied profile, including its localhost path. |
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
            security:
              seccompProfile:
                type: RuntimeDefault
      enforce:
        action: allow
        workloads:
          security:
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
            security:
              seccompProfile:
                type: Localhost
                localhostProfile: profiles/solar.json
      enforce:
        action: allow
        workloads:
          security:
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

`security.appArmorProfile` sets `spec.securityContext.appArmorProfile` on new Linux Pods.
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
| `merge` | Set the configured profile only when the Pod has no `spec.securityContext.appArmorProfile`. Preserve any supplied profile, including its localhost name. |
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
            security:
              appArmorProfile:
                type: RuntimeDefault
      enforce:
        action: allow
        workloads:
          security:
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
            security:
              appArmorProfile:
                type: Localhost
                localhostProfile: solar-confined
      enforce:
        action: allow
        workloads:
          security:
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

## Registries

Configure registry-related mutations under
`mutate[].workloads.registries`. Set `imagePullPolicy` for selected containers
and `imagePullSecrets` for the Pod. The [targets table](#targets) shows which
locations support each property. Both settings apply to Linux and Windows Pods.

### Image pull policy

Set `registries.imagePullPolicy` to one of the native Kubernetes values:

| Value | Container image behavior |
|---|---|
| `Always` | Resolve the image through the registry at each container start; cached image layers can still be reused. |
| `IfNotPresent` | Pull the image when it is not already available on the node. |
| `Never` | Use an image already available on the node; the container cannot start if it is missing. |

See [Kubernetes image pull policies](https://kubernetes.io/docs/concepts/containers/images/#image-pull-policy)
for runtime behavior. Capsule changes the container's policy; it does not pull
images or create registry credentials.

| Mutation configuration | Behavior |
|---|---|
| `action: merge` or omitted action | Overwrite the selected containers' pull policies. |
| `action: replace` | Overwrite the selected containers' pull policies. |
| `registries` or `imagePullPolicy` omitted or `null` | Preserve existing pull policies. |
| `registries: {}` | Leave pull policies unchanged. The mutation entry still needs a property to set. |
| Empty string or a value other than `Always`, `IfNotPresent`, or `Never` | Reject the rule configuration. |

Kubernetes fills an omitted pull policy before mutation. Capsule overwrites
both that default and an explicit user value with either action: `merge` does
**not** mean "only when unset" for this property. Later applicable mutation
entries can overwrite it again. [Conditions](/docs/rules/#mutation-conditions)
gate the whole entry and see changes made by preceding entries.

`registries` is a settings object. The mutation applies the same policy to every
selected container, regardless of its image registry. To restrict image sources
or validate the resulting pull policy, use
[registry enforcement](/docs/rules/enforcement/workloads/#pullpolicy), where
`registries` is a list of matchers with an optional `policy` allowlist.

#### Apply different namespace profiles

This Tenant uses `Always` for all container groups in namespaces labeled
`image-profile: always-pull` and allows images only from `registry.k8s.io`.
Namespaces labeled `image-profile: init-only` receive the mutation only for
init containers and native sidecars, preserving regular-container policies.

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
          image-profile: always-pull
      mutate:
        - action: replace
          workloads:
            targets: [pod]
            registries:
              imagePullPolicy: Always
      enforce:
        action: allow
        workloads:
          targets: [pod/containers, pod/initcontainers, pod/ephemeralcontainers]
          registries:
            - exact: [registry.k8s.io]
              policy: [Always]
    - namespaceSelector:
        matchLabels:
          image-profile: init-only
      mutate:
        - action: merge
          workloads:
            targets: [pod/initcontainers]
            registries:
              imagePullPolicy: Always
```

| Request | Result from these rules |
|---|---|
| New Pod in `always-pull`, with omitted, `Never`, or `IfNotPresent` policies | Regular and init containers receive `Always`; images must pass the registry allowlist. |
| New ephemeral container in `always-pull` | The new container receives `Always`; registry enforcement still applies. |
| New Pod in `init-only` | Init containers and native sidecars receive `Always`; regular containers keep their policies. |
| Namespace with neither profile label | Neither rule applies. |

Existing containers and stored controller templates are unchanged. Pods created
by controllers receive the mutation when admitted. Ordinary Pod updates do not
rewrite pull policies, and ephemeral-container updates change only newly added
containers. Image-volume pull policies are outside the mutation targets.

### Image pull secrets

`registries.imagePullSecrets` sets the Pod's `spec.imagePullSecrets` using a
list of references with a `name` field. This is a Pod-level setting: use
`targets: [pod]`, `targets: []`, or omit targets. Container-only targets are
rejected, including when clearing the list.

| Configuration | Behavior |
|---|---|
| `merge` or omitted action | Keep each existing name once, in first-occurrence order, then append missing configured names. |
| `replace` | Set the complete list to the configured references. |
| `imagePullSecrets: []` with `replace` | Clear the Pod's image pull secret references. |
| `imagePullSecrets: []` with `merge` | Remove duplicate references; otherwise preserve the existing list. |
| Property omitted or `null` | Preserve the list with either action. |

Merge retains each name already supplied on the Pod once, including
[ServiceAccount defaults](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#add-imagepullsecrets-to-a-service-account).
Replace can remove those references. Later mutation entries see and can change
the resulting list. Repeated names on the incoming Pod are removed, and overlapping
rules or repeated admission do not introduce duplicates. Omitting the property
leaves the list untouched. Each entry accepts up to 64 references with unique,
valid Secret names; duplicate configured names are rejected for both actions.

Referenced Secrets must exist in the **Pod's namespace** and contain suitable
registry credentials. Kubernetes accepts `kubernetes.io/dockerconfigjson` or
`kubernetes.io/dockercfg` Secrets for this purpose; see
[image pull secrets](https://kubernetes.io/docs/concepts/containers/images/#specifying-imagepullsecrets-on-a-pod).
Capsule writes only the references: it does not create, copy, read, or verify
the Secrets. Provision the credentials in each selected namespace separately,
for example with [TenantResource](/docs/replications/tenant/) or
[GlobalTenantResource](/docs/replications/global/).

This Tenant adds a shared reference in one namespace profile, replaces the list
in another, and clears it in a third. Create `platform-registry` or `team-registry`
in the corresponding namespaces before workloads need to pull private images.

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
          pull-credentials: shared
      mutate:
        - action: merge
          workloads:
            targets: [pod]
            registries:
              imagePullSecrets:
                - name: platform-registry
    - namespaceSelector:
        matchLabels:
          pull-credentials: dedicated
      mutate:
        - action: replace
          workloads:
            registries:
              imagePullSecrets:
                - name: team-registry
    - namespaceSelector:
        matchLabels:
          pull-credentials: none
      mutate:
        - action: replace
          workloads:
            registries:
              imagePullSecrets: []
```

These rules apply only when a Pod is created, including Pods created by
controllers. They do not rewrite controller templates, ServiceAccounts, existing
Pods, or the secret list when adding ephemeral containers. Configure both
`imagePullPolicy` and `imagePullSecrets` in one `registries` block when using the
Pod target. For a container-specific pull policy, use a separate mutation entry.

## Reference

This complete Tenant combines every supported workload mutation property with
placement, security-profile, and image pull policy enforcement. It selects namespaces labeled
`example.com/application: checkout` and configures workloads for Linux nodes.

The `tenant-scheduler` scheduler, node pool, and zone labels must exist in the
cluster. Eligible nodes must support [user namespaces](#host-user-namespace)
and [AppArmor](#apparmor). Provision the `checkout-registry` image pull Secret
in each selected namespace. Application Pods should carry
`app.kubernetes.io/part-of: checkout` so the spread and Pod-affinity selectors
describe the intended workload.

The first mutation entry replaces the built-in scheduler default while
preserving custom scheduler names. The second entry independently applies the
remaining placement settings, supplies missing Pod-level security profiles, and
sets all selected container root filesystems read-only and image pull policies
to `Always`. It also adds `checkout-registry` to the Pod's image pull secret
references. Provide writable volume mounts for application paths that need them.

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
                !has(object.spec.schedulerName) || object.spec.schedulerName in ['', 'default-scheduler']
          workloads:
            placement:
              scheduler: tenant-scheduler
        - action: merge
          workloads:
            targets: [pod]
            security:
              readOnlyRootFilesystem: true
              hostUsers: false
              seccompProfile:
                type: RuntimeDefault
              appArmorProfile:
                type: RuntimeDefault
            registries:
              imagePullPolicy: Always
              imagePullSecrets:
                - name: checkout-registry
            placement:
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
          # Allow any image source, but require the mutated pull policy.
          registries:
            - exp: '.*'
              policy: [Always]
          security:
            seccompProfiles:
              - types: [RuntimeDefault]
            appArmorProfiles:
              - types: [RuntimeDefault]
          placement:
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
| Existing image pull secret references | Each name is kept once in first-occurrence order; `checkout-registry` is appended if absent. |
| Image pull policy omitted, `IfNotPresent`, or `Never` | Set to `Always` on regular/init containers at creation and newly added ephemeral containers. |
| Root filesystem flag omitted or `false` | Set to `true` on regular/init containers at creation and newly added ephemeral containers. |
| Pod seccomp or AppArmor profile omitted | Defaulted to RuntimeDefault. |
| Explicit Pod or container profile | Preserved by mutation, then rejected unless its effective type is RuntimeDefault. |
| Existing node selector or required affinity | Combined with the configured restrictions, then checked by the placement allowlists. |
| Namespace without `example.com/application: checkout` | These rules do not apply. |

Under `enforce`, the `pod` target validates placement and Pod-level profile defaults. The three
container targets validate effective profiles and image pull policies for regular,
init, and ephemeral containers, including container profile overrides. The registry
matcher accepts all image sources while requiring `Always`. Under `mutate`, `targets: [pod]`
selects all container groups for the root filesystem flag and image pull policy,
and Pod-level fields, including image pull secrets, for the other properties; profile mutation still writes only Pod-level profiles. An Unconfined override or privileged
container is rejected after mutation.

The toleration allowlist includes common Kubernetes-injected tolerations.
Controllers such as DaemonSets may add others; include the entries needed by
the workloads selected by your rule. The affinity validation uses one flat list
for node affinity, Pod affinity, and Pod anti-affinity.

See the [placement matcher reference](/docs/rules/enforcement/workloads/#placement)
for regular expressions, empty matchers, durations, selector operators, and
namespace scope.

These mutations run on Pod creation. The root filesystem flag and image pull policy
also apply to new ephemeral containers; the other properties are skipped on that subresource.
Controller templates and existing containers are not rewritten. Profile enforcement also applies on subsequent Pod updates and
`pods/ephemeralcontainers` updates. See [Order and scope](/docs/rules/#order-and-scope)
for rule composition and admission order.
