---
title: OpenShift
weight: 15
description: >
  How to install Capsule and the Capsule Proxy on OpenShift
---

## Introduction

Capsule is a Kubernetes multi-tenancy operator that enables secure namespace-as-a-service in Kubernetes clusters. When combined with OpenShift's robust security model, it provides an excellent platform for multi-tenant environments.

This guide demonstrates how to deploy Capsule and Capsule Proxy on OpenShift using the `nonroot-v2` and `restricted-v2` [SecurityContextConstraint (SCC)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/authentication_and_authorization/managing-pod-security-policies), ensuring tenant owners operate within OpenShift's security boundaries.

## Why Capsule on OpenShift
While OpenShift can already be configured for multi-tenancy (for example with Kyverno), Capsule takes it a step further and makes it easier to manage.

When people think of a multi-tenant Kubernetes cluster, they often expect one or two namespaces with few privileges. Capsule, however, is different. As a tenant owner, you can create as many namespaces as you want. RBAC is much easier because Capsule handles it, making it less error-prone. Resource quotas are not set per namespace but are spread across the whole tenant, simplifying management. Capsule Proxy also solves RBAC issues when listing cluster-wide resources. Furthermore, some operators can be installed inside a tenant by using the [Capsule Proxy](/docs/proxy/): add the service account as a tenant owner and set the `KUBERNETES_SERVICE_HOST` environment variable of the operator deployment to the Capsule Proxy URL. The operator then behaves as if it has cluster-admin access, while remaining fully confined to the tenant.

## Prerequisites
Before starting, ensure you have:
- OpenShift cluster with cluster-admin privileges
- `kubectl` CLI configured
- Helm 3.x installed
- cert-manager installed

## Limitations
The following limitations are known when using OpenShift with Capsule:
- A tenant owner cannot create a namespace/project in the OpenShift GUI. This must be done with `kubectl`.
- When copying the `login token` from the OpenShift GUI, the server address will always point to the Kubernetes API instead of the Capsule Proxy. An RFE has been filed with Red Hat to make this URL configurable ([RFE-7592](https://issues.redhat.com/browse/RFE-7592)). If you have a support contract with Red Hat, consider opening a support request (SR) asking for this feature. The more requests there are, the higher the priority.

## Capsule Installation
### Remove the self-provisioners ClusterRoleBinding
By default, OpenShift includes a self-provisioner role and ClusterRoleBinding that allows all users to create namespaces. Capsule requires this to be removed. See the [Red Hat documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/building_applications/projects#disabling-project-self-provisioning_configuring-project-creation) for details.

Remove the subjects from the ClusterRoleBinding:
```shell
kubectl patch clusterrolebinding.rbac self-provisioners -p '{"subjects": null}'
```
Also set `autoupdate` to false so the ClusterRoleBinding is not reverted by OpenShift.
```shell
kubectl patch clusterrolebinding.rbac self-provisioners -p '{ "metadata": { "annotations": { "rbac.authorization.kubernetes.io/autoupdate": "false" } } }'
```

### Extend the admin role
This example extends the default Kubernetes `admin` role so tenant owners gain admin privileges on all namespaces within their tenant. The extension adds:
- The finalizers required to create/edit resources managed by Capsule
- The SCCs that tenant owners can use — in this example, `restricted-v2` and `nonroot-v2`

```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: extend-admin-role
  labels:
    rbac.authorization.k8s.io/aggregate-to-admin: 'true'
rules:
  - verbs:
      - update
    apiGroups:
      - capsule.clastix.io
    resources:
      - '*/finalizers'
  - apiGroups:
      - security.openshift.io
    resources:
      - securitycontextconstraints
    resourceNames:
      - restricted-v2
      - nonroot-v2
    verbs:
      - 'use'
```

### Helm Chart Values
The jobs that Capsule uses can be run with the `restricted-v2` SCC, so their `securityContext` and `podSecurityContext` must be disabled. For Capsule itself, they are left enabled because Capsule runs as `nonroot-v2`, which is still a very secure SCC. Always set `pullPolicy: Always` on a multi-tenant cluster to ensure the intended images are used.
The following chart values can be used:
```yaml
  podSecurityContext:
    enabled: true
  securityContext:
    enabled: true
  jobs:
    podSecurityContext:
      enabled: false
    securityContext:
      enabled: false
    image:
      pullPolicy: Always
  manager:
    image:
      pullPolicy: Always
```
Deploy the Capsule Helm chart with (at least) these values.

### Example Tenant and TenantOwners

A minimal example tenant looks like the following:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: sun
spec:
  imagePullPolicies:
    - Always
  permissions:
    matchOwners:
      - matchLabels:
          team: devops
  priorityClasses:
    allowed:
      - openshift-user-critical
```

Combined with a `TenantOwner` resource to grant access to the tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: TenantOwner
metadata:
  labels:
    team: devops
  name: devops
spec:
  kind: Group
  name: "oidc:org:devops:a"
```

More information about tenants and tenant owners can be found in the chapter [Tenants](/docs/tenants/).

## Capsule Proxy
For Capsule Proxy, all (pod)SecurityContexts can be disabled. By disabling these, the proxy and its jobs run under the `nonroot-v2` SCC.
This example also enables the `ProxyAllNamespaced` feature, which is one of the Proxy's most powerful capabilities.
The following helm values can be used as a template:

```yaml
  global:
    jobs:
      kubectl:
        securityContext:
          enabled: false
  securityContext:
    enabled: false
  podSecurityContext:
    enabled: false
  options:
    generateCertificates: false #set to false, since we are using cert-manager in .Values.certManager.generateCertificates
    enableSSL: true
    extraArgs:
      - '--feature-gates=ProxyAllNamespaced=true'
  image:
    pullPolicy: Always
  webhooks:
    enabled: true
  certManager:
    generateCertificates: true
  ingress:
    enabled: true
    annotations:
      route.openshift.io/termination: "reencrypt"
      route.openshift.io/destination-ca-certificate-secret: capsule-proxy-root-secret
    hosts:
      - host: "capsule-proxy.example.com"
        paths: ["/"]
```
That is all the configuration needed for Capsule Proxy.

## Console Customization
The OpenShift console can be customized. For example, the capsule-proxy can be added as a shortcut on the top right application menu with the `ConsoleLink` CR:
```yaml
apiVersion: console.openshift.io/v1
kind: ConsoleLink
metadata:
  name: capsule-proxy-consolelink
spec:
  applicationMenu:
    imageURL: 'https://github.com/projectcapsule/capsule/raw/main/assets/logo/capsule.svg'
    section: 'Capsule'
  href: 'https://capsule-proxy.example.com'
  location: ApplicationMenu
  text: 'Capsule Proxy Kubernetes API'
```
It's also possible to add links specific for certain namespaces, which are shown on the Namespace/Project overview. These can also be tenant specific by adding a NamespaceSelector:
```yaml
apiVersion: console.openshift.io/v1
kind: ConsoleLink
metadata:
  name: namespaced-consolelink-sun
spec:
  text: "Sun Docs"
  href: "https://linktothesundocs.com"
  location: "NamespaceDashboard"
  namespaceDashboard:
    namespaceSelector:
      matchExpressions:
        - key: capsule.clastix.io/tenant
          operator: In
          values:
            - sun
```
Also a custom logo can be provided, for example by adding the Capsule logo.

**Add** these config lines to the existing `cluster` CR `Console`.
```shell
kubectl create configmap console-capsule-logo --from-file capsule-logo.png -n openshift-config
```
```yaml
apiVersion: operator.openshift.io/v1
kind: Console
metadata:
  name: cluster
spec:
  customization:
    customLogoFile:
      key: capsule-logo.png
      name: console-capsule-logo
    customProductName: Capsule OpenShift Cluster
```

# Conclusion
You now have a fully configured Capsule and Capsule Proxy installation on OpenShift, including console customizations, and the environment is ready to hand off to development teams.
