---
title: Permissions
weight: 5
description: >
  Configure policies and restrictions on a per-Tenant basis with Rules
---

Declare permission distribution rules for the selected namespaces.

## Bindings

With `Tenant` RoleBindings you can distribute namespaced RoleBindings to all namespaces which are assigned to a `Tenant`. This ensures the defined RoleBindings are present and reconciled in all namespaces of the `Tenant`. This is useful if users should have more insights on a `Tenant` basis. Let's look at an example.

Assuming a cluster-administrator creates the following clusterRole:

```yaml
kubectl apply -f - << EOF
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: prometheus-servicemonitors-viewer
rules:
- apiGroups: ["monitoring.coreos.com"]
  resources: ["servicemonitors"]
  verbs: ["get", "list", "watch"]
EOF
```

 Now the cluster administrator wants to bind this ClusterRole in each namespace of the solar `Tenant`. They can configure this with a `Tenant` manifest:

```yaml
kubectl apply -f - << EOF
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  rules:
    - permissions:
        bindings:
          - clusterRoleName: 'prometheus-servicemonitors-viewer'
            subjects:
              - kind: User
                name: alice
            labels:
              projectcapsule.dev/sample: "true"
            annotations:
              projectcapsule.dev/sample: "true"
EOF
```

 As you can see, `subjects` uses the standard [RoleBinding subject](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#referring-to-subjects) format. This grants permissions to the subject user **alice**, who can get, list, and watch ServiceMonitors in the solar Tenant namespaces, but has no other permissions.

### Strict

If you have [strict RBAC enabled for the controller](/docs/operating/setup/installation/#strict-rbac), you need to ensure that the controller ServiceAccount has the permission to create RoleBindings for the specified ClusterRole. The Controller Aggregates ClusterRoles with the labels (OR):

  - `projectcapsule.dev/aggregate-to-controller: "true"`
  - `projectcapsule.dev/aggregate-to-controller-instance: {{ .Release.Name }}`

So for the above example, you need to label the `prometheus-servicemonitors-viewer` ClusterRole like this:

```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: prometheus-servicemonitors-viewer
  labels:
    projectcapsule.dev/aggregate-to-controller: "true"
rules:
- apiGroups: ["monitoring.coreos.com"]
  resources: ["servicemonitors"]
  verbs: ["get", "list", "watch"]
```

### Distribution

 You may have the use-case where you want to distribute different ClusterRoles to different namespaces of the same `Tenant`. For example, you want to give `view` permissions to an operational group in all namespaces of the solar `Tenant` with `environment=prod` label, but you want to give `edit` permissions to the operations group in all other namespaces. You can achieve this by leveraging [GlobalTenantResources](/docs/replications/global/):

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - name: alice
      kind: User
    - name: joe
      kind: User
  rules:
    - namespaceSelector:
        matchExpressions:
        - key: environment
          operator: NotIn
          values:
          - prod
      permissions:
        bindings:
          - clusterRoleName: 'edit'
            subjects:
              - kind: Group
                name: tenant:{{ .tenant.metadata.name }}:operators
    - namespaceSelector:
        matchLabels:
          environment: prod
      permissions:
        bindings:
          - clusterRoleName: 'view'
            subjects:
              - kind: Group
                name: tenant:{{ .tenant.metadata.name }}:operators
```

### Built-in ClusterRoles

We strongly recommend you use custom ClusterRoles for your `Tenant` rolebindings, but you can also use built-in ClusterRoles (`admin` (default for Tenant Owners), `view` and `edit`). For example, if you want to give the `view` permissions to Joe in all namespaces of the solar `Tenant`, you can use the built-in `view` ClusterRole.

In that case it also makes sense to use [ClusterRole Aggregation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#aggregated-clusterroles). In the following example we are creating custom aggregated ClusterRoles for these three built-in clusterroles, to allow interactions with the GatewayAPI resources:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tenant:admins:extension
  labels:
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
rules:
  - apiGroups: ["gateway.networking.k8s.io"]
    resources:
      - gateways
      - httproutes
      - grpcroutes
      - tlsroutes
      - tcproutes
      - udproutes
      - referencegrants
      - backendtlspolicies
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["gateway.networking.k8s.io"]
    resources:
      - gateways/status
      - httproutes/status
      - grpcroutes/status
      - tlsroutes/status
      - tcproutes/status
      - udproutes/status
      - referencegrants/status
      - backendtlspolicies/status
    verbs: ["get"]
  - apiGroups: ["gateway.envoyproxy.io"]
    resources:
      - clienttrafficpolicies
      - backendtrafficpolicies
      - securitypolicies
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["gateway.envoyproxy.io"]
    resources:
      - clienttrafficpolicies/status
      - backendtrafficpolicies/status
      - securitypolicies/status
    verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tenant:members:extension
  labels:
    rbac.authorization.k8s.io/aggregate-to-edit: "true"
rules:
  - apiGroups: ["gateway.networking.k8s.io"]
    resources:
      - gateways
      - httproutes
      - grpcroutes
      - tlsroutes
      - tcproutes
      - udproutes
      - referencegrants
      - backendtlspolicies
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["gateway.networking.k8s.io"]
    resources:
      - gateways/status
      - httproutes/status
      - grpcroutes/status
      - tlsroutes/status
      - tcproutes/status
      - udproutes/status
      - referencegrants/status
      - backendtlspolicies/status
    verbs: ["get"]
  - apiGroups: ["gateway.envoyproxy.io"]
    resources:
      - clienttrafficpolicies
      - backendtrafficpolicies
      - securitypolicies
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["gateway.envoyproxy.io"]
    resources:
      - clienttrafficpolicies/status
      - backendtrafficpolicies/status
      - securitypolicies/status
    verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tenant:viewers:extension
  labels:
    rbac.authorization.k8s.io/aggregate-to-view: "true"
rules:
  - apiGroups: ["gateway.networking.k8s.io"]
    resources:
      - gateways
      - httproutes
      - grpcroutes
      - tlsroutes
      - tcproutes
      - udproutes
      - referencegrants
      - backendtlspolicies
    verbs: ["get", "list", "watch"]
  - apiGroups: ["gateway.networking.k8s.io"]
    resources:
      - gateways/status
      - httproutes/status
      - grpcroutes/status
      - tlsroutes/status
      - tcproutes/status
      - udproutes/status
      - referencegrants/status
      - backendtlspolicies/status
    verbs: ["get"]
  - apiGroups: ["gateway.envoyproxy.io"]
    resources:
      - clienttrafficpolicies
      - backendtrafficpolicies
      - securitypolicies
    verbs: ["get", "list", "watch", "create"]
  - apiGroups: ["gateway.envoyproxy.io"]
    resources:
      - clienttrafficpolicies/status
      - backendtrafficpolicies/status
      - securitypolicies/status
    verbs: ["get"]
```

#### Custom Resources

Capsule grants admin permissions to the `TenantOwners` but is only limited to their namespaces. To achieve that, it assigns the ClusterRole [admin](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) to the `TenantOwner`. This ClusterRole does not permit the installation of custom resources in the namespaces.

In order to leave the `TenantOwner` to create Custom Resources in their namespaces, the cluster admin defines a proper Cluster Role. For example:

```yaml
kubectl apply -f - << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argoproj-provisioner
rules:
- apiGroups:
  - argoproj.io
  resources:
  - applications
  - appprojects
  verbs:
  - create
  - get
  - list
  - watch
  - update
  - patch
  - delete
EOF
```

Bill can assign this role to any namespace in the Alice's `Tenant` by setting it in the `Tenant` manifest:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - name: alice
      kind: User
    - name: joe
      kind: User
  rules:
    - permissions:
        bindings:
          - clusterRoleName: 'argoproj-provisioner'
            subjects:
              - apiGroup: rbac.authorization.k8s.io
                kind: User
                name: alice
              - apiGroup: rbac.authorization.k8s.io
                kind: User
                name: joe
```

With the given specification, Capsule will ensure that all Alice's namespaces will contain a RoleBinding for the specified Cluster Role. For example, in the `solar-production` namespace, Alice will see:

```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: capsule-solar-argoproj-provisioner
  namespace: solar-production
subjects:
  - kind: User
    apiGroup: rbac.authorization.k8s.io
    name: alice
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argoproj-provisioner
```

With the above example, Capsule is leaving the `TenantOwner` to create namespaced custom resources.

> Take Note: a `TenantOwner` having the admin scope on its namespaces only, does not have the permission to create Custom Resources Definitions (CRDs) because this requires a cluster admin permission level. Only Bill, the cluster admin, can create CRDs. This is a known limitation of any multi-tenancy environment based on a single shared control plane.



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
