---
title: Installation
description: >
  Installation guide for the capsule-proxy
date: 2017-01-05
weight: 4
---
Capsule Proxy is an optional add-on of the main Capsule Operator, so make sure you have a working instance of Capsule before attempting to install it. Use the capsule-proxy only if you want Tenant Owners to list their Cluster-Scope resources.

The capsule-proxy can be deployed in standalone mode, e.g. running as a pod bridging any Kubernetes client to the APIs server. Optionally, it can be deployed as a sidecar container in the backend of a dashboard.

Running outside a Kubernetes cluster is also viable, although a valid KUBECONFIG file must be provided, using the environment variable KUBECONFIG or the default file in $HOME/.kube/config.

A Helm Chart is available here.

## Exposure

Depending on your environment, you can expose the capsule-proxy by:

 * `Ingress`
 * `NodePort Service`
 * `LoadBalance Service`
 * `HostPort`
 * `HostNetwork`

Here how it looks like when exposed through an Ingress Controller:

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