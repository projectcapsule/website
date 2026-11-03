---
title: Backup & Restore
description: Run Backups and Restores of Tenants
weight: 6
aliases:
  - /docs/operating/backup-restore/
---

[Velero](https://velero.io/) is a backup and restore solution that performs data protection, disaster recovery and migrates Kubernetes cluster from on-premises to the Cloud or between different Clouds.

When coming to backup and restore in Kubernetes, we have two main requirements:

* Configurations backup
* Data backup

The first requirement aims to backup all the resources stored into etcd database, for example: namespaces, pods, services, deployments, etc. The second is about how to backup stateful application data as volumes.

The main limitation of Velero is the multi tenancy. Currently, Velero does not support multi tenancy meaning it can be only used from admin users and so it cannot provided "as a service" to the users. This means that the cluster admin needs to take care of users' backup.

Assuming you have multiple tenants managed by Capsule, for example wind and water, as cluster admin, you can to take care of scheduling backups for:

* Tenant cluster resources
* Namespaces belonging to each tenant, including their PersistentVolumeClaims (PVCs)

## Create backup of a tenant

Create a backup of the tenant `solar`. It consists in two different backups:

* backup of the tenant resource
* backup of all the resources belonging to the tenant, including the volume data

### Prepare Velero and the Tenant

The volume data is backed up with CSI snapshots and the Velero data mover (tested with Velero 1.18). `snapshotMoveData` only moves the data of a snapshot, it does not set up the storage. This requires:

* A CSI driver with snapshot support and a `VolumeSnapshotClass` labeled `velero.io/csi-volumesnapshot-class: "true"`.
* The Velero CSI feature (`--features=EnableCSI`, or `configuration.features: EnableCSI` in the Helm chart) and the Velero node agent. See the Velero documentation on [CSI snapshot data movement](https://velero.io/docs/main/csi-snapshot-data-movement/).

Add the following rule to the Tenant before you back it up, so that it is part of the Tenant backup. During a restore with the data mover, Velero first restores the data into a temporary PersistentVolume (PV) whose `claimRef` points into the `velero` namespace. The Velero server then patches the tenant PVC to set `spec.volumeName` to that PV. The PV does not carry the `capsule.clastix.io/tenant` label yet, so without the rule Capsule rejects the patch as a cross-tenant mount and the restore hangs with the `DataDownload` stuck in `InProgress`:

```text
admission webhook "pvc.validating.projectcapsule.dev" denied the request: Preventing a cross-tenant mount for PersistentVolume pvc-1b6d1f5c-...
```

Grant the Velero ServiceAccount the volume exception with a [storage rule](/docs/rules/enforcement/storage/#volumes) on the Tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  rules:
    - audience:
        - kind: ServiceAccount
          name: system:serviceaccount:velero:velero-server
      enforce:
        action: allow
        conditions:
          - name: restore-rebind
            expression: >-
              request.operation == 'UPDATE' &&
              volume != null &&
              has(volume.spec.claimRef) &&
              volume.spec.claimRef.namespace == 'velero'
        storage:
          volumes:
            - name: velero-dynamic-pv-restore
              selector: {}
```

If Velero does not run in the `velero` namespace as `velero-server`, change both the namespace and name in the audience and the namespace in the `claimRef.namespace` condition, otherwise the condition never matches the temporary PV. The condition limits the exception to Velero's temporary volumes, other Tenants' labeled PVs stay protected, see [Ownership and label protection](/docs/rules/enforcement/storage/#ownership-and-label-protection). After the PVC patch is admitted, Capsule labels the PV with the Tenant label as soon as its `claimRef` points into a Tenant namespace.

### Back up the Tenant and its namespaces

To back up the solar tenant selectively, label the tenant as:

```bash
kubectl label tenant solar capsule.clastix.io/tenant=solar
```

and create the backup of the Tenant, including the rule from above:

```yaml
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: solar-tenant
  namespace: velero
spec:
  includeClusterResources: true
  includedNamespaces:
  - '*'
  includedResources:
  - tenants.capsule.clastix.io
  labelSelector:
    matchLabels:
      capsule.clastix.io/tenant: solar
  storageLocation: default
  ttl: 720h0m0s
```

Create a backup of all the resources belonging to the solar tenant namespaces. Set `snapshotMoveData` to back up the content of the PVCs to the object storage:

```yaml
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: solar-namespaces
  namespace: velero
spec:
  includeClusterResources: false
  includedNamespaces:
  - solar-production
  - solar-development
  - solar-marketing
  snapshotMoveData: true
  storageLocation: default
  ttl: 720h0m0s
```

## Restore a tenant from the backup

To recover the tenant after a disaster, or to migrate it to another cluster, restore the Tenant first:

```yaml
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: solar-tenant
  namespace: velero
spec:
  backupName: solar-tenant
```

If the Tenant backup was taken without the [volume rule](#prepare-velero-and-the-tenant), add the rule to the restored Tenant before you restore the namespaces.

### Create the namespaces

The namespaces have to exist before the restore starts. Velero recreates a missing namespace with its labels but without the `OwnerReference` that binds it to the Tenant. Capsule denies such a namespace and the restore ends as `PartiallyFailed`:

```text
admission webhook "namespaces.validating.projectcapsule.dev" denied the request: namespace has tenant label "solar" but no Tenant ownerReference
```

Create the desired namespaces as a tenant owner. A Capsule administrator can also create the namespace instead of a tenant owner. In that case the tenant label has to be added:

```bash
kubectl create namespace solar-production
kubectl label namespace solar-production capsule.clastix.io/tenant=solar
```

For all options to add a namespace to a tenant, see [adding Namespace to a Tenant](/docs/tenants/namespaces/#adding-namespace-to-a-tenant).

Velero skips resources that already exist, and this includes the namespace itself, even with `existingResourcePolicy: update`. The labels and annotations of the original namespace, for example the ones used by Capsule rules or replication selectors, are therefore **not** restored. Add them again when you create the namespace, taken from the backup or from the source of your manifests, while keeping the Capsule tenant label:

```bash
kubectl label namespace solar-production team=blue
kubectl annotate namespace solar-production note=hello
```

### Restore the resources

Velero restores the objects into the existing namespace. Capsule recreates the objects it manages itself, for example the RoleBindings of the Tenant owners or the ConfigMaps replicated by a `TenantResource`. They are protected by Capsule's webhooks and can only be written by the Capsule controller or a Capsule administrator, so restoring them with Velero is denied and ends the restore as `PartiallyFailed`. Capsule labels every object it manages with `projectcapsule.dev/managed-by`. Skip these objects with the operator `DoesNotExist` on this label:

```yaml
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: solar-namespaces
  namespace: velero
spec:
  backupName: solar-namespaces
  labelSelector:
    matchExpressions:
      - key: projectcapsule.dev/managed-by
        operator: DoesNotExist
```

After these steps, all resources will be restored in the namespaces.
