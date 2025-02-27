---
title: Controller Options
description: >
  Configure the Capsule Proxy Controller
date: 2024-02-20
weight: 3
---

You can customize the Capsule Proxy with the following configuration

## Flags




## Feature Gates

Feature Gates are a set of key/value pairs that can be used to enable or disable certain features of the Capsule Proxy. The following feature gates are available:

| **Feature Gate** | **Default Value** | **Description** |
| :--- | :--- | :--- |
| `ProxyAllNamespaced` | `false` | `ProxyAllNamespaced` allows to proxy all the Namespaced objects. When enabled, it will discover apis and ensure labels are set for resources in all tenant namespaces resulting in increased memory. However this feature helps with user experience. |
| `SkipImpersonationReview` | `false` | `SkipImpersonationReview` allows to skip the impersonation review for all requests containing impersonation headers (user and groups). **DANGER:** Enabling this flag allows any user to impersonate as any user or group essentially bypassing any authorization. Only use this option in trusted environments where authorization/authentication is offloaded to external systems. |
| `ProxyClusterScoped` | `false` | `ProxyClusterScoped` allows to proxy all clusterScoped objects for all tenant users. These can be defined via [ProxySettings](/docs/integrations/capsule-proxy/proxysettings/#cluster-resources) |
