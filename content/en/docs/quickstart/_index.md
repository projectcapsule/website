---
title: Quickstart 🚀
type: docs
weight: 2
description: "Create your first Capsule Tenant and start using it"
---

This guide gets you from zero to a working multi-tenant cluster in minutes. You will install Capsule, create a Tenant as a cluster administrator, and then immediately switch to the tenant owner's perspective to see what Capsule actually does.

## Installation

Start a local Kubernetes cluster with [KinD](https://kind.sigs.k8s.io/):

[Get Here](/docs/quickstart/kind.yaml)
```yaml
# kind.yaml
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
nodes:
  - role: control-plane
  - role: worker
    extraPortMappings:
      - hostPort: 9001
        containerPort: 9001
```

```bash
kind create cluster --name capsule --config kind.yaml --wait=120s
```

The extra port mapping is for the [Capsule Proxy](/docs/proxy/), which lets tenant users issue `kubectl get namespaces` and see only their own. Install Capsule with the Proxy included:

```bash
helm upgrade --install capsule oci://ghcr.io/projectcapsule/charts/capsule --debug --create-namespace -n capsule-system --version {{< capsule_chart_version >}} \
		--set 'proxy.enabled=true' \
		--set 'proxy.certManager.generateCertificates=false' \
		--set 'proxy.options.additionalSANs={localhost}' \
		--set 'proxy.options.generateCertificates=true' \
		--set "proxy.options.leaderElection=true" \
		--set "proxy.options.roleBindingReflector=true" \
		--set "proxy.service.type=NodePort" \
		--set "proxy.kind=DaemonSet" \
		--set "proxy.daemonset.hostNetwork=true" \
		--set "proxy.serviceMonitor.enabled=false" \
		--set "proxy.options.extraArgs={--feature-gates=ProxyClusterScoped=true}"  \
		--set 'crds.install=true' \
		--set 'certManager.generateCertificates=false' \
		--set 'tls.enableController=true' \
		--set 'tls.create=true'
```

Verify everything is running:

```bash
kubectl get pods -n capsule-system

NAME                                          READY   STATUS      RESTARTS      AGE
capsule-controller-manager-7584dc9546-l6tgl   1/1     Running     1 (21s ago)   29s
capsule-crds-vfq9k                            0/1     Completed   0             41s
capsule-post-install-2lm99                    0/1     Completed   0             28s
capsule-proxy-fjl5s                           0/1     Running     0             29s
capsule-proxy-certgen-5x7d6                   0/1     Completed   0             29s
```

For more installation options see the [installation guide](/docs/operating/setup/installation/).

## Create Your First Tenant

A **Tenant** groups one or more namespaces under a shared set of policies and limits. The cluster administrator creates and owns tenants. Users assigned as `TenantOwner` manage namespaces within them, without needing cluster-admin rights.

Apply the following Tenant as cluster admin:

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
    - namespaceSelector:
        matchLabels:
          environment: prod
      enforce:
        action: allow
        workloads:
          qosClasses:
            - Guaranteed
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
```

What this configures:

- **`owners`**: `alice` is the Tenant Owner and can create namespaces inside this tenant.
- **`namespaceOptions.quota: 2`**: alice can create at most 2 namespaces. [Read more](/docs/tenants/namespaces/#namespace-quota)
- **`forceTenantPrefix: true`**: every namespace must start with `solar-`. [Read more](/docs/tenants/administration/#force-tenant-prefix)
- **`rules`**: the `environment` label is required on every namespace, with `dev` as the default. Capsule enforces this at admission time. [Read more](/docs/rules/enforcement/metadata/)
- **`QoS rules`**: production namespaces (labeled `environment=prod`) only accept `Guaranteed` pods. Development and test namespaces accept any QoS class. [Read more](/docs/rules/enforcement/workloads/)

### Tenant Owners

Capsule only acts on requests from subjects it recognises as **Capsule Users**. The recommended way to register a user is to create a `TenantOwner` resource. The label `projectcapsule.dev/tenant: "solar"` binds it to the tenant automatically via [aggregation](/docs/tenants/permissions/#aggregation):

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

Capsule matches users by the groups they carry on every request. Creating a `TenantOwner` registers the subject automatically - no manual configuration needed. You can verify who is recognised at any time:

```bash
kubectl get capsuleconfiguration default -o jsonpath='{.status.users}' | jq
```

For the quickstart we use impersonation (`--as-group projectcapsule.dev`) which bypasses the need for a real certificate or token. In production, authentication depends on your cluster setup (X.509 certificates, OIDC tokens, etc.), use the [Gangplank](/docs/proxy/gangplank/) workflow to issue real kubeconfigs.

Verify the Tenant is active and alice is listed as an owner:

```bash
kubectl get tnt solar

NAME    STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR   READY   STATUS       AGE
solar   Active   2                 0                                 True    reconciled   10s
```

```bash
kubectl get tenant solar -o jsonpath='{.status.owners}' | jq
```

## As a Tenant Owner

Now switch to alice's perspective. Use [impersonation](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#user-impersonation) to simulate her identity:

```bash
# All following commands run as alice
alias kubectl-alice='kubectl --as alice --as-group projectcapsule.dev'
```

### Create a namespace

Try creating a namespace without the required prefix:

```bash
kubectl-alice create namespace development
```

```
Error from server (Forbidden): admission webhook "namespaces.mutating.projectcapsule.dev" denied the request: The Namespace name must start with 'solar-' when ForceTenantPrefix is enabled in the Tenant.
```

Capsule immediately enforces the naming rule. Try with the correct prefix:

```bash
kubectl-alice create namespace solar-development -o yaml
```

The namespace is created and Capsule automatically applies the default label `environment=dev`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  labels:
    capsule.clastix.io/tenant: solar
    environment: dev
    kubernetes.io/metadata.name: solar-development
  name: solar-development
```

### Enforce label constraints

The `environment` label can only be set to `dev`, `test`, or `prod`. Try to label the namespace with a value that is not allowed:

```bash
kubectl-alice label namespace solar-development environment=staging --overwrite
```

```
Error from server (Forbidden): admission webhook "namespaces.validating.projectcapsule.dev" denied the request: metadata label "staging" at metadata.labels["environment"] is not allowed by namespace rule: value did not match any allowed rule. Allowed metadata values: exact: dev, test, prod
```

Allowed values work fine:

```bash
kubectl-alice label namespace solar-development environment=test --overwrite
```

### Namespace quota

Create a second namespace, this time explicitly as production:

```bash
kubectl-alice apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: solar-production
  labels:
    environment: prod
EOF
```

Attempting a third is denied:

```bash
kubectl-alice create namespace solar-staging

Error from server (Forbidden): admission webhook "namespaces.validating.projectcapsule.dev" denied the request: Cannot exceed Namespace quota: please, reach out to the system administrators
```

### List with the Proxy

Without the Proxy, `kubectl get namespaces -A` returns `Forbidden` for non-admin users. Point alice's kubeconfig to the Capsule Proxy to get a filtered view:

```bash
curl -s https://raw.githubusercontent.com/projectcapsule/capsule/main/hack/create-user.sh | bash -s -- alice solar projectcapsule.dev
KUBECONFIG=alice-solar.kubeconfig kubectl config set clusters.kind-capsule.certificate-authority-data $(kubectl -n capsule-system get secret capsule-proxy -o jsonpath='{.data.ca}')
KUBECONFIG=alice-solar.kubeconfig kubectl config set clusters.kind-capsule.server https://localhost:9001
export KUBECONFIG=alice-solar.kubeconfig
```

Now list namespaces; alice sees only hers:

```bash
kubectl get ns -A

NAME                STATUS   AGE
solar-development   Active   5m
solar-production    Active   2m
```

In production, automate kubeconfig distribution with [Gangplank](/docs/proxy/gangplank/).

## Going Further

Want to see more of what Capsule can do? The [Going Further](/docs/quickstart/extended/) guide builds directly on this quickstart and covers Pod Security Standards enforcement, service type restrictions, permission bindings per environment, and automatic LimitRange distribution with `GlobalTenantResource`. None of it is required for a working setup, but it shows the full power of the platform.

## Next Steps

You have seen the core of Capsule: a cluster administrator defines constraints, and tenant owners work freely within them without cluster-admin rights.

| Topic | Link |
|---|---|
| Installation guide | [Installation](/docs/operating/setup/installation/) |
| Tenant Owner Guide | [Tenant Owner Guide](/docs/tenants/tenant-owner-guide/) |
| Rules | [Rules](/docs/rules/) |
| Tenant resource replication | [TenantResources](/docs/replications/tenant/) |
| Cross-tenant replication | [GlobalTenantResources](/docs/replications/global/) |
| Resource Pools | [Resource Pools](/docs/resource-management/resourcepools/) |
| Custom Quotas | [Custom Quotas](/docs/resource-management/customquotas/) |
| Capsule Proxy | [Capsule Proxy](/docs/proxy/) |
| Day-2 Operations | [Day-2 Operations](/docs/operating/operations/) |
