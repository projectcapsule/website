---
title: Known Metadata
weight: 10
description: "Labels and Annotations in Capsule Items"
---




## Labels

Labels commonly used in Capsule items are listed below. These labels are applied to the corresponding resources by the Capsule controller and can be used for filtering and selection purposes.

### `capsule.clastix.io/tenant`

| Description | Target Objects | Audience |
|---|---|---|
| Established the connection between Object and Tenant. It's value indicates the owning `Tenant` | * `Namespaces` having a relationship to `Tenants` |  `Controller` |


### `projectcapsule.dev/tenant`

| Description | Target Objects |Audience |
|---|---|---|
| Established the connection between Object and Tenant. It's value indicates the owning `Tenant`. Long term replacement for `capsule.clastix.io/tenant` and `capsule.clastix.io/managed-by` labels. | * All namespaced items within a `Tenant` `Namespace` become the corresponding Tenant Label via Mutating Admission. | `Controller` |

### `capsule.clastix.io/managed-by`

| Description | Target Objects | Audience |
|---|---|---|
| Established the connection between Object and Tenant. It's value indicates the owning `Tenant`. Long term replacement for `capsule.clastix.io/tenant` | * All namespaced items within a `Tenant` `Namespace` become the corresponding Tenant Label via Mutating Admission. This label is still added to keep compatibility wiht the [Capsule Proxy](/docs/proxy/). | `User` |

### `projectcapsule.dev/managed-by`

| Description | Target Objects |
|---|---|---|
| Indicator which controller of capsule or `Custom Resource` is responsible for managing the corresponding Object. Mainly used in [Replications](/docs/replications/) to establish that objects are at least managed by one Replications. | * `Any Object being influenced by Replications` | `User` |


### `projectcapsule.dev/created-by`

| Description | Target Objects | Audience |
|---|---|
| Indicator which controller of capsule or `Custom Resource` is responsible for managing the corresponding Object. Mainly used in [Replications](/docs/replications/) to establish that objects were originally created by a Replication. | * `Any Object being influenced by Replications` | `Controller` |

### `projectcapsule.dev/name`

| Description | Target Objects | Audience |
|---|---|---|
| Label for tracking internal name or allowing for faster selects. Mainly used to identify relevant rulestatus | * `Tenant Namespaces` | `Controller` |

### `projectcapsule.dev/cordoned`

| Description | Target Objects |  Audience |
|---|---|---|
| Indicator that a namespace is cordoned (when value equals `true`) | * `Tenant Namespaces` | `User` |

### `projectcapsule.dev/pool`

| Description | Target Objects |  Audience |
|---|---|---|
| Allocation of Resourcepool via ResourcePoolClaims | * `ResourcePoolClaims` | `User` |
