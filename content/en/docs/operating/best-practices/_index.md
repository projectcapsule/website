---
title: Best Practices
weight: 2
description: Best Practices when running Capsule in production 
---


This is general advice you should consider before making Kubernetes Distribution consideration. They are partly relevant for Multi-Tenancy with Capsule.

### Authentication

User authentication for the platform should be handled via a central OIDC-compatible identity provider system (e.g., Keycloak, Azure AD, Okta, or any other OIDC-compliant provider).
The rationale is that other central platform components — such as ArgoCD, Grafana, Headlamp, or Harbor — should also integrate with the same authentication mechanism. This enables a unified login experience and reduces administrative complexity in managing users and permissions.

[Capsule relies on native Kubernetes RBAC](/docs/operating/authentication/), so it's important to consider how the Kubernetes API handles user authentication.

### OCI Pull-Cache

By default, Kubernetes clusters pull images directly from upstream registries like `docker.io`, `quay.io`, `ghcr.io`, or `gcr.io`. In production environments, this can lead to issues — especially because Docker Hub enforces rate limits that may cause image pull failures with just a few nodes or frequent deployments (e.g., when pods are rescheduled).

To ensure availability, performance, and control over container images, it's essential to provide an on-premise OCI mirror.
This mirror should be configured via the CRI (Container Runtime Interface) by defining it as a mirror endpoint in registries.conf for default registries (e.g., `docker.io`).
This way, all nodes automatically benefit from caching without requiring developers to change image URLs.

### Secrets Management

In more complex environments with multiple clusters and applications, managing secrets manually via YAML or Helm is no longer practical.
Instead, a centralized secrets management system should be established — such as Vault, AWS Secrets Manager, Azure Key Vault, or the CNCF project [OpenBao](https://openbao.org/) (formerly the Vault community fork).

To integrate these external secret stores with Kubernetes, the [External Secrets Operator (ESO)](https://external-secrets.io/latest/) is a recommended solution. It automatically syncs defined secrets from external sources as Kubernetes secrets, and supports dynamic rotation, access control, and auditing.

If no external secret store is available, there should at least be a secure way to store sensitive data in Git.
In our ecosystem, we provide a solution based on SOPS (Secrets OPerationS) for this use case.

[👉 Demonstration](https://killercoda.com/peakscale/course/playgrounds/sops-secrets)

