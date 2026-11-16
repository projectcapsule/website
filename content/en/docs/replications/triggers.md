---
title: Resource watches
weight: 3
description: >
  Reconcile TenantResources and GlobalTenantResources when source objects change.
---

`TenantResource` and `GlobalTenantResource` support optional resource watch
triggers. Capsule observes persisted namespaced resources and requests
reconciliation when a matching object is added, updated, or deleted.

`spec.resources` continues to define resource behavior and destination namespace
profiles. Triggers control when reconciliation is requested. Replications without
triggers retain their existing behavior.

## Example

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

A GlobalTenantResource's trigger `namespaceSelector` selects **event source
namespaces**. `spec.tenantSelector` and each resource's `namespaceSelector` select
destinations. If source namespace metadata is unavailable or the namespace is
terminating, only triggers requiring namespace labels are skipped. Other triggers
without a namespace restriction remain eligible. Administrators can intentionally
select a shared source namespace
outside the destination tenants.

## Matching changes

Every trigger has a unique DNS-label `name` and requires `operations`, `apiGroups`,
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

### CEL inputs

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

## Managed resources and bookkeeping

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

## Scheduling and recovery

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
reports resource application, not watch synchronization.

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

## Permissions and performance

Source LIST/WATCH requests run under the same execution identity as replication:
`spec.serviceAccount`, the configured default ServiceAccount, or the controller
identity when impersonation is explicitly unconfigured. That identity needs
`list` and `watch` access to the selected resource and namespace scope. A global
stream requires cluster-wide access; a local stream needs access only in its
namespace. `get` access alone cannot establish a watch.

Object selectors and CEL only receive objects read by that execution identity.
A privileged stream or another ServiceAccount's stream cannot supply data to an
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
replaces that ServiceAccount's cached client; it does not reuse the older transport
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

## Observe triggers

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
