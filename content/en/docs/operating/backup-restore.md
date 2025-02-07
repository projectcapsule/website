---
title: Backup & Restore
description: Run Backups and Restores of Tenants
weight: 6
---

[Velero](https://velero.io/) is a backup and restore solution that performs data protection, disaster recovery and migrates Kubernetes cluster from on-premises to the Cloud or between different Clouds.

When coming to backup and restore in Kubernetes, we have two main requirements:

* Configurations backup
* Data backup
  
The first requirement aims to backup all the resources stored into etcd database, for example: namespaces, pods, services, deployments, etc. The second is about how to backup stateful application data as volumes.

The main limitation of Velero is the multi tenancy. Currently, Velero does not support multi tenancy meaning it can be only used from admin users and so it cannot provided "as a service" to the users. This means that the cluster admin needs to take care of users' backup.

Assuming you have multiple tenants managed by Capsule, for example oil and gas, as cluster admin, you can to take care of scheduling backups for:

* Tenant cluster resources
* Namespaces belonging to each tenant

## Create backup of a tenant

Create a backup of the tenant `solar`. It consists in two different backups:

* backup of the tenant resource
* backup of all the resources belonging to the tenant

To backup the oil tenant selectively, label the tenant as:

```bash
kubectl label tenant oil capsule.clastix.io/tenant=solar
```

and create the backup

```bash
velero create backup solar-tenant \
    --include-cluster-resources=true \
    --include-resources=tenants.capsule.clastix.io \
    --selector capsule.clastix.io/tenant=solar
```

resulting in the following Velero object:

```yaml
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: solar-tenant
spec:
  defaultVolumesToRestic: false
  hooks: {}
  includeClusterResources: true
  includedNamespaces:
  - '*'
  includedResources:
  - tenants.capsule.clastix.io
  labelSelector:
    matchLabels:
      capsule.clastix.io/tenant: solar
  metadata: {}
  storageLocation: default
  ttl: 720h0m0s
```

Create a backup of all the resources belonging to the oil tenant namespaces:

```bash
velero create backup solar-namespaces \
    --include-cluster-resources=false \
    --include-namespaces solar-production,solar-development,solar-marketing
```

resulting to the following Velero object:

```yaml
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: solar-namespaces
spec:
  defaultVolumesToRestic: false
  hooks: {}
  includeClusterResources: false
  includedNamespaces:
  - solar-production
  - solar-development
  - solar-marketing
  metadata: {}
  storageLocation: default
  ttl: 720h0m0s
```

> Velero requires an Object Storage backend where to store backups, you should take care of this requirement before to use Velero.

## Restore a tenant from the backup

To recover the tenant after a disaster, or to migrate it to another cluster, create a restore from the previous backups:

```bash
velero create restore --from-backup solar-tenant
velero create restore --from-backup solar-namespaces
```

Using Velero to restore a Capsule tenant can lead to an incomplete recovery of tenant because the namespaces restored with Velero do not have the `OwnerReference` field used to bind the namespaces to the tenant. For this reason, all restored namespaces are not bound to the tenant:

```bash
kubectl get tnt
NAME   STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR     AGE
gas    active   9                 5                 {"pool":"gas"}    34m
oil  active   9                 8                 {"pool":"oil"}  33m
solar    active   9                 0 # <<<           {"pool":"solar"}    54m
```

To avoid this problem you can use the script [velero-restore.sh](https://github.com/projectcapsule/capsule/blob/main/hack/velero-restore.sh) located under the hack/ folder:

```bash
./velero-restore.sh --kubeconfing /path/to/your/kubeconfig --tenant "oil" restore
```

Running this command, we are going to patch the tenant's namespaces manifests that are actually ownerReferences-less. Once the command has finished its run, you got the tenant back.

```bash
kubectl get tnt
NAME   STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR     AGE
gas    active   9                 5                 {"pool":"gas"}    44m
solar  active   9                 8                 {"pool":"oil"}  43m
oil    active   9                 3 # <<<           {"pool":"solar"}    12s
```