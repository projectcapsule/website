---
title: Templating
weight: 10
description: "Templating in Capsule Items"
---

## Fast Templates

For simple template cases we provide a fast templating engine. With this engine, you can use Go templates syntax to reference Tenant and Namespace fields. There are no operators or anything else supported.

Available fields are:

  * `{{tenant.name}}`: The Name of the Tenant
  * `{{namespace}}`: The Name of the namespace within the tenant (current context)


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

## Function Library

Custom Functions we provide in our template package.

### deterministicUUID

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

### generateAgeKey

`generateAgeKey` generates a new age X25519 key pair for use with [`age`](https://github.com/FiloSottile/age). It returns both the private identity and the public recipient key.

This is useful in templates where a resource needs to create an age-compatible encryption identity, for example when generating Kubernetes Secrets that are later used for encrypting or decrypting data.

This is especially useful for:

  * Bootstrap secrets that need an age identity
  * Generating encryption keys during initial provisioning
  * Creating age recipient keys for systems that need to encrypt data for a generated identity

The function does **not** return a plain string. It returns an object with two fields:

* `Identity` — the private age identity, e.g. `AGE-SECRET-KEY-1...`
* `Recipient` — the public age recipient, e.g. `age1...`

What that means in practice:

* Each call generates a new key pair
* The identity is the private key and must be treated as secret
* The recipient is the public key and can be shared with systems that need to encrypt data
* The output is not deterministic
* Calling this function during every reconcile may rotate the generated key unless the result is persisted

```go
generateAgeKey() any
```

Example usage:

```yaml
{{ $key := generateAgeKey }}
apiVersion: v1
kind: Secret
metadata:
  name: age-key
type: Opaque
stringData:
  identity: {{ $key.Identity | quote }}
  recipient: {{ $key.Recipient | quote }}
```

Output:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: age-key
type: Opaque
stringData:
  identity: "AGE-SECRET-KEY-1..."
  recipient: "age1..."
```

Because this function creates a new random key pair on every call, it should usually only be used when the generated Secret is created once and then reused. For continuously reconciled resources, prefer generating the key in controller logic and persisting it before using it in templates.


### generateAgePQKey

`generateAgePQKey` generates a new age post-quantum hybrid key pair for use with [`age`](https://github.com/FiloSottile/age). It returns both the private identity and the public recipient key.

This is useful in templates where a resource needs to create an age-compatible encryption identity using the newer hybrid recipient format.

This is especially useful for:

  * Bootstrap secrets that should use age hybrid keys
  * Generating encryption keys during initial provisioning
  * Creating public recipient keys for systems that need to encrypt data for a generated hybrid identity
  * Future-facing age encryption setups where hybrid keys are preferred

The function does **not** return a plain string. It returns an object with two fields:

* `Identity` — the private age hybrid identity, e.g. `AGE-SECRET-KEY-PQ-1...`
* `Recipient` — the public age recipient, e.g. `age1...`

What that means in practice:

* Each call generates a new key pair
* The identity is the private key and must be treated as secret
* The recipient is the public key and can be shared with systems that need to encrypt data
* The output is not deterministic
* Calling this function during every reconcile may rotate the generated key unless the result is persisted

```go
generateAgePQKey() any
```

Example Usage:

```yaml
{{ $key := generateAgePQKey }}
apiVersion: v1
kind: Secret
metadata:
  name: age-pq-key
type: Opaque
stringData:
  identity: {{ $key.Identity | quote }}
  recipient: {{ $key.Recipient | quote }}
```

Output:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: age-pq-key
type: Opaque
stringData:
  identity: "AGE-SECRET-KEY-PQ-1..."
  recipient: "age1..."
```

Because this function creates a new random key pair on every call, it should usually only be used when the generated Secret is created once and then reused. For continuously reconciled resources, prefer generating the key in controller logic and persisting it before using it in templates.
