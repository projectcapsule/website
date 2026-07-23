---
title: Quickstart 🚀
type: docs
weight: 2
description: "Create your first Capsule Tenant"
---
The following quickstart guide will help you to create your first Capsule Tenant and start using it. The guide assumes that you have already installed Capsule in your cluster and that you have a working Kubernetes cluster. Also it first shows to conceptual side from the Platform (Cluster Administrator) perspective and then from the `TenantOwner` perspective.

## Installation

Start a local Kubernetes cluster with [KinD](https://kind.sigs.k8s.io/) use the following configuration:

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

Create dedicated `kind` cluster with the following command:

```bash
kind create cluster --name capsule --config kind.yaml --wait=120s 
```

We are using a custom port-mapping for the [Capsule Proxy](/docs/proxy/). After the cluster is up and running, install Capsule with the following command:

```bash
helm upgrade --install capsule oci://ghcr.io/projectcapsule/charts/capsule --debug --create-namespace -n capsule-system --version 0.13.10 \
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

For more information about the installation process, please refer to the [installation guide](/docs/operating/setup/installation/). Verify components are running with the following command:

```bash
kubectl get pods -n capsule-system

NAME                                          READY   STATUS      RESTARTS      AGE
capsule-controller-manager-7584dc9546-l6tgl   1/1     Running     1 (21s ago)   29s
capsule-crds-vfq9k                            0/1     Completed   0             41s
capsule-post-install-2lm99                    0/1     Completed   0             28s
capsule-proxy-fjl5s                           0/1     Running     0             29s
capsule-proxy-certgen-5x7d6                   0/1     Completed   0             29s
```

Great, now we are ready to create our first Capsule Tenant. The following sections will guide you through the process of creating a Tenant and configuring it.

## Platform

Perspective of the Cluster Administrator, who is responsible for creating and managing tenants in the cluster. The Cluster Administrator can create tenants and assign them to users or groups of users, who will then be able to manage their own namespaces within the tenant.

### Tenants

In Capsule, a Tenant is an abstraction to group multiple namespaces in a single entity within a set of boundaries defined by the Cluster Administrator.

#### [Ownership](/docs/tenants/permissions/#ownership)

The tenant is then assigned to a user or group of users who is called [`TenantOwner`](/docs/operating/architecture/#tenant-owners). Capsule defines a Tenant as Custom Resource with cluster scope. Create the tenant as cluster admin:

```yaml
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
```

Here we mention the user `alice`, as of now `alice` is not considered a [**Capsule User**](/docs/operating/architecture/#capsule-users) because she was not defined [**as such in the `CapsuleConfiguration`**](/docs/operating/setup/configuration/#users). We must either define her in the configuration or create a [`TenantOwner`](/docs/tenants/permissions/#tenant-owners) resource for her or any of the groups she may belong to. In this example, we will assume that every user carries the group `projectcapsule.dev` (default setting), so we don't have to configure each user manually. Therefore the configuration should look like this:

```yaml
manager:
  options:
    users:
      - kind: Group
        name: projectcapsule.dev
```

The more modern approach would be creating a dedicated [`TenantOwner`](/docs/tenants/permissions/#tenant-owners) resource for `alice`. This makes the step of adding the subject to the [`CapsuleConfiguration`](/docs/operating/setup/configuration/) obsolete, as this is done trough [**aggregation**](/docs/tenants/permissions/#aggregation). With using the label `projectcapsule.dev/tenant: "solar"` we can leverage [implicit assignment](/docs/tenants/permissions/#implicit-tenant-assignment) to the `Tenant` solar. Let's create a `TenantOwner` resource for `joe`:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: TenantOwner
metadata:
  name: joe
  labels:
    projectcapsule.dev/tenant: "solar"
spec:
  kind: User
  name: "joe"
```

We can always verify all [**Capsule User**](/docs/operating/architecture/#capsule-users) via the `status` of the used [`CapsuleConfiguration`](/docs/operating/setup/configuration/) resource:

```bash
kubectl get capsuleconfiguration capsule -o jsonpath='{.status.users}'
```

If a user or any of their groups is not listed in the `status.users` section of the `CapsuleConfiguration` resource, they will not be able to access any tenant or namespace managed by Capsule.


You can check the tenant we created previously with the following command:

```bash
$ kubectl get tnt
NAME   STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR   READY   STATUS       AGE
solar  Active                     0                                 True    reconciled   13s
```

We create dedicated `TenantOwners` who represent cluster administrators. They are matched by labels defined in the `permissions.matchOwners` section of the `Tenant` spec. In our case, any user or group with the label `team: platform` is considered a `TenantOwner` for the `solar` tenant.

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: TenantOwner
metadata:
  name: platform-team
  labels:
    team: platform
spec:
  kind: Group
  name: "oidc:kubernetes:admin"
```

We can now verify all owners of the `solar` tenant:

```bash
kubectl get tenant solar -o jsonpath='{.status.owners}'
```

The result should be similar to:

```json
[
  {
    "kind": "Group",
    "name": "oidc:kubernetes:admin",
    "clusterRoles": [
      "admin",
      "capsule-namespace-deleter"
    ]
  },
  {
    "kind": "User",
    "name": "alice",
    "clusterRoles": [
      "admin",
      "capsule-namespace-deleter"
    ]
  },
  {
    "kind": "User",
    "name": "joe",
    "clusterRoles": [
      "admin",
      "capsule-namespace-deleter"
    ]
  }
]
```

### Namespaces

From the perspective of the Cluster Administrator, we want to mainly control the format on how namespaces are created. The actual management of the namespaces is delegated to the [`TenantOwner`s](#tenant-owners). We can define a set of rules to control how namespaces are created within a `Tenant`. 

#### Size Quota

We can restrict the number of namespaces that can be created within a `Tenant` with [namespace quotas](/docs/tenants/quotas/#namespace-quotas). Let's cap this `Tenant` to a maximum of 2 namespaces:

```yaml
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
  namespaceOptions:
    quota: 2
```

#### [Prefix](/docs/tenants/administration/#force-tenant-prefix)

We are enforcing the `Namespaces` of the `Tenant` to be prefixed with the `Tenant` name. This keeps the sorting of `Namespaces` clean and directly tells us which `Tenant` a `Namespace` belongs to. This is done with the `forceTenantPrefix` option in the `Tenant` spec:

```yaml
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
  namespaceOptions:
    quota: 2
  forceTenantPrefix: true
```

### [Rules](/docs/tenants/rules/)

With [Rules](/docs/tenants/rules/) we can apply different policies within a `Tenant` based on their metadata. As previously seen they can also be used to enforce metadata for `Namespaces`. This comes in handy when we have different applications environment in the same `Tenant` and we want to apply different policies to them. For example, we can have a `Tenant` with two namespaces: `solar-production` (`environment=prod`) and `solar-development` (`environment=dev`) . We can apply different rules to each namespace based on their metadata.

#### [Metadata](/docs/rules/enforcement/metadata/)

Since the `Namespaces` are managed by the `TenantOwners`, we may want to require certain metadata to be present in the namespaces created within a `Tenant`. For this case we want to force the [`TenantOwners`](#tenant-owners) to provide the label `environment` with a value of either `prod`, `test` or `dev` when creating a namespace within the `solar` tenant. This can be done with [namespace metadata](/docs/tenants/metadata/#requiredmetadata):

```yaml
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
```

We may wan't to enforce a set of metadata to be applied to all namespaces created within a `Tenant`. This can be done with [namespace metadata](/docs/tenants/metadata/#additionalmetadatalist). This ensures these labels are always present in the namespaces created within the `Tenant` and can't be removed or modified.

```yaml
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
    - enforce:
        action: allow
        metadata:
          - apiGroups: 
              - "v1"
            kinds:
              - "Namespace"
            labels:
              pod-security.kubernetes.io/audit:
                required: true
                managed: "restricted"
              pod-security.kubernetes.io/warn:
                required: true
                managed: "baseline"
    - namespaceSelector:
        matchExpressions:
        - key: environment
          operator: NotIn
          values:
          - prod
      enforce:
        action: allow
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
      enforce:
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

We can also enforce that certain labels (also via regexp) can be enforced to only a subset of users. For example we may have labels (`"openshift.io/.*"`) which should be able to be modified by anyone else but [Capsule Users](/docs/operating/architecture/#capsule-users)

```yaml
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
  namespaceOptions:
    quota: 2
  forceTenantPrefix: true
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
    - namespaceSelector:
        matchExpressions:
        - key: environment
          operator: NotIn
          values:
          - prod
      enforce:
        action: allow
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
      enforce:
        action: allow
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

#### [Permissions](/docs/tenants/rules/permissions/)

Often you may have other users with different permissions. These are not [Tenant Owners](/docs/operating/architecture/#tenant-owners) but might be other parties that may interact with the `Tenant` and its `Namespaces`. For example, we may have a group of users that are responsible for monitoring the `Tenant` and its `Namespaces`. We can create a set of rules to allow them to view the `Tenant` and its `Namespaces` but not modify them. This can be done with [permissions rules](/docs/tenants/rules/permissions/):

```yaml
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
  namespaceOptions:
    quota: 2
  forceTenantPrefix: true
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
                name: tenant:{{ .tenant.metadata.name }}:operators
    - namespaceSelector:
        matchLabels:
          environment: prod
      permissions:
        bindings:
          - clusterRoleName: 'view'
            subjects:
              - kind: Group
                name: tenant:{{ .tenant.metadata.name }}:operators
```

#### [Workloads](/docs/rules/enforcement/workloads/)

There might also be different requirements for the priority of workloads running in different namespaces. For example, we may want to allow `BestEffort` Pods in the `solar-development` namespace but not in the `solar-production` namespace. This can be done with [Workload Rules](/docs/rules/enforcement/workloads/#best-effort):

```yaml
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
  namespaceOptions:
    quota: 2
  forceTenantPrefix: true
  rules:
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
    - namespaceSelector:
        matchLabels:
          environment: prod
      enforce:
        action: allow
        workloads:
          qosClasses:
            - Guaranteed
```

We can also provide a subset of PriorityClasses for the Tenant to use in their workloads. This is currently only possible for the entire Tenant but will be ported to the rules in the future. For now, we can define a set of allowed PriorityClasses for the entire Tenant:

```yaml
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
  namespaceOptions:
    quota: 2
  forceTenantPrefix: true
  rules:
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
    - namespaceSelector:
        matchLabels:
          environment: prod
      enforce:
        action: allow
        workloads:
          qosClasses:
            - Guaranteed
  priorityClasses:
    matchLabels:
      env: "production"
```

#### [Services](/docs/rules/enforcement/services/)

Often from a platform perspective, we want to control the type of services that can be created within a `Tenant`. It is possible to restrict the type of services that can be created within a `Tenant` with [Service Rules](/docs/rules/enforcement/services/#service-types). For example, we can allow only `ClusterIP` services:

```yaml
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
  namespaceOptions:
    quota: 2
  forceTenantPrefix: true
  rules:
  - enforce:
      action: allow
      services:
        types:
          - ClusterIP
```

You may also allow other `Service` types but be more strict in their configuration. For example, we can allow `ExternalName` services but only if they match a certain hostname pattern (forced to tenant subdomain):

```yaml
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
  namespaceOptions:
    quota: 2
  forceTenantPrefix: true
  rules:
  - enforce:
      action: allow
      services:
        types:
          - ClusterIP
          - ExternalName
        externalNames:
          hostnames:
            - exp: ".*\\.{{ .tenant.metadata.name }}\\.svc\\.company\\.com"
```

### [Resource Quota](/docs/tenants/quotas/)

Another improtant aspect of the `Tenant` is the ability to define a set of [`ResourceQuotas`](https://kubernetes.io/docs/concepts/policy/resource-quotas/) for the entire `Tenant`. This allows the Cluster Administrator to control the amount of resources that can be used by the `Tenant` and its namespaces. For example, we can define a resource quota for the entire `Tenant`:

```yaml
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
```

We also provide other mechanisms to control the amount of resources that can be used by the `Tenant` and its namespaces:

* [Resource Management](/docs/resource-management/)

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

### [Replications](/docs/replications/)

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

```bash
curl -s https://raw.githubusercontent.com/projectcapsule/capsule/main/hack/create-user.sh | bash -s -- alice solar projectcapsule.dev,other_group
```

Now we are also injecting the [Capsule Proxy](/docs/proxy/) as Kubernetes API Server. The Capsule Proxy is a Kubernetes API Server that acts as a reverse proxy to the Kubernetes API Server. It mainly allows to issue `LIST` and `GET` requests to Kubernetes API Server across all namespaces and tenants.

```bash
KUBECONFIG=alice-solar.kubeconfig kubectl config set clusters.kind-capsule.certificate-authority-data $(kubectl -n capsule-system get secret capsule-proxy -o jsonpath='{.data.ca}')
KUBECONFIG=alice-solar.kubeconfig kubectl config set clusters.kind-capsule.server https://localhost:9001
export KUBECONFIG=alice-solar.kubeconfig
kubectl get ns -A
```

Alice can now always `LIST` their `Tenants`:

```bash
kubectl get tnt

NAME    STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR   READY   STATUS       AGE
solar   Active   2                 0                                 True    reconciled   37m
```

In production environments this process can be automated with [Gangplank](/docs/proxy/gangplank/)

### Impersonation

You can simulate this behavior by using [impersonation](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#user-impersonation):

```bash
kubectl --as alice --as-group projectcapsule.dev ...
```

However with this you might hit certain limitations regarding `Namespaces`:

```shell
kubectl --as alice --as-group projectcapsule.dev label namespace solar-development pod-security.kubernetes.io/enforce=baseline --overwrite -o yaml

Error from server (Forbidden): namespaces "solar-development" is forbidden: User "alice" cannot get resource "namespaces" in API group "" in the namespace "solar-development"
```

### Manage Namespaces

As `TenantOwner` (`alice`), we attempt to create a namespace within the `solar` tenant. The `TenantOwner` can create namespaces within the tenant they own. Let's attempt to create a `Namespace` called `development`:

```bash
kubectl projectcapsule.dev create namespace development
```

You will be denied with the following error:

```bash
Error from server (Forbidden): admission webhook "namespaces.mutating.projectcapsule.dev" denied the request: The Namespace name must start with 'solar-' when ForceTenantPrefix is enabled in the Tenant.
```

Since we have enabled the `forceTenantPrefix` option in the `Tenant` spec, we must create namespaces with the prefix of the tenant name (`solar-`) . However capsule correctly identified that `alice` belongs to the `solar` `Tenant` and allowed the creation of the namespace with the correct prefix. This works because `alice` currently belongs to a single `Tenant`. If `alice` belonged to multiple tenants, she would have to specify the tenant name in the namespace name ([Read More](/docs/tenants/namespaces/#multiple-tenants)).

Let's try again with the name `solar-development`:

```bash
kubectl create namespace solar-development -o yaml
```

This has worked, we can also observe that based on the rules defined in the `Tenant`, the namespace has been automatically labeled with `environment=dev` and the pod security labels have been applied:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  creationTimestamp: "2026-07-23T08:26:12Z"
  labels:
    capsule.clastix.io/tenant: solar
    environment: dev
    kubernetes.io/metadata.name: solar-development
    pod-security.kubernetes.io/enforce: restricted
  name: solar-development
  ownerReferences:
  - apiVersion: capsule.clastix.io/v1beta2
    kind: Tenant
    name: solar
    uid: 3e95e43d-9ef7-4ba7-bc66-79af19ca8021
  resourceVersion: "68295"
  uid: cc49f3ba-ba51-4430-af2d-ab4a40369bce
```

Maybe `pod-security.kubernetes.io/enforce=restricted` is a bit too strict for a development environment, so let's change it's value to `baseline`:

```bash
kubectl label namespace solar-development pod-security.kubernetes.io/enforce=baseline --overwrite -o yaml
```

This is allowed by the rules defined in the `Tenant` since the namespace is labeled with `environment=dev` and the rule allows `pod-security.kubernetes.io/enforce` to be set to either `restricted` or `baseline`. If we try to set it to `privileged` we will be denied:

```bash
kubectl  label namespace solar-development pod-security.kubernetes.io/enforce=privileged --overwrite -o yaml
```

```bash
Error from server (Forbidden): admission webhook "namespaces.validating.projectcapsule.dev" denied the request: metadata label "privileged" at metadata.labels["pod-security.kubernetes.io/enforce"] is not allowed by namespace rule: value did not match any allowed rule. Allowed metadata values: exact: restricted, baseline
```

When we are using the [Capsule Proxy](/docs/proxy/) we can now issue `LIST` and `GET` requests to the Kubernetes API Server across all namespaces and tenants and only get the resources from `Tenant` alice is owner of:

```bash
kubectl get ns -A

NAME                STATUS   AGE
solar-development   Active   4m45s
```

Next up we are trying to create namespace in the `environment=prod` which is only allowed to be created with the `pod-security.kubernetes.io/enforce=restricted` label. Let's try to create a namespace called `solar-production`:

```bash
kubectl apply --server-side=true -o yaml -f - <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    environment: prod
    pod-security.kubernetes.io/enforce: privileged
  name: solar-production
EOF
```

We can directly see that we are not rejected, but `pod-security.kubernetes.io/enforce` is set to `restricted` instead of `privileged` as we requested. This is because the rules defined in the `Tenant` enforce that `pod-security.kubernetes.io/enforce` must be set to `restricted` for namespaces labeled with `environment=prod`. The webhook has automatically corrected the label to match the rules defined in the `Tenant`.

```yaml
kind: Namespace
metadata:
  creationTimestamp: "2026-07-23T10:46:21Z"
  labels:
    capsule.clastix.io/tenant: solar
    environment: prod
    kubernetes.io/metadata.name: solar-production
    pod-security.kubernetes.io/enforce: restricted
  name: solar-production
  ownerReferences:
  - apiVersion: capsule.clastix.io/v1beta2
    kind: Tenant
    name: solar
    uid: 406dfd14-8fd3-426d-bf9d-3fed81e37364
  resourceVersion: "11577"
  uid: 1bd9a36c-230d-4606-84cc-eb92a7b87d63
```

Attempting to create a third namespace will be denied since the `Tenant` has a quota of 2 namespaces:

```bash
kubectl create namespace solar-test -o yaml

Error from server (Forbidden): admission webhook "namespaces.validating.projectcapsule.dev" denied the request: Cannot exceed Namespace quota: please, reach out to the system administrators
```

### Events

Alice can also view `Events`, not only in their `Namespace` but also across all `Namespaces` of the `Tenant`:

```bash
kubectl get event -A

NAMESPACE   LAST SEEN   TYPE      REASON              OBJECT                        MESSAGE
default     31s         Warning   Overprovisioned   namespace/solar-test   namespace cannot be attached, quota exceeded for the elected tenant
default     36m         Warning   ForbiddenMetadata   namespace/solar-development   metadata label "privileged" at metadata.labels["pod-security.kubernetes.io/enforce"] is not allowed by namespace rule: value did not match any allowed rule. Allowed metadata values: exact: restricted, baseline
default     38m         Normal    TenantAssigned      namespace/solar-development   namespace has been assigned to the desired tenant solar
default     32m         Normal    TenantAssigned      namespace/solar-production    namespace has been assigned to the desired tenant solar
```

Capsule emits violations and events and tags the corresponding `Namespace` with the `Tenant` it belongs to. This allows the `TenantOwner` to view all events across all `Namespaces` of the `Tenant` and troubleshoot issues.

### Managed Resources

Now we can also inspect what contents are already present from the `Replications`, we are expecting networkpolicies and limitranges to be present in the `solar-production` namespace:

```bash
kubectl get netpol -A

NAMESPACE           NAME             POD-SELECTOR   AGE
solar-development   default-policy   <none>         4m34s
solar-production    default-policy   <none>         59s
```

Alice is also unable to delete these policies, eventough she has full permissions to manage `Networkpolicies`. This allows here to do here own firewalling (maybe among her `Tenants`/`Namespaces`) but enforces strictness by the platform to ensure that all `Namespaces` of the `Tenant` have a default deny policy in place:

```bash
 kubectl delete netpol -n solar-development --all

Error from server (Forbidden): admission webhook "replications.validating.projectcapsule.dev" denied the request: resource default-policy is managed by a global capsule replication default-networkpolicies
```

Since we provide all namespaces with a default network policy, we can see that the `default-policy` has been replicated in all namespaces of the `Tenant`. The same goes for the limitranges, however here we have conditions based on the `environment` label of the namespace:

```bash
kubectl get limitrange -A

NAMESPACE           NAME                   CREATED AT
solar-development   service-level-bronze   2026-07-23T10:43:07Z
solar-production    service-level-gold     2026-07-23T10:46:33Z
```

### Common Interactions

Next up we can try to schedule a pod in the `solar-development` `Namespace`:

```bash
kubectl -n solar-development run nginx --image=docker.io/nginx
```

Here we don't have to do anything special, since QOS class allow BestEffort (no resources) and PSS enforces baseline (no privileged containers) we can schedule a pod without any issues.

```bash
kubectl -n solar-development run nginx --image=docker.io/nginx
kubectl -n solar-development get pods -w
```

If you try to schedule a pod in the `solar-production` `Namespace` you will be denied since the QOS class only allows Guaranteed (resources must be specified) and PSS enforces restricted (no privileged containers):

```bash
kubectl apply --server-side=true -n solar-production -o yaml -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-restricted-guaranteed
  labels:
    app: nginx-restricted-guaranteed
spec:
  restartPolicy: Always
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
    runAsGroup: 101
    fsGroup: 101
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: nginx
      image: nginxinc/nginx-unprivileged:1.27-alpine
      ports:
        - name: http
          containerPort: 8080
      securityContext:
        allowPrivilegeEscalation: false
        privileged: false
        readOnlyRootFilesystem: true
        runAsNonRoot: true
        runAsUser: 101
        runAsGroup: 101
        capabilities:
          drop:
            - ALL
        seccompProfile:
          type: RuntimeDefault
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "100m"
          memory: "128Mi"
      volumeMounts:
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
        - name: tmp
          mountPath: /tmp
  volumes:
    - name: cache
      emptyDir: {}
    - name: run
      emptyDir: {}
    - name: tmp
      emptyDir: {}
EOF
kubectl -n solar-production get pods -w
```

Since this `Pod` actually declares resources, we can verify that this allows counts towards the [ResourceQuota](#resource-quota) defined in the `Tenant` spec:

```yaml
kubectl get resourcequota -A

NAMESPACE           NAME              REQUEST                                             LIMIT                                           AGE
solar-development   capsule-solar-0   requests.cpu: 0/7900m, requests.memory: 0/16256Mi   limits.cpu: 0/7900m, limits.memory: 0/16256Mi   33m
solar-production    capsule-solar-0   requests.cpu: 100m/8, requests.memory: 128Mi/16Gi   limits.cpu: 100m/8, limits.memory: 128Mi/16Gi   27m
```

As seen, we can see that the `Pod` in the `solar-production` namespace is counted towards the `ResourceQuota` defined in the `Tenant` spec. The `solar-development` the rest of the resources are then again available for other workloads in all other `Namespaces` of the `Tenant`. This allows the `TenantOwner` to control the amount of resources that can be used by the `Tenant` and its namespaces.
