---
title: ProxySettings
description: >
  Configure proxy settings for your tenants
date: 2024-02-20
weight: 4
---





#### Primitives

> Namespaces are treated specially. A users can list the namespaces they own, but they cannot list all the namespaces in the cluster. You can't define additional selectors.

Primitives are strongly considered for tenants, therefor 


The proxy setting kind is an enum accepting the supported resources:

| **Enum** | **Description** | **Effective Operations** |
| --- | --- | --- |
| `Tenant` | Users are able to `LIST` this tenant | - `LIST` |
| `StorageClasses` | Perform operations on the [allowed StorageClasses](/docs/tenants/enforcement/#storageclasses) for the tenant | - `LIST` |




  * **Nodes**: Based on the [NodeSelector](/docs/tenants/enforcement/#nodeselector) and the Scheduling Expressions nodes can be listed
  * **[StorageClasses](/docs/tenants/enforcement/#storageclasses)**: Perform actions on the allowed StorageClasses for the tenant
  * **[IngressClasses](/docs/tenants/enforcement/#ingressclasses)**: Perform actions on the allowed IngressClasses for the tenant
  * **[PriorityClasses](/docs/tenants/enforcement/#priorityclasses)**: Perform actions on the allowed PriorityClasses for the tenant
  PriorityClasses
  * **[RuntimeClasses](/docs/tenants/enforcement/#runtimeclasses)**: Perform actions on the allowed RuntimeClasses for the tenant
  * **[PersistentVolumes](/docs/tenants/enforcement/#persistentvolumes)**: Perform actions on the PersistentVolumes owned by the tenant

	GatewayClassesProxy    ProxyServiceKind = "GatewayClasses"
	TenantProxy            ProxyServiceKind = "Tenant"


Each Resource kind can be granted with several verbs, such as:

  * `List`
  * `Update`
  * `Delete`



#### Cluster Scopes

This approach is for more generic cluster scoped resources. 


TBD



## Proxy Settings



## Tenants

The Capsule Proxy is a multi-tenant application. Each tenant is a separate instance of the Capsule Proxy. The tenant is identified by the `tenantId` in the URL. The `tenantId` is a unique identifier for the tenant. The `tenantId` is used to identify the tenant in the Capsule Proxy.

