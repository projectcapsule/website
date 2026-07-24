---
title: Troubleshooting
weight: 15
description: "Different topics when you encounter problems with Capsule"
---

This page covers the most common issues encountered when running Capsule. Each section describes the symptom, the likely cause, and how to resolve it.

## User cannot create namespaces or interact with tenants

**Symptom**: A user runs `kubectl create namespace my-ns` and gets a generic `Forbidden` error, or Capsule completely ignores the request and does not assign the namespace to any tenant.

**Cause**: The user is not recognized as a Capsule User. Capsule only acts on namespace creation requests from subjects that are configured as Capsule Users in the `CapsuleConfiguration`.

**Resolution**: Check which subjects are currently recognized:

```bash
kubectl get capsuleconfiguration default -o jsonpath='{.status.users}' | jq
```

If the user (or any of their groups) is not listed, add them. The recommended approach is to create a `TenantOwner` resource for the user:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: TenantOwner
metadata:
  name: alice
  labels:
    projectcapsule.dev/tenant: "solar"
spec:
  kind: User
  name: "alice"
```

Alternatively, configure a group in the `CapsuleConfiguration`:

```yaml
manager:
  options:
    users:
      - kind: Group
        name: projectcapsule.dev
```

## Namespace creation is rejected by the admission webhook

**Symptom**: `Error from server (Forbidden): admission webhook "namespaces.mutating.projectcapsule.dev" denied the request`.

Two common reasons:

### Namespace quota exceeded

The tenant has reached its namespace quota. The error message will include `Cannot exceed Namespace quota`.

```bash
# Check the current namespace count vs quota
kubectl get tenant solar -o jsonpath='{.status.namespaceCount} / {.spec.namespaceOptions.quota}'
```

Contact your cluster administrator to increase the quota, or delete unused namespaces.

### Force tenant prefix not respected

The tenant has `forceTenantPrefix: true` and the namespace name does not start with the tenant name.

```bash
# Wrong
kubectl create namespace my-app

# Correct
kubectl create namespace solar-my-app
```

If you belong to multiple tenants, Capsule cannot infer which one to use. Prefix the namespace name with the tenant you intend to use.

## Admission webhook denied a label or annotation change

**Symptom**: `Error from server (Forbidden): admission webhook "namespaces.validating.projectcapsule.dev" denied the request: metadata label "..." is not allowed`.

**Cause**: A rule on the tenant restricts which values are allowed for that label. The error message contains the exact label key and the list of allowed values.

**Resolution**:

1. Read the error message carefully. It states the allowed values.
2. Use one of the permitted values:

```bash
# Example: allowed values are restricted and baseline
kubectl label namespace solar-development pod-security.kubernetes.io/enforce=baseline --overwrite
```

3. If the label is marked as `managed`, it is controlled entirely by Capsule and cannot be changed by tenant users. Contact your cluster administrator.

## Cannot list namespaces or cluster-scoped resources

**Symptom**: `kubectl get namespaces` returns an error such as `Error from server (Forbidden): namespaces is forbidden: User "alice" cannot list resource "namespaces" in API group "" at the cluster scope`.

**Cause**: The Capsule Proxy is not in use. Without the proxy, Kubernetes RBAC prevents non-admin users from listing cluster-scoped resources. The proxy intercepts those requests and filters results to show only resources belonging to the user's tenants.

**Resolution**: Verify that the Capsule Proxy is installed and that your kubeconfig points to the proxy endpoint rather than the Kubernetes API server directly. See the [Proxy documentation](/docs/proxy/) for setup instructions.

```bash
# Confirm which server your kubeconfig is pointing to
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
```

## TenantOwner resource is not granting access

**Symptom**: A `TenantOwner` resource was created but the user still cannot interact with the tenant.

**Cause**: The `TenantOwner` CRD uses [aggregation](/docs/tenants/permissions/#aggregation) to bind owners to tenants. The resource must carry the correct label for implicit assignment, and the tenant must reference it via `matchOwners` or the owner must be listed directly.

**Checklist**:

1. Confirm the `TenantOwner` has the correct tenant label:

```bash
kubectl get tenantowner alice -o jsonpath='{.metadata.labels}'
# Expected: {"projectcapsule.dev/tenant":"solar"}
```

2. Confirm the tenant lists the owner in its status:

```bash
kubectl get tenant solar -o jsonpath='{.status.owners}' | jq
```

3. Confirm the user is recognized as a Capsule User (see the first section above).

4. If using `matchOwners` with label selectors, verify the `TenantOwner` carries the matching labels:

```bash
kubectl get tenantowner platform-team --show-labels
```

## Capsule Proxy is being throttled by the API server

**Symptom**: Clients talking through the Capsule Proxy receive connection errors such as:

```
net/http: abort Handler
```

or requests hang and are dropped without a response.

**Cause**: The Capsule Proxy is sending more requests to the Kubernetes API server than its configured QPS and burst limits allow. Because the proxy sits between clients and the API server, the client is the first to see the resulting aborted connections.

**Resolution**: Increase the `clientConnectionQPS` and `clientConnectionBurst` values for the Capsule Proxy. See the [Proxy production installation guide](/docs/proxy/setup/installation/#qpsburst) for the recommended Helm values:

```yaml
options:
  clientConnectionQPS: 200
  clientConnectionBurst: 400
```

## Capsule controller fails to start due to timeouts

**Symptom**: The Capsule controller pod restarts repeatedly or never reaches `Running`. Logs contain errors such as:

```
E0707 08:38:18.319041  1 leaderelection.go:452] "Error retrieving lease lock"
  err="...net/http: request canceled (Client.Timeout exceeded while awaiting headers)"
```

or the controller stalls silently during startup on clusters with many resources.

**Cause**: Two common sources of startup timeouts:

- **Cache sync timeout** — On large clusters the controller's informer cache takes longer to populate than the default timeout allows, causing the controller to give up before it is ready to serve.
- **Leader election timeout** — In high-pressure environments the controller cannot renew its leader lease within the default deadline, triggering repeated leader-election failures.

**Resolution**: Adjust the `cacheSyncTimeout` and `leaderElection` values for the Capsule controller. See the [Production installation guide](/docs/operating/setup/installation/#cache-synchronisation) for the recommended Helm values.
