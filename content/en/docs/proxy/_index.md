---
title: Proxy
weight: 6
description: >
  Improve the User-Experience with teh capsule-proxy
---

Capsule Proxy is an add-on for Capsule Operator addressing some RBAC issues when enabling multi-tenancy in Kubernetes since users cannot list the owned cluster-scoped resources. One solution to this problem would be to grant all users `LIST` permissions for the relevant cluster-scoped resources (eg. `Namespaces`). However, this would allow users to list all cluster-scoped resources, which is not desirable in a multi-tenant environment and may lead to security issues. Kubernetes RBAC cannot list only the owned cluster-scoped resources since there are no ACL-filtered APIs. For example:

```$ kubectl get namespaces
Error from server (Forbidden): namespaces is forbidden:
User "alice" cannot list resource "namespaces" in API group "" at the cluster scope
```

The reason, as the error message reported, is that the RBAC list action is available only at Cluster-Scope and it is not granted to users without appropriate permissions.

To overcome this problem, many Kubernetes distributions introduced mirrored custom resources supported by a custom set of ACL-filtered APIs. However, this leads to radically change the user's experience of Kubernetes by introducing hard customizations that make it painful to move from one distribution to another.

With Capsule, we took a different approach. As one of the key goals, we want to keep the same user experience on all the distributions of Kubernetes. We want people to use the standard tools they already know and love and it should just work.

## Integrations

Capsule Proxy is a strong addition for Capsule and works well with other [CNCF](https://landscape.cncf.io/) kubernetes based solutions. It allows any user facing solutions, which make impersonated requests as the users, to proxy the request and show the results Correctly.

{{< integrations >}}
