---
title: Mutate
weight: 2
description: >
  Set resource properties during admission with typed mutations
---

Use `spec.rules[].mutate` to set resource properties during admission. It is an
ordered list of entries, each with an optional `action` and a typed resource
block. [`ingress.class`](/docs/rules/mutate/ingress/#classes) defaults or replaces
class references on Ingress and Gateway creation and updates.
[`ingress.listenerSets.parentRef`](/docs/rules/mutate/ingress/#listenersets) supplies
Gateway references on ListenerSet creation and updates. `workloads` applies to Pods on creation;
[`security.readOnlyRootFilesystem`](/docs/rules/mutate/workloads/#read-only-root-filesystem)
and [`registries.imagePullPolicy`](/docs/rules/mutate/workloads/#image-pull-policy)
also apply to newly added ephemeral containers.
[Mutation targets](/docs/rules/mutate/workloads/#targets) select compatible Pod
locations, with `pod` including all container groups.

`mutate` and [`enforce`](/docs/rules/enforcement/) are sibling keys. Mutation
changes the resource; enforcement validates the result. Either can be used alone,
and mutated values remain subject to applicable enforcement policies.

[DeviceClass defaults](/docs/rules/mutate/devices/) fill missing class names on
ResourceClaim and ResourceClaimTemplate creation in selected namespaces.

See [Order and scope](/docs/rules/#order-and-scope) for the admission sequence
and [Conditions](/docs/rules/#mutation-conditions) for conditional mutations.

## Action

Each `mutate` entry supports an `action` field:

| Action | Behavior |
|---|---|
| `merge` (default) | Apply supplied values while retaining unrelated settings. Map keys are set, list entries are added or updated, and affinity restrictions are combined according to the property's rules. |
| `replace` | Replace each supplied property in full. Other properties remain unchanged. |

The action applies to every property in that entry. Use separate entries when
properties need different actions:

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
                kubernetes.io/os: linux
        - action: replace
          workloads:
            placement:
              tolerations:
                - key: infrastructure.example.com/dedicated
                  operator: Equal
                  value: shared
                  effect: NoSchedule
```

This retains other node-selector keys, but replaces the entire tolerations list.
Other admission controllers can subsequently add tolerations.

Replacement happens at the supplied property's boundary. For example,
`placement.nodeSelector` is replaced as one map and `placement.affinity` as one object, including
all its branches. The [placement reference](/docs/rules/mutate/workloads/#placement)
explains which list entries match during a merge and how required affinity is
combined. Scalar settings such as `security.hostUsers`, `security.readOnlyRootFilesystem`, and
[`registries.imagePullPolicy`](/docs/rules/mutate/workloads/#image-pull-policy)
overwrite selected values with either action.
[`classes.priority`](/docs/rules/mutate/workloads/#priority-class) is assigned by
merge only when the Pod has no priority class of its own, and by replace always.
[Ingress and Gateway class names](/docs/rules/mutate/ingress/#class-merge-and-replace)
are scalar defaults: merge preserves a non-empty class, while replace sets the
configured name on every matching write.
[ListenerSet parent references](/docs/rules/mutate/ingress/#merge-and-replace) are
applied as complete references: merge fills only an absent or null reference,
while replace replaces it in full.
[DeviceClass defaults](/docs/rules/mutate/devices/#merge-behavior-and-order) support
only merge: they fill missing class names and preserve every explicit name.

### Omitted and empty values

| Value in the mutation | Effect |
|---|---|
| Property omitted or `null` | Leave the existing property unchanged with either action. |
| Empty `placement.nodeSelector`, `placement.tolerations`, `placement.topologySpreadConstraints`, `placement.affinity`, or `registries.imagePullSecrets` with `replace` | Clear that property. |
| Empty `placement: {}`, `security: {}`, `registries: {}`, `classes: {}`, `ingress: {}`, `ingress.listenerSets: {}`, or `devices: {}` | Supply no changes; another mutation property must be supplied. |
| Empty `ingress.listenerSets.parentRef: {}` | Invalid: `name` is required. |
| Empty `ingress.class: ""`, or `ingress.types` without a non-empty `ingress.class` | Invalid: configure the class name and its target kinds together. |
| `security.hostUsers: false` or `security.readOnlyRootFilesystem: false` | Set an explicit Boolean value; `false` is not an omission. |

For example, this clears node selectors and affinity while retaining tolerations
and topology-spread constraints:

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
              nodeSelector: {}
              affinity: {}
```
