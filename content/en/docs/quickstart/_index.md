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

<<<<<<< HEAD
### Replications

[Read More](/docs/replications/)

From a platform perspective, we may want to enforce certain objects per `Namespace` of `Tenant's`. With Replications we can enforce certain objects to be present in all `Namespaces` of a `Tenant`. See the following examples for common use cases of [replications](/docs/replications/).

#### Example: Networkpolicies

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

#### Example: LimitRanges

[LimitRanges](https://kubernetes.io/docs/concepts/policy/limit-range/) can be used to enforce resource limits and requests for containers in a namespace. The following example enforces different `LimitRanges` for different environments (dev, test, prod) within the same `Tenant`. This ensures that workloads in each environment adhere to the specified resource constraints.

[Get Here](/docs/quickstart/gtr-limitranges.yaml)

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: limitranges
spec:
  resyncPeriod: 60s
  resources:
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
              - max:
                  cpu: 0
                  memory: "0"
                min:
                  cpu: 0
                  memory: "0"
                type: Container

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

#### Showcase: Tenant Scope

[Explore](/docs/replications/global/#examples)

They key difference in the example is, that we use `scope: Tenant` instead of `scope: Namespace`. This creates Items for each `Tenant`, not for each `Namespace` of a `Tenant`. This allows us to create a single SopsProvider for the entire Tenant and distribute secrets across all namespaces of the Tenant. In this example we will showcase how to use the [Sops Operator](https://github.com/peak-scale/sops-operator) to distribute secrets across all namespaces of a tenant and for each `Tenant` we provide [`GlobalProxySettings`](/docs/proxy/proxysettings/#globalproxysettings). It also showcases more advanced templating machinsms to generate resources based on the `Tenant` metadata and status. The `GlobalTenantResource` is a powerful tool to manage resources across all namespaces of a tenant.

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-sops-providers
spec:
  resyncPeriod: 600s
  scope: Tenant
  resources:
    - generators:
        - missingKey: zero
          template: |
            ---
            apiVersion: capsule.clastix.io/v1beta1
            kind: GlobalProxySettings
            metadata:
              name: {{ $.tenant.metadata.name }}-proxy-settings
            spec:
              rules:
              - subjects:
                {{- range $.tenant.status.owners }}
                - kind: {{ .kind }}
                  name: {{ .name }}
                {{- end }}
                clusterResources:
                - apiGroups:
                  - "capsule.clastix.io"
                  resources:
                  - "globalcustomquotas"
                  operations:
                  - List
                  selector:
                    matchLabels:
                      company.com/tenant: {{ $.tenant.metadata.name }}
    - rawItems:
        - apiVersion: addons.projectcapsule.dev/v1alpha1
          kind: SopsProvider
          metadata:
            name: "{{tenant.name}}"
          spec:
            keys:
            - namespaceSelector:
                matchLabels:
                  capsule.clastix.io/tenant: "{{tenant.name}}"
            sops:
            - namespaceSelector:
                matchLabels:
                  capsule.clastix.io/tenant: "{{tenant.name}}"
```



## Tenant Owners

Each tenant comes with a delegated user or group of users acting as the tenant admin. In the Capsule jargon, this is called the [`TenantOwner`s](/docs/operating/architecture/#tenant-owners). Other users can operate inside a tenant with different levels of permissions and authorizations assigned directly by the `TenantOwner`.

Capsule does not care about the authentication strategy used in the cluster and all the Kubernetes methods of authentication are supported. The only requirement to use Capsule is to assign tenant users to the group defined by --capsule-user-group option, which defaults to `capsule.clastix.io`.

Assignment to a group depends on the authentication strategy in your cluster.

For example, if you are using capsule.clastix.io, users authenticated through a X.509 certificate must have capsule.clastix.io as Organization: `-subj "/CN=${USER}/O=capsule.clastix.io"`

Users authenticated through an OIDC token must have in their token:

```json
"users_groups": [
  "projectcapsule.dev",
  "other_group"
]
```

### Proxy Access

The [hack/create-user.sh](https://github.com/projectcapsule/capsule/blob/main/hack/create-user.sh) can help you set up a dummy kubeconfig for the alice user acting as owner of a tenant called solar.

=======
>>>>>>> 631231e38c2ac2953262334e9ee85c01b6903c05
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
