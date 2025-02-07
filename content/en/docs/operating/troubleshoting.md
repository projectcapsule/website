---
title: Troubleshooting
weight: 15
description: "Different topics when you encounter problems with Capsule"
---




List of Tenant API changes:

* Capsule v0.1.0 bump to v1beta1 from v1alpha1.
* Capsule v0.2.0 bump to v1beta2 from v1beta1, deprecating v1alpha1.
* Capsule v0.3.0 missing enums required by Capsule Proxy.

This document aims to provide support and a guide on how to perform a clean upgrade to the latest API version in order to avoid service disruption and data loss.

As an installation method, Helm is given for granted. If you are not using Helm, you might experience problems during the upgrade process.

**Considerations**

We strongly suggest performing a full backup of your Kubernetes cluster, such as storage and etcd. Use your favorite tool according to your needs.

## Upgrading from v0.2.x to v0.3.x

A minor bump has been requested due to some missing enums in the Tenant resource.

### Scale down the Capsule controller

Using the kubectl or Helm, scale down the Capsule controller manager: this is required to avoid the old Capsule version from processing objects that aren't yet installed as a CRD.

```bash
helm upgrade -n capsule-system capsule --set "replicaCount=0" 
```

or 

```bash
kubectl scale deploy capsule-controller-manager --replicas=0 -n capsule-system 
```

