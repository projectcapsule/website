---
title: Mutate
weight: 2
description: >
  Apply ordered changes to typed workload properties
---

Use `spec.rules[].mutate` to apply an ordered list of typed mutation entries.
`mutate` and [`enforce`](/docs/rules/enforcement/) are sibling keys: mutation
changes the Pod, then enforcement validates the result. Either can be used alone.

```yaml
spec:
  rules:
    - namespaceSelector:
        matchLabels:
          environment: production
      mutate:
        - action: merge
          workloads:
            hostUsers: false
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

This sets `hostUsers` and the OS selector while retaining other node-selector
keys, then replaces the entire tolerations list. `hostUsers: false` requests a
separate user namespace; see [runtime requirements](/docs/rules/mutate/workloads/#host-user-namespace).
Other admission controllers may subsequently add tolerations.

Choose an action for each entry:

| Action | Effect |
|---|---|
| `merge` (default) | Set the supplied Boolean and map keys, add or update matching list entries, and combine affinity restrictions. Existing unrelated entries remain. |
| `replace` | Replace each supplied workload property in full. Omitted properties remain unchanged. Explicit empty maps/lists clear the supplied property. |

The replacement boundaries are `hostUsers`, `nodeSelector`, `tolerations`,
`topologySpreadConstraints`, and `affinity`. In particular, replacing `affinity`
replaces all its branches, including branches omitted from the rule. See
[merge identities and replacement examples](/docs/rules/mutate/workloads/#choose-an-action)
before choosing an action for lists or affinity.

Entries run in list order within the existing rule order. Values use the same
namespace selection, audience filtering, and Tenant/Namespace templating as
other rules. Rules containing only `mutate` are included in effective RuleStatus.

Workload mutation applies to Pod creation, including Pods created by controllers.
It does not change controller templates or reconcile existing Pods. A rule can
contain up to 64 mutation entries. `enforce.action` independently determines
allow, deny, or audit behavior; mutated values must pass applicable enforcement.

## Optional conditions

Add `workloads.conditions` when an entry should apply only to some Pods. Most
mutations need no conditions. Each condition sees the current Pod immediately
before its entry, including changes from preceding entries.

```yaml
mutate:
  - action: merge
    workloads:
      conditions:
        - name: linux-pods
          expression: has(object.spec.os) && object.spec.os.name == 'linux'
      hostUsers: false
```

Resource selection is built into the typed `workloads` block, so conditions do
not need `kind` or `apiGroup`. Conditions choose whether the typed changes apply;
they cannot supply arbitrary patches or mutation values.

See [workloads](/docs/rules/mutate/workloads/) for all supported fields and a
complete Tenant example, and [conditions](/docs/rules/conditions/) for variables
and evaluation behavior.
