---
title: Workloads
weight: 1
description: >
  Workload enforcement
---

Workload enforcement is configured under `spec.rules[].enforce.workloads`.
Use `targets` to select native workload kinds or locations inside their Pod
specs. A targets-only rule matches the selected kinds themselves. When workload
policies are present, targets scope those policies: [resource management](#resource-management),
[OCI registries](#registries), scheduler names, QoS, [placement](#placement),
[security profiles](#security), and [PodDisruptionBudgets](#pod-disruption-budgets).

Rules use the shared [namespace selection](/docs/tenants/rules/),
[audiences](/docs/rules/#audience),
[conditions](/docs/rules/#enforcement-conditions), and
[actions and order](/docs/rules/enforcement/#action).
See [Reference](#reference) for a complete Tenant example.

## Rule Composition

### Actions and order

Rules are evaluated in declaration order after namespace selection, audience,
and condition filtering. The last matching `allow` or `deny` decision wins for
each evaluated value. An omitted action defaults to `deny`.

| Action | Behavior |
|---|---|
| `allow` | Creates an allow-list for the evaluated matcher. A value must match an applicable allow or deny rule; otherwise an active allow-list rejects it. |
| `deny` | Rejects matching values, unless a later matching allow rule overrides the decision. |
| `audit` | Reports matches without allowing or denying them. Audit matches never satisfy an allow-list. |

Each policy and value is evaluated independently. Allowing a registry does not
bypass a scheduler, security, placement, or other applicable constraint.

For constraints on [requests and limits](#actions-and-compliance) and
[PodDisruptionBudgets](#evaluation), `deny` rejects violations and `allow`
requires compliance. Their policy sections explain which values constitute a
match and how audit events and admission warnings are reported.

Resource policies also have a mutation phase. The last applicable policy is
effective for each target, resource, and request or limit field. The enclosing
`action: audit` **does not disable resource mutation**. See
[Rule order and policy overrides](#rule-order-and-policy-overrides) for how
`Preserve` and `Default` reset earlier constraints.

### Admission scope and limits

Workload rules govern admission of the selected resources and Pod-spec
locations. [Workload Targets](#workload-targets) maps kinds to their Pod specs;
the [controller](#controller-targets) and [Pod](#pod-targets) tables show where
each policy takes effect.

| Scope | Behavior |
|---|---|
| Targets omitted | Policies use their supported Pod locations. Controller templates require explicit controller targets. |
| Creation and updates | Validation checks the incoming resource on supported write paths. Policy-specific subresource handling is described below. |
| Resource mutation | Request and limit policies mutate Pods on creation only. With explicit controller targets, they also mutate controller templates on creation and update. |
| Pod subresources | Resource validation skips Pod subresources, including `ephemeralcontainers`. Registry and security policies use their supported container targets. |
| PDB relationships | Checks can run on workload writes, PDB writes, and supported controller replica changes, including `/scale`. See [Evaluation](#evaluation) for triggers and limits. |
| Existing resources | Rule or namespace-profile changes affect subsequent relevant admissions; they do not rewrite existing workloads. |

A controller write and the Pods it later creates are separate admissions, often
with different callers. Include the required targets and
[audiences](/docs/rules/#audience) for both paths. Conditions inspect the actual
incoming resource, which can also be a PDB or a Scale object.

Kubernetes validation, LimitRanges, ResourceQuotas, and other admission policies
still apply after Capsule's checks. See
[Admission lifecycle](#admission-lifecycle) for the resource policy stages and
[Interaction with Kubernetes resource controls](#interaction-with-kubernetes-resource-controls)
for their combined behavior.

## Workload Targets

Configure targets under `spec.rules[].enforce.workloads.targets`. The same list
selects workloads for resource, registry, scheduler, QoS, placement, security, and
[PodDisruptionBudget policies](#pod-disruption-budgets);
individual policies do not have separate target lists.

* With no workload policies, targets apply the rule's `action` to the selected
  workload kinds. For example, `targets: [daemonset]` with `action: deny` rejects
  DaemonSets.
* With workload policies, targets scope those policies to the selected workloads
  and Pod-spec locations. Adding a policy means the rule checks that property
  instead of restricting the kind itself. Use separate rule entries when you
  need both kind restrictions and property checks.

Omitted or empty targets preserve the default Pod scopes described below and do
not enable controller checks. An empty workload block has no effect. Namespace
selectors, audiences, and `enforce.conditions` apply to both forms.

Each target selects the **object being admitted**. With workload policies
configured, Capsule reads the Pod spec at the following location:

| Target | Native API group / kind | Pod spec evaluated on that object |
|---|---|---|
| `pod` | core / Pod | `spec` |
| `deployment` | apps / Deployment | `spec.template.spec` |
| `statefulset` | apps / StatefulSet | `spec.template.spec` |
| `daemonset` | apps / DaemonSet | `spec.template.spec` |
| `replicaset` | apps / ReplicaSet | `spec.template.spec` |
| `replicationcontroller` | core / ReplicationController | `spec.template.spec` |
| `job` | batch / Job | `spec.template.spec` |
| `cronjob` | batch / CronJob | `spec.jobTemplate.spec.template.spec` |

For example, `cronjob/containers` checks regular containers at
`spec.jobTemplate.spec.template.spec.containers[]` on the CronJob itself.
It does not select a Job or Pod by following its CronJob owner.

Requests match their own API group and kind, without following owner references.
A custom resource named `DaemonSet` in another API group is not a native target.
Targets use the exact lowercase values shown here; wildcards such as `pod/*`,
`deployment/*`, and `*` are not supported.

**Migration:** targets-only rules previously had no effect. They now apply the
action to the selected kinds, and an omitted action defaults to `deny`. Remove
unused targets-only entries before upgrading if they were placeholders.

### Controller targets

Controller targets check the stored Pod template during controller creation and
main-resource updates. They do not wait for a Pod to be created. A denial rejects
the controller write; an accepted template supplies the values Kubernetes later
uses to create child workloads. Existing children are not rewritten by admission.

The table uses `cronjob` as an example. The same suffixes and policy scopes apply
to every controller kind listed above, using that kind's Pod-spec path.
Paths in this table are relative to `spec.jobTemplate.spec.template.spec`.
✅ indicates support; ❌ means the policy does not apply to that target.
Only policies configured in the rule are evaluated.

| Policy | `cronjob` | `cronjob/containers` | `cronjob/initcontainers` | `cronjob/volumes` |
|---|---|---|---|---|
| Resource policies | ✅ Pod-level resources and regular/init-container resources | ✅ `containers[].resources` | ✅ `initContainers[].resources` | ❌ |
| Registry policies | ✅ Regular/init-container images and image volumes | ✅ Regular container images | ✅ Init container images | ✅ Image volumes under `volumes[].image` |
| Placement policies | ✅ Pod placement fields | ❌ | ❌ | ❌ |
| [Seccomp / AppArmor](#security) | ✅ Effective regular/init-container profiles | ✅ Effective regular-container profiles | ✅ Effective init-container profiles | ❌ |
| [PDB policies](#pod-disruption-budgets) | ✅ Template labels: overlap and unhealthy eviction policy | ❌ | ❌ | ❌ |

For example, `deployment/initcontainers` has the same scope as
`cronjob/initcontainers`, but reads `spec.template.spec.initContainers[]`.
Controller templates do not support `/ephemeralcontainers`. Resource policies
cannot be combined with volume targets.

The placement row covers node selectors, tolerations, topology spread, and
affinity. **Scheduler and QoS policies always evaluate the whole selected Pod
spec**, even with a container or volume suffix. For example,
`cronjob/initcontainers` with a scheduler policy checks
`spec.jobTemplate.spec.template.spec.schedulerName`.

A whole-controller target includes container resources and image references;
the explicit `pod` target has the narrower scope in the [Pod table](#pod-targets).
For security profiles, the effective value is the container override or its
inherited Pod default. A whole-controller target does not independently require
a Pod-level default when every container supplies its own allowed profile.

Whole-controller PDB checks use the Pod template's **labels** to find matching
budgets. CronJobs, Jobs, and DaemonSets support overlap and unhealthy eviction
policy checks, but not `evictableReplicas`. See the
[PDB target table](#pod-disruption-budgets) for the complete mapping.

Resource request/limit policies also mutate the selected template locations on
controller creation and updates. Targets do not extend `mutate[].workloads` to
controllers; mutations configured there remain limited to Pod creation. See
[Admission lifecycle](#admission-lifecycle).

Conditions see the whole admitted controller: use `object.spec.template.spec`
for a Deployment and `object.spec.jobTemplate.spec.template.spec` for a CronJob.
Events concern that controller object. Namespace selection, audiences, and
conditions must match each request independently.

#### Example: CronJob admission

This rule denies a forbidden scheduler or image in Deployment and CronJob
templates while permitting compliant ones:

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
    - enforce:
        action: deny
        workloads:
          targets: [deployment, cronjob]
          placement:
            schedulers:
              - exact: [forbidden-scheduler]
          registries:
            - exact: ['example.com/blocked/app:v1']
```

For the CronJob path, assuming the namespace, audience, and conditions match:

| Admission request | Does this rule run? | Effect |
|---|---|---|
| Create or update the CronJob | ✅ `cronjob` is selected | Checks the scheduler and image references under `spec.jobTemplate.spec.template.spec`. A match rejects the CronJob write. |
| The CronJob controller creates a Job | ❌ `job` is not selected | The Job inherits the template, but this rule does not check its admission. Add `job` to check it. |
| The Job controller creates a Pod | ❌ No Pod target is selected | The Pod inherits the template, but this rule does not check its admission. Add the relevant Pod targets to check it. |

To check all three stages, include `cronjob`, `job`, and the Pod targets needed
for the policy. For registry checks, use `pod/containers`,
`pod/initcontainers`, `pod/ephemeralcontainers`, and/or `pod/volumes` for the image
locations you want to cover; `pod` alone does not select images. Controller-created
Jobs and Pods can have different callers, so include those identities in any
[audience filter](/docs/rules/#audience).

With **no workload policies**, `targets: [cronjob]` instead acts on the kind:
`deny` rejects CronJobs, while `allow` establishes a workload-kind allow-list.
A targets-only allow-list must also allow `job` and `pod` for scheduled workloads
to run. See [Select Workloads](#select-workloads).

### Pod targets

When workload policies are present, Pod targets select these locations.
✅ indicates support; ❌ means the policy does not apply to that target.

| Target | Resource policies | Registry policies | Placement policies | [Seccomp / AppArmor](#security) | [PDB policies](#pod-disruption-budgets) |
|---|---|---|---|---|---|
| `pod` | ✅ Pod-level `spec.resources` | ❌ | ✅ Pod placement fields | ✅ Pod default only | ✅ Overlap and unhealthy eviction policy |
| `pod/containers` | ✅ `spec.containers[].resources` | ✅ Regular container images | ❌ | ✅ Effective regular-container profiles | ❌ |
| `pod/initcontainers` | ✅ `spec.initContainers[].resources` | ✅ Init container images | ❌ | ✅ Effective init-container profiles | ❌ |
| `pod/ephemeralcontainers` | ❌ | ✅ Ephemeral container images | ❌ | ✅ Effective ephemeral-container profiles | ❌ |
| `pod/volumes` | ❌ | ✅ Image volumes under `spec.volumes[].image` | ❌ | ❌ | ❌ |

For seccomp and AppArmor, an **effective profile** resolves a container override
before the Pod default. Init containers include restartable sidecars.
Selecting `pod` alone checks the default and leaves container overrides
unchecked. See [Target security profiles](#target-security-profiles) for a
complete Tenant and a comparison of these scopes.

This table describes enforcement. Profile mutations under `mutate[].workloads`
set Pod-level defaults on Pod creation, using `pod` or omitted mutation targets.
Neither `merge` nor `replace` modifies container profile overrides. For
`security.readOnlyRootFilesystem` and `registries.imagePullPolicy` mutations, `pod` selects all container groups and
container targets can narrow the selection. See the separate
[mutation targets table](/docs/rules/mutate/workloads/#targets). Enforcement
targets do not control mutation.

Scheduler and QoS policies always evaluate the whole Pod selected by any Pod
target. For example, `pod/containers` does not limit QoS calculation to regular
containers. Resource policies cannot be combined with targets for ephemeral
containers or volumes.

Omitting `targets`, or setting it to `[]`, selects all compatible Pod locations:
Pod-level resources, regular and init container resources, regular/init/ephemeral
container images, image volumes, and Pod placement fields. Scheduler and QoS
checks also apply. Profile policies check effective regular, init, and ephemeral
container profiles. PDB overlap and unhealthy eviction policies check the Pod;
eviction-count bounds require an explicit supported controller target.
Resource-name compatibility is described under
[Targeting resource locations](#targeting-resource-locations).

An explicit `targets: [pod]` is narrower than omitted targets: it selects
Pod-level resources, placement, and security-profile defaults, together with scheduler and QoS checks. It
does not select container resources or any image references. List the desired
Pod parts explicitly when narrowing container, image, or profile policies.

For example, deny matching images only in init containers:

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
    - enforce:
        action: deny
        workloads:
          targets: [pod/initcontainers]
          registries:
            - exp: "harbor/init-only/.*"
```

The same image reference in a regular container, ephemeral container, or image
volume is unaffected by this rule. Combine targets to check multiple locations:

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
    - enforce:
        action: deny
        workloads:
          targets: [pod/containers, pod/ephemeralcontainers]
          registries:
            - exp: "debug/.*"
```

This checks regular and ephemeral container images. It does not check init
containers or image volumes.

**Targets without policies match the whole kind.** A targets-only rule with
`targets: [pod/containers]` and `action: deny` rejects Pods, just like
`targets: [pod]`. A part suffix narrows property checks only when workload
policies are configured.

#### Target security profiles

This complete Tenant gives namespaces two different profile policies. Namespaces
labeled `profile-scope: pod-only` require RuntimeDefault in the Pod's security
context. Namespaces labeled `profile-scope: containers` require RuntimeDefault
for every effective regular, init, and ephemeral container profile. Namespaces
with neither label are unaffected by these rules.

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
          profile-scope: pod-only
      enforce:
        action: allow
        workloads:
          targets: [pod]
          security:
            seccompProfiles:
              - types: [RuntimeDefault]
            appArmorProfiles:
              - types: [RuntimeDefault]
    - namespaceSelector:
        matchLabels:
          profile-scope: containers
      enforce:
        action: allow
        workloads:
          targets:
            - pod/containers
            - pod/initcontainers
            - pod/ephemeralcontainers
          security:
            seccompProfiles:
              - types: [RuntimeDefault]
            appArmorProfiles:
              - types: [RuntimeDefault]
```

These rules supply no defaults. For Linux Pods, each mechanism is checked
independently:

| Submitted profile configuration | `profile-scope: pod-only` | `profile-scope: containers` |
|---|---|---|
| Pod RuntimeDefault; all containers inherit it | ✅ Allowed | ✅ Allowed |
| Pod RuntimeDefault; regular container overrides it with Unconfined | ✅ Allowed | ❌ Rejected |
| Pod RuntimeDefault; init container overrides it with Unconfined | ✅ Allowed | ❌ Rejected |
| Pod RuntimeDefault; ephemeral container overrides it with Unconfined | ✅ Allowed | ❌ Rejected |
| No Pod profile; every container explicitly uses RuntimeDefault | ❌ Rejected | ✅ Allowed |
| No profile at either level | ❌ Rejected | ❌ Rejected |

List only `pod/initcontainers` to restrict the profile checks to init containers.
Combine `pod` with the three container targets to require both an allowed Pod
default and allowed effective container profiles. Omitting targets checks all
three container groups without independently requiring a Pod default.

The [security reference](#security-reference) combines Pod-level defaulting with
container enforcement. A container override survives mutation and must then
pass the selected enforcement checks, including on `pods/ephemeralcontainers`
updates.

### Select Workloads

A targets-only `allow` rule establishes an allow-list across the eight supported
native workload kinds. Other resource kinds remain outside this allow-list.
Allow controller-created children explicitly:

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
    - enforce:
        action: allow
        workloads:
          targets: [deployment, replicaset, pod]
```

This allows Deployments, ReplicaSets, and Pods while rejecting the other
supported native workload kinds. Allowing a Deployment alone does not allow its
ReplicaSets or Pods: each request is evaluated separately. Kind restrictions
apply to creation and main-resource updates, not deletion or subresources.


#### Deny DaemonSets

Add a targets-only rule under `Tenant.spec.rules` to deny DaemonSets in namespaces
labeled `env: test`:

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
          env: test
      enforce:
        action: deny
        workloads:
          targets: [daemonset]
```

This rejects DaemonSet creation and main-resource updates in the selected
namespaces. It does not remove existing DaemonSets or block deletion or
subresources. Other workload kinds and non-selected namespaces are unaffected
by this rule. To cover all namespaces in the Tenant, omit `namespaceSelector`.

Use `action: audit` to record matching requests without blocking them. For kind
restrictions, the last matching `allow` or `deny` rule wins; `audit` does not
change that decision.

## Resource Management

Configure CPU, memory, and other resource requests and limits, together with
Pod QoS policies.

### Requests and Limits

Resource policies let a Tenant administrator normalize and enforce the
`requests` and `limits` of Pods created in Tenant namespaces. They cover common
requirements that a Kubernetes `LimitRange` cannot express directly, including:

* always removing a resource limit;
* making a limit equal to its request;
* defaulting a missing request or limit without replacing an explicit value;
* deriving a missing limit from a request using a maximum ratio; and
* rejecting or auditing explicit limits that exceed that ratio.

Resource policies are configured under
`spec.rules[].enforce.workloads.resources`. The `requests` and `limits` maps are
keyed by Kubernetes resource name. Each map entry contains a case-sensitive
`policy` and, for policies that need one, a `value`.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  rules:
    - enforce:
        action: deny
        workloads:
          resources:
            limits:
              cpu:
                policy: Remove
              memory:
                policy: MatchRequest
```

At every compatible resource location, this example produces the following
behavior:

* CPU limits are removed, even when the submitted Pod defines them;
* memory limits are set to the corresponding memory requests; and
* because `targets` is omitted, the policy applies to Pod-level resources,
  regular containers, and init containers.

#### Before and after admission

Consider this submitted Pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: api
spec:
  containers:
    - name: api
      image: registry.example.com/api:1.0.0
      resources:
        requests:
          cpu: 250m
          memory: 512Mi
        limits:
          cpu: "1"
          memory: 1Gi
```

Capsule admits it with the equivalent resource configuration:

```yaml
resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    memory: 512Mi
```

The CPU request is untouched, the CPU limit is removed, and the memory limit is
replaced with the memory request. Because `targets` is omitted, Capsule applies
the same policy independently to `spec.resources`, every regular container, and
every init container in the Pod. The submitted example has no Pod-level or init
container resources, so those locations remain empty.

If `MatchRequest` finds neither a request nor a limit, the resource is
compliant and remains undefined. If it finds a limit without a corresponding
request, it cannot derive a replacement and the final state violates the
policy. With `action: deny` the Pod is rejected; with `action: audit` Capsule
admits it and emits an audit event and admission warning.

#### Policy reference

After starting with the common example above, use this reference to
choose the precise behavior for each request and limit.

##### Requests

The following policies are supported under `resources.requests`:

| Policy | `value` | Mutation behavior | Validation behavior |
|---|---|---|---|
| `Preserve` | Not allowed | Leaves an existing or missing request unchanged. | Adds no constraint and clears earlier constraints for the same target and resource. |
| `Default` | Required | Sets the configured quantity only when the request is absent. An explicit request is preserved. | Adds no constraint and clears earlier constraints for the same target and resource. |
| `Remove` | Not allowed | Removes the request when it is present. | Requires the request to be absent in the final Pod. |

Default a request without overriding tenant workloads that already specify it:

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
    - enforce:
        action: deny
        workloads:
          resources:
            requests:
              cpu:
                policy: Default
                value: 100m
              memory:
                policy: Default
                value: 256Mi
```

If a container requests `500m` CPU, Capsule preserves `500m`. If the CPU
request is missing, Capsule adds `100m`.

Remove an extended resource request:

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
    - enforce:
        action: deny
        workloads:
          targets:
            - pod/containers
          resources:
            requests:
              example.com/temporary-device:
                policy: Remove
```

Resource names must be valid Kubernetes qualified names. Custom and extended
resource names can be used for container and init-container policies, subject
to the normal Kubernetes rules for that resource.

##### Limits

The following policies are supported under `resources.limits`:

| Policy | `value` | Mutation behavior | Validation behavior |
|---|---|---|---|
| `Preserve` | Not allowed | Leaves an existing or missing limit unchanged. | Adds no constraint and clears earlier constraints for the same target and resource. |
| `Default` | Required | Sets the configured quantity only when the limit is absent. An explicit limit is preserved. | Adds no constraint and clears earlier constraints for the same target and resource. |
| `Remove` | Not allowed | Removes the limit when it is present. | Requires the limit to be absent in the final Pod. |
| `MatchRequest` | Not allowed | If a request exists, sets the limit to exactly the request, replacing a different explicit limit. If no request exists, it does not add a limit. | Requires request and limit to be equal. When the request is absent, the limit must also be absent. |
| `Ratio` | Required | If a positive request exists and the limit is absent, sets the limit to `request * value`. An explicit limit is preserved for validation. | Requires a positive request and a limit no greater than `request * value`. |

`Default` is a fill-only policy. It does not mean that every limit must equal
the configured value. Use `MatchRequest` when Capsule should own the limit and
keep it equal to the request, or `Ratio` when explicit tenant values are allowed
within a bounded range.

##### Ratio limits

`Ratio` defines the maximum permitted limit as a multiple of the request. It is
available only for limits and supports these resource names:

| Resource | Calculation precision |
|---|---|
| `cpu` | Exact decimal arithmetic, rounded down to the nearest millicore. |
| `memory` | Exact decimal arithmetic, rounded down to a whole byte. |
| `ephemeral-storage` | Exact decimal arithmetic, rounded down to a whole byte. |

The ratio must be greater than or equal to `1`. Quote fractional ratios in YAML
for clarity, for example `"1.5"`.

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
    - enforce:
        action: deny
        workloads:
          targets:
            - pod/containers
          resources:
            limits:
              memory:
                policy: Ratio
                value: "1.5"
```

For a memory request of `1Gi`, the maximum limit is `1536Mi`:

| Submitted limit | Mutation | Result with `action: deny` |
|---|---|---|
| Missing | Capsule adds `1536Mi`. | Admitted. |
| `1Gi` | Explicit value is preserved. | Admitted because it is below the maximum. |
| `1536Mi` | Explicit value is preserved. | Admitted because it equals the maximum. |
| `2Gi` | Explicit value is preserved. | Denied because it exceeds the maximum. |

An explicit limit is never reduced by `Ratio`. This is deliberate: preserving
the submitted value allows `allow`, `deny`, and `audit` to decide how a ratio
violation should be handled. Use `MatchRequest` when the limit should always be
rewritten instead.

`Ratio` requires a positive request. When the request is missing or zero,
Capsule cannot calculate a default limit. The missing or non-positive request
is therefore a policy violation. A `deny` action blocks it, an `audit` action
reports it, and an `allow` action treats it as an allow-list miss and blocks it.

Capsule calculates ratios without floating-point arithmetic and rounds down so
that the generated limit never exceeds the configured factor. For example, a
CPU request of `101m` with a ratio of `1.5` produces a limit of `151m`, not
`152m`.

#### Targeting resource locations

Resource policies reuse `enforce.workloads.targets` to select resource locations.
See [Pod targets](#pod-targets) for the location table and
[Workload targets](#workload-targets) for controller targets.
Ephemeral containers and volumes cannot be selected for resource policies.

When `targets` is omitted or empty, each resource policy applies to every
compatible location: Pod-level `spec.resources`, regular containers, and init
containers. An explicit `targets` list narrows that default.

Compatibility is evaluated per resource name. Kubernetes Pod-level resources
support only `cpu`, `memory`, and huge-page resources. With omitted targets,
those names apply at all three locations, while other valid names such as
`ephemeral-storage` and extended resources apply only to regular and init
containers. Capsule skips those incompatible names at `spec.resources`; it does
not reject the rule or discard their container policies.

Only regular containers:

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
    - enforce:
        action: deny
        workloads:
          targets:
            - pod/containers
          resources:
            limits:
              cpu:
                policy: Remove
```

Only init containers:

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
    - enforce:
        action: deny
        workloads:
          targets:
            - pod/initcontainers
          resources:
            requests:
              cpu:
                policy: Default
                value: 25m
```

Both regular and init containers, explicitly:

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
    - enforce:
        action: deny
        workloads:
          targets:
            - pod/containers
            - pod/initcontainers
          resources:
            limits:
              memory:
                policy: MatchRequest
```

Only Pod-level resources:

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
    - enforce:
        action: deny
        workloads:
          targets:
            - pod
          resources:
            requests:
              cpu:
                policy: Default
                value: 500m
              memory:
                policy: Default
                value: 1Gi
            limits:
              cpu:
                policy: Ratio
                value: "2"
              memory:
                policy: Ratio
                value: "1.5"
```

The Kubernetes API server must support `spec.resources` for Pod-level resource
policies to be useful. Pod-level policies support `cpu`, `memory`, and huge-page
resources. Because `Ratio` itself supports only CPU, memory, and ephemeral
storage, a pod-level ratio can be configured for CPU or memory, but not for huge
pages. Use an explicit `pod` target when the policy must not affect containers.

{{% alert title="Target compatibility" color="warning" %}}
When a workload block contains `resources`, every explicitly configured target
in that block must support resource policies. A block that combines resource
policies with `pod/ephemeralcontainers` or `pod/volumes` is invalid. Put registry
or image-volume enforcement that needs those targets in a separate rule.

If `pod` is explicitly combined with a container target, every configured
resource name must also be valid at Pod level. Omit `targets` when a policy
should use the broad default and automatically skip only its incompatible
Pod-level location.
{{% /alert %}}

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - kind: User
      name: solar-owner
  # Valid: resource and registry policies use separate target scopes.
  rules:
    - enforce:
        action: deny
        workloads:
          targets:
            - pod/containers
          resources:
            limits:
              cpu:
                policy: Remove

    - enforce:
        action: deny
        workloads:
          targets:
            - pod/ephemeralcontainers
            - pod/volumes
          registries:
            - exp: "untrusted.example.com/.*"
```

#### Advanced behavior

The following concepts are mainly relevant when combining multiple rules,
selectors, admission actions, or Kubernetes resource-management components.

##### Admission lifecycle

Resource policy admission has a mutation phase and a validation phase. Knowing
which phase a policy uses is important when choosing a policy and an action.

| Admission phase | Operations | Behavior |
|---|---|---|
| Mutation | Pod `CREATE` | Capsule applies the effective `Default`, `Remove`, `MatchRequest`, or `Ratio` mutation to the incoming Pod. `Preserve` does not change the field. |
| Validation | Pod `CREATE` and normal `UPDATE` | Capsule checks the final resource values for `Remove`, `MatchRequest`, and `Ratio`. `Preserve` and `Default` do not add a validation constraint. |
| Pod subresources | Any | Resource validation is skipped for Pod subresources, including `ephemeralcontainers`. Resource policies do not mutate ephemeral containers. |

For Pods, resource mutation is limited to creation. Capsule does not try to
rewrite resource fields on existing Pods, where Kubernetes immutability rules
would normally reject the change. Normal Pod updates are still validated so
that the policy describes the accepted final state.

With omitted targets or Pod targets, Capsule mutates and validates the resulting
Pods without rewriting controller templates. With explicit controller targets,
resource request/limit policies also mutate and validate the stored Pod template
on controller creation and updates. Defaults therefore appear directly in the
controller. Other workload mutations under `mutate[].workloads` remain Pod-only.

{{% alert title="Important" color="warning" %}}
The enclosing `action` does not disable mutation. A rule with `action: audit`
still applies its resource mutation within the supported target and operation. The action controls the result
of a remaining validation violation. For example, `Ratio` leaves an explicit
limit unchanged, then `deny` rejects an excessive value while `audit` reports
it without blocking the Pod.
{{% /alert %}}

##### Actions and compliance

The `action` belongs to the enclosing `enforce` block and applies to
validation constraints created by `Remove`, `MatchRequest`, and `Ratio`:

| Action | When the final value complies | When the final value violates the policy |
|---|---|---|
| `deny` | No deny decision is produced. | The Pod is denied. |
| `allow` | The policy produces an allow decision. | The value does not satisfy the resource allow-list and the Pod is denied unless a later matching rule allows it. |
| `audit` | No audit is emitted. | The Pod is admitted by this rule, and Capsule emits a Kubernetes event and admission warning. Other rules can still deny it. |

As with other enforcement matchers, the last matching `allow` or `deny`
decision wins. Audit decisions never override allow or deny decisions.

The following example denies memory limits above `1.5` times the request by
default but permits up to `2` times the request in namespaces labeled
`burst-memory=true`:

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
    - enforce:
        action: deny
        workloads:
          targets:
            - pod/containers
          resources:
            limits:
              memory:
                policy: Ratio
                value: "1.5"

    - namespaceSelector:
        matchLabels:
          burst-memory: "true"
      enforce:
        action: allow
        workloads:
          targets:
            - pod/containers
          resources:
            limits:
              memory:
                policy: Ratio
                value: "2"
```

A container with a `1Gi` request and a `1792Mi` limit violates the first rule
but complies with the later allow rule. It is admitted only in a namespace that
matches the selector on the second rule.

Audit explicit ratio violations without rejecting them:

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
    - enforce:
        action: audit
        workloads:
          targets:
            - pod/containers
          resources:
            limits:
              ephemeral-storage:
                policy: Ratio
                value: "2"
```

Remember that a missing limit is still defaulted during create. The audit is
emitted only when the final Pod remains noncompliant, such as when it contains
an explicit excessive limit or a limit without a positive request.

##### Rule order and policy overrides

Rules are processed in declaration order after `namespaceSelector` and
[audience](/docs/rules/#audience) filtering. Resource policies are resolved independently for every
combination of target, resource name, and field (`request` or `limit`). This
allows CPU and memory, or requests and limits, to be managed independently.

For mutation, the last applicable policy for a target, resource name, and field
is effective. A later `Preserve` therefore prevents an earlier mutation:

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
    - enforce:
        action: deny
        workloads:
          resources:
            limits:
              cpu:
                policy: Remove

    - namespaceSelector:
        matchLabels:
          preserve-cpu-limit: "true"
      enforce:
        action: allow
        workloads:
          targets:
            - pod/containers
            - pod/initcontainers
          resources:
            limits:
              cpu:
                policy: Preserve
```

In matching namespaces, the later `Preserve` policy leaves CPU limits intact.
In other namespaces, the earlier `Remove` policy remains effective.

For validation, `Preserve` and `Default` also clear earlier constraints for the
same target, field, and resource. Constraints declared after that reset point
are still evaluated. This makes `Preserve` useful as a namespace-specific
escape hatch and `Default` useful when switching from enforcement back to
fill-only behavior.

For the request identity of controller-created Pods, see [Audience](/docs/rules/#audience).

##### Configuration validation

Capsule validates resource policy configuration before using it. Invalid rules
are reported on the RuleStatus and are not silently accepted.

The following requirements apply:

* At least one non-empty `requests` or `limits` map is required.
* Policy names are case-sensitive.
* `value` is required only by request `Default`, limit `Default`, and limit
  `Ratio`.
* `value` must not be supplied to `Preserve`, `Remove`, or `MatchRequest`.
* Default quantities must not be negative. A zero default is accepted, although
  Kubernetes or another admission policy can impose a stricter requirement.
* A ratio must be greater than or equal to `1`.
* `Ratio` supports only `cpu`, `memory`, and `ephemeral-storage`.
* `pod/ephemeralcontainers`, `pod/volumes`, and the deprecated `pod/images`
  target cannot be used in a workload block containing resource policies.
* A request cannot use `Remove` while the same rule uses `MatchRequest` or
  `Ratio` for that resource's limit, because those limit policies require the
  request.
* When the `pod` target is explicitly present, resource names in that block are
  restricted to `cpu`, `memory`, and huge-page resources supported by
  Kubernetes pod-level resources.
* When `targets` is omitted, Pod-incompatible resource names remain valid and
  are applied only to regular and init containers.

For example, this configuration is invalid:

```yaml
resources:
  requests:
    memory:
      policy: Remove
  limits:
    memory:
      policy: Ratio
      value: "1.5"
```

The following is also invalid because `value` is not accepted by `Remove`:

```yaml
resources:
  limits:
    cpu:
      policy: Remove
      value: "1"
```

##### Interaction with Kubernetes resource controls

Resource policies complement Kubernetes resource controls; they do not replace
or disable them.

* `LimitRange` can still apply its own defaults and min/max validation.
  Configure its constraints consistently with Capsule resource policies to
  avoid admission behavior that depends on webhook and admission-plugin order.
* `ResourceQuota`, Global Resource Quota, and Resource Pools evaluate the
  resulting Pod resources according to their own semantics.
* Other mutating webhooks can also change resources. Capsule's generic mutating
  webhook requests reinvocation when another mutator changes the Pod, and the
  validating webhook checks the final object it receives.
* Kubernetes performs its own resource validation after mutation. A resource
  configuration accepted by a Capsule policy can still be rejected by the API
  server or another admission policy.
* A Vertical Pod Autoscaler or another controller that creates replacement Pods
  is subject to the policy when those Pods are admitted. Normal updates are
  validated but not mutated.

To inspect the effective resources after admission, query the Pod rather than
only its workload-controller template:

```bash
kubectl get pod api -n solar-apps \
  -o jsonpath='{.spec.containers[*].resources}'
```

If admission is denied, Capsule's error identifies the target path, resource
field, and failed requirement. Audit violations appear as admission warnings
and Kubernetes events associated with the Pod and Tenant.

### QoS Classes

For example, reject BestEffort Pods in the Tenant namespaces:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  rules:
    - enforce:
        action: deny
        workloads:
          qosClasses:
            - BestEffort
```

QoS class enforcement allows administrators to allow, deny, or audit Pods based on their [computed Kubernetes QoS class](https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/).

QoS rules are configured under `enforce.workloads.qosClasses`.

Supported QoS classes are:

| QoS class | Description |
|---|---|
| `Guaranteed` | The Pod has CPU and memory requests and limits set so that requests equal limits. |
| `Burstable` | The Pod has at least one CPU or memory request or limit, but does not qualify as `Guaranteed`. |
| `BestEffort` | The Pod has no CPU or memory requests or limits. |

Capsule evaluates the QoS class of the incoming Pod during create and update admission. If Kubernetes has already populated `status.qosClass`, Capsule can use that value; otherwise it computes the QoS class from the Pod specification.

Deny `BestEffort` Pods:

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
        action: deny
        workloads:
          qosClasses:
            - BestEffort
```

With this rule, a Pod without CPU or memory requests and limits is denied:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: best-effort
spec:
  containers:
    - name: shell
      image: harbor/platform/debian:latest
      command: ["sleep", "infinity"]
```

Example rejection:

```bash
Error from server (Forbidden): error when creating "pod.yaml": admission webhook "pods.projectcapsule.dev" denied the request: QoS class "BestEffort" at status.qosClass is denied by namespace rule
```

Audit `Burstable` Pods:

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
    - enforce:
        action: audit
        workloads:
          qosClasses:
            - Burstable
```

A matching Pod is admitted in this audit-only example, but Capsule emits an event and the API server response contains an admission warning. If a QoS allow-list is also configured and the Pod's QoS class is not allowed, the Pod is denied while the audit event is still emitted.

Allow `BestEffort` only for selected namespaces:

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
    - enforce:
        action: deny
        workloads:
          qosClasses:
            - BestEffort

    - namespaceSelector:
        matchLabels:
          allow-best-effort: "true"
      enforce:
        action: allow
        workloads:
          qosClasses:
            - BestEffort
```

Because later matching allow or deny rules take precedence, namespaces labeled `allow-best-effort=true` can run `BestEffort` Pods, while other namespaces cannot.


## Placement

Configure scheduling matchers under `enforce.workloads.placement`, including
`schedulers`, `nodeSelector`, `tolerations`, `topologySpreadConstraints`, and
`affinity`. `targets` remains at `enforce.workloads.targets` and scopes all
configured workload policies.

Configure placement policies under `spec.rules[].enforce.workloads`. Each property
has its own matcher list:

| Property | Evaluated value | Mutation |
|---|---|---|
| [Scheduler names](#scheduler-names) | `spec.schedulerName` | [Set the scheduler](/docs/rules/mutate/workloads/#scheduler) |
| [Node selectors](#node-selectors) | Each key/value pair in `spec.nodeSelector` | [Set node selectors](/docs/rules/mutate/workloads/#node-selectors) |
| [Tolerations](#tolerations) | Each complete entry in `spec.tolerations` | [Set tolerations](/docs/rules/mutate/workloads/#tolerations) |
| [Topology spread constraints](#topology-spread-constraints) | Each complete entry in `spec.topologySpreadConstraints` | [Set spread constraints](/docs/rules/mutate/workloads/#topology-spread-constraints) |
| [Affinity](#affinity) | Each complete required or preferred affinity term | [Set affinity](/docs/rules/mutate/workloads/#affinity) |

Read [Order and scope](/docs/rules/#order-and-scope) for how mutation precedes
enforcement, and [Conditions](/docs/rules/#enforcement-conditions) to apply checks
conditionally. The [Reference](#reference) combines all placement policies with
resource and image rules. To configure mutations alongside enforcement, see the
[complete mutation example](/docs/rules/mutate/workloads/#reference).

Scheduler policies evaluate one scheduler name. Node selectors, tolerations,
topology spread constraints, and affinity are evaluated entry by entry. For
these structured entries, fields within a matcher are combined with AND, and
entries in the matcher list are alternatives. A match requires one complete
matcher to match the entry; different matchers cannot authorize separate parts
of the same affinity term or spread constraint.

The [action rules](/docs/rules/enforcement/#action) apply to each evaluated value:
`allow` enables an allow-list, `deny` rejects matches, and `audit` only records
them. The last matching allow or deny wins. Every supplied entry must pass its
policy; a single rejected entry denies the request. Mutated values and
Kubernetes-injected values are evaluated in the same way.

Allow rules do not require a placement property to be present. Omitted
properties and empty lists have no entries to validate. Use
[workload mutation](/docs/rules/mutate/workloads/) to establish settings before
enforcement. An omitted policy list or `[]` adds no matchers. For node selectors,
tolerations, spread constraints, and affinity, `[{}]` matches every present
entry. Scheduler matchers require a match expression instead.

Those four structured properties use the `pod` target or a whole-controller
target such as `deployment`. Omitting `targets` includes Pod placement checks;
selecting only container or volume targets skips them. Scheduler checks apply
to the whole selected Pod spec even when a part is selected. See
[Workload targets](#workload-targets) for all target scopes.

For those four properties, main-resource Pod updates check changed values and
recheck affinity and spread selectors when labels change. Subresources skip
these checks.

### Matcher fields

Scheduler matchers and the `key`, `values`, `topologyKey`, and `namespaces` fields
use the common [match expression structure](/docs/rules/#match-expressions):
`exact`, `exp`, and optional `negate`.

Omit a matcher field to leave it unrestricted. A supplied expression must contain
`exact` or `exp`; `key: {}` is invalid. Use `exp: '^$'` to match an empty string.
The property references below list the additional fields supported by each
matcher, such as operators, effects, and numeric bounds.

### Selector policies

Topology-spread and Pod-affinity matchers use the following policy structure for
`labelSelector` and, where supported, `namespaceSelector`:

| Field | Behavior |
|---|---|
| `required` | When `true`, require at least one effective selector requirement. |
| `requirements` | Allowlist for individual selector requirements. Omission or an empty list leaves requirements unrestricted. |

Each requirement matcher supports `key`, `values`, and `operators`. Label
selectors support `In`, `NotIn`, `Exists`, and `DoesNotExist`. Every actual
requirement must match one complete entry, and every supplied value must match
its `values` expression. `matchLabels` entries are evaluated as singleton `In`
requirements.

`Exists` and `DoesNotExist` have no values to test. Permitting those operators
permits their valueless form; use `operators: [In]` when allowed values must
restrict the selection. A requirement allowlist constrains supplied requirements;
it does not require every listed key to appear.

Dynamic `matchLabelKeys` and `mismatchLabelKeys` are checked as `In` and `NotIn`
requirements using the incoming Pod's label values. Missing dynamic labels are
ignored, matching Kubernetes behavior. `required: true` uses this effective
selector, including any dynamic requirements.

### Scheduler names

Configure scheduler matchers under `enforce.workloads.placement.schedulers`. Capsule checks
`spec.schedulerName` during create and update admission.

Kubernetes defaults an omitted or empty name to `default-scheduler` before Pod
admission. Enforcement checks that name unless a mutation changes it; the
matcher itself does not fill an empty value. A
[conditional scheduler default](/docs/rules/mutate/workloads/#default-a-scheduler-with-a-condition)
can replace the built-in scheduler while preserving custom names.

Allow only these schedulers:

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
    - enforce:
        action: allow
        workloads:
          placement:
            schedulers:
              - exact: [tenant-scheduler, batch-scheduler]
```

| Pod scheduler name at enforcement | Result |
|---|---|
| `tenant-scheduler` or `batch-scheduler` | Allowed |
| `other-scheduler` | Denied |
| `default-scheduler`, including a name defaulted by Kubernetes | Denied |

To allow a scheduler family as well as fixed names, combine `exact` and `exp`.
Either one can satisfy this matcher:

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
    - enforce:
        action: allow
        workloads:
          placement:
            schedulers:
              - exact: [default-scheduler, batch-scheduler]
                exp: '^tenant-[a-z0-9-]+$'
```

Deny one scheduler while leaving other names unrestricted by this rule:

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
    - enforce:
        action: deny
        workloads:
          placement:
            schedulers:
              - exact: [unsafe-scheduler]
```

Alternatively, negate a trusted set to deny all other names:

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
    - enforce:
        action: deny
        workloads:
          placement:
            schedulers:
              - exact: [default-scheduler, tenant-scheduler]
                negate: true
```

To record usage without changing the admission decision, use `audit`:

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
    - enforce:
        action: audit
        workloads:
          placement:
            schedulers:
              - exact: [custom-scheduler]
```

This emits an event and an admission warning for `custom-scheduler`. Other
policies still apply; an audit match cannot satisfy a scheduler allow-list.

### Node selectors

Each matcher evaluates one key/value pair in `spec.nodeSelector`.

| Field | Matches |
|---|---|
| `key` | The node-label key. |
| `values` | The node-label value, including an explicitly empty value. |

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
    - enforce:
        action: allow
        workloads:
          placement:
            nodeSelector:
              - key:
                  exact: [kubernetes.io/os]
                values:
                  exact: [linux]
              - key:
                  exp: '^placement\.example\.com/[a-z0-9-]+$'
                values:
                  exact: [shared, batch]
```

This allows `kubernetes.io/os: linux` and keys such as
`placement.example.com/pool: shared`. It rejects `kubernetes.io/os: windows`,
`placement.example.com/pool: dedicated`, and unlisted keys. A Pod with no node
selector is allowed by this rule.

### Tolerations

Each matcher evaluates one complete toleration in `spec.tolerations`.

| Field | Matches |
|---|---|
| `key` | Taint key expression. An empty Pod key is a literal empty string. |
| `values` | Toleration value expression. |
| `operators` | `Equal` or `Exists`. An omitted Pod operator is `Equal`. |
| `effects` | `NoSchedule`, `PreferNoSchedule`, `NoExecute`, or the literal empty string `""`. |
| `tolerationSeconds` | Inclusive `min` and `max` bounds, with optional `allowUnlimited`. |

An empty toleration key or effect has broad Kubernetes semantics. It does not
match an allowlist of specific keys or effects. To allow an empty effect, include
`""` explicitly in `effects`.

An absent `tolerationSeconds` means unlimited. Bounds apply to finite durations;
`allowUnlimited` defaults to `true`. Set it to `false` to require a finite duration:

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
    - enforce:
        action: allow
        workloads:
          placement:
            tolerations:
              - key:
                  exact: [node.kubernetes.io/not-ready, node.kubernetes.io/unreachable]
                operators: [Exists]
                effects: [NoExecute]
                tolerationSeconds:
                  max: 600
                  allowUnlimited: false
```

This permits only the two listed NoExecute tolerations, each with a finite
duration of at most 600 seconds. Add other matchers for any additional tolerations
needed by your workloads or injected by Kubernetes.

#### Disallow every toleration

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
    - enforce:
        action: deny
        workloads:
          placement:
            tolerations:
              - {}
```

The empty matcher rejects every toleration, including injected ones. Kubernetes
normally adds not-ready and unreachable tolerations, so this rule rejects ordinary
Pods with those entries too. Use an allowlist when system tolerations must remain
permitted. A Pod with no tolerations has no entry for this deny rule to match.

### Topology spread constraints

Each matcher evaluates one complete entry in `spec.topologySpreadConstraints`.

| Field | Matches |
|---|---|
| `topologyKey` | Topology-key expression. |
| `whenUnsatisfiable` | List containing `DoNotSchedule` or `ScheduleAnyway`. |
| `maxSkew` | Inclusive `min` and `max` bounds. |
| `minDomains` | Inclusive bounds; an omitted Pod value is evaluated as `1`. |
| `nodeAffinityPolicy` | `Honor` or `Ignore`; an omitted Pod value is `Honor`. |
| `nodeTaintsPolicy` | `Honor` or `Ignore`; an omitted Pod value is `Ignore`. |
| `labelSelector` | [Selector policy](#selector-policies) for the Pods counted by the constraint. |

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
    - enforce:
        action: allow
        workloads:
          placement:
            topologySpreadConstraints:
              - topologyKey:
                  exact: [topology.kubernetes.io/zone, kubernetes.io/hostname]
                whenUnsatisfiable: [DoNotSchedule, ScheduleAnyway]
                maxSkew:
                  min: 1
                  max: 3
                labelSelector:
                  required: true
                  requirements:
                    - key:
                        exact: [app]
                      operators: [In]
                      values:
                        exact: [checkout]
```

This allows zone or host spreading with a skew of 1–3 and a selector for
`app: checkout`. A constraint for another topology key, a skew of 4, or a selector
using another key is rejected. The rule constrains supplied entries; it does not
add a spread constraint or require one to be present.

### Affinity

All three affinity types use one flat list under `enforce.workloads.placement.affinity`.
Each matcher evaluates a complete required or preferred term from `spec.affinity`.

| Field | Applies to | Behavior |
|---|---|---|
| `types` | All | Select `nodeAffinity`, `podAffinity`, or `podAntiAffinity`. Omission selects all compatible types. |
| `modes` | All | Select `required`, `preferred`, or both. Omission selects both. |
| `weight` | Preferred terms | Inclusive `min` and `max` bounds within 1–100. Requires `modes: [preferred]`. |
| `requirements` | Node affinity | Match `matchExpressions` using key, values, and operators. |
| `fieldRequirements` | Node affinity | Match `matchFields` using the same requirement structure. |
| `topologyKey` | Pod affinity and anti-affinity | Topology-key expression. |
| `labelSelector` | Pod affinity and anti-affinity | [Selector policy](#selector-policies) for matching Pods. |
| `namespaceScope` | Pod affinity and anti-affinity | `SameNamespace` or `Any`. Omission imposes no scope restriction. |
| `namespaces` | Pod affinity and anti-affinity | Expression matched against every explicitly supplied namespace. |
| `namespaceSelector` | Pod affinity and anti-affinity | [Selector policy](#selector-policies) for matching namespaces. |

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
    - enforce:
        action: allow
        workloads:
          placement:
            affinity:
              - types: [nodeAffinity]
                modes: [required, preferred]
                requirements:
                  - key:
                      exact: [topology.kubernetes.io/zone]
                    operators: [In]
                    values:
                      exact: [zone-a, zone-b]
              - types: [podAffinity, podAntiAffinity]
                modes: [preferred]
                topologyKey:
                  exact: [kubernetes.io/hostname]
                namespaceScope: SameNamespace
                weight:
                  min: 1
                  max: 100
```

This allows node affinity using the listed zone requirements and preferred Pod
affinity or anti-affinity within the Pod's namespace, grouped by host. Required
Pod affinity and anti-affinity are rejected. The second matcher leaves Pod-label
selectors unrestricted; add `labelSelector` to constrain them.

Node requirements also support `Gt` and `Lt`. The value matcher checks the
literal numeric operand; it does not query node labels. When either node
requirement list constrains a term, requirements from the other source must be
explicitly allowed if present. For example, `fieldRequirements: [{}]` permits
any native-valid field requirement alongside constrained `requirements`.

`SameNamespace` permits an omitted `namespaces` list or explicit references to
the Pod's own namespace, and requires the Pod term's `namespaceSelector` to be
absent. Even `namespaceSelector: {}` selects more than the current namespace and
does not match this scope. `Any` leaves namespace scope unrestricted. A
`namespaces` expression alone does not restrict namespaces selected through a
`namespaceSelector`.

Type-specific fields only match types on which they are meaningful. Explicitly
incompatible combinations are rejected when the policy is saved. Matching
examines the submitted terms without listing nodes, Pods, or namespaces.


## Pod Disruption Budgets

Use `enforce.workloads.disruptionBudgets` to constrain PodDisruptionBudgets (PDBs)
covering selected workloads in a namespace. These policies can prevent overlapping
budgets, require room for voluntary disruption at the desired replica count, and
allow eviction of unhealthy Pods during maintenance.

The policies check existing PDBs; they do not create a PDB or require one to exist.

For example, require matching PDBs to leave room for at least one voluntary
eviction per Deployment or StatefulSet with a nonzero desired replica count.
This rule applies to every namespace in the Tenant:

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
    - enforce:
        action: allow
        workloads:
          targets: [deployment, statefulset]
          disruptionBudgets:
            evictableReplicas:
              min: 1
```

For three desired replicas, a PDB with `minAvailable: 2` passes, while
`minAvailable: 3` is rejected. This checks the configured allowance; actual
eviction still depends on workload health.

The [Reference](#reference) includes all three properties in the combined Tenant.
For maintenance scenarios, see [workload best practices](/docs/operating/best-practices/workloads/#pod-disruption).

The shared `workloads.targets` list selects the Pods and controller templates
whose PDBs are checked. Capsule also checks PDB writes that affect those workloads
in the same namespace. A controller need not have running Pods for its template
to be checked.

| Target | `allowOverlap` | `unhealthyPodEvictionPolicies` | `evictableReplicas` |
|---|---|---|---|
| Omitted or `pod` | ✅ Pod labels | ✅ PDBs selecting the Pod | ❌ |
| `deployment`, `statefulset`, `replicaset`, `replicationcontroller` | ✅ Template labels | ✅ PDBs selecting the template | ✅ Desired `spec.replicas`, including `/scale` |
| `daemonset`, `job`, `cronjob` | ✅ Template labels | ✅ PDBs selecting the template | ❌ No supported desired replica count |
| Container or volume part targets | ❌ | ❌ | ❌ |

Controller targets are explicit opt-ins. Include `pod` as well to check labels on
actual Pods, including those created by controllers. CronJobs use the Pod template
inside their Job template. Part targets such as `pod/containers` and
`deployment/containers` do not participate in PDB checks.

An `evictableReplicas` policy must explicitly select at least one of the four
supported controller targets. Other targets in the same rule still participate
in overlap and unhealthy-policy checks.

### Evictable replicas

`evictableReplicas.min` and `.max` define inclusive bounds on the configured
number of replicas that a PDB would allow to be evicted from a selected controller
at its desired size, assuming those replicas are healthy. Both bounds are
nonnegative integers. An omitted bound is unrestricted; for example, `min: 1`
requires room for at least one disruption without setting an upper limit.

Capsule calculates this allowance from the PDB and the controller's desired
`spec.replicas`:

| PDB size field | Configured allowance |
|---|---|
| Integer `minAvailable` | Desired replicas minus `minAvailable`, with a minimum of zero |
| Percentage `minAvailable` | Desired replicas minus the rounded-up percentage of desired replicas, with a minimum of zero |
| Integer `maxUnavailable` | `maxUnavailable`, capped at the desired replica count |
| Percentage `maxUnavailable` | Rounded-up percentage of desired replicas, capped at the desired replica count |
| Both size fields omitted | Zero |

Both percentage forms use [Kubernetes' upward rounding](https://kubernetes.io/docs/tasks/run-application/configure-pdb/#rounding-logic-when-specifying-percentages).
For an allow rule with `evictableReplicas.min: 1`:

| PDB configuration | Desired replicas | Allowance | Admission |
|---|---:|---:|---|
| `minAvailable: "75%"` | 3 | 0 | ❌ Rejected |
| `minAvailable: "75%"` | 4 | 1 | ✅ Allowed |
| `minAvailable: 2` | 3 | 1 | ✅ Allowed |
| `maxUnavailable: "25%"` | 1 | 1 | ✅ Allowed; the only replica can be evicted |
| `maxUnavailable: 0` | 4 | 0 | ❌ Rejected |

Replica changes are checked through both the controller resource and its `/scale`
subresource, including requests from `kubectl scale` and autoscalers. With the
first two rows above, scaling from four replicas down to three is rejected.

**Zero replicas are exempt from the replica-count check.** Scaling a controller
to zero remains possible. Scaling back above zero checks the resulting allowance.
Overlap and unhealthy-policy checks still apply to zero-replica templates.

Each matching PDB is checked against each selected controller independently.
Capsule does not add replicas from multiple controllers or calculate a combined
live PDB allowance. This can be stricter than Kubernetes for a PDB that covers
multiple workloads. The `max` bound applies to this per-controller calculation;
it does not cap aggregate live disruptions across multiple controllers. Use a PDB
selector that covers the complete intended controller rather than an arbitrary
subset of its Pods.

{{% alert title="Configured allowance and live eviction" color="info" %}}
These checks use desired replicas, not `status.disruptionsAllowed`. Pending,
unhealthy, missing or terminating Pods and rollout state can still prevent an
eviction. A compliant configuration does not guarantee that a drain will finish.
PDBs also do not limit direct Pod deletion or controller scale-down.
{{% /alert %}}

### Unhealthy Pods

`unhealthyPodEvictionPolicies` matches the effective value of the PDB's
`spec.unhealthyPodEvictionPolicy`:

| Value | Behavior for unhealthy Running Pods |
|---|---|
| `IfHealthyBudget` | Eviction requires the application's healthy Pod count to satisfy its budget. This is also the effective value when the PDB omits the field. |
| `AlwaysAllow` | Unhealthy Running Pods may be evicted even when the healthy budget is not satisfied. Healthy Pods still obey the PDB. |

An allow rule listing only `AlwaysAllow` rejects a matching PDB that omits this
field or sets `IfHealthyBudget`. Alternatively, a deny rule listing
`IfHealthyBudget` rejects that value, including omission. An omitted or empty
policy list adds no restriction. These rules validate the field; they do not
populate it. See [Kubernetes' unhealthy Pod eviction policies](https://kubernetes.io/docs/tasks/run-application/configure-pdb/#unhealthy-pod-eviction-policy)
for their effect during a drain.

### Overlap

`allowOverlap: false` requires at most one PDB to select each Pod or selected
controller template. Kubernetes accepts overlapping PDBs, but an eviction can
fail when more than one PDB selects the Pod. See [API-initiated eviction](https://kubernetes.io/docs/concepts/scheduling-eviction/api-eviction/#how-api-initiated-eviction-works).

Matching uses Pod or Pod-template labels and each PDB's `matchLabels` and
`matchExpressions` in the same namespace. With `policy/v1`, a null selector
matches no Pods, while an empty selector `{}` matches every Pod in the namespace.
An omitted `allowOverlap` field adds no constraint. A later allow rule with
`allowOverlap: true` can permit overlap, but it does not change Kubernetes'
eviction behavior.

For example, two PDBs selecting `app: frontend` can be created before any matching
Pod or selected controller template exists. Creating a matching workload is then
rejected. If the workload already exists, creating the second PDB is rejected
instead. Deleting a conflicting PDB or changing selectors to remove the overlap
allows subsequent writes.

### Evaluation

Checks run on both sides of the relationship:

| Request | PDB checks |
|---|---|
| Selected Pod creation or changed labels | Matching PDB overlap and unhealthy eviction policies; label changes through Pod `/status` are also checked |
| Selected controller creation or changed template labels | Matching PDB policies for that controller target |
| Supported controller replica change with an applicable `evictableReplicas` policy, including `/scale` | Resulting configured eviction allowance and the other applicable PDB policies |
| PDB creation or relevant spec change | Policies for existing selected Pods and controller templates that its selector matches |
| Unchanged relevant fields | No new PDB check |
| Deletion | Allowed by these policies, so a conflicting PDB can be removed |

A PDB with no matching selected workload can be created. The workload is checked
when it is later admitted, allowing either creation order without making PDB
existence a requirement.

Actions differ between numeric/boolean constraints and the list of policy values:

| Property | `allow` | `deny` | `audit` |
|---|---|---|---|
| `allowOverlap` and `evictableReplicas` | Requires compliance | Rejects violations | Reports violations |
| `unhealthyPodEvictionPolicies` | Accepts listed values | Rejects listed values | Reports listed values |

An omitted action defaults to `deny`. Normal [rule ordering](/docs/rules/#order-and-scope)
applies independently to each property: the last matching allow/deny decision
wins. Allowing one property does not bypass a failure of another. Audit rules
emit events without changing the admission decision. Omitted properties never
override an earlier rule.

[Namespace selection, audiences](/docs/rules/), and
[enforcement conditions](/docs/rules/#enforcement-conditions) use the usual rules
scope. Conditions inspect the actual incoming object: a PDB during a PDB write,
a controller during a controller write, and an `autoscaling/v1` Scale during a
`/scale` update. Include all relevant actors and write paths when using these
gates; a condition restricted to Pod creation does not protect controller, PDB,
or scale updates.

Changing a rule or namespace profile affects subsequent relevant admissions; it
does not repair existing PDBs or immediately revalidate stored workloads.
Concurrent PDB and workload writes can race because admission across separate
resources is not atomic. Monitor actual PDB status and workload health when
planning maintenance.

## Security

Configure `seccompProfiles` and `appArmorProfiles` under
`enforce.workloads.security`. The workload-level `targets` field selects the
Pod or container locations to check.

`seccompProfiles` and `appArmorProfiles` allow, deny, or audit profile choices
for Linux workloads. The [Seccomp](#seccomp) and [AppArmor](#apparmor) sections
below describe each mechanism and its local-profile matching. Use
[security mutations](/docs/rules/mutate/workloads/#security) to supply Pod
defaults before enforcement. These checks complement namespace Pod Security
labels; they skip Pods and templates declaring `spec.os.name: windows`.

Both matchers use these fields and the usual [rule order](/docs/rules/#order-and-scope):

| Field | Meaning |
|---|---|
| `types` | Required list of 1–3 entries containing `RuntimeDefault`, `Localhost`, or `Unconfined`. |
| `localhostProfiles` | Optional list of up to 64 `exact`, `exp`, and `negate` expressions for local profile paths or names. Requires `Localhost` in `types`. |

Each enforcement rule supports up to 64 `seccompProfiles` matchers and up to
64 `appArmorProfiles` matchers. Oversized lists are rejected when the policy
is saved, limiting nested matching work during workload admission.

Multiple matchers are alternatives. The expressions in `localhostProfiles`
constrain only Localhost; other types in the same matcher still match normally.
Omitting these expressions permits any non-empty Localhost path or name.
Audit reports matching admission choices through Capsule events; it does not
configure kernel syscall logging or AppArmor learning modes.

The shared [workload targets](#pod-targets) select where checks apply. Omitted
targets check effective profiles for regular, init, and ephemeral containers.
Explicit `pod` checks only the Pod default, so it does not prevent container
overrides. Controller targets inspect effective profiles in their templates,
including CronJobs' nested templates. Targeted templates must declare allowed
profiles themselves because profile mutation applies only to Pod creation.

Validation runs on Pod and controller create/update requests, and on
`pods/ephemeralcontainers` updates. It does not run on status, resize, or delete
requests and does not reconfigure existing containers. Policy changes apply
to subsequent admissions, so a previously admitted Pod may fail a later update
under a stricter policy.

### Seccomp

`enforce.workloads.security.seccompProfiles` evaluates a container's explicit
`securityContext.seccompProfile`, falling back to the Pod's
`spec.securityContext.seccompProfile`. Regular containers, init containers
(including restartable sidecars), and ephemeral containers use this resolution.
A Pod default is optional when every selected container declares an allowed
profile of its own.

| Effective type | What the matcher checks |
|---|---|
| `RuntimeDefault` | The workload selects the container runtime's default seccomp profile. |
| `Localhost` | The workload selects a local seccomp file. `localhostProfiles` matches its relative path. |
| `Unconfined` | The workload explicitly disables seccomp, or the selected container is privileged. |

Privileged containers are evaluated as Unconfined even if their manifest
names a different profile. When neither the container nor Pod supplies a
profile, Capsule evaluates it as `Unset`. An allow-list rejects this value;
Capsule does not infer the kubelet's seccomp default. `Unset` appears only in
diagnostics and cannot be listed in `types`. A deny rule for Unconfined alone
therefore permits an unset profile. Pair an allow-list with
[seccomp mutation](/docs/rules/mutate/workloads/#seccomp) when a declared
profile is required.

#### Match local seccomp paths

For Localhost, `localhostProfiles` matches the value of `localhostProfile`,
such as `profiles/solar.json`, relative to the kubelet's seccomp directory.
It does not match an absolute node path or inspect the file's contents.

This complete Tenant allows RuntimeDefault, the exact local path
`profiles/solar.json`, and files matching `^profiles/shared/[a-z0-9-]+\.json$`
in the selected namespaces. A local path outside those matches, Unconfined,
or an unset effective profile is denied. It does not add defaults; use
[seccomp mutation](/docs/rules/mutate/workloads/#seccomp) for that.

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
      enforce:
        action: allow
        workloads:
          security:
            seccompProfiles:
              - types: [RuntimeDefault, Localhost]
                localhostProfiles:
                  - exact: [profiles/solar.json]
                  - exp: '^profiles/shared/[a-z0-9-]+\.json$'
```

Admission checks the reference, while nodes apply the actual profile. Install
approved files on eligible nodes before use. See the
[Kubernetes seccomp tutorial](https://kubernetes.io/docs/tutorials/security/seccomp/).

### AppArmor

`enforce.workloads.security.appArmorProfiles` checks effective AppArmor profiles in this
order: the container's structured `securityContext.appArmorProfile`, a legacy
per-container AppArmor annotation, then the Pod's
`spec.securityContext.appArmorProfile`. This also covers init, restartable
sidecar, and ephemeral containers. A container override therefore remains
subject to enforcement even when the Pod default is allowed.

| Effective type | What the matcher checks |
|---|---|
| `RuntimeDefault` | The workload selects the container runtime's default AppArmor profile. |
| `Localhost` | The workload selects a loaded AppArmor profile. `localhostProfiles` matches its name. |
| `Unconfined` | The workload explicitly disables AppArmor, or the selected container is privileged. |

A missing effective profile is reported as `Unset` and fails an allow-list.
Capsule does not infer a runtime's implicit AppArmor behavior. A deny rule
matching only Unconfined permits an unset profile. Use
[AppArmor mutation](/docs/rules/mutate/workloads/#apparmor) with an allow-list
to require a declared profile. Privileged containers evaluate as Unconfined
regardless of the profile written in the manifest.

#### Match loaded AppArmor names

`localhostProfiles` matches a loaded profile name such as `solar-confined`.
The value is not the filesystem path where the AppArmor definition is stored.
For example, `exact: [solar-confined]` checks the name in `localhostProfile`;
`exp: '^solar-[a-z0-9-]+$'` would permit any matching name.

This complete Tenant allows RuntimeDefault and only the named local profile
in selected namespaces. Other Localhost names, Unconfined, and unset effective
profiles are rejected. It supplies no defaults by itself.

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
      enforce:
        action: allow
        workloads:
          security:
            appArmorProfiles:
              - types: [RuntimeDefault, Localhost]
                localhostProfiles:
                  - exact: [solar-confined]
```

Capsule does not verify that AppArmor is supported, that the named profile is
loaded, or that its contents are identical on all nodes. Configure eligible
nodes before using these profiles. See the
[Kubernetes AppArmor guide](https://kubernetes.io/docs/tutorials/security/apparmor/).

### Security reference

This complete Tenant defaults both profiles in selected namespaces. It allows
RuntimeDefault and one approved Localhost profile for each mechanism. The same
checks apply to explicitly targeted Deployment templates, which must supply
their own profile configuration. Apply this example only with eligible Linux
nodes supporting AppArmor and with the custom profiles installed before use.

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
              appArmorProfile:
                type: RuntimeDefault
      enforce:
        action: allow
        workloads:
          targets:
            - pod/containers
            - pod/initcontainers
            - pod/ephemeralcontainers
            - deployment
          security:
            seccompProfiles:
              - types: [RuntimeDefault, Localhost]
                localhostProfiles:
                  - exact: [profiles/solar.json]
            appArmorProfiles:
              - types: [RuntimeDefault, Localhost]
                localhostProfiles:
                  - exact: [solar-confined]
```

| Container choice | Result |
|---|---|
| No override; Pod default is RuntimeDefault | Allowed through inheritance. |
| Approved Localhost profile | Allowed and preserved by merge. |
| Unapproved Localhost profile | Denied. |
| Explicit Unconfined or privileged container | Denied. |
| No profile at either level in a targeted template | Denied. |
| Ephemeral container overriding the Pod default with Unconfined | Denied. |

## Registries

Registry enforcement allows administrators to allow, deny, or audit Pod image references. Registry matchers are evaluated against the full OCI reference string, including registry, repository path, image name, tag, or digest.

Registry rules are configured under `enforce.workloads.registries`. The shared [Workload targets](#workload-targets) field under `enforce.workloads.targets` selects image references in Pods or controller templates. See [Pod targets](#pod-targets) for container and image-volume scopes and examples.

Registry matchers use the common match expression structure:

```yaml
registries:
  - exact:
      - harbor/platform/debian:latest
      - harbor/platform/busybox:latest
  - exp: "harbor/platform/.*"
```

Use `exact` for a fixed list of complete references and `exp` for path or registry patterns. A single matcher may contain both fields:

```yaml
registries:
  - exact:
      - harbor/platform/debian:latest
    exp: "harbor/shared/.*"
```

This matcher succeeds for `harbor/platform/debian:latest` or any reference matching `harbor/shared/.*`.

The following example allows Harbor images by default, denies a more specific customer path for regular containers and image volumes, allows and audits regular container images from an audit registry, and allows a production image path only for namespaces matching `env=prod`:

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
        action: allow
        workloads:
          registries:
            - exp: "harbor/.*"

    - enforce:
        action: deny
        workloads:
          targets:
            - pod/containers
            - pod/volumes
          registries:
            - exp: "harbor/customer/.*"

    - enforce:
        action: allow
        workloads:
          targets:
            - pod/containers
          registries:
            - exp: "audit/.*"

    - enforce:
        action: audit
        workloads:
          targets:
            - pod/containers
          registries:
            - exp: "audit/.*"

    - namespaceSelector:
        matchExpressions:
          - key: env
            operator: In
            values: ["prod"]
      enforce:
        action: allow
        workloads:
          targets:
            - pod/containers
            - pod/volumes
          registries:
            - exp: "harbor/customer/prod-image/.*"
              policy: ["Always"]
```

Apply the following Pod in namespace `solar-test`, which does not match the `env=prod` selector:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: image-volume
spec:
  containers:
    - name: shell
      command: ["sleep", "infinity"]
      imagePullPolicy: IfNotPresent
      image: harbor/customer/test-image/debian:latest
      volumeMounts:
        - name: volume
          mountPath: /volume
  volumes:
    - name: volume
      image:
        reference: quay.io/crio/artifact:v2
        pullPolicy: IfNotPresent
```

The request is denied:

```bash
kubectl apply -f pod.yaml -n solar-test

Error from server (Forbidden): error when creating "pod.yaml": admission webhook "pods.projectcapsule.dev" denied the request: containers[0] reference "harbor/customer/test-image/debian:latest" is denied by registry rule "harbor/customer/.*"
```

The Pod is denied because the regular container image matches both `harbor/.*` and `harbor/customer/.*`. Since the deny rule is declared later, it has higher precedence.

The image volume reference is not denied by the shown deny rule because it does not match `harbor/customer/.*`. If the image volume used a matching reference, for example `harbor/customer/volume-artifact:v1`, the same deny rule would apply because it targets both `pod/containers` and `pod/volumes`.

In a namespace matching `env=prod`, the more specific production allow rule is also considered:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: prod-image
spec:
  containers:
    - name: shell
      command: ["sleep", "infinity"]
      imagePullPolicy: Always
      image: harbor/customer/prod-image/debian:latest
```

The request is allowed because the namespace-specific rule matches later and allows `harbor/customer/prod-image/.*` with `imagePullPolicy: Always`.

Target-specific registry rules allow different behavior for different parts of the same Pod. For example, this rule denies the registry only for init containers:

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
    - enforce:
        action: deny
        workloads:
          targets:
            - pod/initcontainers
          registries:
            - exp: "harbor/init-only/.*"
```

A matching reference under `spec.initContainers` is denied. The same reference under `spec.containers` is ignored by this rule.

### PullPolicy

Define the allowed image pull policies for a matching registry rule. Supported policies are:

* `Always`: The image is always pulled.
* `IfNotPresent`: The image is pulled only if it is not already present on the node.
* `Never`: The image is never pulled. If the image is not present on the node, the Pod fails to start.

The `policy` field is optional. If no policy is specified, all image pull policies are accepted for the matching registry rule.

To set the policy before validation, use
[`mutate[].workloads.registries.imagePullPolicy`](/docs/rules/mutate/workloads/#image-pull-policy).
The configured mutation must produce a policy accepted by the matching enforcement rule.

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
        action: allow
        workloads:
          targets:
            - pod/containers
          registries:
            - exp: "harbor/v2/customer-registry/.*"
              policy: ["IfNotPresent", "Always"]
```

If the final matching registry decision is `allow` and that matching registry rule defines `policy`, the Pod must use one of the configured pull policies. For example, this rule allows the registry but only with `Always`:

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
    - enforce:
        action: allow
        workloads:
          targets:
            - pod/containers
          registries:
            - exp: "harbor/v2/customer-registry/.*"
              policy: ["Always"]
```

A Pod using `imagePullPolicy: Never` for that registry is rejected:

```bash
Error from server (Forbidden): error when creating "pod.yaml": admission webhook "pods.projectcapsule.dev" denied the request: containers[0] reference "harbor/v2/customer-registry/debian:latest" uses pullPolicy=Never which is not allowed (allowed: Always)
```

Policy is checked only after the final registry decision is `allow`. A final `deny` decision always denies the request, regardless of the configured pull policy.

### Negation

A registry matcher can be negated with `negate: true`. Negation applies to the final result of the matcher, including both `exact` and `exp`.

For example, the following rule denies every regular container image that is not from the trusted registry path:

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
        action: deny
        workloads:
          targets:
            - pod/containers
          registries:
            - exp: "trusted/.*"
              negate: true
```

With this rule:

* `trusted/backend/api:1.0.0` is allowed in this deny-only example because it does not match the negated deny rule and no registry allow-list is configured.
* `docker.io/library/nginx:latest` is denied because it does not match `trusted/.*`, so the negated matcher evaluates to true.

Negation also applies to exact values:

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
    - enforce:
        action: deny
        workloads:
          targets:
            - pod/containers
          registries:
            - exact:
                - trusted/backend/api:1.0.0
                - trusted/frontend/web:1.0.0
              negate: true
```

This rule denies every explicit container image except the two exact references listed, as long as no separate registry allow-list requires an explicit allow. If an allow rule is configured for the same matcher scope, the excepted references must also match an allow rule.

You can combine exact values, regular expressions, negation, namespace selectors, and action precedence. For example, deny all untrusted container images by default, but allow a controlled exception in production namespaces:

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
    - enforce:
        action: deny
        workloads:
          targets:
            - pod/containers
          registries:
            - exact:
                - trusted/base/debian:latest
              exp: "trusted/platform/.*"
              negate: true

    - enforce:
        action: allow
        workloads:
          targets:
            - pod/containers
          registries:
            - exact:
                - trusted/base/debian:latest
              exp: "trusted/platform/.*"

    - namespaceSelector:
        matchLabels:
          env: prod
      enforce:
        action: allow
        workloads:
          targets:
            - pod/containers
          registries:
            - exp: "partner-registry/prod-approved/.*"
```

The second rule explicitly allows the trusted references that were excluded from the negated deny rule, which is required when registry allow-list behavior is active. In a namespace labeled `env=prod`, `partner-registry/prod-approved/app:1.0.0` is allowed because the later matching allow rule overrides the earlier negated deny rule.

### OCI Examples

#### Registry exact match examples

Use `exact` when you want to allow or deny a fixed set of complete image references:

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
    - enforce:
        action: allow
        workloads:
          targets:
            - pod/containers
          registries:
            - exact:
                - harbor/platform/debian:latest
                - harbor/platform/busybox:1.36
```

A Pod using `harbor/platform/debian:latest` or `harbor/platform/busybox:1.36` is admitted. A Pod using `harbor/platform/nginx:latest` is denied because an allow rule exists for registry enforcement but does not match that reference.

You can combine `exact` and `exp` in the same registry matcher:

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
    - enforce:
        action: allow
        workloads:
          registries:
            - exact:
                - harbor/platform/debian:latest
              exp: "harbor/shared/.*"
```

This rule allows the exact Debian image and any image under `harbor/shared/*`.

## Reference

This complete Tenant combines workload kind restrictions, resource policies,
image rules, QoS, all five placement policies, and PDB constraints. It applies
only to its namespaces labeled `example.com/profile: restricted`; other namespaces in the
Tenant keep their own profiles. Replace `solar-owner` with your owner identity.

The kind rule rejects DaemonSets. Resource, image, QoS, and placement policies
use Pod targets and run when Pods are admitted, including controller-created
Pods. The PDB rule also selects Deployment and StatefulSet templates, covering
PDB writes and replica changes. See [Workload targets](#workload-targets) to
expand the scope of individual policies.

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
    # Keep kind restrictions separate from property policies.
    - namespaceSelector:
        matchLabels:
          example.com/profile: restricted
      enforce:
        action: deny
        workloads:
          targets: [daemonset]
    # Manage resources on regular and init containers.
    - namespaceSelector:
        matchLabels:
          example.com/profile: restricted
      enforce:
        action: deny
        workloads:
          targets: [pod/containers, pod/initcontainers]
          resources:
            requests:
              cpu:
                policy: Default
                value: 100m
              memory:
                policy: Default
                value: 128Mi
            limits:
              cpu:
                policy: Remove
              memory:
                policy: Ratio
                value: "2"
    # Include the whole Pod for placement and its parts for image checks.
    - namespaceSelector:
        matchLabels:
          example.com/profile: restricted
      enforce:
        action: allow
        workloads:
          targets:
            - pod
            - pod/containers
            - pod/initcontainers
            - pod/ephemeralcontainers
            - pod/volumes
          registries:
            - exp: '^registry\.example\.com/solar/.+$'
              policy: [Always, IfNotPresent]
          qosClasses: [Burstable, Guaranteed]
          placement:
            schedulers:
              - exact: [default-scheduler, batch-scheduler]
            nodeSelector:
              - key: {exact: [kubernetes.io/os]}
                values: {exact: [linux]}
              - key: {exact: [infrastructure.example.com/pool]}
                values: {exact: [shared, batch]}
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
                      values: {exact: [solar]}
            affinity:
              - types: [nodeAffinity]
                modes: [required, preferred]
                requirements:
                  - key: {exact: [topology.kubernetes.io/zone]}
                    operators: [In]
                    values: {exact: [zone-a, zone-b]}
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
                      values: {exact: [solar]}
    # Keep selected workloads compatible with voluntary maintenance.
    - namespaceSelector:
        matchLabels:
          example.com/profile: restricted
      enforce:
        action: allow
        workloads:
          targets: [pod, deployment, statefulset]
          disruptionBudgets:
            allowOverlap: false
            evictableReplicas:
              min: 1
              max: 2
            unhealthyPodEvictionPolicies:
              - AlwaysAllow
    # Override the broader registry allow rule for this path.
    - namespaceSelector:
        matchLabels:
          example.com/profile: restricted
      enforce:
        action: deny
        workloads:
          registries:
            - exp: '^registry\.example\.com/solar/blocked/.+$'
    - namespaceSelector:
        matchLabels:
          example.com/profile: restricted
      enforce:
        action: audit
        workloads:
          registries:
            - exp: '^registry\.example\.com/solar/legacy/.+$'
```

With this configuration:

* DaemonSet creation and main-resource updates are denied in selected namespaces.
* On Pod creation, missing regular and init container requests default to `100m`
  CPU and `128Mi` memory. CPU limits are removed. Missing memory limits become
  twice the corresponding request; explicit limits above that ratio are denied.
  [Resource admission lifecycle](#admission-lifecycle) describes update behavior.
* Every selected image reference must use `registry.example.com/solar/` with an
  allowed pull policy. The later deny rule blocks the `solar/blocked/` path.
  Images under `solar/legacy/` are audited while the other checks still apply.
* The resulting Pod must have `Burstable` or `Guaranteed` QoS and use
  `default-scheduler` or `batch-scheduler`. A custom scheduler must already be
  installed to schedule Pods assigned to it.
* Supplied node selectors, tolerations, spread constraints, and affinity terms
  must match the configured shapes. These allow-lists do not require those
  properties to be present or populate them. Use
  [workload mutation](/docs/rules/mutate/workloads/#reference)
  to establish placement settings before enforcement.
* The toleration list includes common Kubernetes-injected entries. Add any
  additional tolerations required by your selected workloads or cluster.
* Matching PDBs must not overlap and must use `AlwaysAllow` for unhealthy Pod
  eviction. Each selected Deployment or StatefulSet must have one to two
  configured evictions available at its desired replica count when a PDB
  covers it; zero replicas are exempt. Remove `max: 2` if only a minimum is
  needed. These checks neither require a PDB nor guarantee live drain progress.
