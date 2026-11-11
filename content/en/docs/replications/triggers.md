---
title: Admission triggers
weight: 3
description: >
  Reconcile TenantResources and GlobalTenantResources when source objects change.
---

`TenantResource` and `GlobalTenantResource` support optional admission triggers.
Triggers request reconciliation when a matching namespaced resource is created,
updated, or deleted. This is useful when templates or replicated items depend on
objects that can change between periodic reconciliations.

The resource behavior and destination namespace profiles remain defined in
`spec.resources`. Triggers only control when Capsule requests reconciliation.
Existing replications without triggers retain their behavior.

## Example

This GlobalTenantResource generates a count of selected Secrets in production
namespaces. A matching Secret write requests a refresh without waiting for the
hourly resync.

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
      audience:
        - kind: Custom
          name: CapsuleUser
        - kind: Custom
          name: Administrator
      matchConditions:
        - name: content-changed
          expression: >-
            request.operation != 'UPDATE' ||
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

For a TenantResource, use the same trigger fields except `namespaceSelector`.
Its triggers observe only the namespace containing the TenantResource. This does
not change its existing replication destinations within the tenant.

A GlobalTenantResource trigger's `namespaceSelector` selects **event source
namespaces**. `spec.tenantSelector` and each `spec.resources[].namespaceSelector`
continue to select replication destinations. A privileged GlobalTenantResource can
observe a shared source namespace outside its destination tenants.

## Matching requests

Each trigger must have a unique DNS-label `name` and specify `operations`,
`apiGroups`, `apiVersions`, and `resources`. It supports:

| Field | Behavior |
| --- | --- |
| `operations` | `CREATE`, `UPDATE`, `DELETE`, or `"*"` for these three operations. `CONNECT` is unsupported. |
| `apiGroups`, `apiVersions`, `resources` | Kubernetes admission resource matching, including resource wildcards and subresources. Matching uses equivalent API versions. |
| `scope` | Optional; only `Namespaced` is accepted. Cluster-scoped events are unsupported. |
| `namespaceSelector` | Label selector on event source namespaces; available only on GlobalTenantResources. |
| `objectSelector` | Label selector with `matchLabels` and `matchExpressions`. A match on either the old or new object qualifies. |
| `matchConditions` | Native admission CEL conditions. Every condition must evaluate to true. |
| `audience` | The request identities eligible to trigger reconciliation, using the [shared audience model](/docs/operating/concepts/audiences/). |

Overlapping resource wildcards are rejected before registration, so malformed
triggers cannot block updates to the shared webhook configuration.

Resource matching, selectors, conditions, and audience must all qualify. CEL
conditions have the native admission variables, including `object`, `oldObject`,
`request`, and `authorizer`. Account for a null `oldObject` on CREATE and a null
`object` on DELETE. Condition evaluation errors skip the notification because the
notification webhook uses `failurePolicy: Ignore`.

There are at most 32 triggers per replication. Each trigger accepts up to 64
audience entries and 60 named match conditions. Each condition expression is
limited to 4096 bytes. Names starting with `capsule-trigger-` are reserved for
Capsule's built-in conditions.

## Audience

Triggers use the shared [audience model](/docs/operating/concepts/audiences/).
See that reference for matching semantics, standard and custom kinds, and request
identity.

For `TenantOwner`, Capsule checks the tenant owning the **event source
namespace**. For a GlobalTenantResource this can differ from the replication
destination tenants. A source namespace without a tenant does not match
`TenantOwner`. The audience does not expand replication destinations.

Capsule evaluates the audience inside the notification webhook after the API
server's native filters match. A mismatch skips notification and does not reject
the original write.

Triggers use `audience` instead of the older admission `opts` properties. Existing
admission configuration continues to support its existing options.

## Managed resources never trigger reconciliation

Capsule-managed resources and objects managed by TenantResources or
GlobalTenantResources are ineligible, including adopted or co-managed objects.
Capsule checks current and legacy management metadata and replication ownership
markers. The legacy `capsule.clastix.io/managed-by` tenant-assignment label is
not a management marker; tenants named `controller`, `resources`, or
`replications` remain eligible. This exclusion also applies to the
[`Controller` audience](/docs/operating/concepts/audiences/#custom-audiences).

On UPDATE, management on either the old or new object excludes the request, so
removing a marker in an update cannot make that update eligible. On DELETE, the
old object is checked. The exclusion is mandatory and cannot be overridden by an
object selector or match condition.

Controller updates to TenantResource and GlobalTenantResource objects are also
excluded, including notification patches and status writes. User edits to these
objects remain eligible. This prevents a replication subscribing to its own kind
from repeatedly triggering itself.

## Authenticated delivery

Capsule authenticates trigger deliveries before decoding the admission review or
looking up subscriptions. Each native predicate has a signed, unpredictable
capability in its webhook URL path. An unsigned request or an invalid capability
receives HTTP 401 and cannot enqueue reconciliation, even if it supplies a forged
request identity or namespace. The API server obtains the capability from the
ValidatingWebhookConfiguration; no API-server client-certificate configuration is
required. Native selectors and CEL still run in the API server, and Capsule checks
the audience after authenticated delivery.

All controller replicas reuse one immutable Secret named
`capsule-trigger-delivery-<hash>` in the controller namespace, owned by the active
CapsuleConfiguration. The signing key stays in that Secret. Published capabilities
are specific to their native predicate. Treat readers of this Secret,
ValidatingWebhookConfigurations, and API-server or proxy logs containing webhook
URLs as trusted delivery-credential readers. Tenant owners must not receive those
permissions. Capsule removes capabilities before its own handler tracing.
Use cluster network controls to restrict tenant access to the webhook service as
an additional layer, accounting for your control-plane networking and CNI.

If Capsule cannot initialize the credential, it logs the error, rejects trigger
deliveries, and omits trigger registrations. Existing admission enforcement and
periodic reconciliation remain enabled. Fix the controller's Secret permissions
or credential ownership and restart the affected controller replicas to enable
delivery.

The key survives controller restarts and certificate renewals. To rotate it,
coordinate replacement of the immutable Secret with a restart of all controller
replicas. Deliveries during a key transition can be missed; periodic reconciliation
provides recovery. Invalid or unavailable delivery still follows the notification
webhook's fail-open policy and cannot reject the original Kubernetes write.

For subresource requests such as `deployments/scale`, selectors and CEL see the
admission projection (for example, a `Scale` object). Capsule also reads the named
parent to check its management metadata before notifying any matching replication.
A managed parent, a changed parent UID, or a failed parent lookup skips the
notification and does not reject the original write. Subscriptions are removed
from native webhook registration when deletion starts, even if finalizers keep the
replication object present.

## Scheduling and delivery

`spec.triggerMinInterval` is shared across all triggers on one replication. It
defaults to `10s` and accepts durations between `1s` and `24h`.

The first eligible event can request reconciliation without waiting for this
interval. Notifications have a short asynchronous settling delay and are
coalesced before Capsule writes a reconciliation request. Events received during
the interval remain pending for one later reconciliation; later events do not
continually postpone that pending work. An event received during reconciliation
is not acknowledged by the older reconciliation.

The dispatcher checks persisted attempt timing and handled notification identity
before issuing a notification, so the interval is shared across webhook replicas
and survives controller leadership changes. It keeps one unacknowledged
notification per resource; later events remain queued until that notification is
handled and the interval permits another. Shortening `triggerMinInterval` also
shortens an existing queued cooldown.

Cooldowns apply only to trigger notifications. Dependency recovery, namespace and
tenant events, configuration changes, spec updates, deletion, manual requests, and
periodic resyncs retain their existing reconciliation paths. Trigger-enabled
replications retry failed reconciliation at a bounded interval, including transient failures during initial resource creation.

Triggers are **best effort**. Admission observes a write attempt before storage
commit, and a later admission step or storage conflict can still reject it. A
reconciliation can therefore read the previous state. Notifications can also be
missed during restarts, webhook failures, or queue saturation. Keep a suitable
`resyncPeriod` as the recovery mechanism; a very long period increases recovery
time for missed events.

For authenticated API-server requests, the notification webhook returns an allow
response. It uses
`failurePolicy: Ignore`, a two-second timeout, and `sideEffects: NoneOnDryRun`.
An unavailable notification webhook can delay a request up to this timeout, but
its failure does not reject the write. Other admission webhooks retain their own
validation and failure policies.

Dry-run requests never enqueue notifications. The admission handler performs
cached, indexed lookups and does not write to the API server synchronously.
Identical native matching configurations share webhook registrations, and all
matching notifications for a target share its interval.

Capsule retains at most 128 distinct native trigger groups within a 512 KiB
trigger-registration budget. The combined webhook payload is limited to 1 MiB
for this calculation, with existing enforcement registrations taking priority.
A group can serve many replications with identical native matching predicates;
audience differences do not create additional groups. Groups beyond the budget
are omitted, and their replications continue to use periodic reconciliation.
Monitor the omitted-registration metric before increasing the number or size of
distinct predicates.

## Observe triggers

For a trigger-enabled replication, the internal notification identity is stored
in the `projectcapsule.dev/replication-trigger` annotation:

- `status.trigger.lastTriggeredAt` records the start of the latest triggered
  attempt, including failed attempts.
- `status.trigger.observedRequest` identifies the last notification handled by a
  completed attempt. Failed attempts leave their notification pending for retry.
- `status.nextResyncAt` records the earliest outstanding periodic recovery deadline.
  An intervening trigger does not postpone it.
- The existing Ready condition and processed-item status report apply errors.

The `capsule_replication_trigger_notifications_total` metric has bounded
`outcome` values: `queued`, `saturated`, and `retry`. Each webhook replica has a
bounded working set of 4096 pending/cooling-down targets. Saturation drops new
target notifications, while notifications for already tracked targets still
coalesce; periodic reconciliation provides recovery. A one-minute maintenance
ticker prunes deleted, cordoned, and unsubscribed targets from this working set.

`capsule_replication_trigger_registrations_omitted` reports the number of native
trigger groups omitted because of the registration budget. A nonzero value means
some subscriptions rely on periodic reconciliation until the configuration fits
the budget.
