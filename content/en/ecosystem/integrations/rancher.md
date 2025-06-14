---
title: Rancher
logo: "https://www.rancher.com/assets/img/logos/rancher-suse-logo-stacked-color.svg"
type: single
display: true
integration: true
---

The integration between [Rancher](https://github.com/rancher/rancher) and Capsule, aims to provide a multi-tenant Kubernetes service to users, enabling:

* a self-service approach
* access to cluster-wide resources

to end-users.

Tenant users will have the ability to access Kubernetes resources through:

* Rancher UI
* Rancher Shell
* Kubernetes CLI
  
On the other side, administrators need to manage the Kubernetes clusters through Rancher.

Rancher provides a feature called Projects to segregate resources inside a common domain. At the same time Projects doesn't provide way to segregate Kubernetes cluster-scope resources.

Capsule as a project born for creating a framework for multi-tenant platforms, integrates with Rancher Projects enhancing the experience with Tenants.

Capsule allows tenants isolation and resources control in a declarative way, while enabling a self-service experience to tenants. With Capsule Proxy users can also access cluster-wide resources, as configured by administrators at Tenant custom resource-level.

You can read in detail how the integration works and how to configure it, in the following guides.

 * [How to integrate Rancher Projects with Capsule Tenants](#tenants-and-projects)
How to enable cluster-wide resources and Rancher shell access.

![capsule rancher addon](/images/content/capsule-rancher-addon.drawio.png)


## Tenants and Projects

This guide explains how to setup the integration between Capsule and Rancher Projects.

It then explains how for the tenant user, the access to Kubernetes resources is transparent.

### Pre-requisites

- An authentication provider in Rancher, e.g. an OIDC identity provider
- A *Tenant Member* `Cluster Role` in Rancher

#### Configure an identity provider for Kubernetes

You can follow [this general guide](/docs/operating/authentication/#oidc) to configure an OIDC authentication for Kubernetes.

For a Keycloak specific setup yon can check [this resources list](./oidc-keycloak.md).

#### Known issues

##### Keycloak new URLs without `/auth` makes Rancher crash

- [rancher/rancher#38480](https://github.com/rancher/rancher/issues/38480)
- [rancher/rancher#38683](https://github.com/rancher/rancher/issues/38683)

#### Create the Tenant Member Cluster Role

A custom Rancher `Cluster Role` is needed to allow Tenant users, to read cluster-scope resources and Rancher doesn't provide e built-in Cluster Role with this tailored set of privileges.

When logged-in to the Rancher UI as administrator, from the Users & Authentication page, create a Cluster Role named *Tenant Member* with the following privileges:

- `get`, `list`, `watch` operations over `IngressClasses` resources.
- `get`, `list`, `watch` operations over `StorageClasses` resources.
- `get`, `list`, `watch` operations over `PriorityClasses` resources.
- `get`, `list`, `watch` operations over `Nodes` resources.
- `get`, `list`, `watch` operations over `RuntimeClasses` resources.

### Configuration (administration)

#### Tenant onboarding

When onboarding tenants, the administrator needs to create the following, in order to bind the `Project` with the `Tenant`:

- In Rancher, create a `Project`.
- In the target Kubernetes cluster, create a `Tenant`, with the following specification:
  ```yaml
  kind: Tenant
  ...
  spec:
    namespaceOptions:
      additionalMetadata:
        annotations:
          field.cattle.io/projectId: ${CLUSTER_ID}:${PROJECT_ID}
        labels:
          field.cattle.io/projectId: ${PROJECT_ID}
  ```
  where `$CLUSTER_ID` and `$PROEJCT_ID` can be retrieved, assuming a valid `$CLUSTER_NAME`, as:

  ```shell
  CLUSTER_NAME=foo
  CLUSTER_ID=$(kubectl get cluster -n fleet-default ${CLUSTER_NAME} -o jsonpath='{.status.clusterName}')
  PROJECT_IDS=$(kubectl get projects -n $CLUSTER_ID -o jsonpath="{.items[*].metadata.name}")
  for project_id in $PROJECT_IDS; do echo "${project_id}"; done
  ```

  More on declarative `Project`s [here](https://github.com/rancher/rancher/issues/35631).
- In the identity provider, create a user with [correct OIDC claim](https://capsule.clastix.io/docs/guides/oidc-auth) of the Tenant.
- In Rancher, add the new user to the `Project` with the *Read-only* `Role`.
- In Rancher, add the new user to the `Cluster` with the *Tenant Member* `Cluster Role`.

#### Create the Tenant Member Project Role

A custom `Project Role` is needed to allow Tenant users, with minimum set of privileges and create and delete `Namespace`s.

Create a Project Role named *Tenant Member* that inherits the privileges from the following Roles:
- *read-only*
- *create-ns*


#### Usage

When the configuration administrative tasks have been completed, the tenant users are ready to use the Kubernetes cluster transparently.

For example can create Namespaces in a self-service mode, that would be otherwise impossible with the sole use of Rancher Projects.

#### Namespace creation

From the tenant user perspective both CLI and the UI are valid interfaces to communicate with.

#### From CLI

- Tenants `kubectl`-logs in to the OIDC provider
- Tenant creates a Namespace, as a valid OIDC-discoverable user.

the `Namespace` is now part of both the Tenant and the Project.

> As administrator, you can verify with:
>
> ```shell
> kubectl get tenant ${TENANT_NAME} -o jsonpath='{.status}'
> kubectl get namespace -l field.cattle.io/projectId=${PROJECT_ID}
> ```

#### From UI

- Tenants logs in to Rancher, with a valid OIDC-discoverable user (in a valid Tenant group).
- Tenant user create a valid Namespace

the `Namespace` is now part of both the Tenant and the Project.

> As administrator, you can verify with:
>
> ```shell
> kubectl get tenant ${TENANT_NAME} -o jsonpath='{.status}'
> kubectl get namespace -l field.cattle.io/projectId=${PROJECT_ID}
> ```

### Additional administration

#### Project monitoring

Before proceeding is recommended to read the official Rancher documentation about [Project Monitors](https://ranchermanager.docs.rancher.com/v2.6/how-to-guides/advanced-user-guides/monitoring-alerting-guides/prometheus-federator-guides/project-monitors).

In summary, the setup is composed by a cluster-level Prometheus, Prometheus Federator via which single Project-level Prometheus federate to.

#### Network isolation

Before proceeding is recommended to read the official Capsule documentation about [`NetworkPolicy` at `Tenant`-level](/docs/tenants/enforcement/#networkpolicies)`.

##### Network isolation and Project Monitor

As Rancher's Project Monitor deploys the Prometheus stack in a `Namespace` that is not part of **neither** the `Project` **nor** the `Tenant` `Namespace`s, is important to apply the label selectors in the `NetworkPolicy` `ingress` rules to the `Namespace` created by Project Monitor.

That Project monitoring `Namespace` will be named as `cattle-project-<PROJECT_ID>-monitoring`.

For example, if the `NetworkPolicy` is configured to allow all ingress traffic from `Namespace` with label `capsule.clastix.io/tenant=foo`, this label is to be applied to the Project monitoring `Namespace` too.

Then, a `NetworkPolicy` can be applied at `Tenant`-level with Capsule `GlobalTenantResource`s. For example it can be applied a minimal policy for the *oil* `Tenant`:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: oil-networkpolicies
spec:
  tenantSelector:
    matchLabels:
      capsule.clastix.io/tenant: oil
  resyncPeriod: 360s
  pruningOnDelete: true
  resources:
    - namespaceSelector:
        matchLabels:
          capsule.clastix.io/tenant: oil
      rawItems:
      - apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        metadata:
          name: oil-minimal
        spec:
          podSelector: {}
          policyTypes:
            - Ingress
            - Egress
          ingress:
            # Intra-Tenant
            - from:
              - namespaceSelector:
                  matchLabels:
                    capsule.clastix.io/tenant: oil
            # Rancher Project Monitor stack
            - from:
              - namespaceSelector:
                  matchLabels:
                    role: monitoring
            # Kubernetes nodes
            - from:
              - ipBlock:
                  cidr: 192.168.1.0/24
          egress:
            # Kubernetes DNS server
            - to:
              - namespaceSelector: {}
                podSelector:
                  matchLabels:
                    k8s-app: kube-dns
                ports:
                  - port: 53
                    protocol: UDP
            # Intra-Tenant
            - to:
              - namespaceSelector:
                  matchLabels:
                    capsule.clastix.io/tenant: oil
            # Kubernetes API server
            - to:
              - ipBlock:
                  cidr: 10.43.0.1/32
                ports:
                  - port: 443
```

## Capsule Proxy and Rancher Projects

This guide explains how to setup the integration between Capsule Proxy and Rancher Projects.

It then explains how for the tenant user, the access to Kubernetes cluster-wide resources is transparent.

### Rancher Shell and Capsule

In order to integrate the Rancher Shell with Capsule it's needed to route the Kubernetes API requests made from the shell, via Capsule Proxy.

The [capsule-rancher-addon](https://github.com/clastix/capsule-addon-rancher/tree/master/charts/capsule-rancher-addon) allows the integration transparently.

#### Install the Capsule addon

Add the Clastix Helm repository `https://clastix.github.io/charts`.

By updating the cache with Clastix's Helm repository a Helm chart named `capsule-rancher-addon` is available.

Install keeping attention to the following Helm values:

* `proxy.caSecretKey`: the `Secret` key that contains the CA certificate used to sign the Capsule Proxy TLS certificate (it should be`"ca.crt"` when Capsule Proxy has been configured with certificates generated with Cert Manager).
* `proxy.servicePort`: the port configured for the Capsule Proxy Kubernetes `Service` (`443` in this setup).
* `proxy.serviceURL`: the name of the Capsule Proxy `Service` (by default `"capsule-proxy.capsule-system.svc"` hen installed in the *capsule-system* `Namespace`).

### Rancher Cluster Agent

In both CLI and dashboard use cases, the [Cluster Agent](https://ranchermanager.docs.rancher.com/v2.5/how-to-guides/new-user-guides/kubernetes-clusters-in-rancher-setup/launch-kubernetes-with-rancher/about-rancher-agents) is responsible for the two-way communication between Rancher and the downstream cluster.

In a standard setup, the Cluster Agents communicates to the API server. In this setup it will communicate with Capsule Proxy to ensure filtering of cluster-scope resources, for Tenants.

Cluster Agents accepts as arguments:
- `KUBERNETES_SERVICE_HOST` environment variable
- `KUBERNETES_SERVICE_PORT` environment variable

which will be set, at cluster import-time, to the values of the Capsule Proxy `Service`. For example:
- `KUBERNETES_SERVICE_HOST=capsule-proxy.capsule-system.svc`
- (optional) `KUBERNETES_SERVICE_PORT=9001`. You can skip it by installing Capsule Proxy with Helm value `service.port=443`.

The expected CA is the one for which the certificate is inside the `kube-root-ca` `ConfigMap` in the same `Namespace` of the Cluster Agent (*cattle-system*).

### Capsule Proxy

[Capsule Proxy](docs/proxy/) needs to provide a x509 certificate for which the root CA is trusted by the Cluster Agent.
The goal can be achieved by, either using the Kubernetes CA to sign its certificate, or by using a dedicated root CA.

#### With the Kubernetes root CA

> Note: this can be achieved when the Kubernetes root CA keypair is accessible. For example is likely to be possibile with on-premise setup, but not with managed Kubernetes services.

With this approach Cert Manager will sign certificates with the Kubernetes root CA for which it's needed to be provided a `Secret`.

```shell
kubectl create secret tls -n capsule-system kubernetes-ca-key-pair --cert=/path/to/ca.crt --key=/path/to/ca.key
```

When installing Capsule Proxy with Helm chart, it's needed to specify to generate Capsule Proxy `Certificate`s with Cert Manager with an external `ClusterIssuer`:
- `certManager.externalCA.enabled=true`
- `certManager.externalCA.secretName=kubernetes-ca-key-pair`
- `certManager.generateCertificates=true`

and disable the job for generating the certificates without Cert Manager:
- `options.generateCertificates=false`

#### Enable tenant users access cluster resources

In order to allow tenant users to list cluster-scope resources, like `Node`s, Tenants need to be configured with proper `proxySettings`, for example:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: oil
spec:
  owners:
  - kind: User
    name: alice
    proxySettings:
    - kind: Nodes
      operations:
      - List
[...]
```

Also, in order to assign or filter nodes per Tenant, it's needed labels on node in order to be selected:

```shell
kubectl label node worker-01 capsule.clastix.io/tenant=oil
```

 and a node selector at Tenant level:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: oil
spec:
  nodeSelector:
    capsule.clastix.io/tenant: oil
[...]
```

The final manifest is:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: oil
spec:
  owners:
  - kind: User
    name: alice
    proxySettings:
    - kind: Node
      operations:
      - List
  nodeSelector:
    capsule.clastix.io/tenant: oil
```

The same appplies for:
- `Nodes`
- `StorageClasses`
- `IngressClasses`
- `PriorityClasses`

More on this in the [official documentation](https://capsule.clastix.io/docs/general/proxy#tenant-owner-authorization).


## Configure OIDC authentication with Keycloak

### Pre-requisites

- Keycloak realm for Rancher
- Rancher OIDC authentication provider

### Keycloak realm for Rancher

These instructions is specific to a setup made with Keycloak as an OIDC identity provider.

#### Mappers

- Add to userinfo Group Membership type, claim name `groups`
- Add to userinfo Audience type, claim name `client audience`
- Add to userinfo, full group path, Group Membership type, claim name `full_group_path`

More on this on the [official guide](/docs/operating/authentication/#oidc).

### Rancher OIDC authentication provider

Configure an OIDC authentication provider, with Client with issuer, return URLs specific to the Keycloak setup.

> Use old and Rancher-standard paths with `/auth` subpath (see issues below).
>
> Add custom paths, remove `/auth` subpath in return and issuer URLs.

### Configuration

#### Configure Tenant users

1. In Rancher, configure OIDC authentication with Keycloak to use [with Rancher](https://ranchermanager.docs.rancher.com/how-to-guides/new-user-guides/authentication-permissions-and-global-configuration/authentication-config/configure-keycloak-oidc).
1. In Keycloak, Create a Group in the rancher Realm: *capsule.clastix.io*.
1. In Keycloak, Create a User in the rancher Realm, member of *capsule.clastix.io* Group.
1. In the Kubernetes target cluster, update the `CapsuleConfiguration` by adding the `"keycloakoidc_group://capsule.clastix.io"` Kubernetes `Group`.
1. Login to Rancher with Keycloak with the new user.
1. In Rancher as an administrator, set the user  custom role with `get` of Cluster.
1. In Rancher as an administrator, add the Rancher user ID of the just-logged in user as Owner of a `Tenant`.
1. (optional) configure `proxySettings` for the `Tenant` to enable tenant users to access cluster-wide resources.

