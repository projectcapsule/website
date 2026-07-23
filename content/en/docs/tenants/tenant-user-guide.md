---
title: Tenant User Guide
weight: 2
description: >
  You have been given access to a namespace inside a Tenant. Here is what you need to know.
---

This guide is for **Tenant Users**: developers and other team members who have been granted access to one or more namespaces inside a Capsule Tenant. You do not own the Tenant itself. Your Tenant Owner manages the namespace and its constraints. Your job is to deploy and operate workloads within those constraints.

## Verify your access

Check which namespaces you can work in:

```bash
kubectl get namespaces
```

If this returns nothing or `Forbidden`, your cluster may be using the [Capsule Proxy](/docs/proxy/). Ask your cluster administrator or Tenant Owner for the correct server URL to use in your kubeconfig.

Check what you are allowed to do in a specific namespace:

```bash
kubectl auth can-i --list -n solar-development
```

## Understand your resource limits

Your namespace has a `ResourceQuota` that caps CPU, memory, and other resources. Check what is available:

```bash
kubectl get resourcequota -n solar-development
```

Example output:

```
NAME              AGE   REQUEST                                                       LIMIT
capsule-solar-0   2d    requests.cpu: 250m/7900m, requests.memory: 512Mi/16Gi        limits.cpu: 250m/7900m, limits.memory: 512Mi/16Gi
```

This quota is shared across all namespaces in the Tenant. If workloads in other namespaces consume resources, less is available here.

There may also be a `LimitRange` that sets default and maximum values for individual containers:

```bash
kubectl get limitrange -n solar-development
```

If a `LimitRange` is present, containers that do not specify `resources` will have defaults applied automatically.

## Understand pod restrictions

Depending on the namespace, different security restrictions may be in place.

### Pod Security Standards

Check the pod security level enforced in your namespace:

```bash
kubectl get namespace solar-development --show-labels | grep pod-security
```

The `pod-security.kubernetes.io/enforce` label tells you the active level:

| Level | What it means for your workloads |
|---|---|
| `privileged` | No restrictions. |
| `baseline` | No privileged containers, no host networking/PID/IPC, limited volume types. |
| `restricted` | Everything in baseline, plus: must run as non-root, must drop all capabilities, must use `seccompProfile`. |

If your pod is rejected at admission, the error message names exactly which field violated the policy.

### QoS class requirements

Your cluster administrator may have configured a rule that only allows pods with a specific QoS class:

- **Guaranteed**: pods must set equal `requests` and `limits` for every resource. This is the typical requirement in production namespaces.
- **Burstable**: pods set at least one request or limit but not equal values.
- **BestEffort**: pods set no requests or limits at all.

If `Guaranteed` is required and you deploy a pod without resource declarations, it will be denied.

## Deploy a compliant workload

This example satisfies common `restricted` PSS + `Guaranteed` QoS requirements:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  namespace: solar-production
spec:
  restartPolicy: Always
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: my-app
      image: my-registry/my-app:1.0.0
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "100m"
          memory: "128Mi"
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
```

Key points:
- `runAsNonRoot: true` and a non-zero `runAsUser` satisfy the non-root requirement.
- `seccompProfile.type: RuntimeDefault` is required by `restricted` PSS.
- Equal `requests` and `limits` produce a `Guaranteed` QoS class.
- `capabilities.drop: [ALL]` and `allowPrivilegeEscalation: false` are required by `restricted` PSS.

## Interpret a rejection message

When the admission webhook denies a request, the error message tells you exactly what went wrong. Examples:

**Missing required label on namespace creation:**
```
Error from server (Forbidden): admission webhook "namespaces.validating.projectcapsule.dev" denied the request: metadata label "environment" is required
```
- Ask your Tenant Owner: the namespace needs a specific label at creation time.

**Label value not in the allowed list:**
```
Error from server (Forbidden): admission webhook "namespaces.validating.projectcapsule.dev" denied the request: metadata label "privileged" at metadata.labels["pod-security.kubernetes.io/enforce"] is not allowed by namespace rule: value did not match any allowed rule. Allowed metadata values: exact: restricted, baseline
```
- Use one of the listed allowed values.

**Quota exceeded:**
```
Error from server (Forbidden): admission webhook "namespaces.validating.projectcapsule.dev" denied the request: Cannot exceed Namespace quota: please, reach out to the system administrators
```
- Contact your Tenant Owner or cluster administrator to increase the quota or free up resources.

**Pod security violation:**
```
Error from server (Forbidden): pods "my-app" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "my-app" must set securityContext.allowPrivilegeEscalation=false)
```
- Adjust your pod spec to satisfy the named requirement. The error message names the exact field and container.

**Workload QoS class not allowed:**
```
Error from server (Forbidden): admission webhook "pods.validating.projectcapsule.dev" denied the request: workload QoS class BestEffort is not allowed by the tenant rules
```
- Add `resources.requests` and `resources.limits` to your container spec.

## Who to contact

| Problem | Contact |
|---|---|
| Cannot access your namespace at all | Cluster administrator |
| Namespace quota is too low | Tenant Owner or cluster administrator |
| A rule is too strict for your use case | Tenant Owner (they can adjust Tenant rules or request a change from the cluster admin) |
| Unexpected webhook denial you cannot explain | Tenant Owner, or check [Troubleshooting](/docs/operating/operations/troubleshoting/) |
