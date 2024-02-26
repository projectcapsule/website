---
title: Replications
weight: 10
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

The GlobalTenantResource is a cluster-scoped resource, thus it has been designed for cluster administrators and cannot be used by Tenant owners: for that purpose, the [TenantResource](#tenantresource) one can help.

> Capsule will select all the Tenant resources according to the key tenantSelector. Each object defined in the namespacedItems and matching the provided selector will be replicated into each Namespace bounded to the selected Tenants. Capsule will check every 60 seconds if the resources are replicated and in sync, as defined in the key resyncPeriod.

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
        "replicated-by": "capsule" 
      namespaceSelector:
        matchLabels:
          environment: production
      rawItems:
        - apiVersion: postgresql.cnpg.io/v1
          kind: Cluster
          metadata:
            name: postgresql
          spec:
            description: PostgreSQL cluster for the Solar project
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
NAMESPACE   NAME         AGE   INSTANCES   READY   STATUS                     PRIMARY
solar-1     postgresql   80s   3           3       Cluster in healthy state   postgresql-1
solar-2     postgresql   80s   3           3       Cluster in healthy state   postgresql-1
```

The TenantResource object has been created in the namespace `solar-system` that doesn't satisfy the Namespace selector. Furthermore, Capsule will automatically inject the required labels to avoid a `TenantResource` could start polluting other Namespaces.

Eventually, using the key namespacedItem, it is possible to reference existing objects to get propagated across the other Tenant namespaces: in this case, a Tenant Owner can just refer to objects in their Namespaces, preventing a possible escalation referring to non owned objects.
