---
title: GlobalTenantResources
weight: 1
description: >
  Replicate resources across tenants or namespaces as Cluster Administrator.
---

## Overview

`GlobalTenantResource` is a cluster-scoped CRD designed for cluster administrators. It lets you automatically replicate Kubernetes resources - such as Secrets, ConfigMaps, or custom resources - into the Namespaces of selected Tenants. Tenant owners cannot create `GlobalTenantResource` objects; for tenant-scoped replication, see [TenantResource](/docs/replications/tenant/).

The diagram below shows that an Administrator can create a `GlobalTenantResource`. In the `GlobalTenantResource` spec, an Administrator specifies which resource they would like to replicate, and where this resource should be replicated to. When applied, this resource gets automatically distributed across all Namespaces of the `Tenants` that are selected in the `GlobalTenantResource`.

![Global Tenant Resource Replication overview](/images/content/replication-globaltenantresource.png)

{{% alert title="OpenShift: etcd Encryption" color="warning" %}}
If you are running on OpenShift with etcd encryption enabled and replicating `ConfigMap`s or `Secret`s, you must exclude the OpenShift storage version migrator from the replication webhook. Without this, the migrator cannot rotate encryption keys. See the [OpenShift installation guide](/docs/operating/setup/openshift/#etcd-encryption) for the required configuration.
{{% /alert %}}

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

Each block accepts a [resource policy](#object-management) for creation, protection,
SSA conflicts, cleanup, and optional CEL conditions.

A resource block defines *what* to replicate. Multiple blocks can be stacked in the `resources` array, each using one or more of the strategies below.

#### NamespaceSelector

The `namespaceSelector` field restricts replication to Namespaces matching a label selector. Capsule also protects selected resources from modification by Tenant users via its webhook.

#### AdditionalMetadata

Use `additionalMetadata` to attach extra `labels` and `annotations` to every generated object. [Fast Template values](/docs/operating/concepts/templating/#fast-templates) are supported:

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

[Fast Templates](/docs/operating/concepts/templating/#fast-templates) are supported for `namespace`:

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

[Fast Templates](/docs/operating/concepts/templating/#fast-templates) are supported for `selector`:

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

Raw items let you define resources inline as standard Kubernetes manifests. Use this when the resource does not yet exist in the cluster, or when you want to define it directly in the spec. [Fast Templates](/docs/operating/concepts/templating/#fast-templates) are supported.

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

Generators render one or more Kubernetes objects from a Go template string. The template content must be valid YAML; multi-document output separated by `---` is supported. The template engine is based on [go-sprout](https://github.com/go-sprout/sprout) - see [available functions](/docs/operating/concepts/templating/#sprout-templating).

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

  * `None`: Replicate based on items generated within generators. Essentially not reconciling based on items but running once.
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

Set `spec.resources[].policy` separately for each resource block. The policy applies
to all destinations produced by that block, while namespace selectors determine
which namespace profiles receive them. See the
[shared SSA policy reference](/docs/operating/concepts/managed-resources/) for the
complete contract and [migration guidance](/docs/replications/#deprecated-settings-and-migration)
for existing manifests using `spec.settings`.

#### Create

`creation: Owner` is the default. Capsule creates an absent object and applies future
changes to objects created by the applying controller. An unrelated existing target
is an ownership error. Capsule records whether each processed target was created or
adopted; `protect: true` blocks direct user updates and deletion while it is managed.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: namespace-profile
spec:
  resources:
    - policy:
        creation: Owner
        force: false
        protect: true
        deletion: Remove
      rawItems:
        - apiVersion: v1
          kind: ConfigMap
          metadata:
            name: namespace-profile
          data:
            environment: production
```

SSA tracks ownership of individual fields. Multiple managers can contribute
non-conflicting fields to a shared object. A conflict is reported through
processed-item status; use [Force](#force) only when Capsule should take ownership
of those fields.

#### Adopt

Use `creation: Merge` to manage fields on an existing object, or create it if it is
absent. For example, this block adds a data entry to an existing ConfigMap:

```yaml
spec:
  resources:
    - policy:
        creation: Merge
        force: false
        protect: false
        deletion: Remove
      rawItems:
        - apiVersion: v1
          kind: ConfigMap
          metadata:
            name: shared-config
          data:
            capsule-profile: production
```

This example explicitly disables protection so other actors can continue managing
the ConfigMap. Adoption alone does not disable protection; the default remains
`protect: true`. Existing fields owned by other managers remain unless ownership
conflicts are intentionally resolved with `force`.

##### Pruning

Each block's `policy.deletion` controls cleanup when its targets leave scope,
including namespace deselection, block removal, or parent deletion:

| Policy | Created target | Adopted target |
| --- | --- | --- |
| `Remove` | Delete the object | Relinquish Capsule's applied fields and tracking |
| `Orphan` | Retain the object and content; remove lifecycle metadata | Retain the object and content; remove lifecycle metadata |

Cleanup uses the last successfully reconciled policy. A false apply condition does
not suppress cleanup, and changing `deletion` while the condition is false updates
the policy used for subsequent cleanup of already managed targets.

#### Conditional apply

Use `policy.condition` to control when rendered content is applied. It is evaluated
independently for every destination, with `object` set to the existing resource or
`null`, and `now` set to the evaluation timestamp:

```yaml
policy:
  condition: "object == null"
```

This creates a target only when absent. Rendering still happens before evaluation.
A false result reports `ConditionNotMet: apply skipped`, preserves content and its
last apply timestamp, and keeps already managed targets tracked. Policy changes
still take effect: protection metadata is reconciled and the current cleanup policy
is retained. Previously unowned targets remain untouched. See
[apply conditions](/docs/operating/concepts/managed-resources/#apply-conditions)
for validation, error handling, and field-retention semantics, and
[conditional age-key rotation](/docs/replications/global/#conditional-age-key-rotation)
for a complete stateful generator. A TenantResource can use the same resource block
within its tenant.

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

Setting `spec.resources[].policy.force: true` instructs Capsule to [force-apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/#conflicts) changes on Server-Side Apply conflicts, claiming field ownership even if another manager already holds it.

**This option should generally be avoided.** Forcing ownership over a field managed by another operator will almost certainly cause a reconcile war. Only use it in scenarios where you intentionally want Capsule to win ownership disputes.

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-technical-accounts
spec:
  resources:
    - policy:
        creation: Owner
        force: true
        protect: true
        deletion: Remove
      generators:
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

The `context` field lets you load additional Kubernetes resources into the template rendering context. This is useful when you need to iterate over existing objects as part of your template logic. To inspect the full context available to a template, you can create a `ConfigMap` that dumps it:

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

A useful use case for this can be to add all imagePullSecrets to the `default` service account, so users don't have to add these manually to their deployment spec. In the example below, all the secrets with the label `energy: non-renewable` are selected from the namespace `system-imagepullsecrets`. The names of these secrets are added to the `default` service account's `.imagePullSecrets` for all matching tenants. Note also the `dependsOn`, which is a dependency to a different `GlobalTenantResource` which replicates the secret itself into each tenant namespace:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: imagepullsecrets-default-sa-non-renewable
spec:
  tenantSelector:
    matchLabels:
      energy: non-renewable
  dependsOn:
    - name: replicate-imagepullsecrets-non-renewable
  resyncPeriod: 600s
  resources:
    - policy:
        creation: Merge
        force: false
        protect: false
        deletion: Remove
      context:
        resources:
          - index: secrets
            apiVersion: v1
            kind: Secret
            namespace: "system-imagepullsecrets"
            selector:
              matchLabels:
                imagePullSecret: "true"
                energy: non-renewable
      generators:
        - template: |
            ---
            apiVersion: v1
            kind: ServiceAccount
            metadata:
              name: default
            {{- if $.secrets }}
            imagePullSecrets:
            {{- range $.secrets }}
              - name: {{ .metadata.name }}
            {{- end }}
            {{- end }}
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

### Monitoring

Currently mainly the conditions of `GlobalTenantResources` are exposed as metrics:

```
# HELP capsule_global_resource_condition The current condition status of a global tenant resource.
# TYPE capsule_global_resource_condition gauge
capsule_global_resource_condition{condition="Cordoned",name="templated-forbidden-namespace"} 0
capsule_global_resource_condition{condition="Ready",name="templated-forbidden-namespace"} 1
```

## Examples

Different use cases for `GlobalTenantResource` objects.

### Conditional age-key rotation

This namespace profile creates `<tenant>-age-keys` in every selected namespace and
retains each previous private identity in its own Secret data entry. It rotates on
the first successful reconciliation at least 30 days after the last rotation.
`720h` is a fixed 30-day duration, not a calendar month; `30d` is not supported by
`resyncPeriod` or CEL's `duration()`.

The example uses `deletion: Orphan`, so removing the GTR, its block, or namespace
selection retains the Secret and keys while removing Capsule's lifecycle metadata.

Create the execution identity and grant it Secret access before applying the GTR.
This cluster-wide example is for platform administrators; scope the binding to the
intended namespaces when distributing only to a fixed set of namespaces.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gtr-reconciler
  namespace: capsule-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: capsule-age-key-reconciler
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: capsule-age-key-reconciler
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: capsule-age-key-reconciler
subjects:
  - kind: ServiceAccount
    name: gtr-reconciler
    namespace: capsule-system
```

Apply this GTR, then opt in a namespace belonging to a Tenant:

```yaml
---
# Enable this namespace profile with:
# kubectl label namespace <namespace> projectcapsule.dev/age-keys=enabled
# Uses the gtr-reconciler ServiceAccount and Secret permissions from rbac.yaml.
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: age-key-rotation
spec:
  scope: Namespace
  resyncPeriod: 720h
  serviceAccount:
    name: gtr-reconciler
    namespace: capsule-system
  resources:
    - namespaceSelector:
        matchLabels:
          projectcapsule.dev/age-keys: enabled
      policy:
        creation: Owner
        force: false
        protect: true
        deletion: Orphan
        # First creation, then the first successful reconciliation after 30 days.
        # A missing marker initializes rotation; an invalid marker blocks writes.
        condition: |
          object == null ||
          !has(object.metadata.annotations) ||
          !('keys.example.org/rotated-at' in object.metadata.annotations) ||
          now >= timestamp(object.metadata.annotations['keys.example.org/rotated-at']) + duration('720h')
      context:
        resources:
          - index: existing
            apiVersion: v1
            kind: Secret
            # Fast-template syntax; the namespace defaults to the selected namespace.
            name: "{{tenant.name}}-age-keys"
            optional: true
      generators:
        - missingKey: error
          template: |
            {{- $name := printf "%s-age-keys" .tenant.metadata.name -}}
            {{- $existing := getResourceByName $name (index . "existing" | default (list)) -}}
            {{- $key := generateAgeKey -}}
            apiVersion: v1
            kind: Secret
            metadata:
              name: {{ $name | quote }}
              annotations:
                keys.example.org/rotated-at: {{ now | date "2006-01-02T15:04:05Z07:00" | quote }}
            type: Opaque
            data:
              # Keep every previous entry under its original name and value.
              {{- range $field, $value := get "data" $existing | default (dict) }}
              {{- if ne $field "recipient" }}
              {{ $field | quote }}: {{ $value | quote }}
              {{- end }}
              {{- end }}
              # Each identity gets a unique entry named after its public recipient.
              {{ printf "%s.agekey" $key.Recipient | quote }}: {{ $key.Identity | b64enc | quote }}
              recipient: {{ $key.Recipient | b64enc | quote }}
```

```bash
kubectl label namespace solar-uat projectcapsule.dev/age-keys=enabled
```

Context reference names use fast templates: `"{{tenant.name}}-age-keys"`.
Generator bodies use Go templates: `.tenant.metadata.name`. An omitted context
namespace resolves to the selected namespace, and `optional: true` handles the
initial missing Secret. Context reads use the execution ServiceAccount. When a
conditional generator reads its destination as context, Capsule checks the observed
resource version before applying content; concurrent changes trigger a fresh render.

Each identity is stored under `<public-recipient>.agekey`, preserving its name and
value across rotations. `data.recipient` holds the newest public recipient. When
mounted as a volume, each identity becomes a separate file. The generator explicitly
loads and renders the previous data entries: a condition does not change SSA field
retention. History has no automatic limit and must fit Kubernetes' Secret size limit.

Rendering precedes condition evaluation, so a candidate key may be generated and
discarded on a skip. A missing rotation marker initializes rotation; a malformed
timestamp is an evaluation error and prevents the target write. A false condition
keeps keys, the rotation marker, and the last content-apply timestamp unchanged.
Protection and cleanup-policy changes still reconcile on an already managed Secret.

`resyncPeriod` controls how often eligibility is checked, with reconciliation jitter;
the condition defines the minimum rotation interval. The example uses `720h` for
both. Use a shorter resync for more frequent eligibility checks. For a quick local
demo, use `resyncPeriod: 10s` and `duration('5m')` in the condition.

Inspect the result without printing private identities:

```bash
kubectl get gtr age-key-rotation -o json \
  | jq '.status | {selectedTenants, size, processedItems, conditions}'
kubectl get secret solar-age-keys -n solar-uat -o json \
  | jq '{rotatedAt: .metadata.annotations["keys.example.org/rotated-at"],
         identityEntries: [.data | keys[] | select(endswith(".agekey"))]}'
```

A fresh Secret has one `.agekey` entry. Before the interval elapses, the timestamp
and entries stay unchanged. The next eligible successful reconciliation advances
the timestamp and adds one entry while preserving every previous entry's name and
value. Each selected namespace, including namespaces in different tenants, has an
independent Secret and rotation timestamp.

`Ready=True` with `size: 0` and empty `processedItems` can mean no namespace matched.
`selectedTenants` alone does not prove that a namespace was selected. Check tenant
membership and the namespace's `projectcapsule.dev/age-keys=enabled` label. A
condition skip on a rendered destination instead appears in processed-item status
as `ConditionNotMet: apply skipped`.

### Generate ServiceAccount Tenant Owner per Tenant

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: gitops-reconciler
spec:
  resyncPeriod: 60s
  resources:
    - rawItems:
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

### Manage Global Proxy Settings per Tenant

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
                  - "globalcustomquotas"
                  operations:
                  - List
                  selector:
                    matchLabels:
                      company.com/tenant: {{ $.tenant.metadata.name }}
```

### Collect HTTPRoutes within per Tenant and aggregate to managed gateway

The following example solves a common problem with Gateway-API and Certificate management. Assume you have a managed gateway with a managed cluster-issuer. In this case we can load all the HTTPRoutes and template the corresponding tenant. The following example also allows to modify the EnvoyProxy instance with [Tenant Data](/docs/operating/concepts/templating/#data)

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: managed-envoy-gateway
spec:
  scope: Tenant
  resyncPeriod: 30s
  resources:
    - context:
        resources:
          - apiVersion: gateway.networking.k8s.io/v1
            kind: HTTPRoute
            index: https
            selector:
              matchLabels:
                projectcapsule.dev/tenant: "{{tenant.name}}"
      generators:
        - missingKey: zero
          template: |
            {{- $ingressBandwidth := dig "spec" "data" "networking" "ingress" "bandwidth" "" $.tenant }}
            {{- $egressBandwidth := dig "spec" "data" "networking" "egress" "bandwidth" "" $.tenant }}
            {{- $loadBalancerIP := dig "spec" "data" "networking" "ingress" "loadbalancer" "" $.tenant }}
            ---
            apiVersion: gateway.envoyproxy.io/v1alpha1
            kind: EnvoyProxy
            metadata:
              name: tenant-{{ $.tenant.metadata.name }}-gateway
              namespace: tenant-{{ $.tenant.metadata.name }}-system
            spec:
              logging:
                level:
                  default: info
              provider:
                type: Kubernetes
                kubernetes:
                  envoyDeployment:
                    replicas: 2
                    pod:
                      priorityClassName: tenant-critical
                      {{- if or $ingressBandwidth $egressBandwidth }}
                      annotations:
                        {{- with $ingressBandwidth }}
                        kubernetes.io/ingress-bandwidth: {{ . }}
                        {{- end }}
                        {{- with $egressBandwidth }}
                        kubernetes.io/egress-bandwidth: {{ . }}
                        {{- end }}
                      {{- end }}
                  {{- with $loadBalancerIP }}
                  envoyService:
                    loadBalancerIP: {{ . }}
                  {{- end }}

        - missingKey: zero
          template: |
            ---
            apiVersion: gateway.networking.k8s.io/v1
            kind: Gateway
            metadata:
              name: tenant-{{ $.tenant.metadata.name }}-gateway
              namespace: tenant-{{ $.tenant.metadata.name }}-system
              annotations:
                cert-manager.io/cluster-issuer: managed-cluster-issuer
                cert-manager.io/private-key-size: "4096"
                cert-manager.io/private-key-algorithm: RSA
            spec:
              gatewayClassName: tenants
              infrastructure:
                parametersRef:
                  group: gateway.envoyproxy.io
                  kind: EnvoyProxy
                  name: tenant-{{ $.tenant.metadata.name }}-gateway
              listeners:
                - name: http-challenge
                  port: 80
                  protocol: HTTP
                  allowedRoutes:
                    namespaces:
                      from: Selector
                      selector:
                        matchLabels:
                          capsule.clastix.io/tenant: "{{ $.tenant.metadata.name }}"
                {{- range $_, $http := $.https }}
                  {{- range $i, $hostname := $http.spec.hostnames }}
                - name: {{ $http.metadata.namespace }}-{{ $http.metadata.name }}-{{ $i }}
                  port: 443
                  protocol: HTTPS
                  hostname: {{ $hostname}}
                  tls:
                    mode: Terminate
                    certificateRefs:
                      - group: ''
                        kind: Secret
                        name: {{ $http.metadata.namespace }}-{{ $http.metadata.name }}-{{ $i }}-tls
                  allowedRoutes:
                    namespaces:
                      from: Selector
                      selector:
                        matchLabels:
                           kubernetes.io/metadata.name: "{{ $http.metadata.namespace }}"
                  {{- end }}
                {{- end }}
```

### Generate Cortex/Mimir Overrides per Tenant

This example shows the case when you need to populate content in a subkey, where Server-Side Apply is not sufficient, since it cannot manage specific fields of an object, but only the whole object itself. In this case, we can use a generator to generate the whole content of the subkey based on the Tenant's data.

With Cortex/Mimir, you can use the `overrides` field to specify tenant-specific configuration ([limits](https://grafana.com/docs/mimir/latest/configure/configuration-parameters/#limits)). This example generates a `ConfigMap` for each Tenant containing its overrides, based on the Tenant's data, if provided. This is a case, where the [scope](#scope) is set to `None`, since we don't want to replicate the generated `ConfigMap` into each Namespace, but just have it available in a single location for consumption by an external system:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: mimir-overrides-cluster
spec:
  scope: None
  resyncPeriod: 30s
  resources:
    - context:
        resources:
          - apiVersion: capsule.clastix.io/v1beta2
            kind: Tenant
            index: tnts
      generators:
        - missingKey: zero
          template: |
            ---
            apiVersion: v1
            kind: ConfigMap
            metadata:
              name: mimir-overrides
              namespace: observability-system
            data:
              overrides.yaml: |
                overrides:
                {{- range $i, $tnt := $.tnts }}
                  {{ $tnt.metadata.name }}:
                    ingestion_rate: {{ $tnt | dig "spec" "data" "limits" "ingestionRate" 10000 }}
                    ingestion_burst_size: {{ $tnt | dig "spec" "data" "limits" "ingestionBurstSize" 20000 }}
                {{- end }}
```
