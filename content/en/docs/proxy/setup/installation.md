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

Consdierations when deploying capsule-proxy

### Exposure

Depending on your environment, you can expose the capsule-proxy by:

 * `Ingress`
 * `NodePort Service`
 * `LoadBalance Service`
 * `HostPort`
 * `HostNetwork`

Here how it looks like when exposed through an Ingress Controller:

```
                +-----------+          +-----------+         +-----------+
 kubectl ------>|:443       |--------->|:9001      |-------->|:6443      |
                +-----------+          +-----------+         +-----------+
                ingress-controller     capsule-proxy         kube-apiserver
```

### User Authentication

The capsule-proxy intercepts all the requests from the kubectl client directed to the APIs Server. Users using a TLS client-based authentication with a certificate and key can talk with the API Server since it can forward client certificates to the Kubernetes APIs server.

It is possible to protect the capsule-proxy using a certificate provided by Let's Encrypt. Keep in mind that, in this way, the TLS termination will be executed by the Ingress Controller, meaning that the authentication based on the client certificate will be withdrawn and not reversed to the upstream.

If your prerequisite is exposing capsule-proxy using an Ingress, you must rely on the token-based authentication, for example, OIDC or Bearer tokens. Users providing tokens are always able to reach the APIs Server.

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


