---
title: Metadata
weight: 2
description: >
  Metadata Enforcement
---

Metadata enforcement allows administrators to allow, deny, or audit Kubernetes object labels and annotations for namespaced resources.

Metadata rules are configured under `spec.rules[].enforce.metadata`. They are evaluated by a generic validating webhook and can target one or more Kubernetes kinds. This makes metadata enforcement useful for objects such as `ConfigMap`, `Secret`, `Service`, `Deployment`, custom resources, and other namespaced resources.

```yaml
rules:
  - enforce:
      action: allow
      metadata:
        - apiGroups:
            - "*"
          kinds:
            - ConfigMap
            - Service
          labels:
            corp.com/tenant:
              required: true
              values:
                - exact:
                    - prod
                    - test
          annotations:
            example.corp/cost-center:
              required: false
              values:
                - exp: "^INV-[0-9]{4}$"
                  exact:
                    - prod
                    - test
```

Metadata enforcement follows the same action and precedence model as other namespace rules:

* `allow` creates an allow-list for the evaluated metadata key.
* `deny` denies matching metadata values.
* `audit` emits Kubernetes events and admission warnings but does not allow or deny the request.
* If multiple `allow` or `deny` rules match the same metadata key and value, the last matching allow or deny rule wins.
* If at least one `allow` rule exists for a metadata key and the object contains that key with a value that does not match any allow or deny rule, Capsule denies the request.
* Audit rules never satisfy allow-list behavior.
* Missing optional metadata keys are ignored.

Metadata rules are evaluated during create and update admission. Metadata enforcement is intentionally generic and conservative. Keep the following behavior in mind:

| Behavior | Explanation |
|---|---|
| Namespaced resources and explicitly selected Namespaces are evaluated | Metadata rules normally target resources inside Tenant namespaces. `Namespace` is the only supported cluster-scoped kind, and it must be selected explicitly with `kinds: ["Namespace"]`. |
| Controller-managed objects can be skipped | Objects labeled `managed-by=controller` are ignored by generic metadata validation. This prevents controllers from being blocked when reconciling managed objects. The skip check is exact and case-sensitive. |
| Capsule-managed metadata is ignored | Built-in Capsule labels and annotations are treated as managed metadata and are ignored by metadata validation. Do not rely on metadata rules to validate Capsule-owned keys. |
| Managed annotation prefixes are ignored | Capsule-managed annotation prefixes such as resource quota and resource usage annotations are ignored. |
| Missing optional metadata is ignored | If `required: false`, the key is only evaluated when it is present. |
| `required` applies to allow rules | `required: true` enforces presence for `action: allow`. `deny` and `audit` rules match values; they do not require missing keys to exist. |
| Empty metadata values are valid values | A label or annotation with an empty string value is still present and can be matched with `exact: [""]`. |
| Labels and annotations are independent | A matching annotation does not satisfy a required label with the same key, and a matching label does not satisfy a required annotation. |
| Empty `apiGroups` means core `v1` | Omitted `apiGroups`, an empty list, or an empty entry selects the core Kubernetes `v1` API. Use `apiGroups: ["*"]` to match every API group and version. |
| `kinds` must be set | Use `kinds: ["*"]` to match all namespaced kinds. A wildcard does not implicitly include `Namespace`. |

Capsule-managed labels include labels used to track Tenant ownership, resource pools, freeze and cordon state, promotion state, Capsule ownership, and generated namespace resources. Capsule-managed annotations include release and reconciliation annotations, available class and registry annotations, forbidden namespace metadata annotations, protected Tenant annotations, and resource quota or resource usage annotation prefixes.

Because these keys are owned by Capsule, metadata rules that reference them are ignored by default. Use application-specific labels and annotations for Tenant policy enforcement.

## Target resources

Each metadata rule defines which resource kinds it applies to:

| Field | Description |
|---|---|
| `apiGroups` | List of API group or group/version selectors. Empty or omitted means core `v1`; `apps` matches every version in that group; `apps/v1` matches that exact group/version; and `"*"` matches all groups and versions. |
| `kinds` | List of Kubernetes kind selectors. `"*"` and partial wildcards match namespaced kinds, but `Namespace` must always appear as a separate literal entry to include it. |

Examples:

```yaml
metadata:
  - kinds:
      - ConfigMap
      - Service
```

This targets core `v1` `ConfigMap` and `Service` resources because `apiGroups`
is omitted.

```yaml
metadata:
  - apiGroups:
      - apps/v1
    kinds:
      - Deployment
      - StatefulSet
```

This targets only `apps/v1` `Deployment` and `StatefulSet` resources.

```yaml
metadata:
  - apiGroups:
      - "*"
    kinds:
      - "*"
```

This targets all namespaced resources handled by the generic metadata webhook.
It does **not** target `Namespace`, despite both selectors being wildcards.

Partial wildcards are also supported:

```yaml
metadata:
  - apiGroups:
      - "apps/*"
    kinds:
      - "*Set"
```

This can match resources such as `apps/v1` `ReplicaSet` and `apps/v1` `StatefulSet`.


### Namespace

`Namespace` is the only cluster-scoped resource supported by metadata rules. It
is deliberately opt-in: the `kinds` list must contain the literal,
case-sensitive value `Namespace`. This prevents a broad rule intended for
resources inside Tenant namespaces from accidentally changing or rejecting the
Namespace object itself.

The Namespace GVK is core `v1`, `Kind=Namespace`. The `apiGroups` selector must
therefore match core `v1`. The clearest form is:

```yaml
metadata:
  - apiGroups:
      - "v1"
    kinds:
      - "Namespace"
```

Because omitted `apiGroups` defaults to core `v1`, this shorter form is
equivalent:

```yaml
metadata:
  - kinds:
      - Namespace
```

An API-group wildcard may also match core `v1`, but it still does not remove the
explicit-kind requirement. For example, this targets all namespaced kinds **and**
Namespace:

```yaml
metadata:
  - apiGroups:
      - "*"
    kinds:
      - "*"
      - Namespace
```

The following selectors do **not** target Namespace:

```yaml
# A full kind wildcard is not an explicit Namespace opt-in.
metadata:
  - apiGroups:
      - "*"
    kinds:
      - "*"

# A partial kind wildcard is not an explicit Namespace opt-in either,
# even when its pattern would otherwise match the word "Namespace".
  - apiGroups:
      - "v1"
    kinds:
      - "Name*"
```

In short, both conditions must be true: `apiGroups` must match core `v1`, and
`kinds` must contain a dedicated `Namespace` entry.

### Important `apiGroups` behavior

Omitted or empty `apiGroups` does **not** mean all API groups and versions. It
means the core Kubernetes API version `v1`.

For example:

```yaml
metadata:
  - kinds:
      - Deployment
```

This does **not** match `apps/v1` `Deployment`, because omitted `apiGroups` is
interpreted as core `v1`.

To match `apps/v1` deployments, set the API group/version selector explicitly:

```yaml
metadata:
  - apiGroups:
      - apps/v1
    kinds:
      - Deployment
```

To match deployments across all API groups and versions, use `"*"`:

```yaml
metadata:
  - apiGroups:
      - "*"
    kinds:
      - Deployment
```

## Label rules

Label rules are configured under `metadata[].labels`. Each map key is the label key to validate.

```yaml
rules:
  - enforce:
      action: allow
      metadata:
        - kinds:
            - ConfigMap
          labels:
            env:
              required: true
              values:
                - exact:
                    - prod
                    - test
```

With this rule, a matching `ConfigMap` must contain `metadata.labels["env"]`, and its value must be either `prod` or `test`.

This object is admitted:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  labels:
    env: prod
data:
  key: value
```

This object is denied because the required label is missing:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  key: value
```

This object is denied because the label value does not match the allow-list:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  labels:
    env: stage
data:
  key: value
```

Example rejection:

```bash
Error from server (Forbidden): error when creating "configmap.yaml": admission webhook "rules.generic.projectcapsule.dev" denied the request: metadata label "env" is required at metadata.labels["env"]
```

## Annotation rules

Annotation rules are configured under `metadata[].annotations`. Each map key is the annotation key to validate.

```yaml
rules:
  - enforce:
      action: allow
      audience:
        - kind: "Group"
          name: "system:authenticated"
        - kind: "Custom"
          name: "CapsuleUser"
        - kind: "Custom"
          name: "Administrator"
        - kind: "Custom"
          name: "TenantOwner"
      metadata:
        - apiGroups:
            - "v1"
          kinds:
            - Namespace
          annotations:
            example.corp/cost-center:
              required: false
              values:
                - exp: "^INV-[0-9]{4}$"
              # Overwrites anything, even if the user has set a value, Should be applied using SSA by the rulestatus controller, if removed also removes (one fieldmanager per rulestatus which controlles all managed metadata). Also enforce at admission
              managed: "INV-10"
            example.corp/cost-center-2:
              values:
                - exp: "II-10"
              default: "{{$.tenant.spec.data.costCenter}}"
```

With this rule, the annotation is optional. If the object does not contain `metadata.annotations["example.corp/cost-center"]`, Capsule ignores the rule. If the annotation is present, its value must match the configured expression.

This object is admitted because the annotation is absent and `required` is `false`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  key: value
```

This object is admitted because the annotation value matches:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  annotations:
    example.corp/cost-center: INV-1234
data:
  key: value
```

This object is denied because the annotation is present but does not match:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  annotations:
    example.corp/cost-center: BAD-1234
data:
  key: value
```

## Default

The `default` field provides a value for coressponding field should no value be provided by the user. This is only applied at admission time and does not enforce the value to be present in the object.

`default` is meaningful for `action: allow`. `deny` and `audit` rules are value matchers; they do not require missing metadata to exist.

```yaml
rules:
  - enforce:
      action: allow
      metadata:
        - kinds:
            - ConfigMap
          labels:
           cost-center:
              default: "internal"
```

Default values still validate against the configured `values` matchers. If the default value does not match any allow or deny rule, the request is denied.

## Managed

Providing managed values ensures the metadata is always set to the provided value. This is applied at admission time and also enforced by the `RuleStatus` controller. Meaning it's also applied to already existing objects and also enforced at admission time. This is useful for enforcing certain metadata to be present and also to ensure the value is always set to a specific value.

```yaml
rules:
  - enforce:
      action: allow
      metadata:
        - apiGroups:
            - "v1"
          kinds:
            - Namespace
          annotations:
            example.corp/cost-center:
              required: false
              values:
                - exp: "^INV-[0-9]{4}$"
              # Overwrites anything, even if the user has set a value, Should be applied using SSA by the rulestatus controller, if removed also removes (one fieldmanager per rulestatus which controlles all managed metadata). Also enforce at admission
              managed: "INV-10"
```

## Required

The `required` field controls whether the metadata key must be present.

| `required` | Behavior |
|:---|:---|
| `true` | For `action: allow`, the key must be present on matching objects. |
| `false` | The key is optional. If it is missing, Capsule ignores it. If it is present, configured values are evaluated. |

`required` is meaningful for `action: allow`. `deny` and `audit` rules are value matchers; they do not require missing metadata to exist.

Presence-only enforcement is possible by setting `required: true` and omitting `values`:

```yaml
rules:
  - enforce:
      action: allow
      metadata:
        - kinds:
            - ConfigMap
          labels:
            tenant-approved:
              required: true
```

With this rule, matching `ConfigMap` resources must contain the `tenant-approved` label, but any value is accepted.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  labels:
    tenant-approved: "true"
data:
  key: value
```

If the label is missing, the request is denied.

## Validation

The `values` field uses the common match expression structure with `exact`, `exp`, and optional `negate`.

```yaml
values:
  - exact:
      - prod
      - test
  - exp: "^sandbox-[0-9]+$"
```

A metadata value matches if any configured value matcher matches.

`exact` and `exp` can be combined in the same matcher:

```yaml
values:
  - exact:
      - prod
      - test
    exp: "^dev-[0-9]+$"
```

This matcher allows `prod`, `test`, and values matching `^dev-[0-9]+$`.

`negate: true` inverts the final matcher result:

```yaml
rules:
  - enforce:
      action: deny
      metadata:
        - apiVersion: "*"
          kinds:
            - ConfigMap
          labels:
            team:
              values:
                - exp: "^trusted-.*"
                  negate: true
```

With this rule:

* `team=trusted-platform` is not denied by this deny-only rule.
* `team=untrusted` is denied.

If an allow-list also exists for the same metadata key, values excluded from a negated deny rule still need a matching allow rule.

## Migration

The legacy metadata fields under `Tenant.spec` can be migrated to metadata
rules. Rules use the same policy structure for Namespaces, Pods, Services, and
other resources, and allow validation, admission defaults, and reconciled
managed values to be combined.

Migrate one resource type at a time. When old and new configuration overlap,
keep their values identical until the rule has been verified.

### Migrate Namespace Metadata

The legacy [Namespace metadata
options](/docs/tenants/metadata/#namespaces) map to rules as follows:

* `requiredMetadata` becomes an `allow` rule with `required: true` and a
  `values` expression.
* `additionalMetadata` and `additionalMetadataList` become `managed` values.
  Managed values are applied during admission and reconciled on existing
  Namespaces. Use `default` instead when a value should only be added during
  admission and remain user-editable afterwards.
* An `additionalMetadataList[].namespaceSelector` moves to the
  `rules[].namespaceSelector` at the same rule level. For a Namespace target,
  the selector is evaluated against that Namespace's labels.
* Exact entries in `forbiddenLabels.denied` and
  `forbiddenAnnotations.denied` become `deny` rules that match any value for
  the concrete metadata key.

`Namespace` must be selected explicitly. Use the concrete core `v1` API and
the literal `Namespace` kind, especially when the rule contains `managed`
values:

```yaml
apiGroups:
  - "v1"
kinds:
  - Namespace
```

The following rules replace the `requiredMetadata`,
`additionalMetadataList`, and exact forbidden-key examples from the legacy
page:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - name: alice
      kind: User
  rules:
    # Require user-provided metadata and manage common metadata on every
    # Namespace in the Tenant.
    - enforce:
        action: allow
        metadata:
          - apiGroups:
              - "v1"
            kinds:
              - Namespace
            labels:
              env:
                required: true
                values:
                  - exp: "^(prod|test|dev)$"
              projectcapsule.dev/backup:
                managed: "true"
              templated-label:
                managed: "{{ .namespace.metadata.name }}"
            annotations:
              example.corp/cost-center:
                required: true
                values:
                  - exp: "^INV-[0-9]{4}$"
              storagelocationtype:
                managed: s3
              templated-annotation:
                managed: "{{ .tenant.metadata.name }}"

    # Apply the baseline security profile unless the Namespace explicitly
    # opts into the low-security profile.
    - namespaceSelector:
        matchExpressions:
          - key: projectcapsule.dev/low_security_profile
            operator: NotIn
            values:
              - "true"
      enforce:
        action: allow
        metadata:
          - apiGroups:
              - "v1"
            kinds:
              - Namespace
            labels:
              pod-security.kubernetes.io/enforce:
                managed: baseline

    # The selectors are mutually exclusive, so only one rule manages the Pod
    # Security Admission label for a Namespace.
    - namespaceSelector:
        matchExpressions:
          - key: projectcapsule.dev/low_security_profile
            operator: In
            values:
              - "true"
      enforce:
        action: allow
        metadata:
          - apiGroups:
              - "v1"
            kinds:
              - Namespace
            labels:
              pod-security.kubernetes.io/enforce:
                managed: privileged

    # Deny the presence of these concrete labels or annotations, regardless
    # of their values.
    - enforce:
        action: deny
        metadata:
          - apiGroups:
              - "v1"
            kinds:
              - Namespace
            labels:
              foo.acme.net:
                values:
                  - exp: ".*"
              bar.acme.net:
                values:
                  - exp: ".*"
            annotations:
              foo.acme.net:
                values:
                  - exp: ".*"
              bar.acme.net:
                values:
                  - exp: ".*"
```

With these rules:

* Tenant owners must provide a valid `env` label and cost-center annotation.
* Common and templated metadata is enforced on new and existing Namespaces.
* The Pod Security Admission profile follows the Namespace selector.
* `foo.acme.net` and `bar.acme.net` are denied as both labels and annotations,
  including when their value is an empty string.

#### Legacy options without a direct equivalent

Metadata rules are keyed by concrete label and annotation names. They do not
currently provide a direct replacement for these key-wide legacy behaviors:

* `managedMetadataOnly: true`, which rejects all user metadata not managed by
  Capsule; and
* `forbiddenLabels.deniedRegex` or
  `forbiddenAnnotations.deniedRegex`, which match metadata _keys_ by regular
  expression.

Enumerate known sensitive keys with `deny` rules as shown above. If the policy
must reject every unlisted key or a changing family of keys, retain the legacy
option during migration or enforce that part with another admission policy.
Value regular expressions remain supported through `values[].exp`; the
limitation only applies to regular expressions over metadata key names.

#### Rollout

1. Add the equivalent rules while the legacy values are still configured.
   Ensure overlapping `managed` values are identical.
2. Check the generated `RuleStatus` objects and verify both creation and update
   admission with a test Namespace.
3. Confirm that managed metadata has been reconciled onto existing Namespaces.
4. Remove the migrated `requiredMetadata`, `additionalMetadata`,
   `additionalMetadataList`, and exact forbidden-key entries.
5. Keep `managedMetadataOnly` or key-regex restrictions until an alternative
   policy covers them.

### Migrate Pod Metadata

Use the following rule to migrate the [old
`spec.podOptions.additionalMetadata` API](/docs/tenants/metadata/#pods) to the
new `spec.rules[].enforce.metadata` API:

```yaml
rules:
  - enforce:
      action: allow
      metadata:
        - kinds:
            - Pod
          annotations:
            storagelocationtype:
              managed: s3
          labels:
            projectcapsule.dev/backup:
              managed: "true"
```

### Migrate Service Metadata

Use the following rule to migrate the [old
`spec.serviceOptions.additionalMetadata` API](/docs/tenants/metadata/#services)
to the new `spec.rules[].enforce.metadata` API:

```yaml
rules:
  - enforce:
      action: allow
      metadata:
        - kinds:
            - Service
            - Endpoints
          annotations:
            customer.corp/routable:
              managed: "true"
          labels:
            customer.corp/network-tenant:
              managed: "{{ .tenant.metadata.name }}"
        - apiGroups:
            - "discovery.k8s.io/v1"
          kinds:
            - EndpointSlice
          annotations:
            customer.corp/routable:
              managed: "true"
          labels:
            customer.corp/network-tenant:
              managed: "{{ .tenant.metadata.name }}"
```

## Advanced

### Allow-list behavior for metadata

An `allow` rule creates an allow-list for the specific metadata key it controls.

```yaml
rules:
  - enforce:
      action: allow
      metadata:
        - kinds:
            - ConfigMap
          labels:
            env:
              required: true
              values:
                - exact:
                    - prod
                    - test
```

With this rule:

| Object label | Result |
|---|---|
| `env=prod` | Allowed |
| `env=test` | Allowed |
| `env=stage` | Denied |
| missing `env` | Denied because `required: true` |

If `required` is `false`, missing metadata is ignored:

```yaml
rules:
  - enforce:
      action: allow
      metadata:
        - kinds:
            - ConfigMap
          labels:
            env:
              required: false
              values:
                - exact:
                    - prod
                    - test
```

With this rule:

| Object label | Result |
|---|---|
| `env=prod` | Allowed |
| `env=test` | Allowed |
| `env=stage` | Denied |
| missing `env` | Allowed |

Allow-list behavior is evaluated per metadata key. A matching value for one key does not satisfy another required key.

For example:

```yaml
rules:
  - enforce:
      action: allow
      metadata:
        - kinds:
            - ConfigMap
          labels:
            env:
              required: true
              values:
                - exact:
                    - prod
            team:
              required: true
              values:
                - exact:
                    - platform
```

The object must contain both `env=prod` and `team=platform`.

### Deny metadata values

Use `action: deny` to reject specific metadata values.

```yaml
rules:
  - enforce:
      action: deny
      metadata:
        - kinds:
            - ConfigMap
          labels:
            environment:
              values:
                - exact:
                    - deprecated
```

This `ConfigMap` is denied:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  labels:
    environment: deprecated
data:
  key: value
```

A later matching `allow` rule can override an earlier `deny` rule:

```yaml
rules:
  - enforce:
      action: deny
      metadata:
        - kinds:
            - ConfigMap
          labels:
            environment:
              values:
                - exact:
                    - deprecated

  - namespaceSelector:
      matchLabels:
        allow-deprecated: "true"
    enforce:
      action: allow
      metadata:
        - kinds:
            - ConfigMap
          labels:
            environment:
              required: true
              values:
                - exact:
                    - deprecated
```

In namespaces labeled `allow-deprecated=true`, `environment=deprecated` is admitted because the later namespace-specific allow rule matches.

### Audit metadata values

Use `action: audit` to observe metadata usage without blocking the request.

```yaml
rules:
  - enforce:
      action: audit
      metadata:
        - apiGroups:
            - "*"
          kinds:
            - ConfigMap
            - Service
          labels:
            example.corp/audit:
              values:
                - exp: "^audit-.*"
```

A matching object is admitted in this audit-only example, but Capsule emits an audit event and returns an admission warning.

If an allow-list also exists for the same metadata key, audit does not satisfy that allow-list. The metadata value must still match an `allow` rule.

### Multiple resource kinds

A single metadata rule can target multiple kinds:

```yaml
rules:
  - enforce:
      action: allow
      metadata:
        - apiGroups:
            - "*"
          kinds:
            - ConfigMap
            - Service
          labels:
            corp.com/tenant:
              required: true
              values:
                - exact:
                    - prod
                    - test
```

With this rule, both matching `ConfigMap` and `Service` objects must contain `corp.com/tenant=prod` or `corp.com/tenant=test`.

### Namespace-specific metadata rules

Metadata enforcement supports `namespaceSelector` like other namespace rules.

```yaml
rules:
  - namespaceSelector:
      matchLabels:
        environment: prod
    enforce:
      action: allow
      metadata:
        - kinds:
            - ConfigMap
          annotations:
            example.corp/approval:
              required: true
              values:
                - exact:
                    - approved
```

This rule only applies to namespaces labeled `environment=prod`. In those namespaces, matching `ConfigMap` objects must contain `example.corp/approval=approved`.

### Complete metadata enforcement example

The following example combines required labels, optional annotations, multiple kinds, audit rules, deny rules, and namespace-specific exceptions:

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
        metadata:
          - apiGroups:
            - "*"
            kinds:
              - ConfigMap
              - Service
            labels:
              corp.com/tenant:
                required: true
                values:
                  - exact:
                      - prod
                      - test
            annotations:
              example.corp/cost-center:
                required: false
                values:
                  - exp: "^INV-[0-9]{4}$"
                  - exact:
                      - prod
                      - test

    - enforce:
        action: deny
        metadata:
          - kinds:
              - ConfigMap
            labels:
              environment:
                values:
                  - exact:
                      - deprecated

    - enforce:
        action: audit
        metadata:
          - apiGroups:
            - "*"
            kinds:
              - ConfigMap
              - Service
            labels:
              example.corp/audit:
                values:
                  - exp: "^audit-.*"

    - namespaceSelector:
        matchLabels:
          environment: prod
      enforce:
        action: allow
        metadata:
          - kinds:
              - ConfigMap
            annotations:
              example.corp/approval:
                required: true
                values:
                  - exact:
                      - approved
```

With this configuration:

* `ConfigMap` and `Service` objects must contain `projectcapsule.dev/tenant=prod` or `projectcapsule.dev/tenant=test`.
* `example.corp/cost-center` is optional, but if present it must match `^INV-[0-9]{4}$`, `prod`, or `test`.
* `ConfigMap` objects with `environment=deprecated` are denied unless a later matching allow rule overrides the decision.
* Objects with `example.corp/audit` values matching `^audit-.*` emit audit events.
* In namespaces labeled `environment=prod`, `ConfigMap` objects must also contain `example.corp/approval=approved`.
