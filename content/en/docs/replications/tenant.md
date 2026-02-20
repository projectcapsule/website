
---
title: TenantResources
weight: 2
description: >
  Replicate resources across a Tenant's Namespaces as Tenant Owner
---

Although Capsule is supporting a few amounts of personas, it can be used to allow building an Internal Developer Platform used barely by [Tenant owners](/docs/tenants/permissions#ownership), or users created by these thanks to Service Account.

In a such scenario, a Tenant Owner would like to distribute resources across all the Namespace of their Tenant, without the need to establish a manual procedure, or the need for writing a custom automation.

The Namespaced-scope API TenantResource allows to replicate resources across the Tenant's Namespace.

The Tenant owners must have proper RBAC configured in order to create, get, update, and delete their TenantResource CRD instances. This can be achieved using the Tenant key additionalRoleBindings or a custom Tenant owner role, compared to the default one (admin). You can for example create this clusterrole, which will aggregate to the admin role, to allow the Tenant Owner to create TenantResource objects. This allows all users with the rolebinding to `admin` to create TenantResource objects.

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

For our example, Alice, the project lead for the solar tenant, wants to provision automatically a DataBase resource for each Namespace of their Tenant: these are the Namespace list.

```bash
$ kubectl get namespaces -l capsule.clastix.io/tenant=solar --show-labels
NAME           STATUS   AGE   LABELS
solar-1        Active   59s   capsule.clastix.io/tenant=solar,environment=production,kubernetes.io/metadata.name=solar-1,name=solar-1
solar-2        Active   58s   capsule.clastix.io/tenant=solar,environment=production,kubernetes.io/metadata.name=solar-2,name=solar-2
solar-system   Active   62s   capsule.clastix.io/tenant=solar,kubernetes.io/metadata.name=solar-system,name=solar-system
```

Alice creates a TenantResource in the Tenant namespace solar-system as follows.

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

The expected result will be the object Cluster for the API version postgresql.cnpg.io/v1 to get created in all the Solar tenant namespaces matching the label selector declared by the key `namespaceSelector`.

```bash
$ kubectl get clusters.postgresql.cnpg.io -A
NAMESPACE   NAME              AGE   INSTANCES   READY   STATUS                     PRIMARY
solar-1     postgres-solar-1  80s   3           3       Cluster in healthy state   postgresql-1
solar-2     postgres-solar-2  80s   3           3       Cluster in healthy state   postgresql-1
```

The TenantResource object has been created in the namespace `solar-system` that doesn't satisfy the Namespace selector. Furthermore, Capsule will automatically inject the required labels to avoid a `TenantResource` could start polluting other Namespaces.

Eventually, using the key namespacedItem, it is possible to reference existing objects to get propagated across the other Tenant namespaces: in this case, a Tenant Owner can just refer to objects in their Namespaces, preventing a possible escalation referring to non owned objects.


## Object Management

It's differenciated between to object management methods which can occour. See the methods below:

### Create

An Object is considered `Created` when it was fully created by one `TenantResource`. Meaning prior to it's reconcilation this object was not yet present. For `Created` resources the following metadata is added:

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

Since we are using [Server-Side Apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/) we can also allow different items making changes to the same object, when it was created by a `TenantResource`, unless there are no conflicts:

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

Will result in the following object:

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

You can also verify in each items status via the `created` property if it was created or [adopted](#adopt)The above error could be resolved using [force](#force).

#### Pruning

Objects which were `Created` will always be deleted, when pruning is enabled. If pruning is disabled, the following metadata will be removed:

  * `metadata.labels.projectcapsule.dev/managed-by`: `resources`


Note that the label `metadata.labels.projectcapsule.dev/created-by` is preserved on pruning. Meaning another `GlobalTenantResource` or `TenantResource` can again manage this object, without requiring [adoption](#adopt). If you want to prevent this behavior, you must manually remove the `metadata.labels.projectcapsule.dev/created-by` or set it's value to a different value than `resources`.

### Adopt

Allows `TenantResources` to interact with resources, which were not created by the controller itself. This must be explicitly allowed. For `Created` resources the following metadata is added:

  * `metadata.labels.projectcapsule.dev/managed-by`: `resources`

For example the following `TenantResource` tries to change content of the existing `app-demo` `ConfigMap` in the namespace `wind-test`:

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

We can see, that we get an error for all items. Telling us, we can overwrite an existing object:

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

If we want to allow that, we can set the `adopt` property to `true`:

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

If we allow adoption, Resources can be overwriten. Note that if multiple operators are manging the same resource they should all use Server-Side-Apply.

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

#### Pruning

Objects which were `Adopted` will revert the patches introduced by the `TenantResource`, when pruning is enabled. If pruning is disabled, the following metadata will be removed:

  * `metadata.labels.projectcapsule.dev/managed-by`: `resources`


## Reconciliation
### Period

`TenantResources` are reconciled based on a given period defined in the key `resyncPeriod`. The default value is `60s` (1 minute) if not defined. This means that every minute Capsule will check if the resources defined in the `TenantResource` are properly replicated into the selected Tenants' Namespaces. We are not watching for changes on the resources, but we are reconciling them based on the defined period. Going for a low value could lead to performance issues on large clusters with many Tenants and Namespaces, tune accordingly.

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

### Manual

You can trigger a manual reconciliation of a `TenantResource` by adding the annotation `reconcile.projectcapsule.dev/requested` to the object. In fact with any change to the resource. However the annotation will be removed after the reconciliation is completed, allowing for a repeatable process.

```bash
kubectl annotate tenantresource renewable-pull-secrets -n wind-test \
  reconcile.projectcapsule.dev/requestedAt="$(date -Iseconds)"
```

## Force

You can use **force**, which translates to [forcing changes on conflicts](https://kubernetes.io/docs/reference/using-api/server-side-apply/#conflicts). Meaning two SSA-Managers are trying to manage the same field. **This option usually should be avoided, as this probably leads to reconcile wars between two operators**. However there might legitame use-cases for this:

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
    - templates:
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


## DependsOn

A `TenantResource` can declare multiple dependencies on other `TenantResource` objects in the same `Namespace` using the key `dependsOn`. Until these dependencies are not satisfied (i.e. the depended `TenantResource` is not in Ready condition), the controller will not attempt to reconcile the given `TenantResource`.

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

We can observe the status of the `TenantResource` reflecting, that it^s dependant `TenantResource` is not yet ready.

```bash
kubectl get tenantresource -n wind-test

NAME                           ITEM COUNT   READY   STATUS                            AGE
custom-cm                      6            False   applying of 6 resources failed    12h
gitops-secret                  6            False   dependency custom-cm not ready    8h
```

If a dependency does not exist, we can observe a similar status message when describing the `GlobalTenantResource` object.

```bash
kubectl get tenantresource gitops-secret -n wind-test

NAME                           ITEM COUNT   READY   STATUS                            AGE
gitops-secret                  6            False   dependency custom-cm not found    8h
```

Dependencies are evaluated in the order they are declared in the `dependsOn` array.

## Impersonation

{{% alert title="Information" color="warning" %}}
Without defining a default ServiceAccount for `TenantResource` objects, the Capsule controller ServiceAccount will be used to perform the operations, which could lead to privilege escalation if the controller has more permissions than the Tenant Owners.
{{% /alert %}}

It's strongly recommended to enable the impersonation feature when using the Replication features of Capsule. This will ensure that Replications within the Tenant's namespaces are created using the Tenant Owner's identity, thus ensuring a proper audit trail and avoiding possible privilege escalation. You can always verify which `ServiceAccount` is used via the object's status (This is the default without any configuration):

```bash
kubectl get tenantresource custom-cm -o jsonpath='{.status.serviceAccount}' | jq
{
  "name": "capsule",
  "namespace": "capsule-system"
}
```

Essentially we have the privileges of the controller `ServiceAccount`, which is a potential security concern. To avoid using the controller `ServiceAccount`, we can set the `impersonation` property on the object:

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

When adding a `ServiceAccount` we will quickly note, that the `ServiceAccount` also needs all [required permissions](#required-permissions):

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

Obiously we must provide the according Permissions:

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

### Required Permissions

The following permission are required for each resource, which should be managed by the TenantResource replication feature:

  * `get` (Always required)
  * `create` (Always required)
  * `patch` (Always required)
  * `delete` (Always required)
  * `list` (Required for [Namespaced Items](#namespaced) and [Context](#context) resources)

Missing one of these permissions will cause the replication to fail.

### Default ServiceAccount

You must also consider setting a default ServiceAccount to be used for `TenantResource` objects, to avoid that Tenant Owners could use their own identity to perform operations at the cluster level. The ServiceAccount will load the default `ServiceAccount`, unless a `TenantResource` defines its own ServiceAccount to be used for the operations. [Read More about Impersonation](/docs/operating/setup/configuration/#impersonation). You can only provide the name of the `ServiceAccount`. The namespace will always be the namespace the `TenantResource` resides in.

```yaml
manager:
  options:
    impersonation:
      tenantDefaultServiceAccount: "default"
```

This `ServiceAccount` must have proper RBAC configured in order to `create`, `get`, `update`, and `delete` the resources defined in the `TenantResource` CRD instances. You can for example create this [GlobalTenanResource](#globaltenantresource) to distribute the required RBAC across all tenants:

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

## Resources

One resource is a block which can be defined in both [GlobalTenantResource](#globaltenantresource) and [TenantResource](#tenantresource) objects. Essentially each resource block allows different strategies to define which resources must be replicated.

### NamespaceSelector

You can define resources to be managed by Capsule. This essentially means that a webhook will block any Capsule users interactions with said resources. This is useful to avoid that Tenant Owners could modify or delete resources that are critical for the platform operation.

### AdditionalMetadata

Ability to add additional `labels` and `annotations` to all objects generated by the corresponding block. [Supports Fast Template Values](/docs/operating/templating/#fast-templates):

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
      templates:
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

In the above example we have the label `k8s.company.com/tenant` on both the `template` and `additionalMetadata`. The Value from `additionalMetadata` will always have higher priority.

The following labels are always stripped because they are reserved for the controller itself:

  * `capsule.clastix.io/resources`
  * `projectcapsule.dev/created-by`
  * `capsule.clastix.io/managed-by`
  * `projectcapsule.dev/managed-by`

### NamespacedItems

With namespaced Items you can reference existing resources to be replicated across the selected Tenants' Namespaces. This is useful when the resources to be replicated are already present in the cluster.

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

**Note**: Resources with the label `projectcapsule.dev/created-by` and the value `resources` will be ignored by the namespace items to avoid possible reconciliation loops.




It' verified against the schema of the controller if a resource kind is namespaced or not. If you try to define a cluster-scoped resource under namespacedItems an error will be raised, even if the ServiceAccount used has the proper RBAC to access the resource.

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

#### Name

When you define the `name` property a `GET` request will be performed to fetch the resource to be replicated (instead of `LIST`). Meaning it will only replicate that specific resource. This will load the `Configmap` named `config-namespace` in the `solar-test` namespace and replicate it into each Tenant Namespace.


You can legerage [Fast Templates](/docs/operating/templating/#fast-templates) to parameterize  the `name`, `namespace` and `selector` properties. Allowing for scenarios where you load resources tagged with the corresponding `Tenant` name:

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

This will distribute the `ConfigMap` named `logging-config` to all other `Namespaces` of the `Tenant` where the `Namespace` wind-test belongs to.

#### Namespace

When you only define the `namespace` property a `LIST` request will be performed to fetch all the resources of the given kind in the given namespace. Meaning it will replicate all the resources of that kind in that namespace.

For `GlobalTenantResource` objects, you must define the `namespace` property when a `name` is specified:

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

**Note**: When using `TenantReplication` instead of `GlobalTenantResource`, the `namespace` field is not effective, as the resources **can only be referenced in the Namespace where the `TenantResource` object is created**.

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

      # Fetches specifc configmaps matching the selector in the namespaces tenants-system
      - apiVersion: v1
        kind: ConfigMap
        namespace: "tenants-system"
        selector:
          matchLabels:
            projectcapsule.dev/replicate: "true"
```

You can legerage [Fast Templates](/docs/operating/templating/#fast-templates) to parameterize the `namespace` property. Allowing for scenarios where you load resources tagged with the corresponding `Tenant` name:

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

#### Selector

When using a `selector` property, the keys used to load the items will not be transfered over to the resulting objects. Simply because that would lead to the replicated resources also being viewed as source and then we create a cricular clash between the actual source and the replicated source, which then would also become a source. Meaning if we have the following source `ConfigMap`:


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

And use the following `TenantReplication`:

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

The resulting replicated `ConfigMap` in the namespace `solar-prod` looks something like this (notice the absence of the label `projectcapsule.dev/replicate`):


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

You can legerage [Fast Templates](/docs/operating/templating/#fast-templates) to parameterize the `selector` property. Allowing for scenarios where you load resources tagged with the corresponding `Tenant` name:

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

### Raw

Raw Items allow defining resources to be replicated using standard Kubernetes manifests. This is useful when the resources to be replicated are not present in the cluster yet, or when you want to define them inline. You can use [Fast Templates](/docs/operating/templating/#fast-templates) to parameterize the resources based on the Tenant or Namespace context.

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

Often it's sufficient to replicate resources on a tenant basis without further logic. The following example shows how to create a [`SopsProvider`](https://github.com/peak-scale/sops-operator) for each Tenant using Fast Templates:

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

Since [Server-Side Apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/) is used to manage the resources, it is possible to define only a subset of the resource spec:




Note that when using Raw Items, the templating functionalities are limited. If you need more advanced templating you should consider [Templates](#templates).

### Generators

With `Generator` we bring a strong feature which allows to render any amount of client objects. The content per `template` is expected as valid [YAML](https://yaml.org/). Multi-YAML is supported, make sure every document is properly seperated by `---`. It maybe also produce empty string as output, if you have certain conditions for example.

The Engine used is based on [go-sprout](https://github.com/go-sprout/sprout). You can view the available functions with [our library here](/docs/operating/templating/#sprout-templating).

A fairly simple template might look like this:

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

You can use different kind of flow control tools. As mentioned the string is not limited to expecting a single object from a template:

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

You can view the [Base Context](/docs/replications/#base-context) to get an idea how the available data context looks like. If that's not yet sufficient you might need to consider using [Extra Context](/docs/replications/#context)

#### Template Snippets

Some snippets that might be useful for certain cases.

##### Names

Extract the `Tenant` Name

```html
{{ $.tenant.metadata.name }}
```

Extract the `Namespace` name

```html
{{ $.namespace.metadata.name }}
```

##### Foreach Owner

Iterates for each owner on a tenant:

```html
  {{- range $.tenant.status.owners }}
    {{ .kind }}: {{ .name }}
  {{- end }}
```

#### MissingKey

Declare the behavior when values in a template are not correctly resolved. See the following supported behaviors for missing keys when the context key is not present.

##### Invalid

Do nothing and continue execution. If printed, the result of the index operation is the string `"<no value>"`.

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

##### Zero

**This is the default behavior**

The operation returns the zero value for the map type's element.

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

##### Error

Execution stops immediately with an error.

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

```
NAME                    ITEMS   READY   STATUS                                                                                                               AGE
missing-key   6       False   error running generator: template: tpl:8:7: executing "tpl" at <$.namespace.name>: map has no entry for key "name"   9m5s
```

### Context

It's possible to load additional Resources into context. This may be useful when iterating on existing objects:

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





#### Base-Context

The following context is always available for template items. While the `tenant` key is always available, the `namespace` key is only available for namespaced iterations. Meaning for `GlobalTenantResource` with [scope](#scope) `Tenant` there' will be no `namespace` key.

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

