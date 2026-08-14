---
title: Rules
weight: 8
description: >
  Configure policies and restrictions on a per-Namespace basis with Rules
---

Enforcement rules allow Bill, the cluster administrator, to set policies and restrictions on a per-`Tenant` basis. These rules are enforced by Capsule admission webhooks when Alice, the `TenantOwner`, creates or modifies resources in her `Namespaces`. With the rule construct, namespaces within the same tenant can be profiled differently depending on their metadata.

## Namespace Selector

By default, a rule applies to all namespaces within a `Tenant`. To apply a rule only to a subset of namespaces, use `namespaceSelector`. The selector follows the standard Kubernetes label selector semantics.

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  ...
  rules:
    # Matches all Namespaces and enforces the rule for all of them.
    - enforce:
        action: allow
        workloads:
          registries:
            - exact:
                - harbor/v2/customer-registry/debian:latest
              policy: ["IfNotPresent"]

    # Selects a subset of namespaces (environment=prod) to allow additional registries.
    - namespaceSelector:
        matchExpressions:
          - key: environment
            operator: In
            values: ["prod"]
      enforce:
        action: allow
        workloads:
          registries:
            - exp: "harbor/v2/prod-registry/.*"
              policy: ["IfNotPresent"]
```

Rules are combined together. In this example, all namespaces within the `solar` tenant can use the exact `harbor/v2/customer-registry/debian:latest` image, while namespaces labeled with `environment=prod` can also use images from `harbor/v2/prod-registry/*`.

## Templating

Namespace rule bodies are rendered as Go templates before they are written into the per-namespace `RuleStatus`. This allows administrators to define generic Tenant rules that are rendered differently for each Namespace. Templates can use the `tenant` and `namespace` objects as context, including metadata such as names, labels, and annotations.

For example, the following rule allows an image reference based on the current Tenant and Namespace name:

```yaml
rules:
  - enforce:
      action: allow
      workloads:
        registries:
          - exact:
              - "{{ .tenant.metadata.name }}/{{ .namespace.metadata.name }}/app:1"
```

For a Tenant named `solar` and a Namespace named `solar-prod`, this rule is rendered into an exact registry reference of `solar/solar-prod/app:1`.

Labels and annotations can also be used. Because many Kubernetes label and annotation keys contain dashes, dots, or slashes, use the `index` function when accessing them:

```yaml
rules:
  - enforce:
      action: allow
      workloads:
        registries:
          - exact:
              - "{{ index .namespace.metadata.labels \"registry-prefix\" }}/app:1"
```

If the Namespace has the label `registry-prefix=harbor/team-a`, the rendered registry rule becomes `harbor/team-a/app:1`.

Templates are rendered after `namespaceSelector` matching and before rule evaluation. This means a selected rule can use the concrete Namespace context while preserving the original rule order. Rule order remains important because the last matching `allow` or `deny` rule wins.

If a template references a missing key, Capsule marks the Tenant as not ready and reports the rendering error in the Tenant status. This prevents partially rendered or ambiguous rules from being applied silently.

## Quotas

Tenant rules can generate `GlobalResourceQuota` objects:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - name: alice
      kind: User
  rules:
    - namespaceSelector:
        matchLabels:
          company.example/tier: application
      quota:
        - name: shared-compute
          hard:
            requests.cpu: "8"
            requests.memory: 16Gi
            limits.cpu: "8"
            limits.memory: 16Gi
        - name: object-counts
          hard:
            services: "20"
            count/horizontalpodautoscalers.autoscaling: "10"
```

Capsule creates one `GlobalResourceQuota` per entry in the rule's `quota` list. The generated selector combines:

- The rule's namespace selector.
- The Tenant membership label.

The Tenant membership requirement prevents a rule from selecting another Tenant's namespaces. Generated quotas are reconciled and pruned with the Tenant rule lifecycle.

Every quota entry requires a DNS label-compatible `name` which must be unique across all rules in the Tenant. The name is the durable identity of the generated `GlobalResourceQuota`: changing limits, selectors, or rule ordering updates the existing object. Renaming or removing the quota entry replaces or deletes it.

Generated resource names use `<tenant-name>-<quota-name>`.

Quota accounting is independent of a rule's request audience. An audience can limit other rule behavior but does not partition the shared resource budget. Quota definitions are not copied into namespace `RuleStatus` objects. They are reconciled directly from the Tenant into cluster-scoped `GlobalResourceQuota` objects, which remain the authoritative source for admission and accounting.

Existing `Tenant.spec.resourceQuotas` behavior remains available for compatibility. Use rule-generated or directly managed `GlobalResourceQuota` objects when an atomic shared limit across namespaces is required.

### Migration

This guide demonstrates how to migrate from [`Tenant.spec.resourceQuotas`](/docs/tenants/quotas/#resource-quota) to rule-generated `GlobalResourceQuota` objects. The example Tenant has two resource quotas defined:

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
  namespaceOptions:
    quota: 3
  resourceQuotas:
    scope: Tenant
    items:
    - hard:
        limits.cpu: "8"
        limits.memory: 16Gi
        requests.cpu: "8"
        requests.memory: 16Gi
    - hard:
        pods: "10"
```

Verify what the current usage is for the Tenant's namespaces (for all namespace of the `Tenant` solar):

```bash
NAMESPACE    NAME              REQUEST                                                    LIMIT                                                   AGE
solar-dev    capsule-solar-0   requests.cpu: 0/6800m, requests.memory: 0/15616Mi          limits.cpu: 0/5, limits.memory: 0/14848Mi               87m
solar-dev    capsule-solar-1   pods: 0/4                                                                                                          87m
solar-prod   capsule-solar-0   requests.cpu: 600m/7400m, requests.memory: 384Mi/16000Mi   limits.cpu: 1500m/6500m, limits.memory: 768Mi/15616Mi   87m
solar-prod   capsule-solar-1   pods: 3/7                                                                                                          87m
solar-test   capsule-solar-0   requests.cpu: 600m/7400m, requests.memory: 384Mi/16000Mi   limits.cpu: 1500m/6500m, limits.memory: 768Mi/15616Mi   87m
solar-test   capsule-solar-1   pods: 3/7                                                                                                          87m
```

Now we update the `Tenant` to propagate the same quotas through rules, we are not removing the old `resourceQuotas` yet, to avoid any race conditions with the quota usage. The new `Tenant` spec looks like this:

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
  namespaceOptions:
    quota: 3
  resourceQuotas:
    scope: Tenant
    items:
    - hard:
        limits.cpu: "8"
        limits.memory: 16Gi
        requests.cpu: "8"
        requests.memory: 16Gi
    - hard:
        pods: "10"
  rules:
    - quota:
        - name: shared-compute
          hard:
            requests.cpu: "8"
            requests.memory: 16Gi
            limits.cpu: "8"
            limits.memory: 16Gi
        - name: object-counts
          hard:
            pods: "10"

```

After applying we can verify that `ResourceQuotas` are created for each rule quota. The important value is the **actual allocation**:

```bash
NAMESPACE    NAME                                        REQUEST                                                    LIMIT                                                   AGE

# NEW /OLD
solar-dev    capsule-global-quota-27d5c64b6c978b1b0f9c   pods: 0/4                                                                                                          102m
solar-dev    capsule-solar-1                             pods: 0/4                                                                                                          3h13m

# NEW /OLD
solar-dev    capsule-global-quota-cf84f5e52f0542edd93c   requests.cpu: 0/6800m, requests.memory: 0/15616Mi          limits.cpu: 0/5, limits.memory: 0/14848Mi               102m
solar-dev    capsule-solar-0                             requests.cpu: 0/6800m, requests.memory: 0/15616Mi          limits.cpu: 0/5, limits.memory: 0/14848Mi               3h13m

# NEW /OLD
solar-prod   capsule-global-quota-27d5c64b6c978b1b0f9c   pods: 3/7                                                                                                          102m
solar-prod   capsule-solar-1                             pods: 3/7                                                                                                          3h13m

# NEW /OLD
solar-prod   capsule-global-quota-cf84f5e52f0542edd93c   requests.cpu: 600m/7400m, requests.memory: 384Mi/16000Mi   limits.cpu: 1500m/6500m, limits.memory: 768Mi/15616Mi   102m
solar-prod   capsule-solar-0                             requests.cpu: 600m/7400m, requests.memory: 384Mi/16000Mi   limits.cpu: 1500m/6500m, limits.memory: 768Mi/15616Mi   3h13m

# NEW /OLD
solar-test   capsule-global-quota-27d5c64b6c978b1b0f9c   pods: 3/7                                                                                                          102m
solar-test   capsule-solar-1                             pods: 3/7                                                                                                          3h13m

# NEW /OLD
solar-test   capsule-global-quota-cf84f5e52f0542edd93c   requests.cpu: 600m/7400m, requests.memory: 384Mi/16000Mi   limits.cpu: 1500m/6500m, limits.memory: 768Mi/15616Mi   102m
solar-test   capsule-solar-0                             requests.cpu: 600m/7400m, requests.memory: 384Mi/16000Mi   limits.cpu: 1500m/6500m, limits.memory: 768Mi/15616Mi   3h13m
```

As you can see, the `GlobalResourceQuota` objects are created and the actual usage is preserved. Now we can safely remove the old `resourceQuotas` from the `Tenant` spec, and the new quotas will be enforced by the rules.

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
  namespaceOptions:
    quota: 3
  rules:
    - quota:
        - name: shared-compute
          hard:
            requests.cpu: "8"
            requests.memory: 16Gi
            limits.cpu: "8"
            limits.memory: 16Gi
        - name: object-counts
          hard:
            pods: "10"
```

After applying we only see the new `GlobalResourceQuota` objects, and the actual usage is preserved:

```bash
NAMESPACE    NAME                                        REQUEST                                                    LIMIT                                                   AGE
solar-dev    capsule-global-quota-27d5c64b6c978b1b0f9c   pods: 0/4                                                                                                          121m
solar-dev    capsule-global-quota-cf84f5e52f0542edd93c   requests.cpu: 0/6800m, requests.memory: 0/15616Mi          limits.cpu: 0/5, limits.memory: 0/14848Mi               121m

solar-prod   capsule-global-quota-27d5c64b6c978b1b0f9c   pods: 3/7                                                                                                          121m
solar-prod   capsule-global-quota-cf84f5e52f0542edd93c   requests.cpu: 600m/7400m, requests.memory: 384Mi/16000Mi   limits.cpu: 1500m/6500m, limits.memory: 768Mi/15616Mi   121m

solar-test   capsule-global-quota-27d5c64b6c978b1b0f9c   pods: 3/7                                                                                                          121m
solar-test   capsule-global-quota-cf84f5e52f0542edd93c   requests.cpu: 600m/7400m, requests.memory: 384Mi/16000Mi   limits.cpu: 1500m/6500m, limits.memory: 768Mi/15616Mi   121m
```

### GlobalResourceQuotas with Proxy

When you are using the [Capsule-Proxy](/docs/proxy/) you can allow users to list and get the `GlobalResourceQuota` objects in their `Tenant`. Add a [GlobalTenantResource](/docs/replications/global/) to provide the necessary RBAC permissions to the `Tenant` users:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: capsule-proxy-settings
spec:
  scope: Tenant
  resyncPeriod: 30s
  resources:
    - generators:
        - missingKey: zero
          template: |
            ---
            apiVersion: capsule.clastix.io/v1beta1
            kind: GlobalProxySettings
            metadata:
              name: {{ $.tenant.metadata.name }}-proxy-settings
            spec:
              rules:
              - subjects:
                {{- range $.tenant.status.owners }}
                - kind: {{ .kind }}
                  name: {{ .name }}
                {{- end }}
                clusterResources:
                - apiGroups:
                  - "capsule.clastix.io"
                  resources:
                  - "globalresourcequotas"
                  operations:
                  - List
                  selector:
                    matchLabels:
                      projectcapsule.dev/tenant: {{ $.tenant.metadata.name }} 
```





## Permissions

Declare permission distribution rules for the selected namespaces.

### Bindings

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

#### Strict

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

#### Distribution

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

#### Built-in ClusterRoles

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

##### Custom Resources

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

### Promotions

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

