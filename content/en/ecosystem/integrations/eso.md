---
title: External Secrets Operator
description: Capsule Integration with External Secrets Operator
logo: https://github.com/cncf/artwork/raw/main/projects/external-secrets-operator/icon/color/eso-icon-color.svg
type: single
display: true
integration: true
---

With [External Secrets Operator](https://external-secrets.io/latest/) it's possible to delegate Secrets Management to an external system while keeping the actual management of the secrets within Kubernetes. This guide provides a simple automation example with [External Secrets Operator](https://external-secrets.io/latest/). Before starting, you might want to explore the existing documentation regarding multi-tenancy:

  * [https://external-secrets.io/latest/guides/multi-tenancy/](https://external-secrets.io/latest/guides/multi-tenancy/)

## Secure ClusterSecretStores

If you have any `ClusterSecretStores`, which are not intended to be used by `Tenants`, you must make sure `Tenants` can not reference the `ClusterSecretStore`. You can achieve this by unselecting all `Tenant` `Namespaces` like so:

```yaml
---
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: platform-vault
spec:
  conditions:
    - namespaceSelector:
        matchExpressions:
          - key: capsule.clastix.io/tenant  # Forbid the use of this platform keyvault by tenants
            operator: DoesNotExist
  provider:
    azurekv:
      tenantId: {TENANT}
      vaultUrl: {VAULT}
      authSecretRef:
        clientId:
          name: external-secrets-secret
          key: azure.clientID
          namespace: external-secrets
        clientSecret:
          name: external-secrets-secret
          key: azure.clientSecret
          namespace: external-secrets
```

## ClusterSecretStores






