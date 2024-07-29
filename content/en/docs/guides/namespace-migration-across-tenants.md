---
title: Namespace Migration Across Tenants
weight: 2
description: "A Step-by-Step Guide to Namespace Migration"
---
Capsule relays on two components to associate given namespace with tenant.
- Namespace's OwnerReference.name pointing to the Tenant defintion
- Namespace's OwnerReference.uid pointing to the Tenant defintion

If a cluster administrator changes the Namespace by matching the other Tenant with the proper UID and name, the Namespace can be easily transferred.

```bash
kubectl get tenants
```
```
NAME    STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR   AGE
solar   Active                     1                                 46s
wind    Active                     1                                 39s
```
Get tenant's metadata.uid.
```bash
kubectl get tnt wind -o jsonpath='{.metadata.uid}'
```
```
0df8e9ee-5f6f-40a4-897d-b80d349ca36f%
```
While altering ownerReferences name is sufficient on its own, it's highly recommended to edit the UID to match the output of the previous commands.
```bash
kubectl edit ns ns-foo 
```
If everything is set correctly, the namespace will be correctly recognized as part of the new tenant.
```bash
kubectl get tenants
```
```
NAME    STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR   AGE
solar   Active                     0                                 2m22s
wind    Active                     2                                 2m15s
```

