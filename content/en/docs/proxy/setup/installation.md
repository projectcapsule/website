---
title: Installation
description: >
  Installation guide for the capsule-proxy
date: 2017-01-05
weight: 1
---
Capsule Proxy is an optional add-on of the main Capsule Operator, so make sure you have a working instance of Capsule before attempting to install it. Use the capsule-proxy only if you want Tenant Owners to list their Cluster-Scope resources.

The capsule-proxy can be deployed in standalone mode, e.g. running as a pod bridging any Kubernetes client to the APIs server. Optionally, it can be deployed as a sidecar container in the backend of a dashboard.

We officially only support the installation of Capsule using the Helm chart. The chart itself handles the Installation/Upgrade of needed [CustomResourceDefinitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/). The following Artifacthub repository are official:

* [Artifacthub Page (OCI)](https://artifacthub.io/packages/helm/capsule-proxy/capsule-proxy)
* [Artifacthub Page (Legacy - Best Effort)](https://artifacthub.io/packages/helm/projectcapsule/capsule-proxy)

Perform the following steps to install the capsule Operator:

1. Add repository:

        helm repo add projectcapsule https://projectcapsule.github.io/charts

2. Install Capsule-Proxy:

        helm install capsule-proxy projectcapsule/capsule-proxy -n capsule-system --create-namespace

    or (**OCI**)

        helm install capsule-proxy oci://ghcr.io/projectcapsule/charts/capsule-proxy -n capsule-system --create-namespace

3. Show the status:

        helm status capsule-proxy -n capsule-system

4. Upgrade the Chart

        helm upgrade capsule-proxy projectcapsule/capsule-proxy -n capsule-system

    or (**OCI**)

        helm upgrade capsule-proxy oci://ghcr.io/projectcapsule/charts/capsule-proxy --version 0.13.0

5. Uninstall the Chart

        helm uninstall capsule-proxy -n capsule-system


## GitOps

There are no specific requirements for using Capsule with GitOps tools like ArgoCD or FluxCD. You can manage Capsule resources as you would with any other Kubernetes resource.

### ArgoCD

Visit the [ArgoCD Integration](/ecosystem/integrations/argocd/) for more options to integrate Capsule with ArgoCD.

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: capsule
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: system
  source:
    repoURL: ghcr.io/projectcapsule/charts
    targetRevision: {{< capsule_chart_version >}}
    chart: capsule
    helm:
      valuesObject:
        ...
        proxy:
          enabled: true
          webhooks:
            enabled: true
          certManager:
            generateCertificates: true
          options:
            generateCertificates: false
            oidcUsernameClaim: "email"
            extraArgs:
            - "--feature-gates=ProxyClusterScoped=true"
          serviceMonitor:
            enabled: true
            annotations:
              argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true

  destination:
    server: https://kubernetes.default.svc
    namespace: capsule-system

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - ServerSideApply=true
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    - RespectIgnoreDifferences=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
---
apiVersion: v1
kind: Secret
metadata:
  name: capsule-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  url: ghcr.io/projectcapsule/charts
  name: capsule
  project: system
  type: helm
  enableOCI: "true"
```

### FluxCD

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: capsule
  namespace: flux-system
spec:
  serviceAccountName: kustomize-controller
  targetNamespace: "capsule-system"
  interval: 10m
  releaseName: "capsule"
  chart:
    spec:
      chart: capsule
      version: "{{< capsule_chart_version >}}"
      sourceRef:
        kind: HelmRepository
        name: capsule
      interval: 24h
  install:
    createNamespace: true
  upgrade:
    remediation:
      remediateLastFailure: true
  driftDetection:
    mode: enabled
  values:
    proxy:
      enabled: true
      webhooks:
        enabled: true
      certManager:
        generateCertificates: true
      options:
        generateCertificates: false
        oidcUsernameClaim: "email"
        extraArgs:
        - "--feature-gates=ProxyClusterScoped=true"
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: capsule
  namespace: flux-system
spec:
  type: "oci"
  interval: 12h0m0s
  url: oci://ghcr.io/projectcapsule/charts
```

## Considerations

Considerations when deploying capsule-proxy

### Scalability

For large clusters you might need to consider adjusting values for the Capsule controller.

#### QPS/Burst

In order to handle a large number of tenants and resources, you may need to increase the QPS and Burst values for the Capsule-Proxy. This avoids the Proxy being throttled by the Kubernetes API server (Client Rate limited). You can set the following values in the Helm chart:

```yaml
options:
  # -- QPS to use for interacting with Kubernetes API Server.
  clientConnectionQPS: 200
  # -- Burst to use for interacting with kubernetes API Server.
  clientConnectionBurst: 400
```

#### API Priority and Fairness (APF)

With APF enabled, the Capsule controller will be subject to the APF configuration of the cluster. If you are running a large cluster with many users/tenants, you may need to adjust the APF configuration to ensure that the Capsule controller has sufficient resources to operate effectively. For more information on APF, see [Kubernetes API Priority and Fairness](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/apiserver-aggregation/#api-priority-and-fairness).

We provide a built-in APF configuration for the Capsule-Proxy, which provides API priority for all LIST operations and especially for `subjectaccessreviews` and `tokenreviews`. This configuration is applied automatically when you install Capsule-Proxy. To enable the built-in APF configuration, set the following value in the Helm chart:

```yaml
apiPriorityAndFairness:
  # -- Change to `true` if you want to insulate the API calls made by Capsule admission controller activities.
  # This will help ensure Capsule stability in busy clusters.
  # Ref: https://kubernetes.io/docs/concepts/cluster-administration/flow-control/
  enabled: true
  # -- Only the first matching FlowSchema for a given request matters. If multiple FlowSchemas match a single inbound request, it will be assigned based on the one with the highest matchingPrecedence.
  # Ref: https://kubernetes.io/docs/concepts/cluster-administration/flow-control/#flowschema
  matchingPrecedence: 900
  # -- Priority level configuration.
  # The block is directly forwarded into the priorityLevelConfiguration, so you can use whatever specification you want.
  # ref: https://kubernetes.io/docs/concepts/cluster-administration/flow-control/#prioritylevelconfiguration
  priorityLevelConfigurationSpec:
    type: Limited
    limited:
        nominalConcurrencyShares: 100
        limitResponse:
          type: Queue
          queuing:
            queues: 64
            handSize: 6
            queueLengthLimit: 100
```

### Exposure

Depending on your environment, you can expose the capsule-proxy by:

 * `Gateway API (Recommended)`
 * `Ingress (Recommended)`
 * `NodePort Service`
 * `LoadBalance Service`
 * `HostPort`
 * `HostNetwork`


#### Gateway API

If you are using a Gateway API compliant Ingress Controller, you must first make the decision, how TLS is terminiated or rather what's possible in your environment. We have two potential options.

##### Backend Termination (Recommended)

This is where the TLS termination is executed by the capsule-proxy, meaning that the Ingress Controller will just forward the encrypted traffic to the capsule-proxy, which will decrypt it and forward it to the Kubernetes API Server. In this way, the client certificate authentication will be preserved and reversed to the upstream.

1. On your Gateway, add a listener which allows to forward the encrypted traffic to the capsule-proxy (Pass-Through TLS):

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: service-gateway
  namespace: solar-system
spec:
  gatewayClassName: default
  listeners:
    - allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              kubernetes.io/metadata.name: capsule-system
      hostname: api.cluster-name.company.com
      name: https-capsule-proxy
      port: 443
      protocol: TLS
      tls:
        mode: Passthrough
```

2. Install a `TLSRoute` resource to forward the encrypted traffic to the capsule-proxy:

```yaml
extraManifests:
  - apiVersion: gateway.networking.k8s.io/v1
    kind: TLSRoute
    metadata:
      name: capsule-proxy-tls-route
      namespace: capsule-system
    spec:
      parentRefs:
        - name: service-gateway
          namespace: solar-system
          sectionName: https-capsule-proxy
      hostnames:
        - api.cluster-name.company.com
      rules:
        - backendRefs:
            - name: capsule-proxy
              port: 9001
```

##### Gateway Termination

{{% alert title="Support" color="warning" %}}
With Gateway Termination currently only [Bearer Token authentication](#bearer-token-authentication) is supported, meaning that users providing tokens are always able to reach the APIs Server. [Client certificate authentication](#client-certificate-authentication) is not supported in this scenario. If the Gateway must terminate, you must consider using [Forwarded Client Certificate Authentication (XFCC)](#forwarded-client-certificate-authentication-xfcc) if supported by your Gateway Controller.
{{% /alert %}}

When the Gateway is terminating we must ensure, that users use the corresponding CA/Serving Certificate in their Kubeconfigs. You must ensure that the CA certificate of the Gateway is distributed to the users, so they can use it to verify the identity of the capsule-proxy. In this way, the client certificate authentication will be withdrawn and not reversed to the upstream.

1. Just create a listener on the Gateway and Reference the TLS certificate. The following example uses the [cert-manager integration](https://cert-manager.io/docs/usage/gateway/):

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  annotations:
    cert-manager.io/cluster-issuer: cluster-service-issuer
    cert-manager.io/private-key-algorithm: RSA
    cert-manager.io/private-key-size: "4096"
  name: service-gateway
  namespace: solar-system
spec:
  gatewayClassName: default
  listeners:
    - allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              kubernetes.io/metadata.name: capsule-system
      hostname: api.cluster-name.company.com
      name: https-capsule-proxy
      port: 443
      protocol: HTTPS
      tls:
         certificateRefs:
         - group: ""
           kind: Secret
           name: capsule-proxy-tls
         mode: Terminate
```

#### Ingress

When using an Ingress Controller, you can expose the capsule-proxy through an Ingress resource. The Ingress Controller will handle the TLS termination and forward the requests to the capsule-proxy. The capsule-proxy will then forward the requests to the Kubernetes API Server.

```
                +-----------+          +-----------+         +-----------+
 kubectl ------>|:443       |--------->|:9001      |-------->|:6443      |
                +-----------+          +-----------+         +-----------+
                ingress-controller     capsule-proxy         kube-apiserver
```

You can use the Ingress Values provided in the Helm chart to configure the Ingress resource for the capsule-proxy:

```yaml
ingress:
  enabled: true
  className: "nginx" # or your ingress class name
  hosts:
    - host: capsule-proxy.company.com
      paths:
        - "/"
```

### User Authentication

The capsule-proxy intercepts all the requests from the kubectl client directed to the APIs Server. Users using a TLS client-based authentication with a certificate and key can talk with the API Server since it can forward client certificates to the Kubernetes APIs server. You can configure the capsule-proxy to use multiple authentication methods, for example, you can prefer Bearer Token authentication over TLS client-based authentication or use Forwarded Client Certificate Authentication (XFCC) if supported by your Ingress Controller. The following sections describe the supported authentication methods.

```yaml
options:
  authPreferredTypes: "BearerToken,TLSCertificate,XForwardedClientCert"
```


#### Bearer Token Authentication

Bearer Token authentication is supported by default, meaning that users providing tokens are always able to reach the APIs Server. You can configure the capsule-proxy to prefer Bearer Token authentication over TLS client-based authentication:

```yaml
options:
  authPreferredTypes: "BearerToken"
```

#### Client Certificate Authentication

It is possible to protect the capsule-proxy using a certificate provided by Let's Encrypt. Keep in mind that, in this way, the TLS termination will be executed by the Ingress Controller, meaning that the authentication based on the client certificate will be withdrawn and not reversed to the upstream. For such cases you may want to rely on the token-based authentication, for example, OIDC or Bearer tokens. Users providing tokens are always able to reach the APIs Server or consider using the [Forwarded Client Certificate Authentication (XFCC)](#forwarded-client-certificate-authentication-xfcc) if supported by your Ingress Controller.

```yaml
options:
  authPreferredTypes: "TLSCertificate"
```

#### Forwarded Client Certificate Authentication (XFCC)

It is possible to protect the capsule-proxy using a certificate provided by Let's Encrypt. Keep in mind that, in this way, the TLS termination will be executed by the Ingress Controller, meaning that the authentication based on the client certificate will be withdrawn and not reversed to the upstream.

If your prerequisite is exposing capsule-proxy using an Ingress, you must rely on the token-based authentication, for example, OIDC or Bearer tokens. Users providing tokens are always able to reach the APIs Server.

```yaml
options:
  authPreferredTypes: "XForwardedClientCert"
```

By default the HTTP-Header used for the client certificate is `X-Forwarded-Client-Cert`, but it can be customized using the `--xfcc-header-name` argument:

```yaml
options:
  authPreferredTypes: "XForwardedClientCert"
  extraArgs:
    - "--xfcc-header-name=X-My-Custom-Client-Cert"
```

### Trusted Sources

CIDR ranges of trusted proxies allowed to send forwarded client certificate headers:

```yaml
options:
  extraArgs:
    - "--trusted-proxy-cidrs=10.0.0.0/8"
    - "--trusted-proxy-cidrs=127.0.0.1/32"
```

### Certificate Management

By default, Capsule delegates its certificate management to cert-manager. This is the recommended way to manage the TLS certificates for Capsule.This relates to certifiacates for the proxy and the admissions server. However, you can also use a job to generate self-signed certificates and store them in a Kubernetes Secret:

```yaml
options:
  generateCertificates: true
certManager:
  generateCertificates: false
```

#### Distribute CA within the Cluster

The capsule-proxy requires the CA certificate to be distributed to the clients. The CA certificate is stored in a Secret named `capsule-proxy` in the `capsule-system` namespace, by default. In most cases the distribution of this secret is required for other clients within the cluster (e.g. the Tekton Dashboard). If you are using Ingress or any other endpoints for all the clients, this step is probably not required.

Here's an example of how to distribute the CA certificate to the namespace `tekton-pipelines` by using `kubectl` and `jq`:

```shell
 kubectl get secret capsule-proxy -n capsule-system -o json \
 | jq 'del(.metadata["namespace","creationTimestamp","resourceVersion","selfLink","uid"])' \
 | kubectl apply -n tekton-pipelines -f -
```

This can be used for development purposes, but it's not recommended for production environments. Here are solutions to distribute the CA certificate, which might be useful for production environments:

 * [Kubernetes Reflector](https://github.com/EmberStack/kubernetes-reflector)

##### External Secrets (ESO)

How to distribute the CA certificate using External Secrets Operator (ESO). In the following example we have `Headlamp` running in a different namespace and we want to distribute the CA certificate to it.

First allow ServiceAccount `headlamp` to read the Secret `capsule-proxy` in the `capsule-system` namespace:

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: headlamp:capsule-proxy-ca-reader
  namespace: capsule-system
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["capsule-proxy"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: headlamp:capsule-proxy-ca-reader
  namespace: capsule-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: headlamp:capsule-proxy-ca-reader
subjects:
  - kind: ServiceAccount
    name: headlamp
    namespace: dashboard-system
```

Create ExternalSecret to sync the Secret `capsule-proxy` from the `capsule-system` namespace to the `dashboard-system` namespace:

```yaml
---
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: capsule-proxy-ca
  namespace: dashboard-system
spec:
  provider:
    kubernetes:
      remoteNamespace: capsule-system
      server:
        url: https://kubernetes.default.svc
        caProvider:
          type: ConfigMap
          name: kube-root-ca.crt
          key: ca.crt
      auth:
        serviceAccount:
          name: headlamp
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: capsule-proxy-ca
  namespace: dashboard-system
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: capsule-proxy-ca
  target:
    name: capsule-proxy-ca
    creationPolicy: Owner
  data:
    - secretKey: ca.crt
      remoteRef:
        key: capsule-proxy
        property: ca.crt
```

### HTTP Support

> NOTE: kubectl will not work against a http server.

Capsule proxy supports `https` and `http`, although the latter is not recommended, we understand that it can be useful for some use cases (i.e. development, working behind a TLS-terminated reverse proxy and so on). As the default behaviour is to work with https, we need to use the flag --enable-ssl=false if we want to work under http.

After having the capsule-proxy working under http, requests must provide authentication using an allowed Bearer Token.

For example:

```shell
TOKEN=<type your TOKEN>
curl -H "Authorization: Bearer $TOKEN" http://localhost:9001/api/v1/namespaces
```

### Metrics

Starting from the v0.3.0 release, Capsule Proxy exposes Prometheus metrics available at `http://0.0.0.0:8080/metrics`.

The offered metrics are related to the internal controller-manager code base, such as work queue and REST client requests, and the Go runtime ones.

Along with these, metrics capsule_proxy_response_time_seconds and capsule_proxy_requests_total have been introduced and are specific to the Capsule Proxy code-base and functionalities.

capsule_proxy_response_time_seconds offers a bucket representation of the HTTP request duration. The available variables for these metrics are the following ones:

path: the HTTP path of every single request that Capsule Proxy passes to the upstream
capsule_proxy_requests_total counts the global requests that Capsule Proxy is passing to the upstream with the following labels.

path: the HTTP path of every single request that Capsule Proxy passes to the upstream
status: the HTTP status code of the request
