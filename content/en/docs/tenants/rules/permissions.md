---
title: Permissions
weight: 5
description: >
  Configure policies and restrictions on a per-Tenant basis with Rules
---

Declare permission distribution rules for the selected namespaces.

## Promotions

As an administrator, you can define promotion rules. A promotion rule selects ServiceAccounts within a Tenant based on specified conditions and assigns them predefined ClusterRoles.

The selected ClusterRoles are then applied across all namespaces belonging to the Tenant, or a selected subset of namespaces, with the corresponding ServiceAccounts configured as subjects. This allows a ServiceAccount in one namespace to automatically receive equivalent permissions in other namespaces of the same Tenant.

This feature is particularly useful in scenarios involving [Tenant Replications](/docs/replications/#tenantresource), where consistent permissions across namespaces are required.

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  ...
  rules:
    - permissions:
        promotions:
          # Every promoted ServiceAccount receives this ClusterRole in all Namespaces of Tenant solar.
          - clusterRoles:
              - "configmap-replicator"

          # Every promoted ServiceAccount with the matching labels receives this ClusterRole.
          - clusterRoles:
              - "secret-replicator"
            selector:
              matchLabels:
                super: "account"

    - namespaceSelector:
        matchExpressions:
          - key: env
            operator: In
            values: ["prod"]
      permissions:
        promotions:
          # Promoted ServiceAccounts receive this ClusterRole only in namespaces matching env=prod.
          - clusterRoles:
              - "secret-replicator:prod"
```

Make sure the `ClusterRoles` exist. Otherwise, the corresponding `Tenant` reports a reconciliation error:

```shell
conditions:
- lastTransitionTime: "2026-02-16T23:08:59Z"
  message: 'cannot sync rolebindings items: rolebindings.rbac.authorization.k8s.io
    "tenant-replicator" not found'
```

If you run Capsule in [Strict Mode](/docs/operating/setup/installation/#strict-rbac), the controller must be allowed to grant the corresponding permissions to the `ServiceAccount` in all selected `Namespaces`. You can aggregate the same `ClusterRoles` to the controller:

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: configmap-replicator
  labels:
    projectcapsule.dev/aggregate-to-controller: "true"
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "create", "patch", "watch", "list", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-replicator
  labels:
    projectcapsule.dev/aggregate-to-controller: "true"
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "create", "patch", "watch", "list", "delete"]
```

As a [Tenant Owner](#ownership), Alice can promote `ServiceAccounts` by labeling them with `projectcapsule.dev/promote=true`. This feature must be enabled in the [CapsuleConfiguration](/docs/operating/setup/configuration/#allowserviceaccountpromotion). If the feature is disabled, admission fails:

```shell
Error from server (Forbidden): admission webhook "serviceaccounts.projectcapsule.dev" denied the request: service account promotion is disabled. Contact cluster administrators
```

When the feature is enabled, the following command succeeds, assuming `alice` is a Tenant Owner of the `solar` Tenant:

```shell
kubectl label sa gitops-reconcile -n solar-test projectcapsule.dev/promote=true --as alice --as-group projectcapsule.dev
```

Verify the promotion in the `Tenant` status:

```shell
kubectl get tnt solar -o jsonpath='{.status.promotions}' | jq
```

Example status:

```json
[
  {
    "clusterRoles": [
      "tenant-replicator"
    ],
    "kind": "ServiceAccount",
    "name": "system:serviceaccount:solar-test:gitops-reconcile",
    "targets": [
      "solar-test",
      "solar-prod"
    ]
  }
]
```

You can verify that the RoleBinding was distributed to other namespaces of the `solar` Tenant:

```shell
kubectl get rolebinding -n solar-prod

NAME                               ROLE                                    AGE
..
capsule:managed:7ad688b586eada40   ClusterRole/configmap-replicator        21s
..
```

To revoke the promotion, Alice can remove the label:

```shell
kubectl label sa gitops-reconcile -n solar-test projectcapsule.dev/promote- --as alice --as-group projectcapsule.dev
```
