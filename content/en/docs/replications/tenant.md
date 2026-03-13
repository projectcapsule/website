---
title: TenantResources
weight: 2
description: >
  Replicate resources across a Tenant's Namespaces as Tenant Owner
---

## Overview

`TenantResource` is a namespace-scoped CRD that lets Tenant owners automatically replicate Kubernetes resources across all Namespaces in their Tenant - without manual distribution or custom automation. It is the tenant-level counterpart to [GlobalTenantResource](../global/), which is reserved for cluster administrators.

The diagram below shows that an Administrator or a Tenant Owner can create a `TenantResource` inside a `Tenant`. In the `TenantResource` spec, a user specifies which resource they would like to replicate across the `Tenant`. When applied, this resource gets automatically distributed across all Namespaces that are part of the `Tenant`.

![Tenant Resource Replication overview](/images/content/replication-tenantresource.png)

## Prerequisites

Tenant owners must have RBAC permission to create, update, and delete `TenantResource` objects. The following `ClusterRole` aggregates to the `admin` role, granting all holders permission to manage `TenantResource` instances:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: allow-tenant-resources
  labels:
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
rules:
- apiGroups: ["capsule.clastix.io"]
  resources: ["tenantresources"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

## Example

Alice, the project lead for the `solar` tenant, wants to provision a PostgreSQL database for each production Namespace automatically:

```bash
$ kubectl get namespaces -l capsule.clastix.io/tenant=solar --show-labels
NAME           STATUS   AGE   LABELS
solar-1        Active   59s   capsule.clastix.io/tenant=solar,environment=production,kubernetes.io/metadata.name=solar-1,name=solar-1
solar-2        Active   58s   capsule.clastix.io/tenant=solar,environment=production,kubernetes.io/metadata.name=solar-2,name=solar-2
solar-system   Active   62s   capsule.clastix.io/tenant=solar,kubernetes.io/metadata.name=solar-system,name=solar-system
```

She creates a `TenantResource` in `solar-system`:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: solar-db
  namespace: solar-system
spec:
  resyncPeriod: 60s
  resources:
    - additionalMetadata:
        labels:
          "replicated-by": "capsule"
      namespaceSelector:
        matchLabels:
          environment: production
      rawItems:
        - apiVersion: postgresql.cnpg.io/v1
          kind: Cluster
          metadata:
            name: "postgres-{{namespace}}"
          spec:
            description: PostgreSQL cluster for the {{tenant.name}} Project
            instances: 3
            postgresql:
              pg_hba:
                - hostssl app all all cert
            primaryUpdateStrategy: unsupervised
            storage:
              size: 1Gi
```

Capsule replicates the `Cluster` resource into every Namespace matching the `namespaceSelector`. The Namespace where the `TenantResource` itself lives (`solar-system`) is automatically excluded, and Capsule injects labels to prevent the `TenantResource` from propagating into unowned Namespaces.

```bash
$ kubectl get clusters.postgresql.cnpg.io -A
NAMESPACE   NAME              AGE   INSTANCES   READY   STATUS                     PRIMARY
solar-1     postgres-solar-1  80s   3           3       Cluster in healthy state   postgresql-1
solar-2     postgres-solar-2  80s   3           3       Cluster in healthy state   postgresql-1
```

> Objects managed by this controller can be either **created** (new objects) or **adopted** (existing objects). See [Object Management](#object-management) in the Advanced section for full details.

---

## Basic Usage

### Resources

A resource block defines *what* to replicate. Multiple blocks can be stacked in the `resources` array, each using one or more of the strategies below.

#### NamespaceSelector

The `namespaceSelector` field restricts replication to Namespaces matching a label selector. Capsule also protects selected resources from modification by Tenant users via its webhook.

#### AdditionalMetadata

Use `additionalMetadata` to attach extra `labels` and `annotations` to every generated object. [Fast Template values](/docs/operating/templating/#fast-templates) are supported:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
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
kind: TenantResource
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
kind: TenantResource
metadata:
  name: tenant-resource-replications
spec:
  resyncPeriod: 60s
  resources:
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

Providing `name` triggers a `GET` request for that single resource rather than a `LIST`:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: tenant-resource-replications
  namespace: wind-test
spec:
  resyncPeriod: 60s
  resources:
    - namespacedItems:
      # Fetch ConfigMaps labeled with the tenant name and replicate them into each Tenant Namespace
      - apiVersion: v1
        kind: ConfigMap
        name: "logging-config"
```

This distributes the `ConfigMap` named `logging-config` to all other Namespaces of the Tenant that `wind-test` belongs to.

[Fast Templates](/docs/operating/templating/#fast-templates) are supported for `name`, `namespace`, and `selector`.

##### Namespace

Providing only `namespace` performs a `LIST` of all resources of that kind in that namespace:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: tenant-resource-replications
spec:
  resources:
  - namespacedItems:
    - apiVersion: v1
      kind: ConfigMap
      name: config-namespace
      optional: true
```

[Fast Templates](/docs/operating/templating/#fast-templates) are supported for the `namespace` property:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
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
kind: TenantResource
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
kind: TenantResource
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
kind: TenantResource
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
kind: TenantResource
metadata:
  name: tenant-cluster-rbac
spec:
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
kind: TenantResource
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
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
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
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
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
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
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

Will error the `TenantResources`:

```sh
NAME                    ITEMS   READY   STATUS                                                                                                               AGE
missing-key   6       False   error running generator: template: tpl:7:13: executing "tpl" at <$.custom.account.name>: map has no entry for key "custom"   9m5s
```

---

### Reconciliation

#### Period

`TenantResources` reconcile on the interval defined by `resyncPeriod`. The default is `60s`. Capsule does not watch source resources for changes; it reconciles periodically. A very short interval on large clusters with many Tenants and Namespaces can cause performance issues - tune this value accordingly.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: renewable-pull-secrets
  namespace: wind-test
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
kubectl annotate tenantresource renewable-pull-secrets -n wind-test \
  reconcile.projectcapsule.dev/requestedAt="$(date -Iseconds)"
```

---

### Impersonation

{{% alert title="Information" color="warning" %}}
Without a configured ServiceAccount, the Capsule controller ServiceAccount is used for replication operations. This may allow privilege escalation if the controller has broader permissions than Tenant owners.
{{% /alert %}}

Enabling impersonation ensures that replication operations run under a specific ServiceAccount identity, providing a proper audit trail and limiting privilege exposure. You can check which ServiceAccount is currently in use via the object's status:

```bash
kubectl get tenantresource custom-cm -o jsonpath='{.status.serviceAccount}' | jq
{
  "name": "capsule",
  "namespace": "capsule-system"
}
```

To use a different ServiceAccount, set the `serviceAccount` field on the object. For `TenantResource`, only the name is required - the namespace is always inferred from the Namespace the `TenantResource` resides in:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: tenant-resource-replications
  namespace: wind-test
spec:
  serviceAccount:
    name: "default"
  resources:
    - namespacedItems:
      - apiVersion: v1
        kind: ConfigMap
        name: "config-namespace"
```

If the ServiceAccount lacks the required RBAC, replication will fail with a permission error:

```
  - kind: ConfigMap
    name: game-demo
    namespace: wind-test
    status:
      created: true
      message: 'apply failed for item 0/raw-0: applying object failed: configmaps
        "game-demo" is forbidden: User "system:serviceaccount:wind-test:default"
        cannot patch resource "configmaps" in API group "" in the namespace "wind-test"'
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
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: default-sa-replication
spec:
  resyncPeriod: 60s
  resources:
    - rawItems:
      - apiVersion: rbac.authorization.k8s.io/v1
        kind: RoleBinding
        metadata:
          name: wind-replication
        subjects:
          - kind: ServiceAccount
            name: default
            namespace: wind-test
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

To ensure all `TenantResource` objects use a controlled identity by default, configure a default ServiceAccount in the Capsule manager options. Per-object `serviceAccount` fields override this default. Only the name is required; the namespace is always the one the `TenantResource` resides in.

[Read more about Impersonation](/docs/operating/setup/configuration/#impersonation).

```yaml
manager:
  options:
    impersonation:
      tenantDefaultServiceAccount: "default"
```

The default ServiceAccount must have sufficient RBAC. You can use a [GlobalTenantResource](../global/) to distribute the required `RoleBinding` across all Tenants:

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: capsule-default-namespace
rules:
- apiGroups: [""]
  resources: ["limitranges", "secrets"]
  verbs: ["get", "patch", "create", "delete", "list"]
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: default-sa-replication
spec:
  resyncPeriod: 60s
  resources:
    - rawItems:
      - apiVersion: rbac.authorization.k8s.io/v1
        kind: RoleBinding
        metadata:
          name: default-replication
        subjects:
          - kind: ServiceAccount
            name: default
            namespace: wind-test
        roleRef:
          kind: ClusterRole
          name: capsule-tenant-replications
          apiGroup: rbac.authorization.k8s.io
```

---

## Advanced

This section covers more advanced features of the Replication setup.

### Object Management

Capsule uses [Server-Side Apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/) for all replication operations. Two management modes exist depending on whether the object already existed before reconciliation.

#### Create

An object is *Created* when the `TenantResource` first encounters it - it did not exist prior to reconciliation. Created objects receive the following metadata:

  * `metadata.labels.projectcapsule.dev/created-by`: `resources`
  * `metadata.labels.projectcapsule.dev/managed-by`: `resources`

```yaml
kind: ConfigMap
metadata:
  labels:
    projectcapsule.dev/created-by: resources
    projectcapsule.dev/managed-by: resources
  name: common-config
  namespace: wind-test
  resourceVersion: "549517"
  uid: 23abbb7a-2926-416a-bc72-9f793ebf6080
```

Because Server-Side Apply tracks field ownership, multiple `TenantResource` objects can contribute non-conflicting fields to the same object:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: tenant-ns-cm-registration
  namespace: wind-test
spec:
  resources:
    - generators:
        - template: |
            ---
            apiVersion: v1
            kind: ConfigMap
            metadata:
              name: common-config
            data:
              {{ $.namespace.metadata.name }}.conf: |
                {{ toYAML $.namespace .metadata | nindent 4 }}
    - rawItems:
        - apiVersion: v1
          kind: ConfigMap
          metadata:
            name: common-config
          data:
            additional-data: "raw"
```

Result:

```yaml
apiVersion: v1
data:
  additional-data: raw
  wind-test.conf: |2
    creationTimestamp: "2026-02-10T10:58:33Z"
    labels:
        capsule.clastix.io/tenant: wind
        kubernetes.io/metadata.name: wind-test
    name: wind-test
    ownerReferences:
        - apiVersion: capsule.clastix.io/v1beta2
          kind: Tenant
          name: wind
          uid: 42f72944-f6d9-44a2-9feb-cd2b52f4043d
    resourceVersion: "526252"
    uid: 3f280d61-98b7-4188-9853-9a6598ca10a9
kind: ConfigMap
metadata:
  creationTimestamp: "2026-02-05T15:37:09Z"
  labels:
    projectcapsule.dev/created-by: resources
    projectcapsule.dev/managed-by: resources
  name: common-config
  namespace: wind-test
  resourceVersion: "561707"
  uid: 33cfe1c6-1c9e-4417-9dd5-26ac0ba3bc85
```

You can check the `created` property on each item's status to determine whether it was created or adopted. Field conflicts can be resolved with [Force](#force).

##### Pruning

When pruning is enabled, *Created* objects are deleted when they fall out of scope. When pruning is disabled, the `metadata.labels.projectcapsule.dev/managed-by` label is removed instead.

The label `metadata.labels.projectcapsule.dev/created-by` is preserved after pruning, allowing another `GlobalTenantResource` or `TenantResource` to take ownership without explicit adoption. To prevent re-adoption, remove or change this label manually.

#### Adopt

By default, a `TenantResource` cannot modify objects it did not create. Adoption must be explicitly enabled. Adopted objects receive the following metadata:

  * `metadata.labels.projectcapsule.dev/managed-by`: `resources`

The following example attempts to modify the existing `app-demo` `ConfigMap` in `wind-test`:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: app-config
  namespace: wind-test
spec:
  resources:
    - generators:
        - template: |
            ---
            apiVersion: v1
            kind: ConfigMap
            metadata:
              name: app-demo
            data:
              {{ $.namespace.metadata.name }}.conf: |
                {{ toYAML $.namespace .metadata | nindent 4 }}
```

Without adoption enabled, all items fail:

```yaml
kubectl get tenantresource argo-cd-permission -o yaml

...
  processedItems:
  - kind: ConfigMap
    name: app-demo
    namespace: wind-prod
    origin: 0/template-0-0
    status:
      created: true
      lastApply: "2026-02-10T17:59:46Z"
      status: "True"
      type: Ready
    tenant: wind
    version: v1
  - kind: ConfigMap
    name: app-demo
    namespace: wind-test
    origin: 0/template-0-0
    status:
      message: 'apply failed for item 0/template-0-0: evaluating managed metadata:
        object v1/ConfigMap wind-test/app-demo exists and cannot be adopted'
      status: "False"
      type: Ready
    tenant: wind
    version: v1
```

Enable adoption by setting `settings.adopt: true`:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: app-config
  namespace: wind-test
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
              name: app-demo
            data:
              {{ $.namespace.metadata.name }}.conf: |
                {{ toYAML $.namespace .metadata | nindent 4 }}
```

When adoption is enabled, resources can be modified. Note that if multiple operators manage the same resource, all must use Server-Side Apply to avoid conflicts.

```yaml
  processedItems:
  - kind: ConfigMap
    name: app-demo
    namespace: wind-prod
    origin: 0/generator-0-0
    status:
      created: true
      lastApply: "2026-02-10T17:59:46Z"
      status: "True"
      type: Ready
    tenant: wind
    version: v1
  - kind: ConfigMap
    name: app-demo
    namespace: wind-test
    origin: 0/generator-0-0
    status:
      lastApply: "2026-02-10T18:01:31Z"
      status: "True"
      type: Ready
    tenant: wind
    version: v1
```

##### Pruning

When pruning is enabled, adoption is reverted - the patches introduced by the `TenantResource` are removed from the object. When pruning is disabled, only the `metadata.labels.projectcapsule.dev/managed-by` label is removed.

---

### DependsOn

A `TenantResource` can declare dependencies on other `TenantResource` objects in the same Namespace using `dependsOn`. The controller will not reconcile the resource until all declared dependencies are in `Ready` state.

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: gitops-secret
  namespace: wind-test
spec:
  resyncPeriod: 60s
  dependsOn:
    - name: custom-cm
  resources:
    - additionalMetadata:
        labels:
          projectcapsule.dev/tenant: "{{tenant.name}}"
      rawItems:
        - apiVersion: v1
          kind: Secret
          metadata:
            name: myregistrykey
            namespace: awesomeapps
          data:
            .dockerconfigjson: UmVhbGx5IHJlYWxseSByZWVlZWVlZWVlZWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsbGx5eXl5eXl5eXl5eXl5eXl5eXl5eSBsbGxsbGxsbGxsbGxsbG9vb29vb29vb29vb29vb29vb29vb29vb29vb25ubm5ubm5ubm5ubm5ubm5ubm5ubm5ubmdnZ2dnZ2dnZ2dnZ2dnZ2dnZ2cgYXV0aCBrZXlzCg==
          type: kubernetes.io/dockerconfigjson
```

The status reflects whether a dependency is not yet ready:

```bash
kubectl get tenantresource -n wind-test

NAME                           ITEM COUNT   READY   STATUS                            AGE
custom-cm                      6            False   applying of 6 resources failed    12h
gitops-secret                  6            False   dependency custom-cm not ready    8h
```

If a dependency does not exist:

```bash
kubectl get tenantresource gitops-secret -n wind-test

NAME                           ITEM COUNT   READY   STATUS                            AGE
gitops-secret                  6            False   dependency custom-cm not found    8h
```

Dependencies are evaluated in the order they are declared in the `dependsOn` array.

---

### Force

Setting `settings.force: true` instructs Capsule to [force-apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/#conflicts) changes on Server-Side Apply conflicts, claiming field ownership even if another manager already holds it.

**This option should generally be avoided.** Forcing ownership over a field managed by another operator will almost certainly cause a reconcile war. Only use it in scenarios where you intentionally want Capsule to win ownership disputes.

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: tenant-technical-accounts
  namespace: wind-test
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
kind: TenantResource
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

The following context is always available in generator templates. The `tenant` key is always present.

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

