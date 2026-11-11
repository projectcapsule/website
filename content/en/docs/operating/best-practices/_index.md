---
title: Best Practices
weight: 2
description: Best Practices when running Capsule in production
---


This is general advice you should consider before making Kubernetes Distribution consideration. They are partly relevant for Multi-Tenancy with Capsule.

For a complete configuration combining the workload and networking policies,
see the [combined Tenant baseline](/docs/operating/best-practices/tenants/#reference).

### Authentication

User authentication for the platform should be handled via a central OIDC-compatible identity provider system (e.g., Keycloak, Azure AD, Okta, or any other OIDC-compliant provider).
The rationale is that other central platform components, such as ArgoCD, Grafana, Headlamp, or Harbor, should also integrate with the same authentication mechanism. This enables a unified login experience and reduces administrative complexity in managing users and permissions.

[Capsule relies on native Kubernetes RBAC](/docs/operating/setup/authentication/), so it's important to consider how the Kubernetes API handles user authentication.

### OCI Pull-Cache

By default, Kubernetes clusters pull images directly from upstream registries like `docker.io`, `quay.io`, `ghcr.io`, or `gcr.io`. In production environments, this can lead to issues, especially because Docker Hub enforces rate limits that may cause image pull failures with just a few nodes or frequent deployments (e.g., when pods are rescheduled).

To ensure availability, performance, and control over container images, it's essential to provide an on-premise OCI mirror.
This mirror should be configured via the CRI (Container Runtime Interface) by defining it as a mirror endpoint in registries.conf for default registries (e.g., `docker.io`).
This way, all nodes automatically benefit from caching without requiring developers to change image URLs.

### Secrets Management

In more complex environments with multiple clusters and applications, managing secrets manually via YAML or Helm is no longer practical.
Instead, a centralized secrets management system should be established, such as Vault, AWS Secrets Manager, Azure Key Vault, or the CNCF project [OpenBao](https://openbao.org/) (formerly the Vault community fork).

To integrate these external secret stores with Kubernetes, the [External Secrets Operator (ESO)](https://external-secrets.io/latest/) is a recommended solution. It automatically syncs defined secrets from external sources as Kubernetes secrets, and supports dynamic rotation, access control, and auditing.

If no external secret store is available, there should at least be a secure way to store sensitive data in Git.
In our ecosystem, we provide a solution based on SOPS (Secrets OPerationS) for this use case; called the [sops-operator](https://github.com/peak-scale/sops-operator).

[👉 Demonstration](https://killercoda.com/peakscale/course/playgrounds/sops-secrets)

### Block Static ServiceAccount Tokens

Use the TokenRequest API or projected ServiceAccount token volumes for Kubernetes
API access. Kubernetes recommends these credentials over legacy
`kubernetes.io/service-account-token` Secrets, which hold tokens that do not
expire automatically. See the Kubernetes [ServiceAccount token
documentation](https://kubernetes.io/docs/concepts/security/service-accounts/#manually-retrieve-serviceaccount-credentials).

Prevent new legacy token Secrets in Tenant namespaces with a
[metadata rule](/docs/rules/enforcement/metadata/) that denies the
`kubernetes.io/service-account.name` annotation required by that Secret type:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - kind: User
      name: solar-owner
  rules:
    - enforce:
        action: deny
        metadata:
          - apiGroups: [v1]
            kinds: [Secret]
            annotations:
              'kubernetes\.io/service-account\.name': {}
```

The escaped dots match the exact annotation key. With `action: deny`, the empty
policy `{}` rejects any value, including an empty string. Secrets without this
annotation remain unaffected by this rule. TokenRequest and projected volumes
use a different API path and remain available under their existing permissions.
Setting `automountServiceAccountToken: false` alone does not prevent someone
from creating a legacy token Secret.

Merge this rule into the Tenant's existing `spec.rules`, preserving other
configuration. With no namespace selector, it covers every namespace of that
Tenant. The [combined Tenant baseline](/docs/operating/best-practices/tenants/#reference)
already includes it. Keep later metadata rules from overriding the denial.

This is an admission policy, not credential revocation: unchanged annotations
are skipped on updates, and existing tokens are not removed. Review and remove
existing legacy token Secrets separately. The rule also cannot identify token
strings copied into ordinary Secret data.
