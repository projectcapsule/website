---
title: Replications
weight: 6
aliases:
  - /docs/replications/triggers/
description: >
  Replicate resources across tenants or namespaces
---

Capsule provides two dedicated Custom Resource Definitions for propagating Kubernetes resources across Tenant Namespaces, covering both the cluster administrator and Tenant owner personas:

- **[GlobalTenantResource](./global/)**: cluster-scoped, managed by cluster administrators. Selects Tenants by label and replicates resources into all matching Tenant Namespaces.
- **[TenantResource](./tenant/)**: namespace-scoped, managed by Tenant owners. Replicates resources across the Namespaces within a single Tenant.

Both CRDs follow the same structure: resources are defined in `spec.resources` blocks, reconciled on a configurable `resyncPeriod`, and support [Go-template-based generators](/docs/operating/concepts/templating/) for dynamic resource creation.

Replications always run in a dedicated Deployment alongside the core controller.
Configure their pod resources, replicas and API request budget with the chart's
`controllers.replications` values; see
[controller workloads](/docs/operating/setup/installation/#controller-workloads).

## Resource watches

`TenantResource` and `GlobalTenantResource` support optional resource watch
triggers. Capsule observes persisted namespaced resources and requests
reconciliation when a matching object is added, updated, or deleted.

`spec.resources` continues to define resource behavior and destination namespace
profiles. Triggers control when reconciliation is requested. Replications without
triggers retain their existing behavior.

### Trigger example

This GlobalTenantResource refreshes a Secret summary when selected inputs change.
Its source namespaces and destination namespaces are selected independently.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: production-secret-summary
spec:
  scope: Namespace
  tenantSelector:
    matchLabels:
      environment: production
  resyncPeriod: 1h
  triggerMinInterval: 10s
  triggers:
    - name: secret-changes
      operations: [CREATE, UPDATE, DELETE]
      apiGroups: [""]
      apiVersions: [v1]
      resources: [secrets]
      namespaceSelector:
        matchLabels:
          environment: production
      objectSelector:
        matchExpressions:
          - key: example.com/summary-source
            operator: In
            values: ["true"]
      matchConditions:
        - name: content-changed
          expression: >-
            operation != 'UPDATE' ||
            has(object.data) != has(oldObject.data) ||
            (has(object.data) && object.data != oldObject.data)
  resources:
    - namespaceSelector:
        matchLabels:
          environment: production
      context:
        resources:
          - index: sources
            apiVersion: v1
            kind: Secret
            namespace: "{{namespace}}"
            selector:
              matchLabels:
                example.com/summary-source: "true"
      generators:
        - template: |
            apiVersion: v1
            kind: ConfigMap
            metadata:
              name: secret-summary
            data:
              count: '{{ if $.sources }}{{ len $.sources }}{{ else }}0{{ end }}'
```

For a TenantResource, omit `namespaceSelector` from the trigger. Its sources are
restricted to the namespace containing that TenantResource. This does not change
its replication destinations within the tenant.

For a GlobalTenantResource, the trigger `namespaceSelector` selects the namespaces
that provide events. `spec.tenantSelector` and each resource's `namespaceSelector` select
destinations. If source namespace metadata is unavailable or the namespace is
terminating, only triggers requiring namespace labels are skipped. Other triggers
without a namespace restriction remain eligible. Administrators can intentionally
select a shared source namespace
outside the destination tenants.

### Matching changes

Every trigger has a unique DNS label `name` and requires `operations`, `apiGroups`,
`apiVersions`, and `resources`.

| Field | Behavior |
| --- | --- |
| `operations` | `CREATE`, `UPDATE`, `DELETE`, or `"*"` for these three observed changes. |
| `apiGroups` | Explicit API groups; use `""` for core resources. |
| `apiVersions` | Explicit versions, such as `v1`. |
| `resources` | Explicit plural resource names, such as `configmaps`. Wildcards and subresource paths are unsupported. |
| `scope` | Optional; only `Namespaced` is accepted. Cluster-scoped resources cannot be watched by triggers. |
| `namespaceSelector` | Source namespace label selector; GlobalTenantResources only. |
| `objectSelector` | Label selector with `matchLabels` and `matchExpressions`; a match on either observed object qualifies. |
| `matchConditions` | Named boolean CEL expressions. All conditions in one trigger must match. Any matching trigger can notify the replication. |

Groups, versions, and resources form explicit combinations, with at most 16
combinations per trigger and eight entries per field. There are at most 32
triggers per replication and 60 conditions per trigger. Expressions are limited to
4096 bytes and have a runtime cost limit. Capsule validates expressions in its replication controllers and prepares immutable
programs when subscriptions change. An invalid specification reports `Ready=False`
with its error and current `observedGeneration`; correcting it lets reconciliation
resume. Validation results are reused for the unchanged resource generation,
including valid subscriptions omitted by preparation limits. Invalid specifications
do not schedule fast application retries. Trigger validation does not depend on
a policy-conversion webhook.

Only watchable top-level resources are supported. For example, a write through
`deployments/scale` can appear as an UPDATE of the watched Deployment, but watches
do not identify which subresource or API operation caused that change. An explicit
API version selects that version's watch; there is no admission equivalent-version
matching contract.

#### CEL inputs

Conditions can use:

| Variable | Value |
| --- | --- |
| `object` | The current observed object; null on DELETE. |
| `oldObject` | The previous observed object; null on CREATE. |
| `operation` | `CREATE`, `UPDATE`, or `DELETE`. |

Conditions describe observed state changes. They are not admission conditions.
Watches do not include the requesting user, groups, impersonation information, or
an admission `request` or `authorizer` value. The API schema rejects nonempty `audience` fields. CEL expressions using
admission-only variables produce a validation error in replication status. The shared
[audience model](/docs/operating/concepts/audiences/) remains available for namespace
rules.

Condition errors skip that trigger. Another matching trigger can still notify
the same replication. Namespace and resource selectors must also qualify.

### Managed resources and bookkeeping

Capsule-managed resources, including objects adopted or co-managed by
TenantResources or GlobalTenantResources, never trigger reconciliation. The filter
checks both observed states, management metadata, Capsule owner references, and
replication field managers. Removing a management marker does not make that
particular update eligible. The legacy `capsule.clastix.io/managed-by` assignment
label is not a management marker; tenants named `controller`, `resources`, and
`replications` remain eligible.

A watch can observe a new UID under an existing name after a relist. Capsule
treats this as DELETE for the previous object and CREATE for its replacement.
Selectors and management checks apply independently to each object.

Watches have no writer identity. To avoid feedback when a TenantResource watches
its own kind, Capsule ignores parent status, finalizer, and internal
reconciliation-token changes. Spec, label, non-Capsule owner-reference, and other
annotation changes remain eligible, including transitions that set
`deletionTimestamp`. Ownership changes remain subject to the managed-resource
exclusion above. Ordinary spec changes
already reconcile through the resource controller.

### Scheduling and recovery

`spec.triggerMinInterval` is shared across the triggers on one replication. Its
default is `10s`, with values from `1s` to `24h`.

The elected replica shares watch streams by resource/version, namespace scope, and
replication execution identity. A GlobalTenantResource can require a cluster-wide
stream; a TenantResource uses its own namespace. Streams belonging to different
execution identities are independent. A global impersonated stream does not
replace a local stream that may have different namespace-scoped permissions.
It queues matching targets through the existing asynchronous notification
mechanism. A short 250 ms window coalesces bursts; the first event does not wait
for the full interval. Events during a cooldown remain pending for a later
reconcile and do not continually postpone it. Shortening the interval shortens an
existing queued cooldown. Persisted attempt timing preserves the interval across
leadership changes.

Dependency, namespace, tenant and configuration changes, spec edits, deletion,
manual requests, and periodic resyncs retain their existing paths. Failed resource
reconciliation does not acknowledge the outstanding notification and retries at
a bounded interval.

Triggers are **best effort**. Initial paginated lists establish a baseline without
replaying every existing object as a CREATE. Changes during initial
synchronization, disconnection, leader replacement, or saturation can be missed or
coalesced. A relist restores the observed state, not a complete audit history.
Keep `resyncPeriod` as the recovery mechanism. A replication's Ready condition
reports resource application and, when enabled, [health checks](#health-checks).
It does not assert watch synchronization.

The notification queue is bounded to 4096 targets. The watch event queue is bounded
to 256 events and 8 MiB of accounted object memory, including in-flight work,
with two workers and a 100 ms processing deadline per event. Excess
or expired work is skipped and periodic reconciliation provides recovery. Up to
64 watch streams across all resource/version and namespace combinations,
4096 prepared replications, 8192 condition references, and validation results for
up to 4096 additional replication generations are retained per leader. Prepared
subscriptions supply their own validation result. Results contain no source data
or condition programs and are retired on preparation, deletion, or a newer generation.
Beyond the validation-result bound, omitted subscriptions still validate on each
reconcile; periodic resource application remains active.
Preparation and stream opportunities are shared round-robin by the owning Tenant.
GlobalTenantResources and resources outside Tenant namespaces share a separate
system group. Namespace ownership uses Tenant owner-reference UID checks. When
all tenants cannot fit, priority rotates on the 30-second planning refresh;
ordinary events do not continually replace healthy streams. Multiple identities
or large subscriptions in one tenant cannot reserve every opportunity ahead of
another tenant. The limits apply to planning candidates, so invalid resources or
forbidden LIST/WATCH requests cannot force unbounded discovery or stream initialization.
Within a tenant, sources and stream candidates retain deterministic ordering.

Valid subscriptions omitted by discovery or capacity limits are reported in logs
and metrics and rely on periodic reconciliation. Invalid trigger specifications
report `Ready=False` and stop replication until corrected.

### Watch permissions and performance

Source LIST/WATCH requests run under the same execution identity as replication:
`spec.serviceAccount`, the configured default ServiceAccount, or the controller
identity when impersonation is explicitly not configured. That identity needs
`list` and `watch` access to the selected resource and namespace scope. A global
stream requires cluster-wide access; a local stream needs access only within its
namespace scope. A `get` alone cannot establish a watch.

Object selectors and CEL only receive objects read by that execution identity.
A privileged stream or a stream for another ServiceAccount cannot supply data to an
unprivileged subscription, including through observable trigger tokens. Identity
or impersonation-transport changes retire the old streams and exclude stale
queued events. Each stream uses the endpoint and TLS settings captured for its
execution identity throughout its lifetime. Missing permissions and client-construction errors retry without
falling back to controller credentials. Replication Ready reports application
and validation status; it does not assert that source watches are authorized.
Kubernetes authorizes LIST/WATCH requests using its normal watch semantics.
The controller still reads subscription and namespace metadata for selection.
These background failures cannot block Kubernetes writes.

Capsule checks the selected CA bundle during its 30-second watch-planning refresh.
Updating the referenced Secret's CA data replaces affected streams; unrelated
metadata or data keys do not restart them. A missing Secret or CA key stops those
streams until it is restored. An explicitly configured CA Secret with empty CA
data also stops affected watches; it cannot fall back to system trust. Explicit
`skipTLSVerify` retains its configured behavior. Trust rotation does not require
editing the replication or CapsuleConfiguration. Cached impersonated replication
clients also check the current transport and CA contents on each load, so template
reads and resource applies recover with the source watch. A changed trust snapshot
replaces the cached client for that ServiceAccount; it does not reuse the older transport
or fall back to the controller identity.

Each stream retains at most 1024 object snapshots and 1 MiB of accounted memory.
Across 64 streams, the snapshot budget is at most 64 MiB. Accounting includes
strings, maps, slices, metadata, and bookkeeping; it is not the serialized object
size or an exact measure of process memory. Objects whose accounted size exceeds
512 KiB are skipped. Streams never share object contents across execution identities.

Capsule consumes LIST responses a page at a time, with at most two pages being
decoded concurrently. Pages request 32 objects; responses exceeding 4 MiB retry
with smaller pages. Each page has a 15-second deadline. A baseline stops after
2048 objects, 4 MiB of accounted objects, or 64 pages and then watches from that
snapshot's resource version. It does not accumulate the entire resource collection.

An UPDATE without a retained previous snapshot is skipped and warms that object's
snapshot for a later change. Capsule does not invent a CREATE or set `oldObject`
to null for that UPDATE. A partial relist cannot infer deletions outside its
baseline. Keep `resyncPeriod` short enough to recover changes to cold or oversized
inputs, including objects that change only once between evictions. Resource
application and template reads still run periodically for those inputs.

Share resource types between subscriptions and avoid watching noisy types unless
their changes are needed. Matching uses indexed subscription lookups and prepared
selectors/programs rather than scanning all replications or compiling conditions
for every event.

There is no trigger admission webhook, delivery endpoint, or signing Secret.
Dry-run and rejected writes do not persist changes and therefore produce no watch
notification. Existing Capsule admission checks, including managed-resource
protection, retain their behavior.

### Observe triggers

The `projectcapsule.dev/replication-trigger` annotation identifies queued internal
work. The API status records:

- `status.trigger.lastTriggeredAt`: start of the last triggered attempt.
- `status.trigger.observedRequest`: last notification handled by a completed
  attempt. A notification arriving during reconciliation is not acknowledged by
  the older attempt.
- `status.nextResyncAt`: earliest outstanding periodic recovery deadline; a trigger
  does not postpone it.

The existing Ready condition and processed-item status report application errors.
Metrics use bounded labels:

- `capsule_replication_trigger_notifications_total`: `queued`, `saturated`, `retry`.
- `capsule_replication_trigger_watches`: active watch streams on this replica,
  including streams still initializing or retrying.
- `capsule_replication_trigger_watches_omitted`: subscriptions or resources omitted
  by validation, discovery, or capacity limits.
- `capsule_replication_trigger_events_total`: `queued`, `dropped`, `watch-error`,
  `condition-error`, `unprepared`, `timed-out`, `baseline-limited`,
  `object-too-large`, and `old-object-unavailable`.
- `capsule_replication_trigger_snapshot_bytes`: accounted snapshot memory.
- `capsule_replication_trigger_queued_bytes`: accounted memory in queued and
  processing events.

## Health checks

[TenantResources](/docs/replications/tenant/) and
[GlobalTenantResources](/docs/replications/global/) can wait for their applied
resources to become healthy. Set `spec.healthChecks.wait: true` to require both
successful application and successful health checks across all selected
destinations before reporting `Ready=True`.

With `healthChecks` omitted or `healthChecks.wait` false, readiness keeps its
existing meaning: resources were successfully applied. Capsule performs no
health-check reads in this mode.
Namespace and tenant selectors continue to determine where resources are applied.

### Enable health checks

This TenantResource creates a Deployment in each namespace of its tenant labelled
`projectcapsule.dev/profile: application`, then waits for the rollouts to complete:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: health-example
  namespace: wind-system
spec:
  serviceAccount:
    name: tenant-replicator
  healthChecks:
    wait: true
    timeout: 5m
  resyncPeriod: 10m
  resources:
    - namespaceSelector:
        matchLabels:
          projectcapsule.dev/profile: application
      rawItems:
        - apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: health-example
          spec:
            replicas: 1
            selector:
              matchLabels:
                projectcapsule.dev/app: health-example
            template:
              metadata:
                labels:
                  projectcapsule.dev/app: health-example
              spec:
                containers:
                  - name: workload
                    image: registry.k8s.io/pause:3.10.1
```

The tenant, source namespace and ServiceAccount must already exist. Grant the
ServiceAccount the existing replication permissions and the target read access
described under [Health-check permissions](#health-check-permissions).

The same `healthChecks` block works on a GlobalTenantResource. Keep its `scope`,
`tenantSelector` and resource namespace selectors configured for the intended
destinations. An explicit `serviceAccount`
reference on a GlobalTenantResource includes both its name and namespace.

| Field | Behavior |
| --- | --- |
| `healthChecks.wait` | Defaults to `false`. When `true`, checks all successfully applied targets before reporting readiness. |
| `healthChecks.timeout` | Time allowed for an incomplete health assessment. Defaults to `5m`; must be positive and at most `1h`. |
| `healthChecks.expressions` | Optional custom CEL checks for specific API groups and kinds. Requires `healthChecks.wait: true`; ignored when waiting is disabled. |

Capsule finishes applying and pruning the selected resources before starting the
health phase. It uses Flux's kstatus evaluation for kinds without a custom check.
This includes rollout checks for supported workloads such as Deployments.
Resources without a recognized readiness signal can be considered current as
soon as they exist. Define a custom check when a resource's own controller exposes
readiness differently.

Only targets successfully applied by this replication participate. Objects skipped
by a resource block's conditional-apply policy do not introduce a health check for
that skipped application. If no targets are selected, a successful application
has no health checks to wait for.

### Custom health expressions

Use `healthChecks.expressions` to define readiness for a custom resource. For
example, suppose a `Workload` custom resource reports `Pending`, `Progressing`, `Failed` or
`Ready` in `status.phase`:

```yaml
spec:
  healthChecks:
    wait: true
    timeout: 3m
    expressions:
      - apiVersion: workloads.projectcapsule.dev/v1
        kind: Workload
        inProgress: >-
          !has(object.status) || !has(object.status.phase) ||
          object.status.phase in ['Pending', 'Progressing']
        failed: >-
          has(object.status) && has(object.status.phase) &&
          object.status.phase == 'Failed'
        current: >-
          has(object.status) && has(object.status.phase) &&
          object.status.phase == 'Ready'
```

Each entry replaces the default check for that API **group and kind**. The version
in `apiVersion` is ignored when matching targets, so the example also matches
other served versions of the same Workload kind. Duplicate entries for the same
group and kind are rejected. Use `apiVersion: v1` for a core API kind.

Checks run in this order, stopping at the first expression that returns `true`:

1. `inProgress`: the target is still progressing.
2. `failed`: the target has failed.
3. `current`: the target is healthy.

`current` is required; `inProgress` and `failed` are optional. If none returns
`true`, the target remains in progress. All expressions must return a boolean.
There can be at most 32 entries, with at most 4096 characters per expression.
Invalid expressions report an application error before any resources are applied.

Expressions receive the persisted target object:

| Variable | Value |
| --- | --- |
| `object` | The complete target object. |
| `apiVersion`, `kind`, `metadata`, `spec`, `status` | Aliases for the corresponding top-level target fields, when present. |

Admission request variables, users, audiences, `oldObject`, `operation` and
`authorizer` are unavailable. Guard optional fields with `has(object.status)` and
similar checks: a missing field can otherwise cause an evaluation error.
Evaluation errors keep the replication unready and are retried until the target
recovers or the health timeout is reported.

Capsule also checks that each target still has the applied UID and generation.
When present, `status.observedGeneration` and a successful Ready condition's
`observedGeneration` must match the target generation. A custom expression cannot
make an older rollout satisfy these checks.

### Readiness, timeouts and dependencies

With waiting enabled, inspect the `Healthy` and `Ready` conditions:

| Healthy condition | Meaning |
| --- | --- |
| `Unknown`, reason `HealthChecking` | Applied targets are still progressing or the current scan is incomplete. |
| `Unknown`, reason `HealthCheckError` | The health execution client or check preparation failed. The message identifies the error. |
| `True`, reason `Succeeded` | All applied targets are healthy; the replication can report `Ready=True`. |
| `False`, reason `HealthCheckFailed` | A target reported a failed state. |
| `False`, reason `HealthCheckTimeout` | Targets have not become healthy before the deadline. |

`Ready` remains false while application fails, health is pending, or health fails.
An application error can also leave `Healthy=Unknown` with reason
`ApplicationIncomplete`. Conditions report their `observedGeneration`; after
editing a replication, compare this with `metadata.generation` before relying on
readiness from a previous revision.

```bash
kubectl get tenantresource health-example -n wind-system -o yaml
kubectl wait tenantresource/health-example -n wind-system \
  --for=condition=Ready --timeout=6m
```

For a GlobalTenantResource, use `globaltenantresource` and omit the `-n` flag.
`kubectl wait` tests the condition currently stored on the object; check generation
freshness separately when waiting immediately after an update.

The timeout starts after a successful application. Its deadline is stored in
`status.health`, so retries, controller restarts and leader changes retain it.
An unchanged application while health is pending does not extend the deadline.
A new source generation, changed applied content or changed target identity
starts a new assessment. A completed healthy assessment can also be checked again
after a subsequent application.

Failures and timeouts do not roll back or delete successfully applied resources.
Capsule continues health checks and can recover to `Healthy=True` without applying
the resources again. Once all targets are healthy, polling stops until another
application requests an assessment. Use `resyncPeriod` and
[resource watches](/docs/replications/#resource-watches) to control further applications.

Existing `dependsOn` references honor the dependency's readiness. If a dependency
uses `healthChecks.wait: true`, dependents wait for its successful application
and health checks for the current source generation. Dependencies that do not enable waiting keep
their existing apply-only readiness behavior.

### Health-check metrics

The replication controller exposes the `Healthy` condition through the existing
condition gauges:

```promql
capsule_resource_condition{condition="Healthy",name="health-example",target_namespace="wind-system"} 1
capsule_global_resource_condition{condition="Healthy",name="health-example-global"} 1
```

The value is `1` for `Healthy=True` and `0` for `False` or `Unknown`, including
failed checks, timeouts and checks still in progress. Inspect the object's
conditions to distinguish those states and read their reasons. For TenantResources,
`target_namespace` identifies the namespace containing the TenantResource.

The series is absent when there is no Healthy condition. Disabling
`healthChecks.wait` removes it after reconciliation; deleting the replication
removes all its condition
series. Other replications keep their own metrics.

Scrape these gauges from the replication controller's metrics endpoint. Health-only
observations update them after publishing status, without waiting for the next
resource application. `Ready` and `Cordoned` keep their existing metric names and
labels. Existing alerts on `Ready` also reflect health failures when waiting is
enabled.

The chart's default Prometheus rule list includes
`CapsuleGlobalTenantResourceNotHealthy` and `CapsuleTenantResourceNotHealthy`.
Each raises a warning when its `Healthy` gauge remains `0` for ten minutes.
Healthy resources and replications without a Healthy condition do not match.
Because `False` and `Unknown` both map to `0`, prolonged pending checks also match;
adjust the rule's `for` duration if normal rollouts can take longer.

With the Prometheus Operator installed, enable the existing chart settings to
scrape both controller workloads and install the default alert rules:

```yaml
monitoring:
  serviceMonitor:
    enabled: true
  prometheusRules:
    enabled: true
```

### Health-check permissions

Health checks read targets using the **same execution identity as replication**:
the explicit `spec.serviceAccount`, the configured default ServiceAccount, or the
controller identity when impersonation is not configured. See the
[TenantResource](/docs/replications/tenant/#impersonation) and
[GlobalTenantResource](/docs/replications/global/#impersonation) impersonation
settings.

Review existing Roles and ClusterRoles before enabling health checks or resource
watches. These features need different read verbs:

| Operation | Permission on the execution ServiceAccount |
| --- | --- |
| Health checks | `get` on every applied target's main resource, in every destination namespace or cluster scope where it is applied. |
| Resource-watch triggers | `list` and `watch` on the selected source resource and namespace scope; see [watch permissions](/docs/replications/#watch-permissions-and-performance). |
| Replication and template reads | Existing apply, cleanup and input-read permissions still apply; health checks do not replace them. |

A normal `get` returns the object's status too. Health checks do not require
`get` on `deployments/status`, permission to update status, or additional
`list`/`watch` permissions. If the ServiceAccount already has `get` on every target,
health checks require no new verb. Resource watches may still require adding
`list` and `watch` to existing read permissions.

For example, this **additional read-only grant** lets the example's existing
`wind-system/tenant-replicator` ServiceAccount check its Deployment in `wind-test`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: replication-health-reader
  namespace: wind-test
rules:
  - apiGroups: [apps]
    resources: [deployments]
    resourceNames: [health-example]
    verbs: [get]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: replication-health-reader
  namespace: wind-test
subjects:
  - kind: ServiceAccount
    name: tenant-replicator
    namespace: wind-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: replication-health-reader
```

This supplements the permissions needed to create, apply and clean up the
Deployment. Grant the corresponding read access in every selected destination.
For multiple namespaces, a reusable ClusterRole with a RoleBinding in each
destination can keep the grant scoped. Cluster-scoped targets need an appropriate
ClusterRoleBinding.

An administrator allowed to impersonate the ServiceAccount can verify the grant:

```bash
kubectl auth can-i get deployments.apps/health-example -n wind-test \
  --as=system:serviceaccount:wind-system:tenant-replicator
```

Missing read access leaves the replication unready; the health condition reports
the permission error and eventually the timeout if access is not restored.
Capsule retries with the same identity and does not fall back to controller
credentials. The `status.serviceAccount` field identifies the execution account.

### Scheduling and scale

Health checks run in the background replication controller, with a queue separate
from resource application. Pending checks normally poll every five seconds in
batches of at most 64 target reads. Larger inventories continue across batches.
Choose a timeout that covers both rollout time and the time needed to observe
all selected targets under your API-server limits.

Health retries do not render templates or apply resources, and
`triggerMinInterval` does not delay them. These checks do not introduce an admission
webhook or block Kubernetes writes. Existing managed-resource protection remains
in effect.

## Per-resource policies

Each `spec.resources[]` block accepts a resource policy in both replication APIs.
The policy applies to every `rawItems`, `namespacedItems`, and `generators` result
in that block. These are the defaults:

```yaml
spec:
  resources:
    - policy:
        creation: Owner
        force: false
        protect: true
        deletion: Remove
      rawItems:
        - apiVersion: v1
          kind: ConfigMap
          metadata:
            name: namespace-profile
          data:
            environment: production
```

An optional `policy.condition` gates content apply for each destination using CEL.
A false condition keeps existing content while policy updates still reconcile on
managed targets. See the [shared policy reference](/docs/operating/concepts/managed-resources/)
for ownership, protection, cleanup, conditions, and status, and the
[age-key rotation example](./global/#conditional-age-key-rotation) for recurring
updates that retain old data.

## Deprecated settings and migration

`spec.settings.adopt`, `spec.settings.force`, and `spec.pruningOnDelete` remain
accepted for compatibility but are deprecated. The `replicationDefaults` admission
hook converts them on create and update, adding a policy only to blocks that do not
already have one:

| Deprecated setting | Per-resource policy |
| --- | --- |
| `settings.adopt: true` | `creation: Merge` |
| `settings.adopt: false` or omitted | `creation: Owner` |
| `settings.force` | `force`, defaulting to `false` |
| `pruningOnDelete: false` | `deletion: Orphan` |
| `pruningOnDelete: true` or omitted | `deletion: Remove` |

Conversion uses the shared `protect: true` default, including adopted resources.
Set `protect: false` explicitly when another actor must modify a managed target.
The deprecated fields remain on the object; conversion does not remove them.

An explicit policy replaces the deprecated settings for its entire block. After
conversion, change `spec.resources[].policy` to update behavior: changing the old
settings does not overwrite an existing policy. Defaults fill omitted fields in an
explicit policy rather than inheriting those fields from `spec.settings`.

Stored objects that have not passed through admission again keep a runtime fallback
to their legacy settings, including legacy protection and pruning behavior. Their
missing policies are converted the next time they are admitted. Cleanup uses the
last successfully reconciled policy even after a block or its parent is removed.
