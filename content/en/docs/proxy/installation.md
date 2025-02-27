---
title: Installation
description: >
  Installation guide for the capsule-proxy
date: 2017-01-05
weight: 1
---
Capsule Proxy is an optional add-on of the main Capsule Operator, so make sure you have a working instance of Capsule before attempting to install it. Use the capsule-proxy only if you want Tenant Owners to list their Cluster-Scope resources.

The capsule-proxy can be deployed in standalone mode, e.g. running as a pod bridging any Kubernetes client to the APIs server. Optionally, it can be deployed as a sidecar container in the backend of a dashboard.

We only support the installation via helm-chart, you can find the chart here:

* [https://artifacthub.io/packages/helm/capsule-proxy/capsule-proxy](https://artifacthub.io/packages/helm/capsule-proxy/capsule-proxy)

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

### Distribute CA within the Cluster

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


