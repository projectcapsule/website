---
title: Container Images
weight: 5
description: Multi-Tenant Container Images considerations
---

> [Until this issue is resolved (might be in Kubernetes 1.34)](https://github.com/kubernetes/enhancements/issues/2535)

it's recommended to use the [ImagePullPolicy](https://kubernetes.io/docs/concepts/containers/images/#image-pull-policy) `Always` for private registries on shared nodes. This ensures that no images can be used which are already pulled to the node.