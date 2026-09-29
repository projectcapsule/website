---
title: Parameter Schemas and Dynamic Forms
weight: 8
aliases:
  - /docs/resource-permits/parameter-validation/
  - /docs/resource-permits/dynamic-forms/
  - /docs/resource-leases/parameter-validation/
  - /docs/resource-leases/dynamic-forms/
  - /docs/operating/concepts/parameter-validation/
description: >
  Validate parameterized APIs with JSON Schema and Kubernetes CEL, and enrich clients with live Kubernetes resource selectors.
---

Capsule parameter schemas define the contract between a template and the values
submitted by a consuming API object. Resource Permits currently use `spec.paramSchema`
to validate `ResourcePermit.spec.params` before context loading and rendering.

`spec.paramSchema` on the referenced template is the complete contract for
`ResourcePermit.spec.params`. It accepts JSON Schema 2020-12 keywords,
Kubernetes-compatible `x-kubernetes-validations` CEL rules, and Capsule's
`x-capsule-form` presentation extension.

Capsule validates parameters during ResourcePermit admission, before loading context or
rendering resources. Invalid parameters are rejected and no ResourcePermit is created.
Failures that require runtime context or rendering remain visible on an accepted
request as `Created` with `Ready=False`; Capsule does not apply any resources.

## JSON Schema 2020-12

Use ordinary JSON Schema for types, required fields, enums, ranges, lengths, patterns,
and conditional structure:

```yaml
paramSchema:
  $schema: https://json-schema.org/draft/2020-12/schema
  type: object
  additionalProperties: false
  required:
    - subjectKind
    - subjectName
  properties:
    subjectKind:
      type: string
      enum: [User, Group, ServiceAccount]
    subjectName:
      type: string
      minLength: 1
  allOf:
    - if:
        properties:
          subjectKind:
            const: ServiceAccount
        required: [subjectKind]
      then:
        properties:
          subjectName:
            pattern: '^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?/[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$'
```

With this schema:

- `ServiceAccount` with `operations/resource-permit-runner` is valid;
- `ServiceAccount` with `resource-permit-runner` is invalid; and
- `User` with `alice@example.com` remains valid.

The example represents a ServiceAccount as `namespace/name`. When rendering an RBAC
`Subject`, split that value into the subject's `namespace` and `name` fields.

Other useful JSON Schema keywords include `dependentRequired`,
`dependentSchemas`, `contains`, `prefixItems`, `allOf`, `anyOf`, `oneOf`,
and `unevaluatedProperties`.

## Kubernetes CEL rules

Use `x-kubernetes-validations` for readable cross-field and collection invariants.
It has the same shape as validation rules generated from Kubebuilder's
`+kubebuilder:validation:XValidation` marker. Capsule converts the parameter schema
to a Kubernetes structural schema and delegates evaluation to Kubernetes' CEL
validator.

```yaml
paramSchema:
  type: object
  additionalProperties: false
  required:
    - subjectKind
    - subjectName
  properties:
    subjectKind:
      type: string
      enum: [User, Group, ServiceAccount]
    subjectName:
      type: string
      minLength: 1
  x-kubernetes-validations:
    - rule: >-
        self.subjectKind != 'ServiceAccount' ||
        self.subjectName.matches('^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?/[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$')
      message: ServiceAccount subjects must use namespace/name
      reason: FieldValueInvalid
      fieldPath: .subjectName
```

`self` is the value at the schema node containing the extension. At the root it is
the whole parameters object. Use `has(self.field)` for optional properties.

The accepted validation-rule fields are:

| Field | Meaning |
| --- | --- |
| `rule` | Required CEL expression returning a boolean |
| `message` | Static failure message; required when a rule contains line breaks |
| `messageExpression` | CEL expression returning a dynamic failure string |
| `reason` | `FieldValueInvalid`, `FieldValueForbidden`, `FieldValueRequired`, or `FieldValueDuplicate` |
| `fieldPath` | Relative field path associated with the error |
| `optionalOldSelf` | Kubernetes transition-rule behavior for an optional previous value |

Rule and message-expression syntax is compiled when the template is admitted.
Evaluation uses Kubernetes CEL cost limits.

Parameter validation has no previous parameter object. A transition rule using
`oldSelf` therefore behaves like Kubernetes validation on create: an ordinary
transition rule is skipped, while `optionalOldSelf: true` can explicitly handle an
absent previous value. Use `self` for request-time constraints.

Dynamic failure messages are supported:

```yaml
x-kubernetes-validations:
  - rule: "self.subjectKind != 'ServiceAccount' || self.subjectName.contains('/')"
    message: invalid ServiceAccount path
    messageExpression: >-
      'subjectName ' + self.subjectName + ' must use namespace/name for a ServiceAccount'
    reason: FieldValueInvalid
    fieldPath: .subjectName
```

If `messageExpression` fails or produces an invalid message, evaluation falls back
to `message`, then to the rule text.

Rules may also be attached to structural properties, array items, and
additional-property schemas. Their `self` value is scoped accordingly:

```yaml
paramSchema:
  type: object
  properties:
    subjects:
      type: array
      items:
        type: object
        required: [name]
        properties:
          name:
            type: string
        x-kubernetes-validations:
          - rule: "!self.name.startsWith('system:')"
            messageExpression: "'subject ' + self.name + ' uses a reserved prefix'"
            fieldPath: .name
```

CEL rules must be attached to Kubernetes structural schema nodes. Do not place them
inside `$defs`, `if`/`then`, or another JSON-Schema-only branch. Put the rule on
a root, property, item, or additional-property node that can see the required values.
Standard JSON Schema may still use those constructs alongside CEL.

Choose the smallest validation mechanism that expresses the invariant:

| Requirement | Mechanism |
| --- | --- |
| Type, enum, range, length, or regex | JSON Schema property keyword |
| Field required for a discriminator value | JSON Schema `if`/`then` |
| Relationship between fields | `x-kubernetes-validations` CEL |
| Collection-item relationship | Nested CEL rule or CEL collection macro |
| Populate choices from live objects | `x-capsule-form` |
| Authoritatively load a selected object | Template `context.resources` |

## Dynamic forms and live cluster data

`x-capsule-form` is an optional JSON Schema vendor extension for compatible clients
such as a Headlamp plugin. It populates a string field from live Kubernetes objects
without changing server-side JSON Schema semantics.

This complete example combines JSON Schema, conditional validation, CEL, and a live
Secret selector:

```yaml
paramSchema:
  $schema: https://json-schema.org/draft/2020-12/schema
  type: object
  additionalProperties: false
  required:
    - subjectKind
    - subjectName
    - credentialsSecret
  properties:
    subjectKind:
      type: string
      enum: [User, Group, ServiceAccount]
    subjectName:
      type: string
      minLength: 1
    credentialsSecret:
      type: string
      pattern: '^[a-z0-9.-]+/[a-z0-9.-]+$'
      x-capsule-form:
        widget: kubernetes-resource
        source:
          apiVersion: v1
          kind: Secret
          namespace: request
          labelSelector: access.example.com/selectable=true
        option:
          labelTemplate: '{{ .metadata.name }}'
          valueTemplate: '{{ .metadata.namespace }}/{{ .metadata.name }}'
  allOf:
    - if:
        properties:
          subjectKind:
            const: ServiceAccount
        required: [subjectKind]
      then:
        properties:
          subjectName:
            pattern: '^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?/[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$'
  x-kubernetes-validations:
    - rule: >-
        self.subjectKind != 'Group' ||
        !self.subjectName.startsWith('system:')
      message: Groups using the system prefix cannot be requested
      reason: FieldValueForbidden
      fieldPath: .subjectName
```

The accepted form-extension shape is:

```yaml
x-capsule-form:
  widget: kubernetes-resource       # required
  source:                           # required
    apiVersion: group.example.io/v1 # required; v1 is also valid
    kind: Example                   # required; one exact kind
    namespace: request              # optional: request, "*", or a namespace
    labelSelector: key=value        # optional
    fieldSelector: metadata.name=x  # optional
  option:                           # optional
    labelTemplate: '{{ .metadata.name }}'
    valueTemplate: '{{ .metadata.namespace }}/{{ .metadata.name }}'
```

Unknown widgets and extension fields are rejected. `option` may be omitted; both
templates then default to `{{ .metadata.name }}`.

### Resource source

| Field | Required | Meaning |
| --- | --- | --- |
| `apiVersion` | Yes | Exact version such as `v1`, `apps/v1`, or an arbitrary CRD version |
| `kind` | Yes | Exact Kubernetes kind; wildcards are unsupported |
| `namespace` | No | List scope for a namespaced GVK |
| `labelSelector` | No | Kubernetes label selector passed to the list request |
| `fieldSelector` | No | Kubernetes field selector passed to the list request |

`namespace` supports four modes:

| Value | Behavior |
| --- | --- |
| omitted | Request namespace for namespaced GVKs; cluster endpoint for cluster-scoped GVKs |
| `request` | Explicitly use the ResourcePermit namespace |
| `*` | List a namespaced GVK across every namespace |
| namespace name | List only that literal namespace |

Any exact discoverable GVK is supported, including CRDs. Capsule validates API-version
syntax, selectors, namespaces, extension fields, and option-template syntax when the
template is admitted. It does not require the GVK to exist at that time, allowing the
template to be installed before its CRD.

The form client uses Kubernetes discovery to determine whether a GVK is namespaced or
cluster-scoped. For example:

```yaml
properties:
  gatewayClass:
    type: string
    x-capsule-form:
      widget: kubernetes-resource
      source:
        apiVersion: gateway.networking.k8s.io/v1
        kind: GatewayClass
      option:
        labelTemplate: '{{ .metadata.name }} — {{ .spec.controllerName }}'
        valueTemplate: '{{ .metadata.name }}'
```

To list a namespaced type across all namespaces:

```yaml
properties:
  sourceConfigMap:
    type: string
    x-capsule-form:
      widget: kubernetes-resource
      source:
        apiVersion: v1
        kind: ConfigMap
        namespace: '*'
        labelSelector: access.example.com/exportable=true
      option:
        valueTemplate: '{{ .metadata.namespace }}/{{ .metadata.name }}'
```

The user's Kubernetes RBAC must permit the corresponding list operation.

### Option templates

The listed object is an unstructured map at the Go-template root:

```yaml
option:
  labelTemplate: '{{ .metadata.name }} ({{ .metadata.namespace }})'
  valueTemplate: '{{ .metadata.namespace }}/{{ .metadata.name }}'
```

Both fields default to `{{ .metadata.name }}`. They use Capsule's safe Go-template
function map; environment-reading functions are unavailable. Keep values deterministic
because the rendered value is stored in `spec.params`.

### Nested form schemas

Capsule finds and validates `x-capsule-form` recursively in properties, array items,
tuple and prefix items, `$defs`, `definitions`, `allOf`, `anyOf`, `oneOf`, and
conditional schemas:

```yaml
paramSchema:
  type: object
  properties:
    targets:
      type: array
      items:
        type: object
        properties:
          secret:
            type: string
            x-capsule-form:
              widget: kubernetes-resource
              source:
                apiVersion: v1
                kind: Secret
                namespace: request
```

### Arrays and multiple selections

For one or more selections, define an array and place `x-capsule-form` on its string
`items` schema. A compatible client may display this as a multi-select control or as
repeatable resource selectors:

```yaml
properties:
  clusterRoles:
    type: array
    minItems: 1
    uniqueItems: true
    items:
      type: string
      x-capsule-form:
        widget: kubernetes-resource
        source:
          apiVersion: rbac.authorization.k8s.io/v1
          kind: ClusterRole
  namespaces:
    type: array
    minItems: 1
    uniqueItems: true
    items:
      type: string
      x-capsule-form:
        widget: kubernetes-resource
        source:
          apiVersion: v1
          kind: Namespace
```

`minItems` enforces at least one selection and `uniqueItems` prevents duplicate
generator output. The submitted values remain ordinary arrays in `spec.params` and
can be iterated with nested Go-template `range` actions.

### Client and security contract

A compatible client:

1. traverses JSON Schema and locates `x-capsule-form`;
2. resolves the exact `apiVersion` and `kind` through Kubernetes discovery;
3. selects the namespaced, all-namespaces, or cluster list endpoint;
4. passes the configured label and field selectors;
5. renders a label and value for every unstructured object; and
6. submits the chosen value through ordinary `spec.params`.

Discovery and listing must use the logged-in user's credentials, not the template's
execution ServiceAccount. Otherwise a dropdown could disclose objects the user cannot
list.

`x-capsule-form` is presentation metadata, not an authorization boundary:

- it grants no list permission;
- it does not prove that a value came from the dropdown;
- it does not load the selected object into rendering context; and
- it does not validate that the GVK is installed.

Validate submitted values with JSON Schema or CEL. For authoritative lookup, load the
selected object through `spec.context.resources`, which uses the recorded template
ServiceAccount:

```yaml
paramSchema:
  type: object
  required: [crd]
  properties:
    crd:
      type: string
      x-capsule-form:
        widget: kubernetes-resource
        source:
          apiVersion: apiextensions.k8s.io/v1
          kind: CustomResourceDefinition
context:
  resources:
    - apiVersion: apiextensions.k8s.io/v1
      kind: CustomResourceDefinition
      name: '{{ .crd }}'
      index: crdInfo
      optional: false
```

If the context object is missing or the execution identity cannot read it, the request
becomes `Ready=False`.
