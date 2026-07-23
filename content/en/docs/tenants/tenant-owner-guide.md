---
title: Tenant Owner Guide
weight: 1
description: >
  You have been given a Tenant. Here is what you can do with it.
---

This guide is for **Tenant Owners**: users who have been assigned ownership of a Capsule Tenant and are responsible for managing namespaces and team access within it. You do not need cluster-admin rights. Everything here is done with your own kubeconfig.

If you have not set up your kubeconfig yet, ask your cluster administrator or follow the [Proxy Access section of the Quickstart](/docs/quickstart/#proxy-access).

## See your Tenant

Start by confirming which Tenant you own:

```bash
kubectl get tnt
```

Example output:

```
NAME    STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR   READY   STATUS       AGE
solar   Active   5                 2                                 True    reconciled   3d
```

The `NAMESPACE QUOTA` column shows the maximum number of namespaces you are allowed to create. `NAMESPACE COUNT` shows how many you have used.

To see the full detail of your Tenant, including its owners, active rules, and resource quotas:

```bash
kubectl get tenant solar -o yaml
```

To see who the current owners are:

```bash
kubectl get tenant solar -o jsonpath='{.status.owners}' | jq
```

## Create namespaces

As a Tenant Owner, you can create namespaces inside your Tenant without needing cluster-admin rights:

```bash
kubectl create namespace solar-development
```

### Prefix enforcement

If your cluster administrator has enabled `forceTenantPrefix`, all namespaces must start with your Tenant name. Attempting to create `development` directly will be rejected:

```
Error from server (Forbidden): admission webhook "namespaces.mutating.projectcapsule.dev" denied the request: The Namespace name must start with 'solar-' when ForceTenantPrefix is enabled in the Tenant.
```

Use `solar-development` instead.

If you belong to multiple Tenants, Capsule cannot infer which one to use from the namespace name alone. Prefix the namespace explicitly with the correct Tenant name. See [Multiple Tenants](/docs/tenants/namespaces/#multiple-tenants) for details.

### Required labels

Your cluster administrator may require certain labels to be present when you create a namespace. If a label is missing or has a disallowed value, the webhook returns an error that states exactly which label is expected and what values are permitted:

```
Error from server (Forbidden): admission webhook "namespaces.validating.projectcapsule.dev" denied the request: metadata label "environment" is required
```

Some labels may be automatically defaulted or managed (controlled entirely by Capsule). Those cannot be changed. Others can be set to any of the listed allowed values.

### Track your namespaces

View all namespaces belonging to your Tenant and their status:

```bash
kubectl get tnt solar -o jsonpath='{.status.namespaces}'
```

## Understand your constraints

Before deploying workloads, check what limits and rules apply.

### Resource quotas

Each namespace may have a `ResourceQuota` that limits CPU, memory, and other resources. Check what quota is in place and how much has been used:

```bash
kubectl get resourcequota -A
```

Example output:

```
NAMESPACE           NAME              REQUEST                                                LIMIT
solar-development   capsule-solar-0   requests.cpu: 0/7900m, requests.memory: 0/16Gi        limits.cpu: 0/7900m, limits.memory: 0/16Gi
solar-production    capsule-solar-0   requests.cpu: 100m/8, requests.memory: 128Mi/16Gi     limits.cpu: 100m/8, limits.memory: 128Mi/16Gi
```

The quota is shared across all your namespaces. Resources consumed in one namespace reduce what is available in the others.

### Workload restrictions

Your cluster administrator may have restricted which types of workloads can run in your namespaces. Common examples:

- **QoS class**: production namespaces may require `Guaranteed` pods (explicit CPU and memory requests/limits). Development namespaces may allow `BestEffort`.
- **Pod Security Standards**: namespaces may enforce a PSS level (`restricted`, `baseline`, or `privileged`) that controls what security contexts are allowed.

Check the labels on your namespace to understand what is enforced:

```bash
kubectl get namespace solar-production --show-labels
```

Look for `pod-security.kubernetes.io/enforce`.

### Allowed services

Service type restrictions may apply. For example, only `ClusterIP` and `ExternalName` may be allowed, with `ExternalName` hostnames restricted to a specific pattern. Attempting to create a `NodePort` or `LoadBalancer` service in such a Tenant will be denied by the webhook.

## Grant team members access

You can grant access to your namespaces by creating `RoleBindings`. Capsule does not prevent you from doing standard Kubernetes RBAC within your own namespaces.

To give a developer `view` access to a specific namespace:

```bash
kubectl create rolebinding developer-view \
  --clusterrole=view \
  --user=joe \
  -n solar-development
```

To give a group `edit` access:

```bash
kubectl create rolebinding ops-edit \
  --clusterrole=edit \
  --group=solar:operators \
  -n solar-development
```

Your cluster administrator may also configure automatic RoleBinding distribution across all your namespaces via [Permission Rules](/docs/rules/permissions/). These are defined in the Tenant spec and applied to every namespace you create.

## Distribute resources across namespaces

Use `TenantResource` to automatically replicate a Kubernetes resource into all namespaces of your Tenant. This is useful for Secrets, ConfigMaps, or any resource that should be present everywhere.

You need RBAC permission to create `TenantResource` objects. Ask your cluster administrator to apply the [prerequisite ClusterRole](/docs/replications/tenant/#prerequisites) if it is not already in place.

Example: distribute an image pull Secret to every namespace:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: registry-credentials
  namespace: solar-system
spec:
  resyncPeriod: 60s
  resources:
    - rawItems:
        - apiVersion: v1
          kind: Secret
          metadata:
            name: registry-credentials
          type: kubernetes.io/dockerconfigjson
          data:
            .dockerconfigjson: <base64-encoded-credentials>
```

See [TenantResources](/docs/replications/tenant/) for full documentation.

## The Proxy and kubectl

When using the [Capsule Proxy](/docs/proxy/), your `kubectl` commands are filtered to show only resources that belong to your Tenant.

```bash
# Lists only namespaces you own, not all namespaces in the cluster
kubectl get namespaces -A

# Lists events across all your namespaces
kubectl get events -A
```

Without the Proxy, `kubectl get namespaces -A` returns `Forbidden`. If you are hitting this, confirm with your cluster administrator that the Proxy is installed and that your kubeconfig points to the Proxy endpoint:

```bash
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
```

## View events and troubleshoot rejections

Capsule emits events when it blocks or modifies a request. These are visible in the `default` namespace:

```bash
kubectl get events -A
```

Example events:

```
NAMESPACE   LAST SEEN   TYPE      REASON              OBJECT                       MESSAGE
default     2m          Warning   ForbiddenMetadata   namespace/solar-development  metadata label "privileged" at metadata.labels["pod-security.kubernetes.io/enforce"] is not allowed
default     5m          Normal    TenantAssigned      namespace/solar-production   namespace has been assigned to the desired tenant solar
default     10m         Warning   Overprovisioned     namespace/solar-test         namespace cannot be attached, quota exceeded for the elected tenant
```

Each admission webhook error message names the exact label, value, or rule that caused the rejection. If the error message references a `managed` label or a rule you cannot change, contact your cluster administrator to adjust the Tenant configuration.

For more common issues and their solutions, see the [Troubleshooting guide](/docs/operating/operations/troubleshoting/).
