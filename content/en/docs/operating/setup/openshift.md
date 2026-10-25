---
title: OpenShift
weight: 15
description: >
  How to install Capsule and the Capsule Proxy on OpenShift
---

## Introduction

This guide shows how to deploy Capsule and the Capsule Proxy on OpenShift with a single Helm chart and one OpenShift toggle, so workloads run under the OpenShift SCCs. It also covers the recommended tenant settings to keep OpenShift-managed metadata protected, and optional customizations of the OpenShift Console.

## Why Capsule on OpenShift

Capsule and OpenShift complement each other. Capsule brings the tenancy model, with rules and policy enforcement for tenants. OpenShift provides the native security boundaries through [SecurityContextConstraint (SCC)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/authentication_and_authorization/managing-pod-security-policies).

- **Tenancy model (Capsule):** tenant owners can create as many namespaces as they need, and Capsule manages the RBAC for them. Resource quotas are spread across the whole tenant instead of being set per namespace, and rules enforce which metadata, resources and settings tenants may use.
- **Security boundaries (OpenShift):** SCCs control what the workloads of a tenant are allowed to do, such as the user they run as and the privileges they can request. Tenant owners only get the SCCs you grant them, so they stay within OpenShift's security boundaries.

The [Capsule Proxy](/docs/proxy/) extends this model. It solves RBAC issues when listing cluster-wide resources, and it allows some operators to be installed inside a tenant: add the service account as a tenant owner and set the `KUBERNETES_SERVICE_HOST` environment variable of the operator deployment to the Capsule Proxy URL. The operator then behaves as if it has cluster-admin access, while remaining fully confined to the tenant.

## Limitations

The following limitations are known when using OpenShift with Capsule:

- A tenant owner cannot create a namespace/project in the OpenShift GUI. This must be done with `kubectl`.

- When copying the `login token` from the OpenShift GUI, the server address will always point to the Kubernetes API instead of the Capsule Proxy, so the `--server` flag has to be adjusted manually. Browser-based `oc login --web` against the Capsule Proxy works without this workaround.

## Prerequisites

Before starting, ensure you have:

- OpenShift cluster with cluster-admin privileges
- `kubectl` CLI configured
- Helm 3.x installed
- cert-manager installed (for example the `cert-manager Operator for Red Hat OpenShift`)

## Capsule Installation

### Remove the self-provisioners ClusterRoleBinding

By default, OpenShift includes a self-provisioner role and ClusterRoleBinding that allows all users to create namespaces. This is recommended to be disabled. For more information about this rolebinding, see the [Red Hat documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/2/html/building_applications/projects#disabling-project-self-provisioning_configuring-project-creation).

To disable the rolebinding, follow the following steps:
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
- The SCCs that tenant owners can use (in this example, `restricted-v3`, `restricted-v2` and `nonroot-v2`).

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
      - restricted-v3
      - restricted-v2
      - nonroot-v2
    verbs:
      - 'use'
```

### Helm Chart Values

A single set of values configures Capsule, the OpenShift specific settings and the Capsule Proxy. The proxy is a dependency of the Capsule chart, so it is configured under the `proxy` key. Each part is explained in the sections below.

```yaml
# values.yaml
global:
  openshift:
    enabled: true # Default: false. See OpenShift Toggle
    requiredScc: restricted-v2 # Default: restricted-v2. Recommended are restricted-v2 and restricted-v3

openshift:
  etcdEncryption:
    enabled: true # Default: false. Enable if etcd encryption is enabled. See etcd Encryption chapter

proxy:
  enabled: true # Default: false. See Capsule Proxy chapter
  options:
    extraArgs:
      - "--feature-gates=ProxyClusterScoped=true" # Default: false. See ProxyClusterScoped and OpenShift Projects
  ingress:
    enabled: true # Default: false
    annotations:
      route.openshift.io/termination: "reencrypt"
      route.openshift.io/destination-ca-certificate-secret: capsule-proxy-root-secret # Depends on release name. If something else is used then "capsule", rename this.
    hosts:
      - host: "capsule-proxy.example.com" # Set the desired domain for the Capsule Proxy.
        paths: ["/"]
```

Install the chart with these values:

```bash
helm upgrade --install capsule oci://ghcr.io/projectcapsule/charts/capsule --create-namespace -n capsule-system --version {{< capsule_chart_version >}} -f values.yaml
```

### OpenShift Toggle

The Capsule chart has a global OpenShift toggle, `global.openshift.enabled`, which configures everything OpenShift needs in one go. When enabled, it:

- Omits the `securityContext` and `podSecurityContext` of the Capsule controller and all jobs, so the SCC assigns the UID, fsGroup and SELinux level.

- Adds the `openshift.io/required-scc` annotation to all pods. The value is `restricted-v2` by default and can be changed with `global.openshift.requiredScc`.

- Sets `hostUsers: false` on all pods when `global.openshift.requiredScc` is `restricted-v3`. This SCC enforces user namespaces and is available since OpenShift 4.20.

The option is global, so the Capsule Proxy dependency inherits it (see [Capsule Proxy](#capsule-proxy)).

The security contexts are only omitted when they are not configured explicitly. To keep a security context on OpenShift, set its `enabled` value explicitly (for example `securityContext.enabled: true` for the controller, or `jobs.securityContext.enabled: true` for the jobs).

### etcd Encryption

If etcd encryption is enabled on your OpenShift cluster and you are using `TenantResource` or `GlobalTenantResource` to replicate `ConfigMap` or `Secret` resources, the Capsule replication webhook must be configured to skip requests from OpenShift's storage version migrator. Without this exclusion, the migrator, which iterates over all Secrets and ConfigMaps to rotate the encryption key, will be blocked or cause reconciliation errors, because the webhook intercepts its requests.

Enable the exclusion with `openshift.etcdEncryption.enabled` in the [Helm Chart Values](#helm-chart-values). It adds an exclusion for the `system:serviceaccount:openshift-kube-storage-version-migrator:kube-storage-version-migrator-sa` service account to the replication webhook.

Note in advanced configurations: The exclusion is rendered as an explicit `matchCondition`. When explicit match conditions are set on a webhook, the generated `capsule-user-gate` is not created. If you clear `webhooks.hooks.replications.matchConditions` and enable `webhooks.hooks.replications.opts.capsuleUsers` or `webhooks.hooks.replications.opts.administrators`, the chart refuses to render with `openshift.etcdEncryption.enabled`. Set explicit match conditions for the replication webhook in that case.

### Example Tenant and TenantOwners

A minimal example tenant looks like the following:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  permissions:
    matchOwners:
      - matchLabels:
          team: devops
  priorityClasses:
    allowed:
      - openshift-user-critical
  rules:
    - audience:
        - kind: Custom
          name: "CapsuleUser"
      enforce:
        action: deny
        metadata:
          - kinds:
              - "Namespace"
            labels:
              ".*openshift.io/.*":
                required: false
              "pod-security.kubernetes.io/enforce":
                required: false
            annotations:
              ".*openshift.io/.*":
                required: false
              "pod-security.kubernetes.io/enforce":
                required: false
```

{{% alert title="Block openshift labels and annotations" color="warning" %}}
Make sure that CapsuleUsers cannot modify OpenShift-managed labels and annotations. These metadata fields should be mutable only by OpenShift-managed components. For example, modifying the openshift.io/run-level label on a namespace can allow a user to bypass SecurityContextConstraints and create privileged workloads. Similarly, the openshift.io/sa.scc.uid-range annotation controls important SecurityContextConstraints configuration and must not be user-modifiable. The pod-security.kubernetes.io/enforce label should also be protected because it is managed by OpenShift based on the SCCs. See the [Red Hat documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/authentication_and_authorization/managing-pod-security-policies#security-context-constraints-about_configuring-internal-oauth) for more information.
{{% /alert %}}

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

This tenant is only a starting point. For further configuration of a tenant, see the [Quickstart](/docs/quickstart/) and the [Best Practices](/docs/operating/best-practices/), which include a [complete Tenant baseline](/docs/operating/best-practices/tenants/). More information about tenants and tenant owners can be found in the chapter [Tenants](/docs/tenants/).

## Capsule Proxy

The Capsule Proxy is installed as a dependency of the Capsule chart, under the `proxy` key. Because `global.openshift.enabled` is a global value, the proxy inherits it and no OpenShift specific proxy configuration is needed. When enabled, the proxy:

- Omits its (pod)SecurityContexts and those of its jobs, so the configured SCC applies.
- Gets the `openshift.io/required-scc` annotation and, with `restricted-v3`, `hostUsers: false`, using the same `global.openshift.requiredScc` value as Capsule.
- Gets the option `--public-paths=/.well-known/oauth-authorization-server` added to its arguments.

The public path allows `oc login --web` to be used against the Capsule Proxy. The `oc login --web` flow retrieves the OAuth server metadata from `/.well-known/oauth-authorization-server` on the API endpoint before any credentials exist. Since Capsule Proxy requires authentication on every request, this lookup is rejected by default and the login aborts with `unsupported protocol scheme ""`. Public paths solve this: requests to a public path are proxied to the upstream API server without authentication, while everything else keeps requiring one.

The `proxy` values in the [Helm Chart Values](#helm-chart-values) enable the proxy and expose it through an OpenShift Route with `reencrypt` termination. The certificates are generated by cert-manager, which is the default.

### ProxyClusterScoped and OpenShift Projects

The `ProxyClusterScoped` feature gate is enabled in the [Helm Chart Values](#helm-chart-values) through `proxy.options.extraArgs`. It allows tenant users to list cluster-scoped resources that are granted through a `GlobalProxySettings`. OpenShift `Projects` are the equivalent of Kubernetes `Namespaces`, and it's recommended to create a `GlobalProxySettings` for `Projects` so users can list those as well.

```yaml
apiVersion: capsule.clastix.io/v1beta1
kind: GlobalProxySettings
metadata:
  name: openshift-projects
spec:
  rules:
  - subjects:
    - kind: Group
      name: oidc:org:devops:a
    clusterResources:
    - apiGroups:
      - "project.openshift.io"
      resources:
      - "projects"
      operations:
      - List
      selector:
        matchLabels:
            capsule.clastix.io/tenant: solar
```

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
  name: namespaced-consolelink-solar
spec:
  text: "solar Docs"
  href: "https://linktothesolardocs.com"
  location: "NamespaceDashboard"
  namespaceDashboard:
    namespaceSelector:
      matchExpressions:
        - key: capsule.clastix.io/tenant
          operator: In
          values:
            - solar
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
