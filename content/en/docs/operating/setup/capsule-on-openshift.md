---
title: Capsule on OpenShift
weight: 30
description: >
  How to install Capsule and the Capsule Proxy on OpenShift
---

## Introduction

Capsule is a Kubernetes multi-tenancy operator that enables secure namespace-as-a-service in Kubernetes clusters. When combined with OpenShift's robust security model, it provides an excellent platform for multi-tenant environments.

This guide demonstrates how to deploy Capsule and Capsule Proxy on OpenShift using the `nonroot-v2` and `restricted-v2` SecurityContextConstraint [SecurityContextConstraint (SCC)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/authentication_and_authorization/managing-pod-security-policies), ensuring tenant owners operate within OpenShift's security boundaries.

## Why Capsule on OpenShift
While OpenShift can be already configured to be quite multi-tenant (together with for example Kyverno), Capsule takes it a step further and easier to manage.

When people say a multitenant kubernetes cluster, they often think they will get one or two namespaces inside a cluster, with not that much privileges. But: Capsule is different. As a tenant owner, you can create as many namespaces as you want. RBAC is much easier, since Capsule is handling it, making it less error-prone. And resource quota is not set per namespace, but it's spread across a whole tenant, making management easy. Not to mention RBAC issues while listing clusterwide resources that are solved by the Capsule Proxy. Also, even some operators are able to be installed inside a tenant because of the [Capsule Proxy](./docs/proxy). Add the service account as a tenant owner, and set the env variable `KUBERNETES_SERVICE_HOST` of the operator deployment to the capsule proxy url. Now your operator thinks it is admin, but it lives completely inside the tenant.

## Prerequisites
Before starting, ensure you have:
- OpenShift cluster with cluster-admin privileges
- `kubectl` CLI configured
- Helm 3.x installed
- cert-manager installed

## Limitations
There are a few limitations that are currently known of using OpenShift with Capsule:
- A tenant owner can not create a namespace/project in the OpenShift GUI. This must be done with `kubectl`.
- When copying the `login token` from the OpenShift GUI, there will always be the server address of the kubernetes api instead of the Capsule Proxy. There is a RFE created at Red Hat to make this url configurable ([RFE-7592](https://issues.redhat.com/browse/RFE-7592)). If you have a support contract at Red Hat, it would be great to create a SR and ask that you would also like to have this feature to be implemented. The more requests there are, the more likely it will be implemented.

## Capsule Installation
### Remove selfprovisioners rolebinding
By default, OpenShift comes with a selfprovisioner role and rolebinding.  This role lets all users always create namespaces. For the use case of Capsule, this should be removed. The [Red Hat documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.16/html/building_applications/projects#disabling-project-self-provisioning_configuring-project-creation) can be found here.
Remove the subjects from the rolebinding:
```shell
kubectl patch clusterrolebinding.rbac self-provisioners -p '{"subjects": null}'
```
Also set the `autoupdate` to false, so the rolebinding doesn't get reverted by Openshift.
```shell
kubectl patch clusterrolebinding.rbac self-provisioners -p '{ "metadata": { "annotations": { "rbac.authorization.kubernetes.io/autoupdate": "false" } } }'
```

### Extend the admin role
In this example, we will add the default kubernetes `admin` role to the tenant owner, so it gets admin privileges on the namespaces that are in their tenant. This role should be extended.
- Add the finalizers so users can create/edit resources that are managed by capsule
- Add the SCC's that tenant owners can use. In this example, it is will be `restricted-v2` and `nonroot-v2`.

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

### Helm Chart values
The jobs that Capsule uses can be runned with the `restricted-v2` SCC. For this, the securityContext and podSecurityContexts of the job must be disabled. For Capsule it self, we leave it to enabled. This is because capsule runs as `nonroot-v2`, which is still a very secure SCC. Also, always add the `pullPolicy: Always` on a multitenant cluster, to make sure you are working with the correct images you intended to.
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

### Example tenant
A minimal example tenant can look as the following:
```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: sun
spec:
  imagePullPolicies:
    - Always
  owners:
    - clusterRoles:
        - admin
        - capsule-namespace-deleter
      kind: Group
      name: sun-admin-group
  priorityClasses:
    allowed:
      - openshift-user-critical
```

## Capsule Proxy
The same principles for Capsule are also for Capsule Proxy. That means, that all (pod)SecurityContexts should be disabled for the job.
In this example we enable the `ProxyAllNamespaced` feature, because that is one of the things where the Proxy really shines in its power.
The following helm values can be used as a template:
```yaml
  securityContext:
    enabled: true
  podSecurityContext:
    enabled: true
  options:
    generateCertificates: false #set to false, since we are using cert-manager in .Values.certManager.generateCertificates
    enableSSL: true
    extraArgs:
      - '--feature-gates=ProxyAllNamespaced=true'
      - '--feature-gates=ProxyClusterScoped=false'
  image:
    pullPolicy: Always
  global:
    jobs:
      kubectl:
        securityContext:
          enabled: true
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
That is basically all the configuration needed for the Capsule Proxy.

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
  href: 'capsule-proxy.example.com'
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
After this section, you have a ready to go Capsule and Capsule-Proxy setup configured on OpenShift with some nice customizations in the OpenShift console. All ready to go and to ship to the development teams!
