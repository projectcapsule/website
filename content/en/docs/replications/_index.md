---
title: Replications
weight: 6
description: >
  Replicate resources across tenants or namespaces
---

When developing an Internal Developer Platform the Platform Administrator could want to propagate a set of resources. These could be Secret, ConfigMap, or other kinds of resources that the tenants would require to use the platform. We provide dedicated Custom Resource Definitions to achieve this goal. Either on [tenant basis](#tenantresource) or [tenant-wide](#globaltenantresource).

## GlobalTenantResource

When developing an Internal Developer Platform the Platform Administrator could want to propagate a set of resources. These could be Secret, ConfigMap, or other kinds of resources that the tenants would require to use the platform.

 > A generic example could be the container registry secrets, especially in the context where the Tenants can just use a specific registry.

Starting from Capsule v0.2.0, a new set of Custom Resource Definitions have been introduced, such as the GlobalTenantResource, let's start with a potential use-case using the personas described at the beginning of this document.

Bill created the Tenants for Alice using the Tenant CRD, and labels these resources using the following command:

```bash
$ kubectl label tnt/solar energy=renewable
tenant solar labeled

$ kubectl label tnt/green energy=renewable
tenant green labeled
```

In the said scenario, these Tenants must use container images from a trusted registry, and that would require the usage of specific credentials for the image pull.

The said container registry is deployed in the cluster in the namespace harbor-system, and this Namespace contains all image pull secret for each Tenant, e.g.: a secret named `harbor-system/fossil-pull-secret` as follows.

```bash
$ kubectl -n harbor-system get secret --show-labels
NAME                    TYPE     DATA   AGE   LABELS
renewable-pull-secret   Opaque   1      28s   tenant=renewable
```

These credentials would be distributed to the Tenant owners manually, or vice-versa, the owners would require those. Such a scenario would be against the concept of the self-service solution offered by Capsule, and Bill can solve this by creating the `GlobalTenantResource` as follows.

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

The `GlobalTenantResource` is a cluster-scoped resource, thus it has been designed for cluster administrators and cannot be used by Tenant owners: for that purpose, the [TenantResource](#tenantresource) one can help.

> Capsule will select all the Tenant resources according to the key tenantSelector. Each object defined in the namespacedItems and matching the provided selector will be replicated into each Namespace bounded to the selected Tenants. Capsule will check every 60 seconds if the resources are replicated and in sync, as defined in the key resyncPeriod.

### Reconciliation Period

`GlobalTenantResources` are reconciled based on a given period defined in the key `resyncPeriod`. The default value is `60s` (1 minute) if not defined. This means that every minute Capsule will check if the resources defined in the `GlobalTenantResource` are properly replicated into the selected Tenants' Namespaces. We are not watching for changes on the resources, but we are reconciling them based on the defined period. Going for a low value could lead to performance issues on large clusters with many Tenants and Namespaces, tune accordingly.

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

#### Manual Reconciliation

You can trigger a manual reconciliation of a `GlobalTenantResource` by adding the annotation `reconcile.projectcapsule.dev/requested` to the object. In fact with any change to the resource. However the annotation will be removed after the reconciliation is completed, allowing for a repeatable process.

```bash
kubectl annotate globaltenantresource renewable-pull-secrets \
  reconcile.projectcapsule.dev/requestedAt="$(date -Iseconds)"
```







### Scope

By default, a `GlobalTenantResource` will replicate resources into all the Namespaces of the selected Tenants. However, it is possible to change this behavior to replicating items for each Tenant. For this you can change the scope of the `GlobalTenantResource` by defining the key `scope` as follows.

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


Possible Values:

  * `Tenant`: Replicate resources once per Tenant.
  * `Namespace`: Replicate resources into each Namespace of the selected Tenants. (Default)



### DependsOn

A `GlobalTenantResource` can declare multiple dependencies on other `GlobalTenantResource` objects using the key `dependsOn`. Until these dependencies are not satisfied (i.e. the depended `GlobalTenantResource` is not in Ready condition), the controller will not attempt to reconcile the given `GlobalTenantResource`.

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

We can observe the status of the `GlobalTenantResource` reflecting, that it^s dependant `GlobalTenantResource` is not yet ready.

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

### Scope

You can change to scope


### Impersonation

It's strongly recommended to enable the impersonation feature when using the Replication features of Capsule. This will ensure that Replications within the Tenant's namespaces are created using the Tenant Owner's identity, thus ensuring a proper audit trail and avoiding possible privilege escalation.









{{% alert title="Information" color="warning" %}}
Without defining a default ServiceAccount for GlobalTenantResource objects, the Capsule controller ServiceAccount will be used to perform the operations, which could lead to privilege escalation if the controller has more permissions than the Tenant Owners.
{{% /alert %}}


You must also consider setting a default ServiceAccount to be used for `GlobalTenantResource` objects, to avoid that Tenant Owners could use their own identity to perform operations at the cluster level. The ServiceAccount will load the default `ServiceAccount`, unless a `GlobalTenantResource` defines its own ServiceAccount to be used for the operations. [Read More about Impersonation](/docs/operating/setup/configuration/#impersonation). You must always provide both the name and the namespace of the `ServiceAccount` to be used, as follows.

```yaml
options:
  impersonation:
    globalDefaultServiceAccount: "capsule-default-global"
    globalDefaultServiceAccountNamespace: "capsule-system"
```

This `ServiceAccount` must have proper RBAC configured in order to `create`, `get`, `update`, and `delete` the resources defined in the `GlobalTenantResource` CRD instances. You can for example create this clusterrole, which will aggregate to the admin role, to allow the ServiceAccount to manage Secrets across all the Tenants.

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

Now let's try to create a `GlobalTenantResource`, which attempts to create a resource not allowed by the above ClusterRole:

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




## TenantResource

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









### Impersonation

It's strongly recommended to enable the impersonation feature when using the Replication features of Capsule. This will ensure that Replications within the Tenant's namespaces are created using the Tenant Owner's identity, thus ensuring a proper audit trail and avoiding possible privilege escalation.

The following permission are required for each resource, which should be managed by the TenantResource replication feature:

  * `get` (Always required)
  * `create` (Always required)
  * `patch` (Always required)
  * `delete` (Always required)
  * `list` (Required for [Namespaced Items](#namespaced) and [Context](#context) resources)

Missing one of these permissions will cause the replication to fail.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  # "namespace" omitted since ClusterRoles are not namespaced
  name: capsule-tenant-replications
rules:
- apiGroups: [""]
  #
  # at the HTTP level, the name of the resource for accessing Secret
  # objects is "secrets"
  resources: ["secrets"]
  verbs: ["get"]
```

You might want to consider using [Additional Role Bindings](/docs/tenants/permissions/#additional-rolebindings) to grant ServiceAccounts the necessary/allowed RBAC for . For example:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  additionalRoleBindings:
  - clusterRoleName: 'capsule-tenant-replications'
    subjects:
    - apiGroup: rbac.authorization.k8s.io
      kind: ServiceAccount
      name: default
```


## Resources

One resource is a block which can be defined in both [GlobalTenantResource](#globaltenantresource) and [TenantResource](#tenantresource) objects. Essentially each resource block allows different strategies to define which resources must be replicated.





### NamespaceSelector

You can define resources to be managed by Capsule. This essentially means that a webhook will block any Capsule users interactions with said resources. This is useful to avoid that Tenant Owners could modify or delete resources that are critical for the platform operation.


### AdditionalMetadata


### Namespaced

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

**Note**: When using `TenantReplication` instead of `GlobalTenantResource`, the `namespace` field is not required, as the resources **can only be referenced in the Namespace where the `TenantResource` object is created**.

**Note**: Resources with the label `projectcapsule.dev/created-by` and the value `resources` will be ignored by the namespace items to avoid possible reconciliation loops.

When you define the `name` property a `GET` request will be performed to fetch the resource to be replicated (instead of `LIST`). Meaning it will only replicate that specific resource. This will load the `Configmap` named `config-namespace` in the `solar-test` namespace and replicate it into each Tenant Namespace.

```yaml

```



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





When you only define the `namespace` property a `LIST` request will be performed to fetch all the resources of the given kind in the given namespace. Meaning it will replicate all the resources of that kind in that namespace.




You can legerage [Fast Templates](/docs/operating/templating/#fast-templates) to parameterize  the `name`, `namespace` and `selector` properties. Allowing for scenarios where you load resources tagged with the corresponding `Tenant` name:

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
            projectcapsule.dev/tenant: "{{tenant.name}}"

      # Fetch ConfigMaps labeled with the tenant name and replicate them into each Tenant Namespace
      - apiVersion: v1
        kind: ConfigMap
        name: "config-{{tenant.name}}"
        namespace: "tenant-configs"

      # Fetch ConfigMaps labeled with the tenant name and replicate them into each Tenant Namespace
      - apiVersion: v1
        kind: Secret
        namespace: "{{tenant.name}}-system"
```

When you define the `name` property a `GET` request will be performed to fetch the resource to be replicated (instead of `LIST`). Meaning it will only replicate that specific resource. 



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



### Templates

### Context
