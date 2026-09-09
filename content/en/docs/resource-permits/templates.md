---
title: Resource Permit Templates
weight: 10
aliases:
  - /docs/resource-leases/templates/
  - /docs/resource-permits/impersonation/
  - /docs/resource-leases/impersonation/
description: Define reusable resources, inputs, execution identities, readiness, and limits.
---

A template describes what Capsule renders for a `ResourcePermit`, who executes it, and
how long the resulting resources may remain active.

## Choose the template scope

Use `ResourcePermitTemplate` when the workflow and its execution identity belong to one
namespace. Use `GlobalResourcePermitTemplate` when platform administrators provide the
same workflow to several namespaces.

| Behavior | `ResourcePermitTemplate` | `GlobalResourcePermitTemplate` |
| --- | --- | --- |
| Scope | Namespaced | Cluster |
| Request location | Same namespace | Any allowed namespace |
| ServiceAccount reference | Name only, in the template namespace | Name and namespace |
| Namespace selectors/status | Not applicable | Supported |
| Ready condition and observed generation | Supported | Supported |

A minimal local template renders its namespaced targets into the ResourcePermit
namespace when `metadata.namespace` is omitted:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: ResourcePermitTemplate
metadata:
  name: temporary-config
  namespace: solar-uat
spec:
  paramSchema:
    type: object
    required: [owner]
    properties:
      owner:
        type: string
  resources:
    - targets:
        - apiVersion: v1
          kind: ConfigMap
          metadata:
            name: temporary-config
          data:
            requestedBy: '{{ .owner }}'
```

For a global template, `namespaceSelectors` is an OR list. Omitting it allows requests
from every namespace.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalResourcePermitTemplate
metadata:
  name: production-debug
spec:
  namespaceSelectors:
    - matchLabels:
        environment: production
    - matchExpressions:
        - key: resource-permit.example.com/enabled
          operator: In
          values: ["true"]
  resources:
    - targets:
        - apiVersion: v1
          kind: ConfigMap
          metadata:
            name: production-debug
```

Capsule publishes matching namespaces in `.status.namespaces`; an unrestricted global
template reports `"*"`. Admission rejects a reference when the template is missing,
its current generation has not reconciled, or the request namespace is not selected.

## Template readiness

Both template kinds expose `.status.observedGeneration` and a `Ready` condition in
`.status.conditions`. Successful reconciliation reports `Ready=True` with reason
`Succeeded`; a failure reports `Ready=False` with reason `Failed` and an explanatory
message. The condition's `observedGeneration` identifies the template generation
that was checked. Compare it with `.metadata.generation` after editing a template.

Template readiness covers static validation of the approval policy, duration limits,
parameter schema, and resource definitions. Global templates also resolve namespace
selection. On failure, their namespace list is cleared so it cannot grant access from
an earlier successful reconciliation. A ready template still requires each permit's
parameters, context reads, rendering, execution permissions, and dry-run to succeed.

For example, an unrestricted global template reports:

```yaml
status:
  observedGeneration: 1
  namespaces: ["*"]
  conditions:
    - type: Ready
      status: "True"
      reason: Succeeded
      message: reconciled
      observedGeneration: 1
      lastTransitionTime: "2026-09-09T12:00:00Z"
```

A namespaced template has the same readiness fields without `namespaces`. Both kinds
show `Ready` and `Status` columns in `kubectl get` output:

```bash
kubectl get rpt -n solar-uat
kubectl get grpt
kubectl wait --for=condition=Ready rpt/temporary-config -n solar-uat --timeout=60s
kubectl wait --for=condition=Ready grpt/production-debug --timeout=60s
```

The controller exports readiness gauges for both kinds; see
[Metrics](../requests/#metrics) for names, labels, and example queries.

## Define inputs and rendered resources

`spec.paramSchema` validates `ResourcePermit.spec.params` before context is loaded or
resources are rendered:

```yaml
paramSchema:
  type: object
  additionalProperties: false
  required: [name, crd]
  properties:
    name:
      type: string
      minLength: 1
      maxLength: 63
    crd:
      type: string
```

See [Parameter Schemas and Dynamic Forms](/docs/operating/concepts/parameter-schema/)
for JSON Schema 2020-12, cross-field CEL, and Kubernetes resource selectors used by
clients such as Headlamp.

Every entry in `spec.resources` is one resource group. Its policy applies to all
manifests produced by that entry. A group may contain structured `targets`, a
multi-document `template`, or both:

```yaml
resources:
  - policy:
      creation: Owner
      protect: true
      force: false
      deletion: Remove
    targets:
      - apiVersion: v1
        kind: ConfigMap
        metadata:
          name: '{{ .name }}'
        data:
          requestedBy: '{{ .request.username }}'
    template: |
      ---
      apiVersion: v1
      kind: Secret
      metadata:
        name: {{ $.params.name }}
      stringData:
        requestedBy: {{ $.request.username }}
```

Direct targets expose parameters and loaded context indexes at the root. Generated
templates use a structured root:

| Data | Direct target | Generated template |
| --- | --- | --- |
| Request parameters | `.name` | `$.params.name` |
| Loaded context | `index .crdInfo 0` | `index $.context.resources.crdInfo 0` |
| Trusted request data | `.request.username` | `$.request.username` |

The trusted request object contains:

| Field | Meaning |
| --- | --- |
| `name` | ResourcePermit name |
| `username` | Authenticated requester |
| `groups` | Authenticated groups as a string array |
| `timestamp` | Stable ResourcePermit creation time in UTC RFC3339 |

Use `join "," .request.groups` for a direct string field and
`join "," $.request.groups` in a generator. The `request` key is reserved; parameters
and context indexes cannot replace these trusted values. Missing template keys are
errors, and environment-reading functions such as `env` are not exposed.

The policy shown above uses all defaults. Its ownership, conflict, protection, and
cleanup semantics are documented once in
[Managed Resources and Server-Side Apply](/docs/operating/concepts/managed-resources/).

**Load Kubernetes context**

Context references load arbitrary Kubernetes GVKs before every resource group is
rendered. Each result is an array, even when selecting one named object. Context
indexes must be distinct from parameter names and the reserved `request` key. Here,
`crd` is the input parameter and `crdInfo` holds the loaded CRD.

```yaml
context:
  resources:
    - apiVersion: apiextensions.k8s.io/v1
      kind: CustomResourceDefinition
      name: '{{ .crd }}'
      index: crdInfo
      optional: false
    - apiVersion: v1
      kind: ConfigMap
      namespace: '{{ .managementNamespace }}'
      selector:
        matchLabels:
          access.example.com/source: resource-permit
      index: management
```

`name`, `namespace`, and selector values may use declared parameters. For a namespaced
GVK, an omitted namespace means the ResourcePermit namespace; cluster-scoped GVKs ignore
it. The execution ServiceAccount performs all reads, and Capsule sanitizes objects
before exposing them to templates.

Access a ConfigMap value whose key contains punctuation with `index`:

```gotemplate
{{ index (index .management 0).data "team-a" }}
{{ index (index $.context.resources.management 0).data "team-a" }}
```

The first expression is for a direct target and the second for a generated template.

## Choose the execution identity and limits

Capsule resolves one ServiceAccount for context reads, discovery, apply, reconciliation,
dry-run, and cleanup. It always records the result in
`.status.request.impersonation`, including when the controller ServiceAccount is used.

| Template | Explicit identity | Configuration fallback | Final fallback |
| --- | --- | --- | --- |
| Local | `spec.impersonation.name` in the template namespace | `tenantDefaultServiceAccount` in that namespace | Capsule controller ServiceAccount |
| Global | `spec.impersonation.name` and `.namespace` | `globalDefaultServiceAccount` in `globalDefaultServiceAccountNamespace` | Capsule controller ServiceAccount |

Local and global references respectively look like this:

```yaml
# ResourcePermitTemplate
spec:
  impersonation:
    name: resource-permit-runner
---
# GlobalResourcePermitTemplate
spec:
  impersonation:
    name: resource-permit-global-runner
    namespace: capsule-system
```

Configure fallbacks centrally:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: CapsuleConfiguration
metadata:
  name: default
spec:
  impersonation:
    tenantDefaultServiceAccount: resource-permit-runner
    globalDefaultServiceAccount: resource-permit-global-runner
    globalDefaultServiceAccountNamespace: capsule-system
```

The ServiceAccount needs `get` for named context objects or `list` for selected
context, plus the lifecycle verbs required by every rendered GVK. This usually means
`get`, `create`, `patch`, and `update`, plus `delete` for resources that Capsule may
remove. Cluster-scoped inputs and outputs require appropriately scoped RBAC. Keep this
execution identity separate from approval identities: the approver authorizes the
snapshot; the ServiceAccount executes it.

Capsule performs a server-side dry-run with this identity before the request becomes
reviewable. The ServiceAccount is protected from deletion while it is referenced by a
ResourcePermit that has not expired, a TenantResource, or a GlobalTenantResource.

Duration and retention limits are also template properties:

```yaml
defaultDuration: 30m
maxDuration: 2h
keepFor: 7d
```

`defaultDuration` applies when the request omits a duration, `maxDuration` limits the
approved value, and `keepFor` retains an expired request for auditing. Without an
effective duration, access remains until explicitly expired.

## Complete CRD access example

This global template loads a CRD and creates a dedicated Role and RoleBinding for the
requester. The namespaced manifests omit `metadata.namespace`, so Capsule places them
in the ResourcePermit namespace.

Install the target CRD and label the request namespace before using this example:

```bash
kubectl label namespace solar-uat resource-permit.example.com/enabled=true
```

The execution identity must be able to read CRDs and manage and grant the rendered
RBAC permissions. A reviewer must belong to `platform-on-call` and have permission
to update the permit's status.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalResourcePermitTemplate
metadata:
  name: temporary-crd-editor
spec:
  defaultDuration: 30m
  maxDuration: 4h
  keepFor: 14d
  namespaceSelectors:
    - matchLabels:
        resource-permit.example.com/enabled: "true"
  approvals:
    approvers:
      - kind: Group
        name: platform-on-call
  paramSchema:
    type: object
    additionalProperties: false
    required: [name, crd]
    properties:
      name:
        type: string
      crd:
        type: string
  context:
    resources:
      - apiVersion: apiextensions.k8s.io/v1
        kind: CustomResourceDefinition
        name: '{{ .crd }}'
        index: crdInfo
        optional: false
  resources:
    - policy:
        creation: Owner
        protect: true
        force: false
        deletion: Remove
      template: |
        ---
        apiVersion: rbac.authorization.k8s.io/v1
        kind: Role
        metadata:
          name: {{ $.params.name }}
        rules:
          - apiGroups:
              - {{ (index $.context.resources.crdInfo 0).spec.group }}
            resources:
              - {{ (index $.context.resources.crdInfo 0).spec.names.plural }}
            verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
        ---
        apiVersion: rbac.authorization.k8s.io/v1
        kind: RoleBinding
        metadata:
          name: {{ $.request.name }}
        roleRef:
          apiGroup: rbac.authorization.k8s.io
          kind: Role
          name: {{ $.params.name }}
        subjects:
          - kind: User
            apiGroup: rbac.authorization.k8s.io
            name: {{ $.request.username }}
```

See [Resource Permits](/docs/resource-permits/requests/) for approval, review, activation,
expiry, and troubleshooting.
