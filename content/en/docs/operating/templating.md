---
title: Templating
weight: 10
description: "Templating in Capsule Items"
---


## Fast Templates

For simple template cases we provide a fast templating engine. With this engine, you can use Go templates syntax to reference Tenant and Namespace fields. There are no operators or anything else supported.

Available fields are:

  * `{{tenant.name}}`: The Name of the Tenant
  * `{{namespace}}`: The Name of the Tenant


## Sprout Templating

Our template library is mainly based on the upstream implementation from Sprout. You can find the all available functions here:

* [https://docs.atom.codes/sprout/registries/list-of-all-registries](https://docs.atom.codes/sprout/registries/list-of-all-registries)

We have removed certain functions which could exploit runtime information. Therefor the following functions are not available:

  * `env`
  * `expandEnv`

### Data

You can provide structured data for each `Tenant` which can be used in templating:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  data:
    bool: true
    foo: bar
    list:
    - a
    - b
    number: 123
    obj:
      nested: value
```

### Custom Functions

Custom Functions we provide in our template package.

#### deterministicUUID

`deterministicUUID` generates a deterministic, RFC-4122–compliant UUID (version 5 + RFC4122 variant) from a set of input strings. It is designed for use in templates where you need stable, repeatable IDs derived from meaningful inputs (e.g. cluster name, tenant, role name), instead of random UUIDs.

This is especially useful for:

  * Crossplane / IaC resources that must not change IDs across reconciles

The function takes any number of strings and turns them into a UUID in a fully deterministic way.

What that means in practice:

* If you call it twice with the same values, you get the same UUID
* If any input changes, the UUID changes too
* There is no randomness involved
* The output is always a valid UUID

So from the outside, it behaves just like a normal UUID — just deterministic.

```go
deterministicUUID(parts ...string) string
```

Example usage:

```yaml
{{ deterministicUUID "cluster-a" "app-123" "tenant-x" "some-role" }}
```