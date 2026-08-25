---
title: Going Further
weight: 2
description: >
  Optional deep-dive into Capsule rules, permissions, and resource distribution.
---

{{% alert title="Optional" color="info" %}}
This page builds on the [basic quickstart](/docs/quickstart/). It shows more of what Capsule can do once you have a working Tenant.
{{% /alert %}}

The examples below extend the `solar` Tenant from the quickstart. Apply each section on top of the existing Tenant with `kubectl apply`.

---

## Pod Security Standards

[Read More](/docs/rules/enforcement/metadata/)

Kubernetes [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) (PSS) control what security contexts are allowed in a namespace. Capsule can enforce a PSS level per environment and even **manage** a label so users cannot override it.

Add the following rules to the `solar` Tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  namespaceOptions:
    quota: 2
  forceTenantPrefix: true
  rules:
    - enforce:
        action: allow
        metadata:
          - apiGroups:
              - "v1"
            kinds:
              - "Namespace"
            labels:
              environment:
                required: true
                default: "dev"
                values:
                  - exact:
                      - dev
                      - test
                      - prod

    # dev and test: allow restricted or baseline, default to restricted
    - namespaceSelector:
        matchExpressions:
        - key: environment
          operator: NotIn
          values:
          - prod
      enforce:
        action: allow
        workloads:
          qosClasses:
            - BestEffort
            - Burstable
            - Guaranteed
        metadata:
          - apiGroups:
              - "v1"
            kinds:
              - "Namespace"
            labels:
              pod-security.kubernetes.io/enforce:
                required: true
                default: "restricted"
                values:
                  - exact:
                      - restricted
                      - baseline

    # prod: lock pod-security to restricted, users cannot change it
    - namespaceSelector:
        matchLabels:
          environment: prod
      enforce:
        action: allow
        workloads:
          qosClasses:
            - Guaranteed
        metadata:
          - apiGroups:
              - "v1"
            kinds:
              - "Namespace"
            labels:
              pod-security.kubernetes.io/enforce:
                required: true
                managed: "restricted"
```

The key difference between `values` and `managed`:

- `values` defines what a user is **allowed** to set.
- `managed` means Capsule owns the value. It is applied automatically and any attempt to change it is silently corrected by the webhook.

### See it in action

Create a production namespace and try to set a permissive PSS level:

```bash
kubectl-alice apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: solar-production
  labels:
    environment: prod
    pod-security.kubernetes.io/enforce: privileged
EOF
```

The namespace is created, but inspect it:

```bash
kubectl get namespace solar-production --show-labels
```

```
NAME               STATUS   LABELS
solar-production   Active   environment=prod   pod-security.kubernetes.io/enforce=restricted   ...
```

Capsule silently corrected `privileged` to `restricted` because the label is managed. No error, no friction - the policy is simply enforced.

Now try to change it after creation:

```bash
kubectl-alice label namespace solar-production pod-security.kubernetes.io/enforce=baseline --overwrite
```

```
Error from server (Forbidden): admission webhook "namespaces.validating.projectcapsule.dev" denied the request: metadata label "baseline" at metadata.labels["pod-security.kubernetes.io/enforce"] is not allowed by namespace rule: value did not match any allowed rule.
```

In a development namespace the user has more freedom. Create one and change the PSS to `baseline`:

```bash
kubectl-alice create namespace solar-development
kubectl-alice label namespace solar-development pod-security.kubernetes.io/enforce=baseline --overwrite
```

This succeeds because the dev rule lists both `restricted` and `baseline` as allowed values.

---

## Service Restrictions

[Read More](/docs/rules/enforcement/services/)

Prevent tenants from creating `NodePort` or `LoadBalancer` services, and optionally restrict `ExternalName` hostnames to a pattern:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  rules:
  - enforce:
      action: allow
      services:
        types:
          - ClusterIP
          - ExternalName
        externalNames:
          hostnames:
            - exp: ".*\\.solar\\.svc\\.company\\.com"
```

Any attempt to create a `NodePort` or `LoadBalancer` service is denied at admission. `ExternalName` services are allowed only if their hostname matches the pattern - in this case any subdomain of `solar.svc.company.com`.

---

## Permission Bindings

[Read More](/docs/tenants/rules/#bindings)

Automatically distribute `RoleBindings` across Tenant namespaces based on namespace metadata. This example gives an `operators` group `edit` access in dev and test namespaces, and only `view` access in production:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  rules:
    - namespaceSelector:
        matchExpressions:
        - key: environment
          operator: NotIn
          values:
          - prod
      permissions:
        bindings:
          - clusterRoleName: 'edit'
            subjects:
              - kind: Group
<<<<<<< HEAD
<<<<<<< HEAD
                name: "tenant:{{ .tenant.metadata.name }}:operators"
=======
                name: "solar:operators"
>>>>>>> 040fb2af9f39a8b5da7f6bdd18c5e15c63687b80
=======
                name: "tenant:{{ .tenant.metadata.name }}:operators"
>>>>>>> 5298aace8a45da78c5806f42687fcf787e5cbf47

    - namespaceSelector:
        matchLabels:
          environment: prod
      permissions:
        bindings:
          - clusterRoleName: 'view'
            subjects:
              - kind: Group
                name: "solar:operators"
```

Capsule creates and maintains the `RoleBindings` automatically. When alice creates a new namespace with `environment=dev`, the `edit` binding is added without any manual step.

---

## Resource Distribution with GlobalTenantResource

[Read More](/docs/replications/global/)

`GlobalTenantResource` lets a cluster administrator push resources into every namespace of selected Tenants automatically. A common use case is distributing `LimitRange` objects to cap resource consumption per container.

### LimitRanges

The following example enforces different `LimitRange` defaults per environment:

[Get Here](/docs/quickstart/gtr-limitranges.yaml)

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: limitranges
spec:
  resyncPeriod: 60s
  resources:
    # bronze: no defaults, containers must declare their own
    - namespaceSelector:
        matchLabels:
          environment: dev
      rawItems:
        - apiVersion: v1
          kind: LimitRange
          metadata:
            name: service-level-bronze
          spec:
            limits:
              - type: Container

    # silver: default memory limits for test
    - namespaceSelector:
        matchLabels:
          environment: test
      rawItems:
        - apiVersion: v1
          kind: LimitRange
          metadata:
            name: service-level-silver
          spec:
            limits:
              - default:
                  memory: "256Mi"
                defaultRequest:
                  cpu: 128m
                  memory: "256Mi"
                type: Container

    # gold: enforced defaults for production
    - namespaceSelector:
        matchLabels:
          environment: prod
      rawItems:
        - apiVersion: v1
          kind: LimitRange
          metadata:
            name: service-level-gold
          spec:
            limits:
              - default:
                  cpu: 128m
                  memory: "256Mi"
                defaultRequest:
                  cpu: 128m
                  memory: "256Mi"
                type: Container
```

Apply this and Capsule will immediately create the appropriate `LimitRange` in every matching namespace. New namespaces pick it up within the `resyncPeriod`. Verify:

```bash
kubectl get limitrange -n solar-production
```

```
NAME                 CREATED AT
service-level-gold   2026-07-24T10:00:00Z
```

### Networkpolicies

Distribute a [`NetworkPolicy`](https://kubernetes.io/docs/concepts/services-networking/network-policies/) to all `Namespaces` of a `Tenant` to enforce a certain network policy for all workloads within the `Tenant`/`Namespace`. The following `NetworkPolicy` is an attempt to achieve a default deny policy for all `Namespaces` of the `Tenant` but allow intra-namespace communication and allow communication between all `Namespaces` of the same `Tenant`. It also allows communication to system namespaces (eg. monitoring, ingress, etc.). [Read More](https://kubernetes.io/docs/concepts/security/multi-tenancy/#network-isolation)

[Get Here](/docs/quickstart/gtr-netpol.yaml)

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: default-networkpolicies
spec:
  resyncPeriod: 60s
  resources:
    - rawItems:
        - apiVersion: networking.k8s.io/v1
          kind: NetworkPolicy
          metadata:
            name: default-policy
          spec:
            # Apply to all pods in this namespace
            podSelector: {}
            policyTypes:
              - Ingress
              - Egress
            ingress:
              # Allow traffic from the same namespace (intra-namespace communication)
              - from:
                  - podSelector: {}

              # Allow traffic from all namespaces within the tenant
              - from:
                  - namespaceSelector:
                      matchLabels:
                        capsule.clastix.io/tenant: "{{tenant.name}}"

              # Allow ingress from other namespaces labeled (System Namespaces, eg. Monitoring, Ingress)
              - from:
                  - namespaceSelector:
                      matchLabels:
                        company.com/system: "true"

            egress:
              # Allow DNS to kube-dns service IP (might be different in your setup)
              - to:
                  - ipBlock:
                      cidr: 10.96.0.10/32
                ports:
                  - protocol: UDP
                    port: 53
                  - protocol: TCP
                    port: 53

              # Allow traffic to all namespaces within the tenant
              - to:
                  - namespaceSelector:
                      matchLabels:
                        capsule.clastix.io/tenant: "{{tenant.name}}"
```

---

## Quota Management

Capsule also provides two dedicated quota mechanisms worth knowing about:

- **Resource Pools** - a cluster-scoped pool of resources (CPU, memory, storage) that selected namespaces can draw from via `ResourcePoolClaim` objects. Useful when you want a shared budget across multiple tenants or namespaces, with claims that stack automatically. See [Resource Pools](/docs/resource-management/resourcepools/).
- **Custom Quotas** - a flexible quota system that sits between classic `ResourceQuota` and Resource Pools, allowing fine-grained per-tenant quota management with custom rules on all types of resources. See [Custom Quotas](/docs/resource-management/customquotas/).

Both are managed by cluster administrators and are independent of the Tenant rules shown on this page.

### Full Tenant

Here we have two `Tenants` with different rules and permissions. The `solar` tenant is a production tenant with multiple application stages with strict rules and permissions, while the `lunar` tenant is a development tenant with more relaxed rules and permissions.

[Get Here](/docs/quickstart/full-tenant.yaml)

```yaml
# solar.yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  permissions:
    matchOwners:
    - matchLabels:
        team: platform
  owners:
  - name: alice
    kind: User
  - name: bob
    kind: User
  namespaceOptions:
    quota: 2
  forceTenantPrefix: true
  resourceQuotas:
    scope: Tenant
    items:
    - hard:
        limits.cpu: "8"
        limits.memory: 16Gi
        requests.cpu: "8"
        requests.memory: 16Gi
  rules:
    - audience:
        - kind: Custom
          name: "CapsuleUser"
      enforce:
        action: deny
        metadata:
          - apiGroups:
              - "v1"
            kinds:
              - "Namespace"
            labels:
              "openshift.io/.*":
                required: false
                values:
                  - exp: ".*"
    - enforce:
        action: allow
        metadata:
          - apiGroups:
              - "v1"
            kinds:
              - "Namespace"
            labels:
              environment:
                required: true
                default: "dev"
                values:
                  - exact:
                      - dev
                      - test
                      - prod
        services:
          types:
            - ClusterIP
            - ExternalName
          externalNames:
            hostnames:
              - exp: ".*\\.{{ .tenant.metadata.name }}\\.svc\\.company\\.com"
    - namespaceSelector:
        matchExpressions:
        - key: environment
          operator: NotIn
          values:
          - prod
      permissions:
        bindings:
          - clusterRoleName: 'edit'
            subjects:
              - kind: Group
                name: tenant:{{ .tenant.metadata.name }}:operators
      enforce:
        action: allow
        workloads:
          qosClasses:
            - Guaranteed
            - BestEffort
        metadata:
          - apiGroups:
              - "v1"
            kinds:
              - "Namespace"
            labels:
              pod-security.kubernetes.io/enforce:
                required: true
                default: "restricted"
                values:
                  - exact:
                      - restricted
                      - baseline
    - namespaceSelector:
        matchLabels:
          environment: prod
      permissions:
        bindings:
          - clusterRoleName: 'view'
            subjects:
              - kind: Group
                name: tenant:{{ .tenant.metadata.name }}:operators
      enforce:
        action: allow
        workloads:
          qosClasses:
            - Guaranteed
        metadata:
          - apiGroups:
              - "v1"
            kinds:
              - "Namespace"
            labels:
              pod-security.kubernetes.io/enforce:
                required: true
                managed: "restricted"
```

Once applied we can verify the `Tenant` with the following command:

```bash
kubectl get tnt solar

NAME    STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR   READY   STATUS       AGE
solar   Active   2                 0                                 True    reconciled   35s
```

---

## Next Steps

| Topic | Link |
|---|---|
| Installation guide | [Installation](/docs/operating/setup/installation/) |
| Rules | [Rules](/docs/rules/) |
| Tenant resource replication | [TenantResources](/docs/replications/tenant/) |
| Cross-tenant replication | [GlobalTenantResources](/docs/replications/global/) |
| Resource Pools | [Resource Pools](/docs/resource-management/resourcepools/) |
| Custom Quotas | [Custom Quotas](/docs/resource-management/customquotas/) |
| Capsule Proxy | [Capsule Proxy](/docs/proxy/) |
| Day-2 Operations | [Day-2 Operations](/docs/operating/operations/) |
