---
title: Mutate
weight: 2
description: >
  Set resource properties during admission with typed mutations
---

Use `spec.rules[].mutate` to set resource properties during admission. It is an
ordered list of entries, each with an optional `action` and a typed resource
block. Currently, `workloads` is supported and applies to Pods on creation.

`mutate` and [`enforce`](/docs/rules/enforcement/) are sibling keys. Mutation
changes the resource; enforcement validates the result. Either can be used alone,
and mutated values remain subject to applicable enforcement policies.

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
mutate:
  - action: merge
    workloads:
      nodeSelector:
        kubernetes.io/os: linux
  - action: replace
    workloads:
      tolerations:
        - key: infrastructure.example.com/dedicated
          operator: Equal
          value: shared
          effect: NoSchedule
```

This retains other node-selector keys, but replaces the entire tolerations list.
Other admission controllers can subsequently add tolerations.

Replacement happens at the supplied property's boundary. For example,
`nodeSelector` is replaced as one map and `affinity` as one object, including
all its branches. The [scheduling reference](/docs/rules/mutate/workloads/#scheduling)
explains which list entries match during a merge and how required affinity is
combined.

### Omitted and empty values

| Value in the mutation | Effect |
|---|---|
| Property omitted or `null` | Leave the existing property unchanged with either action. |
| Empty map, list, or `affinity: {}` with `replace` | Clear that property. |
| `hostUsers: false` | Set an explicit Boolean value; `false` is not an omission. |

For example, this clears node selectors and affinity while retaining tolerations
and topology-spread constraints:

```yaml
mutate:
  - action: replace
    workloads:
      nodeSelector: {}
      affinity: {}
```

## Workloads

See [Workloads](/docs/rules/mutate/workloads/) for workload configuration and
property behavior:

- [Configure workload mutations](/docs/rules/mutate/workloads/#configure-workload-mutations).
- [Configure scheduling](/docs/rules/mutate/workloads/#scheduling).
- [Default a scheduler with a condition](/docs/rules/mutate/workloads/#default-a-scheduler-with-a-condition).
- [Configure security](/docs/rules/mutate/workloads/#security).
- [Combine mutation and enforcement in a Tenant](/docs/rules/mutate/workloads/#complete-placement-example).
