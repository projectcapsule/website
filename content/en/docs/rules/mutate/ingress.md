---
title: Ingress
weight: 2
description: >
  Default or replace Ingress and Gateway classes and ListenerSet Gateway references
---

Ingress mutations configure Kubernetes Ingress and Gateway API resources under
`spec.rules[].mutate[].ingress`. Use [class mutations](#classes) to supply class
names and [ListenerSet mutations](#listenersets) to configure Gateway references
in selected Tenant namespaces.

| Mutation | Resource | Field | Operations |
|---|---|---|---|
| [`types` and `class`](#classes) | `networking.k8s.io/v1` Ingress or `gateway.networking.k8s.io/v1` Gateway | `spec.ingressClassName` or `spec.gatewayClassName` | Main-resource `CREATE` and `UPDATE` |
| [`listenerSets.parentRef`](#parent-reference) | `gateway.networking.k8s.io/v1` ListenerSet | `spec.parentRef` | Main-resource `CREATE` and `UPDATE` |

**Gateway API v1 is the primary supported API.** All Gateway API examples here
use `gateway.networking.k8s.io/v1`. When installed CRDs also serve `v1beta1`
Gateways, those requests receive the same class mutation. ListenerSet parent
reference mutation uses the `v1` API.

## Classes {#classes}

Configure `ingress.types` together with `ingress.class` to set a class name:

| Field | Behavior |
|---|---|
| `types` | Required with `class`. Select `Ingress`, `Gateway`, or both. |
| `class` | Required with `types`. A non-empty class name, optionally using Tenant/Namespace rule templates. |

For an Ingress, Capsule sets `spec.ingressClassName`. For a Gateway, it sets
`spec.gatewayClassName`. These mutations apply on main-resource creation and
updates. Deletes and status or other subresource updates are skipped.

The `types` field selects the resources for the `class` mutation.
`listenerSets.parentRef` selects ListenerSets independently and does not use
this list. Use separate entries to give Ingresses and Gateways different class
names or mutation actions.

### Default classes by namespace profile

This Tenant supplies different defaults to its private and public namespaces,
then restricts the resulting class references with
[class enforcement](/docs/rules/enforcement/network/#classes):

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
          exposure: private
      mutate:
        - action: merge
          ingress:
            types: [Ingress, Gateway]
            class: internal
      enforce:
        action: allow
        ingress:
          types: [Ingress, Gateway]
          classes:
            - exact: [internal, custom]
    - namespaceSelector:
        matchLabels:
          exposure: public
      mutate:
        - ingress:
            types: [Ingress, Gateway]
            class: public
      enforce:
        action: allow
        ingress:
          types: [Ingress, Gateway]
          classes:
            - exact: [public]
```

In a private namespace, a class that is still absent or empty when mutation
runs becomes `internal`; an explicit `custom` class is preserved and allowed.
In a public namespace, a missing class becomes `public`. The IngressClass and GatewayClass objects are
separate resources even when their names are the same. Create the required
classes and configure their controllers separately; Capsule supplies the
reference without creating or checking the class object.

Namespaces without either label receive no default from these rules, and other
Tenants are outside their scope. An `enforce.action` applies only to enforcement;
the mutation entry has its own independent `action`.

### Merge and replace {#class-merge-and-replace}

| Action | Behavior |
|---|---|
| `merge` (default) | Fill an absent or empty class. Preserve a non-empty class supplied in the native field or the legacy Ingress annotation. |
| `replace` | Set the configured native class field on every matching write, overwriting an existing value. If the legacy Ingress annotation exists, update it to the same name. |

Merge preserves values already supplied by Kubernetes or an earlier defaulting
webhook. For example, a cluster default IngressClass already present in
`spec.ingressClassName` is retained. If that preserved name is outside the
configured class allow-list, admission is denied. With a legacy annotation
alone, merge preserves the annotation and leaves an absent native class field
unset.

To set a class regardless of an existing choice, use `replace`:

```yaml
mutate:
  - action: replace
    ingress:
      types: [Ingress, Gateway]
      class: internal
```

Replacement synchronizes an existing `kubernetes.io/ingress.class` annotation;
it does not add that annotation when it is absent. Every resulting class must
still pass namespace rules, legacy Tenant class restrictions, and native API
validation. A default alone does not restrict explicit choices; add class
enforcement when required.

### Templates, order, and conditions {#class-order-and-conditions}

Class names support Tenant/Namespace rule templates. For example:

```yaml
mutate:
  - ingress:
      types: [Gateway]
      class: "{{ .tenant.metadata.name }}-edge"
```

The rendered class name must be a valid DNS subdomain. Configure `types` and
`class` together; an empty class name is invalid.

Entries run in their effective order. The first matching merge supplies a
missing class; later merges preserve it. A later replacement can override it.
Use [audience](/docs/rules/#audience) to select requesting subjects and
[mutation conditions](/docs/rules/#mutation-conditions) to select individual
resources. Conditions inspect the object after preceding mutations; a false
condition skips only its entry. Conditions under `enforce` do not gate class
mutation.

### Rule and namespace changes {#class-changes}

Rule changes and namespace label changes update the defaults used for subsequent
admissions. They do not rewrite existing Ingresses or Gateways. Merge preserves
a class already set on a later update; replace applies the current class on the
next matching main-resource write.

## ListenerSets

Install Gateway API CRDs and a Gateway controller supporting
`gateway.networking.k8s.io/v1` ListenerSets before using these examples. Other
resource kinds, deletes, and status or other subresource updates do not apply
this mutation. A ListenerSet has one
`spec.parentRef`; Route resources use a separate `spec.parentRefs` list.

### Parent reference

`listenerSets.parentRef` supplies a default Gateway reference for ListenerSets,
or replaces that reference on every matching write.

#### Default a Gateway reference

Give namespaces within a Tenant different Gateway defaults with
`namespaceSelector`. This example sends ListenerSets in namespaces labeled
`exposure: public` to `public-edge` and those labeled `exposure: private` to
`private-edge`:

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
          exposure: public
      mutate:
        - ingress:
            listenerSets:
              parentRef:
                name: public-edge
                namespace: platform-gateways
    - namespaceSelector:
        matchLabels:
          exposure: private
      mutate:
        - ingress:
            listenerSets:
              parentRef:
                name: private-edge
                namespace: platform-gateways
```

`action` defaults to `merge`. Namespaces without either label receive no default
from these rules. Namespaces in other Tenants are outside their scope.

In a `solar-production` namespace belonging to `solar` and labeled
`exposure: public`, a tenant owner can submit a ListenerSet without a parent:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: ListenerSet
metadata:
  name: web
  namespace: solar-production
spec:
  listeners:
    - name: http
      hostname: web.solar.example.com
      port: 80
      protocol: HTTP
```

Capsule adds the following reference before validation and persistence:

```yaml
spec:
  parentRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: public-edge
    namespace: platform-gateways
```

An explicitly supplied `parentRef` is retained with `merge`. This is a default,
so users can choose a different reference. Gateway attachment remains subject
to [attachment permissions](#attachment-permissions).

#### Reference fields

Configure the complete parent reference under `ingress.listenerSets.parentRef`:

| Field | Required | Behavior |
|---|---|---|
| `name` | Yes | Name of the parent Gateway. Must be a valid DNS subdomain. |
| `namespace` | No | Namespace of the parent. Omitted means the ListenerSet's own namespace. An explicit empty string is invalid. |
| `group` | No | Defaults to `gateway.networking.k8s.io`. |
| `kind` | No | Defaults to `Gateway`. |

The `group` and `kind` defaults can also be written explicitly. An explicit empty
`group` selects the core API group, following Gateway API reference semantics;
it does not select the default Gateway group. The Gateway controller determines
which parent kinds it supports.

Reference fields support the existing Tenant/Namespace rule templates. For
example, set the Tenant label
`networking.example.com/default-gateway-namespace: platform-gateways` and use
this rule fragment to select a Gateway named after the Tenant:

```yaml
mutate:
  - ingress:
      listenerSets:
        parentRef:
          name: "{{ .tenant.metadata.name }}-edge"
          namespace: '{{ index .tenant.metadata.labels "networking.example.com/default-gateway-namespace" }}'
```

Template source strings can contain up to 4096 characters, including expressions
longer than a Kubernetes namespace name. Templates are rendered into the effective
RuleStatus for each namespace. Rendered values must pass validation before the
rule becomes ready: namespaces and kinds are limited to 63 characters, and
names and API groups to 253 characters. Rendered namespaces must be valid DNS
labels; the larger source limit does not relax that requirement.

#### Merge and replace

The action applies to the complete reference, including its namespace:

| Action | Behavior |
|---|---|
| `merge` (default) | Set `spec.parentRef` only when it is absent or `null`. Preserve any supplied reference, including one with an omitted namespace. |
| `replace` | Replace the entire `spec.parentRef` with the configured reference. An omitted namespace in the rule removes an existing namespace and selects the ListenerSet's own namespace. |

Merge does not fill individual fields in an existing reference. For example,
`parentRef: {name: custom-edge}` still refers to a Gateway in the ListenerSet's
own namespace even if the rule supplies `namespace: platform-gateways`. An invalid supplied reference
remains subject to Gateway API validation; merge does not repair it or fall back
when a referenced Gateway is missing.

Omitting `parentRef` in the rule, or setting it to `null`, supplies no mutation.
An empty `parentRef: {}` is invalid because `name` is required. An entry must
supply at least one mutation property.

To set the same reference on every matching creation or update, use `replace`:

```yaml
mutate:
  - action: replace
    ingress:
      listenerSets:
        parentRef:
          name: public-edge
          namespace: platform-gateways
```

#### Order and conditions

Applicable rules retain their effective order, and mutation entries run in list
order. The first matching merge fills a missing reference; later merges preserve
it. A later replacement can override it. Put specific merge defaults before a
shared fallback when their selectors overlap.

Use [audience](/docs/rules/#audience) to select requesting subjects and
[mutation conditions](/docs/rules/#mutation-conditions) to select individual
ListenerSets. This fragment supplies a private Gateway for objects labeled
`exposure: private`, then a public fallback for other objects without a parent:

```yaml
mutate:
  - conditions:
      - name: private-listener
        expression: >-
          has(object.metadata.labels) &&
          'exposure' in object.metadata.labels &&
          object.metadata.labels.exposure == 'private'
    ingress:
      listenerSets:
        parentRef:
          name: private-edge
          namespace: platform-gateways
  - ingress:
      listenerSets:
        parentRef:
          name: public-edge
          namespace: platform-gateways
```

Conditions inspect the object after preceding mutations. A false condition
skips only its entry. Workload-only mutation conditions are not evaluated for
ListenerSet requests. Conditions under `enforce` do not control these mutations,
and `enforce.action` does not select or disable them.

#### Attachment permissions

Capsule supplies the reference without reading or creating the Gateway. It does
not check that the parent exists or grant attachment permissions. The Gateway's
`spec.allowedListeners` must permit ListenerSets from the selected namespaces,
including when the Gateway is in a platform namespace outside the Tenant.

For a managed Gateway and tenant-owned listeners, see
[Envoy Gateway: Tenant ListenerSets](/ecosystem/integrations/envoy-gateway/#tenant-listenersets).
Combine this mutation with [ingress hostname enforcement](/docs/rules/enforcement/network/#ingress)
to restrict listener hostnames; mutated resources still pass through enforcement.
Metadata rules can also apply to the same ListenerSets: select
`apiGroups: [gateway.networking.k8s.io/v1]` and `kinds: [ListenerSet]` in the
[metadata rule](/docs/rules/enforcement/metadata/#target-resources).

#### Rule and namespace changes

Rule and namespace label changes update the effective profile for subsequent
admissions. They do not change the parent of existing ListenerSets.
With `merge`, a ListenerSet that already has a parent keeps it on later updates,
even after its default changes. If the parent is removed on an update, the
currently applicable default is inserted. With `replace`, the reference is
updated on the next matching main-resource write.
