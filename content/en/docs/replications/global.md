---
title: GlobalTenantResources
weight: 1
description: >
  Replicate resources across tenants or namespaces as Cluster Administrator.
---

## Overview

`GlobalTenantResource` is a cluster-scoped CRD designed for cluster administrators. It lets you automatically replicate Kubernetes resources - such as Secrets, ConfigMaps, or custom resources - into the Namespaces of selected Tenants. Tenant owners cannot create `GlobalTenantResource` objects; for tenant-scoped replication, see [TenantResource](../tenant/).

The diagram below shows that an Administrator can create a `GlobalTenantResource`. In the `GlobalTenantResource` spec, an Administrator specifies which resource they would like to replicate, and where this resource should be replicated to. When applied, this resource gets automatically distributed across all Namespaces of the `Tenants` that are selected in the `GlobalTenantResource`.

![Global Tenant Resource Replication overview](/images/content/replication-globaltenantresource.png)

A common use case is distributing image pull secrets to all Tenants that must use a specific container registry. In the following example, Bill labels two Tenants and then creates a `GlobalTenantResource` to push the corresponding pull secret into each of their Namespaces automatically.

```bash
$ kubectl label tnt/solar energy=renewable
tenant solar labeled

$ kubectl label tnt/green energy=renewable
tenant green labeled
```

The pull secret already exists in the `harbor-system` namespace, labelled accordingly:

```bash
$ kubectl -n harbor-system get secret --show-labels
NAME                    TYPE     DATA   AGE   LABELS
imagePullSecret   Opaque   1      28s   tenant=renewable
```

Without automation, these credentials would need to be distributed manually - against the self-service principle of Capsule. Bill solves this with a single `GlobalTenantResource`:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: renewable-pull-secrets
spec:
  tenantSelector:
    matchLabels:
      energy: renewable
  resyncPeriod: 60s
  resources:
    - namespacedItems:
        - apiVersion: v1
          kind: Secret
          namespace: harbor-system
          selector:
            matchLabels:
              tenant: renewable
```

Capsule selects all Tenants matching `tenantSelector`, then replicates every item in `namespacedItems` into each Namespace belonging to those Tenants. The controller reconciles on the interval defined by `resyncPeriod`.

> Objects managed by this controller can be either **created** (new objects) or **adopted** (existing objects). See [Object Management](#object-management) in the Advanced section for full details.

---

## Basic Usage

### TenantSelector

A block that describes which Tenants the resource should be replicated to. `matchLabels` and `matchExpressions` can be used to select the desired Tenants. To select all tenants with the label `energy: renewable`, use:

```yaml
  tenantSelector:
    matchLabels:
      energy: renewable
```

TenantSelector is an optional field. If not set, the resources will be replicated to all tenants.

### Resources

A resource block defines *what* to replicate. Multiple blocks can be stacked in the `resources` array, each using one or more of the strategies below.

#### NamespaceSelector

The `namespaceSelector` field restricts replication to Namespaces matching a label selector. Capsule also protects selected resources from modification by Tenant users via its webhook.

#### AdditionalMetadata

Use `additionalMetadata` to attach extra `labels` and `annotations` to every generated object. [Fast Template values](/docs/operating/templating/#fast-templates) are supported:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-cluster-rbac
spec:
  scope: Tenant
  resources:
    - additionalMetadata:
        labels:
          k8s.company.com/tenant: "{{tenant.name}}"
        annotations:
          k8s.company.com/cost-center: "inv-120"
      generators:
        - missingKey: error
          template: |
            ---
            apiVersion: rbac.authorization.k8s.io/v1
            kind: ClusterRole
            metadata:
              name: tenant:{{$.tenant.metadata.name}}:priority
              labels:
                k8s.company.com/tenant: "test"
            rules:
              - apiGroups: ["scheduling.k8s.io"]
                verbs: ["get"]
                resources: ["priorityclasses"]
```

When the same label key appears in both `additionalMetadata` and the template, `additionalMetadata` takes priority.

The following labels are always stripped because they are reserved for the controller:

  * `capsule.clastix.io/resources`
  * `projectcapsule.dev/created-by`
  * `capsule.clastix.io/managed-by`
  * `projectcapsule.dev/managed-by`

#### NamespacedItems

Reference existing resources for replication across Tenant Namespaces. The controller validates that any resource kind listed here is namespace-scoped; cluster-scoped kinds are rejected with an error.

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-resource-replications
spec:
  resyncPeriod: 60s
  resources:
    - namespacedItems:

      # Replicate all Configmaps labeled with projectcapsule.dev/replicate: "true"
      - apiVersion: v1
        kind: ConfigMap
        selector:
          matchLabels:
            projectcapsule.dev/replicate: "true"

      # Replicate all Configmaps labeled with projectcapsule.dev/replicate: "true" and in namespace capsule-system
      - apiVersion: v1
        kind: ConfigMap
        namespace: capsule-system
        selector:
          matchLabels:
            projectcapsule.dev/replicate: "true"

      # Replicate Configmap named "logging-config" in namespace capsule-system labeled with projectcapsule.dev/replicate: "true" and in namespace capsule-system
      - apiVersion: v1
        kind: ConfigMap
        name: logging-config
        namespace: capsule-system
```

**Note**: Resources with the label `projectcapsule.dev/created-by: resources` are ignored by `namespacedItems` to prevent reconciliation loops.

If you try to define a cluster-scoped resource under `namespacedItems`, the reconciliation will fail immediately:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-resource-replications
spec:
  resyncPeriod: 60s
  - namespacedItems:
    - apiVersion: addons.projectcapsule.dev/v1alpha1
      kind: SopsProvider
      name: infrastructure-provider
      optional: true

status:
  conditions:
  - lastTransitionTime: "2026-01-15T21:04:15Z"
    message: cluster-scoped kind addons.projectcapsule.dev/v1alpha1/SopsProvider is
      not allowed
    reason: Failed
    status: "False"
    type: Ready
```

##### Name

Providing `name` triggers a `GET` request for that single resource rather than a `LIST`. You must also specify `namespace` when using `name` in a `GlobalTenantResource`:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-resource-replications
spec:
  resources:
  - namespacedItems:
    - apiVersion: v1
      kind: ConfigMap
      name: config-namespace
      optional: true
status:
  conditions:
  - lastTransitionTime: "2026-01-15T21:10:17Z"
    message: 'failed to get ConfigMap/config-namespace: an empty namespace may not
      be set when a resource name is provided'
    reason: Failed
    status: "False"
    type: Ready
```

##### Namespace

Providing only `namespace` performs a `LIST` of all resources of that kind in that namespace:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-resource-replications
spec:
  resyncPeriod: 60s
  resources:
    - namespacedItems:
      # Fetches all configmaps in the namespace tenants-system
      - apiVersion: v1
        kind: ConfigMap
        namespace: "tenants-system"

      # Fetches specific configmaps matching the selector in the namespaces tenants-system
      - apiVersion: v1
        kind: ConfigMap
        namespace: "tenants-system"
        selector:
          matchLabels:
            projectcapsule.dev/replicate: "true"
```

[Fast Templates](/docs/operating/templating/#fast-templates) are supported for `namespace`:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-resource-replications
spec:
  resyncPeriod: 60s
  resources:
    - namespacedItems:
      # Fetch ConfigMaps labeled with the tenant name and replicate them into each Tenant Namespace
      - apiVersion: v1
        kind: Secret
        namespace: "{{tenant.name}}-system"
```

**Note**: When using `TenantResource` instead of `GlobalTenantResource`, the `namespace` field has no effect - resources can only be referenced from the Namespace where the `TenantResource` object was created.

##### Selector

When using `selector`, the selector labels are stripped from the replicated objects. This prevents the replicated copy from also matching the source selector, which would cause a circular reconciliation loop.

Source `ConfigMap`:

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  labels:
    projectcapsule.dev/replicate: "true"
  namespace: wind-test
data:
  player_initial_lives: "3"
  ui_properties_file_name: "user-interface.properties"
```

`TenantResource`:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: app-config
spec:
  resources:
    - namespacedItems:
      - apiVersion: v1
        kind: ConfigMap
        selector:
          matchLabels:
            projectcapsule.dev/replicate: "true"
```

Resulting object in `wind-prod` (notice the absence of `projectcapsule.dev/replicate`):

```yaml
apiVersion: v1
data:
  player_initial_lives: "3"
  ui_properties_file_name: "user-interface.properties"
kind: ConfigMap
metadata:
  labels:
    projectcapsule.dev/created-by: resources
    projectcapsule.dev/managed-by: resources
  name: app-config
  namespace: wind-prod
  resourceVersion: "784529"
  uid: 5f10a3f3-863e-4f45-9454-cff8f5bce86a
```

[Fast Templates](/docs/operating/templating/#fast-templates) are supported for `selector`:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-resource-replications
spec:
  resyncPeriod: 60s
  resources:
    - namespacedItems:
      # Fetch ConfigMaps labeled with the tenant name and replicate them into each Tenant Namespace
      - apiVersion: v1
        kind: ConfigMap
        selector:
          matchLabels:
            company.com/replicate-for: "{{tenant.name}}"
```

#### Raw

Raw items let you define resources inline as standard Kubernetes manifests. Use this when the resource does not yet exist in the cluster, or when you want to define it directly in the spec. [Fast Templates](/docs/operating/templating/#fast-templates) are supported.

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-resource-replications
spec:
  resyncPeriod: 300s
  resources:
    - rawItems:
      - apiVersion: v1
        kind: LimitRange
        metadata:
          name: "{{tenant.name}}-{{namespace}}-resource-constraint"
        spec:
          limits:
          - default: # this section defines default limits
              cpu: 500m
            defaultRequest: # this section defines default requests
              cpu: 500m
            max: # max and min define the limit range
              cpu: "1"
            min:
              cpu: 100m
            type: Container
```

The following example creates a [`SopsProvider`](https://github.com/peak-scale/sops-operator) for each Tenant:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-sops-providers
spec:
  resyncPeriod: 600s
  scope: Tenant
  resources:
    - rawItems:
        - apiVersion: addons.projectcapsule.dev/v1alpha1
          kind: SopsProvider
          metadata:
            name: "{{tenant.name}}-secrets"
          spec:
            keys:
            - namespaceSelector:
                matchLabels:
                  capsule.clastix.io/tenant: "{{tenant.name}}"
            sops:
            - namespaceSelector:
                matchLabels:
                  capsule.clastix.io/tenant: "{{tenant.name}}"
```

Because [Server-Side Apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/) is used, you only need to specify the fields you want to manage - the full resource spec is not required.

For more advanced templating, consider [Generators](#generators).

#### Generators

Generators render one or more Kubernetes objects from a Go template string. The template content must be valid YAML; multi-document output separated by `---` is supported. The template engine is based on [go-sprout](https://github.com/go-sprout/sprout) - see [available functions](/docs/operating/templating/#sprout-templating).

A simple example that creates a `ClusterRole` per Tenant:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-cluster-rbac
spec:
  scope: Tenant
  resources:
    - generators:
        - missingKey: error
          template: |
            apiVersion: rbac.authorization.k8s.io/v1
            kind: ClusterRole
            metadata:
              name: tenant:{{$.tenant.metadata.name}}:reader
            rules:
            - apiGroups: [""]
              resources: ["secrets"]
              verbs: ["get", "watch", "list"]
```

Templates can also produce multiple objects using flow control:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-priority-rbac
spec:
  scope: Tenant
  resources:
    - generators:
        - missingKey: error
          template: |
            {{- range $.tenant.status.classes.priority }}
            ---
            apiVersion: rbac.authorization.k8s.io/v1
            kind: ClusterRole
            metadata:
              name: tenant:{{$.tenant.metadata.name}}:priority:{{.}}
            rules:
              - apiGroups: ["scheduling.k8s.io"]
                resources: ["priorityclasses"]
                resourceNames: ["{{.}}"]
                verbs: ["get"]
            {{- end }}
```

See [Base Context](#base-context) for available template variables. To load additional resources into the template context, see [Context](#context) in the Advanced section.

##### Template Snippets

Some snippets that might be useful for certain cases.

###### Names

Extract the `Tenant` name:

```html
{{ $.tenant.metadata.name }}
```

Extract the `Namespace` name:

```html
{{ $.namespace.metadata.name }}
```

###### Foreach Owner

Iterate over all owners of a Tenant:

```html
  {{- range $.tenant.status.owners }}
    {{ .kind }}: {{ .name }}
  {{- end }}
```

##### MissingKey

Controls template behaviour when a referenced context key is absent.

###### Invalid

Continues execution silently. Missing keys render as the string `"<no value>"`.

This definition with the missing context:

```yaml
kind: GlobalTenantResource
metadata:
  name: missing-key
spec:
  resources:
  - generators:
    - missingKey: invalid
      template: |
        ---
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: show-key
        data:
          value: {{ $.custom.account.name }}
```

Turns into after templating:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: show-key
data:
  value: "<no value>"
```

###### Zero

**This is the default behavior.** Missing keys resolve to the zero value of their type (usually an empty string).

This definition with the missing context:

```yaml
kind: GlobalTenantResource
metadata:
  name: missing-key
spec:
  resources:
  - generators:
    - missingKey: zero
      template: |
        ---
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: show-key
        data:
          value: {{ $.custom.account.name }}
```

Turns into after templating:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: show-key
data:
  value: ""
```

###### Error

Stops execution immediately with an error when a required key is missing.

This definition with the missing context:

```yaml
kind: GlobalTenantResource
metadata:
  name: missing-key
spec:
  resources:
  - generators:
    - missingKey: error
      template: |
        ---
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: show-key
        data:
          value: {{ $.custom.account.name }}
```

Will error the `GlobalTenantResources`:

```shell
NAME                    ITEMS   READY   STATUS                                                                                                               AGE
missing-key   6       False   error running generator: template: tpl:8:7: executing "tpl" at <$.namespace.name>: map has no entry for key "name"   9m5s
```

---

### Reconciliation

#### Period

`GlobalTenantResources` reconcile on the interval defined by `resyncPeriod`. The default is `60s`. Capsule does not watch source resources for changes; it reconciles periodically. A very short interval on large clusters with many Tenants and Namespaces can cause performance issues - tune this value accordingly.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: renewable-pull-secrets
spec:
  resyncPeriod: 300s # 5 minutes
  resources:
    - namespacedItems:
        - apiVersion: v1
          kind: Secret
          namespace: harbor-system
          selector:
            matchLabels:
              tenant: renewable
```

#### Manual

To trigger an immediate reconciliation, add the `reconcile.projectcapsule.dev/requestedAt` annotation. The annotation is removed once reconciliation completes, making the process repeatable.

```bash
kubectl annotate globaltenantresource renewable-pull-secrets \
  reconcile.projectcapsule.dev/requestedAt="$(date -Iseconds)"
```

---

### Scope

By default, a `GlobalTenantResource` replicates resources into **every Namespace** of the selected Tenants. Setting `scope: Tenant` changes this to replicate once per Tenant instead.

Possible values:

  * `Tenant`: Replicate once per Tenant.
  * `Namespace`: Replicate into each Namespace of the selected Tenants. *(Default)*

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-sops-providers
spec:
  resyncPeriod: 60s
  scope: Tenant
  resources:
    - rawItems:
        - apiVersion: addons.projectcapsule.dev/v1alpha1
          kind: SopsProvider
          metadata:
            name: {{tenant.name}}-secrets
          spec:
            keys:
            - namespaceSelector:
                matchLabels:
                  capsule.clastix.io/tenant: {{tenant.name}}
            sops:
            - namespaceSelector:
                matchLabels:
                  capsule.clastix.io/tenant: {{tenant.name}}
```

Using the `scope: Tenant` is mainly useful when you want to deploy a cluster-scoped resource once per tenant, such as the `SopsProvider` above.

**Note:** When `scope: Tenant` is set, `namespacedItems` entries are not processed, since there is no target Namespace in that scope.

---

### Impersonation

{{% alert title="Information" color="warning" %}}
Without a configured ServiceAccount, the Capsule controller ServiceAccount is used for replication operations. This may allow privilege escalation if the controller has broader permissions than Tenant owners.
{{% /alert %}}

Enabling impersonation ensures that replication operations run under a specific ServiceAccount identity, providing a proper audit trail and limiting privilege exposure. You can check which ServiceAccount is currently in use via the object's status:

```bash
kubectl get globaltenantresource custom-cm -o jsonpath='{.status.serviceAccount}' | jq
{
  "name": "capsule",
  "namespace": "capsule-system"
}
```

To use a different ServiceAccount, set the `serviceAccount` field on the object:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-resource-replications
spec:
  serviceAccount:
    name: "default"
    namespace: "kube-system"
  resources:
    - namespacedItems:
      - apiVersion: v1
        kind: ConfigMap
        name: "config-namespace"
```

If the ServiceAccount lacks the required RBAC, replication will fail with a permission error:

```yaml
  - kind: ConfigMap
    name: game-demo
    namespace: wind-prod
    status:
      created: true
      message: 'apply failed for item 0/raw-0: applying object failed: configmaps
        "game-demo" is forbidden: User "system:serviceaccount:kube-system:default"
        cannot patch resource "configmaps" in API group "" in the namespace "wind-prod"'
      status: "False"
      type: Ready
    tenant: wind
    version: v1
```

Grant the ServiceAccount the necessary permissions:

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: capsule-tenant-replications
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["list", "get", "patch", "create", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: capsule-tenant-replications
subjects:
- kind: ServiceAccount
  name: default
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: capsule-tenant-replications
  apiGroup: rbac.authorization.k8s.io

```

#### Required Permissions

The following permissions are required for each resource type managed by the replication feature:

  * `get` (always required)
  * `create` (always required)
  * `patch` (always required)
  * `delete` (always required)
  * `list` (required for [Namespaced Items](#namespaceditems) and [Context](#context))

Missing any of these will cause replication to fail.

#### Default ServiceAccount

To ensure all `GlobalTenantResource` objects use a controlled identity by default, configure a cluster-wide default ServiceAccount in the Capsule manager options. Per-object `serviceAccount` fields override this default.

[Read more about Impersonation](/docs/operating/setup/configuration/#impersonation). You must provide both the name and namespace of the ServiceAccount:

```yaml
manager:
  options:
    impersonation:
      globalDefaultServiceAccount: "capsule-default-global"
      globalDefaultServiceAccountNamespace: "capsule-system"
```

The default ServiceAccount must have sufficient RBAC. The following example allows it to manage Secrets and LimitRanges across all Tenants:

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: capsule-default-global
rules:
- apiGroups: [""]
  resources: ["limitranges", "secrets"]
  verbs: ["get", "patch", "create", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: capsule-default-global
subjects:
- kind: ServiceAccount
  name: capsule-default-global
  namespace: capsule-system
roleRef:
  kind: ClusterRole
  name: capsule-default-global
  apiGroup: rbac.authorization.k8s.io
```

If a `GlobalTenantResource` attempts to manage a resource type not covered by the default ServiceAccount's ClusterRole, replication will fail with a permissions error:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: default-sa-replication
spec:
  resyncPeriod: 60s
  resources:
    - rawItems:
      - apiVersion: v1
        kind: ConfigMap
        metadata:
          name: game-demo
        data:
          player_initial_lives: "3"
          ui_properties_file_name: "user-interface.properties"
```

---

## Advanced

This section covers more advanced features of the Replication setup.

### Object Management

Capsule uses [Server-Side Apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/) for all replication operations. Two management modes exist depending on whether the object already existed before reconciliation.

#### Create

An object is *Created* when the `GlobalTenantResource` first encounters it - it did not exist prior to reconciliation. Created objects receive the following metadata:

  * `metadata.labels.projectcapsule.dev/created-by`: `resources`
  * `metadata.labels.projectcapsule.dev/managed-by`: `resources`
  * `metadata.ownerReferences`: Owner reference to the corresponding `GlobalTenantResource`

```yaml
kind: ConfigMap
metadata:
  labels:
    projectcapsule.dev/created-by: resources
    projectcapsule.dev/managed-by: resources
  name: common-config
  namespace: green-test
  ownerReferences:
  - apiVersion: capsule.clastix.io/v1beta2
    kind: GlobalTenantResource
    name: tenant-cm-providers
    uid: 903395eb-9314-462d-ae19-7c87d71e890b
  resourceVersion: "549517"
  uid: 23abbb7a-2926-416a-bc72-9f793ebf6080
```

Since we are using [Server-Side Apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/) we can also allow different items making changes to the same object, when it was created by a `GlobalTenantResource`, as long as there are no conflicts:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-cm-registration
spec:
  scope: Tenant
  resources:
    - generators:
        - template: |
            ---
            apiVersion: v1
            kind: ConfigMap
            metadata:
              name: common-config
              namespace: default
            data:
              {{ $.tenant.metadata.name }}.conf: |
                {{ toYAML $.tenant.metadata | nindent 4 }}
```

Will result in the following object:

```yaml
apiVersion: v1
data:
  green.conf: "\ncreationTimestamp: \"2026-02-05T08:03:25Z\"\ngeneration: 2\nlabels:\n
    \ customer: a\n  kubernetes.io/metadata.name: green\nname: green\nresourceVersion:
    \"549455\"\nuid: 7b756efd-cdad-484b-a41f-d1a00d401781 \n"
  solar.conf: "\ncreationTimestamp: \"2026-02-05T08:03:25Z\"\ngeneration: 2\nlabels:\n
    \ customer: a\n  kubernetes.io/metadata.name: solar\nname: solar\nresourceVersion:
    \"549521\"\nuid: c2b21703-2321-4789-af9f-65e541c883d5 \n"
  wind.conf: "\ncreationTimestamp: \"2026-02-05T13:43:22Z\"\ngeneration: 1\nlabels:\n
    \ kubernetes.io/metadata.name: wind\nname: wind\nresourceVersion: \"542629\"\nuid:
    72388253-ff5c-4614-94a2-2fd8cd7cf813 \n"
kind: ConfigMap
metadata:
  creationTimestamp: "2026-02-05T15:37:09Z"
  labels:
    projectcapsule.dev/created-by: resources
    projectcapsule.dev/managed-by: resources
  name: common-config
  namespace: default
  ownerReferences:
  - apiVersion: capsule.clastix.io/v1beta2
    kind: GlobalTenantResource
    name: tenant-sops-providers
    uid: 7cf01d19-0555-490f-bd01-a5beff0cbc64
  resourceVersion: "561707"
  uid: 33cfe1c6-1c9e-4417-9dd5-26ac0ba3bc85
```

This also works across different `GlobalTenantResources`:

```yaml
apiVersion: v1
data:
  common.conf: "\ncreationTimestamp: \"2026-02-05T08:03:25Z\"\ngeneration: 2\nlabels:\n
    \ customer: a\n  kubernetes.io/metadata.name: green\nname: green\nresourceVersion:
    \"549455\"\nuid: 7b756efd-cdad-484b-a41f-d1a00d401781 \n"
  green.conf: "\ncreationTimestamp: \"2026-02-05T08:03:25Z\"\ngeneration: 2\nlabels:\n
    \ customer: a\n  kubernetes.io/metadata.name: green\nname: green\nresourceVersion:
    \"549455\"\nuid: 7b756efd-cdad-484b-a41f-d1a00d401781 \n"
  solar.conf: "\ncreationTimestamp: \"2026-02-05T08:03:25Z\"\ngeneration: 2\nlabels:\n
    \ customer: a\n  kubernetes.io/metadata.name: solar\nname: solar\nresourceVersion:
    \"549521\"\nuid: c2b21703-2321-4789-af9f-65e541c883d5 \n"
  wind.conf: "\ncreationTimestamp: \"2026-02-05T13:43:22Z\"\ngeneration: 1\nlabels:\n
    \ kubernetes.io/metadata.name: wind\nname: wind\nresourceVersion: \"542629\"\nuid:
    72388253-ff5c-4614-94a2-2fd8cd7cf813 \n"
kind: ConfigMap
metadata:
  creationTimestamp: "2026-02-05T15:37:09Z"
  labels:
    projectcapsule.dev/created-by: resources
    projectcapsule.dev/managed-by: resources
  name: common-config
  namespace: default
  ownerReferences:
  - apiVersion: capsule.clastix.io/v1beta2
    kind: GlobalTenantResource
    name: tenant-sops-providers
    uid: 7cf01d19-0555-490f-bd01-a5beff0cbc64
  - apiVersion: capsule.clastix.io/v1beta2
    kind: GlobalTenantResource
    name: tenant-cm-registration
    uid: b2d34727-b403-4e2a-9115-232ba61d3c69
  resourceVersion: "562881"
  uid: 33cfe1c6-1c9e-4417-9dd5-26ac0ba3bc85
```

 However, when try to manage the same field, we will get an error:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-cm-registration
spec:
  scope: Tenant
  resources:
      generators:
        - template: |
            ---
            apiVersion: v1
            kind: ConfigMap
            metadata:
              name: common-config
              namespace: default
            data:
              common.conf: |
                {{ toYAML $.tenant.metadata.name | nindent 4 }}
```

We can see a Conflict Error in the `GlobalTenantResource` status:

```yaml
kubectl get globaltenantresource tenant-cm-registration -o yaml

...

  status:
    processedItems:
    - kind: ConfigMap
      name: common-config
      namespace: default
      status:
        lastApply: "2026-02-05T15:52:26Z"
        status: "True"
        type: Ready
      tenant: wind
      version: v1
    - kind: ConfigMap
      name: common-config
      namespace: default
      status:
        created: true
        message: 'apply failed for item 0/generator-0-0: applying object failed: Apply
          failed with 1 conflict: conflict with "projectcapsule.dev/resource/cluster/tenant-cm-registration//default/wind/":
          .data.common.conf'
        status: "False"
        type: Ready
      tenant: green
      version: v1
    - kind: ConfigMap
      name: common-config
      namespace: default
      status:
        created: true
        message: 'apply failed for item 0/generator-0-0: applying object failed: Apply
          failed with 1 conflict: conflict with "projectcapsule.dev/resource/cluster/tenant-cm-registration//default/wind/":
          .data.common.conf'
        status: "False"
        type: Ready
      tenant: solar
      version: v1
```

You can check the `created` property on each item's status to determine whether it was created or adopted. Field conflicts can be resolved with [Force](#force).

##### Pruning

When pruning is enabled, *Created* objects are deleted when they fall out of scope. When pruning is disabled, the following metadata is removed instead:

  * `metadata.labels.projectcapsule.dev/managed-by`: `resources`
  * `metadata.ownerReferences`: owner reference to the `GlobalTenantResource`

The label `metadata.labels.projectcapsule.dev/created-by` is preserved after pruning, allowing another `GlobalTenantResource` or `TenantResource` to take ownership without explicit adoption. To prevent re-adoption, remove or change this label manually.

#### Adopt

By default, a `GlobalTenantResource` cannot modify objects it did not create. Adoption must be explicitly enabled. Adopted objects receive the following metadata:

  * `metadata.labels.projectcapsule.dev/managed-by`: `resources`

For example the following `GlobalTenantResource` tries to change the content of the existing `argo-rbac` `ConfigMap`:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: argo-cd-permission
spec:
  resources:
    - generators:
        - template: |
            ---
            apiVersion: v1
            kind: ConfigMap
            metadata:
              name: argocd-rbac-cm
            data:
              {{ $.tenant.metadata.name }}.csv: |
                {{- range $.tenant.status.owners }}
                p, {{ .name }}, applications, sync, my-{{ $.tenant.metadata.name }}/*, allow
                {{- end }}
```

We can see, that we get an error for all items. Telling us, we can not overwrite an existing object:

```yaml
kubectl get globaltenantresource argo-cd-permission -o yaml

...
  processedItems:
  - kind: ConfigMap
    name: argocd-rbac-cm
    namespace: argocd
    status:
      message: 'apply failed for item 0/generator-0-0: resource evaluation: resource
        v1/ConfigMap argocd/argocd-rbac-cm exists and cannot be adopted'
      status: "False"
      type: Ready
    tenant: green
    version: v1
  - kind: ConfigMap
    name: argocd-rbac-cm
    namespace: argocd
    status:
      message: 'apply failed for item 0/generator-0-0: resource evaluation: resource
        v1/ConfigMap argocd/argocd-rbac-cm exists and cannot be adopted'
      status: "False"
      type: Ready
    tenant: solar
    version: v1
  - kind: ConfigMap
    name: argocd-rbac-cm
    namespace: argocd
    status:
      message: 'apply failed for item 0/generator-0-0: resource evaluation: resource
        v1/ConfigMap argocd/argocd-rbac-cm exists and cannot be adopted'
      status: "False"
      type: Ready
    tenant: wind
    version: v1
```

If we want to allow that, we can set the `adopt` property to `true`:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: argo-cd-permission
spec:
  settings:
    adopt: true
  resources:
    - generators:
        - template: |
            ---
            apiVersion: v1
            kind: ConfigMap
            metadata:
              name: argocd-rbac-cm
            data:
              {{ $.tenant.metadata.name }}.csv: |
                {{- range $.tenant.status.owners }}
                p, {{ .name }}, applications, sync, {{ $.tenant.metadata.name }}/*, allow
                {{- end }}
```

When adoption is enabled, resources can be modified. Note that if multiple operators manage the same resource, all must use Server-Side Apply to avoid conflicts.

```shell
kubectl get cm -n argocd  argocd-rbac-cm -o yaml
apiVersion: v1
data:
  policy.csv: |
    p, my-org:team-alpha, applications, sync, my-project/*, allow
    g, my-org:team-beta, role:admin
    g, user@example.org, role:admin
    g, admin, role:admin
    g, role:admin, role:readonly
  policy.default: role:readonly
  scopes: '[groups, email]'

  green.csv: |2

    p, oidc:org:devops, applications, sync, green/*, allow
    p, bob, applications, sync, green/*, allow
  solar.csv: |2

    p, oidc:org:platform, applications, sync, solar/*, allow
    p, alice, applications, sync, solar/*, allow
  wind.csv: |2

    p, oidc:org:devops, applications, sync, wind/*, allow
    p, joe, applications, sync, wind/*, allow
kind: ConfigMap
```

##### Pruning

When pruning is enabled, adoption is reverted - the patches introduced by the `GlobalTenantResource` are removed from the object. When pruning is disabled, only the `metadata.labels.projectcapsule.dev/managed-by` label is removed.

---

### DependsOn

A `GlobalTenantResource` can declare dependencies on other `GlobalTenantResource` objects using `dependsOn`. The controller will not reconcile the resource until all declared dependencies are in `Ready` state.

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: gitops-owners
spec:
  resyncPeriod: 60s
  dependsOn:
    - name: custom-cm
  resources:
    - additionalMetadata:
        labels:
          projectcapsule.dev/tenant: "{{tenant.name}}"
      rawItems:
        - apiVersion: capsule.clastix.io/v1beta2
          kind: TenantOwner
          metadata:
            name: "{{tenant.name}}-{{namespace}}"
          spec:
            clusterRoles:
              - capsule-namespace-deleter
              - admin
            kind: ServiceAccount
            name: "system:serviceaccount:{{namespace}}:gitops-reconciler"
```

We can observe the status of the `GlobalTenantResource` reflecting, that it depends `GlobalTenantResource` is not yet ready.

```bash
kubectl get globaltenantresource

NAME                           ITEM COUNT   READY   STATUS                            AGE
custom-cm                      6            False   applying of 6 resources failed    12h
gitops-owners                  6            False   dependency custom-cm-2 not found   8h
```

If a dependency does not exist, we can observe a similar status message when describing the `GlobalTenantResource` object.

```bash
kubectl get globaltenantresource gitops-owners

NAME                           ITEM COUNT   READY   STATUS                            AGE
gitops-owners                  6            False   dependency custom-cm-2 not found   8h
```

Dependencies are evaluated in the order they are declared in the `dependsOn` array.

---

### Force

Setting `settings.force: true` instructs Capsule to [force-apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/#conflicts) changes on Server-Side Apply conflicts, claiming field ownership even if another manager already holds it.

**This option should generally be avoided.** Forcing ownership over a field managed by another operator will almost certainly cause a reconcile war. Only use it in scenarios where you intentionally want Capsule to win ownership disputes.

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-technical-accounts
spec:
  settings:
    force: true
  resources:
    - generators:
        - template: |
            ---
            apiVersion: v1
            kind: ConfigMap
            metadata:
              name: shared-config
            data:
              common.conf: |
                {{ toYAML $.tenant.metadata | nindent 4 }}
```

---

### Context

The `context` field lets you load additional Kubernetes resources into the template rendering context. This is useful when you need to iterate over existing objects as part of your template logic:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-sops-providers
spec:
  resyncPeriod: 600s
  resources:
    - context:
        resources:
          - index: secrets
            apiVersion: v1
            kind: Secret
            namespace: "{{.namespace}}"
            selector:
              matchLabels:
                pullsecret.company.com: "true"
          - index: sa
            apiVersion: v1
            kind: ServiceAccount
            namespace: "{{.namespace}}"

      generators:
        - template: |
            ---
            apiVersion: v1
            kind: ConfigMap
            metadata:
              name: show-context
            data:
              context.yaml: |
                {{- toYAML $ | nindent 4 }}
```





#### Base Context

The following context is always available in generator templates. The `tenant` key is always present. The `namespace` key is only available when the scope is `Namespace` (the default); it is absent when `scope: Tenant` is set.

```yaml
tenant:
    apiVersion: capsule.clastix.io/v1beta2
    kind: Tenant
    metadata:
        creationTimestamp: "2026-02-06T09:54:30Z"
        generation: 1
        labels:
            kubernetes.io/metadata.name: wind
        name: wind
        resourceVersion: "4038"
        uid: 93992a2b-cba4-4d33-9d09-da8fc0bfe93c
    spec:
        additionalRoleBindings:
            - clusterRoleName: view
              subjects:
                - apiGroup: rbac.authorization.k8s.io
                  kind: Group
                  name: wind-users
        owners:
            - clusterRoles:
                - admin
                - capsule-namespace-deleter
              kind: User
              name: joe
        permissions:
            matchOwners:
                - matchLabels:
                    team: devops
                - matchLabels:
                    tenant: wind
    status:
        classes:
            priority:
                - system-cluster-critical
                - system-node-critical
            storage:
                - standard
        conditions:
            - lastTransitionTime: "2026-02-06T09:54:30Z"
              message: reconciled
              reason: Succeeded
              status: "True"
              type: Ready
            - lastTransitionTime: "2026-02-06T09:54:30Z"
              message: not cordoned
              reason: Active
              status: "False"
              type: Cordoned
        namespaces:
            - wind-prod
            - wind-test
        owners:
            - clusterRoles:
                - admin
                - capsule-namespace-deleter
              kind: Group
              name: oidc:org:devops
            - clusterRoles:
                - admin
                - capsule-namespace-deleter
              kind: User
              name: joe
        size: 2
        spaces:
            - conditions:
                - lastTransitionTime: "2026-02-06T09:54:30Z"
                  message: reconciled
                  reason: Succeeded
                  status: "True"
                  type: Ready
                - lastTransitionTime: "2026-02-06T09:54:30Z"
                  message: not cordoned
                  reason: Active
                  status: "False"
                  type: Cordoned
              metadata: {}
              name: wind-test
              uid: 24bb3c33-6e93-4191-8dc6-24b3df7cb1ed
            - conditions:
                - lastTransitionTime: "2026-02-06T09:54:30Z"
                  message: reconciled
                  reason: Succeeded
                  status: "True"
                  type: Ready
                - lastTransitionTime: "2026-02-06T09:54:30Z"
                  message: not cordoned
                  reason: Active
                  status: "False"
                  type: Cordoned
              metadata: {}
              name: wind-prod
              uid: b3f3201b-8527-47c4-928b-ad6ae610e707
        state: Active
namespace:
    apiVersion: v1
    kind: Namespace
    metadata:
        creationTimestamp: "2026-02-06T09:54:30Z"
        labels:
            capsule.clastix.io/tenant: wind
            kubernetes.io/metadata.name: wind-test
        name: wind-test
        ownerReferences:
            - apiVersion: capsule.clastix.io/v1beta2
              kind: Tenant
              name: wind
              uid: 93992a2b-cba4-4d33-9d09-da8fc0bfe93c
        resourceVersion: "3977"
        uid: 24bb3c33-6e93-4191-8dc6-24b3df7cb1ed
    spec:
        finalizers:
            - kubernetes
    status:
        phase: Active
```
