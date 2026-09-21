---
title: Conditions
weight: 8
description: >
  Apply typed resource blocks conditionally using Boolean CEL expressions
---

Conditions determine whether a typed workload or service block applies to the
current admission request. They are optional and belong inside the resource
block, allowing workload and service settings in the same rule to have
independent conditions.

| Location | Scope |
|---|---|
| `mutate[].workloads.conditions` | That entry's workload mutations on Pod creation. |
| `enforce.workloads.conditions` | That rule's workload policies, including existing resource request/limit mutations. |
| `enforce.services.conditions` | That rule's Service enforcement. |

A Service request never evaluates workload conditions. A false workload
condition does not skip service, ingress, metadata, or other rules. Existing
namespace selection and audience filtering apply before these conditions.

## Expressions

Each entry has an `expression` containing one Boolean CEL expression and an
optional `name` used in error messages. Names must be unique within a block and
use a DNS label of up to 63 characters. A block supports up to 64 conditions;
each expression can contain up to 4096 characters and has a bounded evaluation
cost. Expressions are compiled when rules are validated and cached for reuse.

| Variable | Meaning |
|---|---|
| `object` | The current Pod or Service, using its Kubernetes field structure. |
| `request` | Admission metadata, such as `operation`, `namespace`, `name`, `userInfo`, `kind`, `resource`, `subResource`, and `dryRun`. Raw objects and admission options are not exposed here. |

Check absent fields with `has`, and map membership with `in`. For example:

```yaml
conditions:
  - name: missing-os-selector
    expression: |
      !has(object.spec.nodeSelector) ||
      !('kubernetes.io/os' in object.spec.nodeSelector)
```

The Pod node selector is at `object.spec.nodeSelector`; it is not a container
property. Use `request.userInfo` for request identity, while keeping existing
`audience` settings for straightforward subject selection.

## Evaluation

- No conditions means the block applies.
- All conditions must return true for the block to apply. Use `||` within an expression for alternatives.
- Any false condition skips the block, including when another condition produces an error.
- If none is false, an evaluation error rejects admission and identifies the condition.
- Invalid syntax and non-Boolean expressions are rejected when saving the rule. Templated expressions are checked after rendering into the namespace's RuleStatus.

Mutation entries run in order. Each block's conditions see the object after
preceding mutation entries and before any changes from their own entry. Thus,
an unconditional entry that sets `nodeSelector` makes a later check for an
absent `nodeSelector` false. Check a specific key when that is the intended gate.
Existing metadata and resource request/limit mutations run before the ordered
workload mutation entries. Enforcement checks the resulting admission object.

On Pod updates, conditional placement enforcement is reevaluated even when only
labels or another condition input changes. Pod workload mutation still applies
only on creation. Conditions do not expand a block's supported operations or
subresources.

## Independent resource conditions

```yaml
enforce:
  action: deny
  workloads:
    conditions:
      - name: restricted-pods
        expression: |
          has(object.metadata.labels) &&
          'example.com/restricted' in object.metadata.labels &&
          object.metadata.labels['example.com/restricted'] == 'true'
    nodeSelector:
      - key: {exact: [infrastructure.example.com/pool]}
        values: {exact: [dedicated]}
  services:
    conditions:
      - name: external-traffic
        expression: object.spec.type == 'NodePort'
    types: [NodePort]
```

This rule denies the selected node-selector entry on matching Pods and denies
NodePort Services independently. Skipping a block removes only that block from
the existing ordered allow/deny/audit evaluation.

## Find the failing entry

A mutation condition error includes its location and optional condition name:

```text
rules[0].mutate[1].workloads: conditions[0] ("shared-pool"): ...
```

Indices are zero-based within the effective rules and mutation entries evaluated
for this request. Inspect the namespace's effective RuleStatus and its audience
selection when tracing a rendered rule back to its source. A condition gates the
whole workload block, rather than a single property.

Mutation errors identify the affected property where applicable. For example,
an affinity merge that exceeds the term limit identifies
`affinity: nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution` together
with the rule and mutation indices. Workload and Service enforcement condition
errors identify their resource block, enforcement rule index, and condition.
