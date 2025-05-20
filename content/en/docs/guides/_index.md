---
title: Guides
description: Guides for using the Capsule and Capsule Proxy
weight: 11
---

Capsule does not care about the authentication strategy used in the cluster and all the Kubernetes methods of authentication are supported. The only requirement to use Capsule is to assign tenant users to the group defined by userGroups option in the CapsuleConfiguration, which defaults to capsule.clastix.io.

In the following guide, we'll use [Keycloak](https://www.keycloak.org/) an Open Source Identity and Access Management server capable to authenticate users via OIDC and release JWT tokens as proof of authentication.