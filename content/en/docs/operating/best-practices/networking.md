---
title: Networking
weight: 3
description: Control Service exposure and network isolation in tenant namespaces
---

## Services

For ordinary application namespaces, start with `ClusterIP` Services and expose
applications through a platform-managed Gateway or Ingress. Give namespaces
that need other Service types an explicit profile through
[Service enforcement rules](/docs/rules/enforcement/network/#services).

See the [combined Tenant baseline](/docs/operating/best-practices/tenants/#reference)
for Service restrictions together with workload and namespace policies.

### Recommended Baseline

| Setting | Default policy for application namespaces | Reason |
|---|---|---|
| `ClusterIP` | Allow, including headless Services. | Supports internal service discovery. NetworkPolicy still needs to control who can connect. |
| `NodePort` | Deny. | Opens a port on node addresses, creating an exposure path outside the managed application entry point. |
| `LoadBalancer` | Deny unless approved. | Can provision externally reachable infrastructure and normally allocates node ports too. |
| `ExternalName` | Deny unless approved. | Lets a tenant alias a Service name to another DNS name; review destinations before enabling it. |
| `spec.externalIPs` | Deny on every Service type. | Lets a Service claim traffic for an IP independently of its type. |

These are recommended rules to install, not Capsule's automatic defaults. See
the Kubernetes [Service types](https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types)
for their networking behavior. The upstream [external IP deprecation
proposal](https://github.com/kubernetes/enhancements/blob/master/keps/sig-network/5707-deprecate-service-externalips/README.md)
explains the traffic-interception risk of user-selected external IPs.

This complete Tenant applies the baseline to all its namespaces:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - kind: User
      name: solar-owner
  rules:
    - enforce:
        action: allow
        services:
          types: [ClusterIP]
    - enforce:
        action: deny
        services:
          externalIPs: {}
```

Replace `solar` and `solar-owner` with your Tenant name and owner identity. The
type allow-list rejects `NodePort`, `LoadBalancer`, and `ExternalName`.
Under `action: deny`, `externalIPs: {}` rejects every supplied external IP,
including IPv4 and IPv6, while allowing Services without external IPs. This
separate check matters because a `ClusterIP` Service can also set
`spec.externalIPs`.

These checks run on Service creation and updates. They do not remove existing
Services or close existing exposure when a rule is installed. Review existing
Services during rollout; subsequent updates must satisfy the effective rules.

### Scope Exceptions to a Namespace Profile

Keep the baseline for ordinary namespaces and add narrowly scoped exceptions
for workloads that need them. Protect the namespace labels selecting an
exception so tenant users cannot grant themselves a more permissive profile.
See [Namespace metadata rules](/docs/rules/enforcement/metadata/#namespace).

For example, this complete Tenant retains the baseline and permits an
`ExternalName` pointing to `database.example.com` only in namespaces labeled
`example.com/service-profile: external-database`:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - kind: User
      name: solar-owner
  rules:
    - enforce:
        action: allow
        services:
          types: [ClusterIP]
    - enforce:
        action: deny
        services:
          externalIPs: {}
    - namespaceSelector:
        matchLabels:
          example.com/service-profile: external-database
      enforce:
        action: allow
        services:
          types: [ExternalName]
          externalNames:
            hostnames:
              - exact: [database.example.com]
```

In selected namespaces, `ClusterIP` remains allowed and the approved
`ExternalName` is added. Other hostnames, `NodePort`, `LoadBalancer`, and all
external IPs remain denied. Non-selected namespaces retain the baseline.
Hostname constraints alone do not allow the `ExternalName` type; the exception
must include both the type and its hostname constraint.

The examples are alternative configurations of the same Tenant. Combine the
desired `spec.rules` entries into one manifest when adopting other policies.
Review [rule order and scope](/docs/rules/#order-and-scope): later matching rules
can override earlier decisions for the same Service value.

An `ExternalName` allow-list checks the submitted DNS name, not its resolved IP
addresses. It does not restrict connections made directly to other names or
IPs. Keep egress controls in place and consider who controls the approved DNS
name. See [ExternalName Services](https://kubernetes.io/docs/concepts/services-networking/service/#externalname).

### Approve LoadBalancers Deliberately

Some workloads need a dedicated load balancer. Treat that as a separate
namespace profile, with a reviewed provider configuration:

* **Control the implementation and exposure.** Allow `LoadBalancer` only in
  selected namespaces. Require the appropriate class or provider annotations
  for an internal load balancer where needed. Use
  [metadata rules](/docs/rules/enforcement/metadata/) for annotations and
  [enforcement conditions](/docs/rules/#enforcement-conditions) to deny
  incompatible Service fields. An allowed address range alone does not make a
  load balancer private.
* **Account for node ports.** Denying the `NodePort` Service type does not stop
  a permitted `LoadBalancer` from allocating node ports. If the implementation
  routes directly to Pods, require `spec.allocateLoadBalancerNodePorts: false`
  and reject explicit `spec.ports[].nodePort` values. Changing that flag on an
  existing Service does not release previously allocated ports; remove them
  explicitly. Other implementations need node ports, so constrain access with
  node firewalls and provider controls. See [load balancer node-port
  allocation](https://kubernetes.io/docs/concepts/services-networking/service/#load-balancer-nodeport-allocation).
* **Require the intended client networks.** Use explicit
  `spec.loadBalancerSourceRanges` and verify the provider enforces them; an
  unsupported provider can ignore this field. Capsule's
  [LoadBalancer CIDR checks](/docs/rules/enforcement/network/#loadbalancer)
  validate both `spec.loadBalancerIP` and `spec.loadBalancerSourceRanges`.
  They do not require source ranges specifically when `loadBalancerIP` is
  present, so use a condition-based deny rule if missing source ranges must be
  rejected. See the [Service API](https://kubernetes.io/docs/reference/kubernetes-api/core/service-v1/).
* **Control provider-specific options and consumption.** Review annotations
  that select public exposure, address pools, or firewall behavior. Bound load
  balancer counts with [quotas](/docs/resource-management/) and review the
  resulting addresses and firewall rules after provisioning.

### Keep Network and Access Controls in Place

Service admission controls configuration; it does not establish tenant network
isolation. Apply [NetworkPolicies](#network-policies) with a supporting CNI and
test the actual ingress and egress paths. Address translation can affect which
source or destination a policy sees, particularly with load balancers. See
[NetworkPolicy behavior](https://kubernetes.io/docs/concepts/services-networking/network-policies/#behavior-of-to-and-from-selectors).

Also review these paths outside the Service type rules:

* Restrict direct writes to `EndpointSlice`, legacy `Endpoints`, and
  `services/status` through RBAC. Endpoint writes can redirect Service traffic;
  keep them with trusted controllers unless a workload explicitly needs that
  capability. See [RBAC guidance on traffic
  redirection](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#write-access-for-endpoints).
* Apply [Pod Security Standards](/docs/operating/best-practices/workloads/#pod-security-standards)
  to restrict `hostNetwork` and `hostPort`. Blocking NodePort Services does not
  restrict these Pod settings.
* Control who can publish Gateway routes or Ingresses and which hosts they may
  use. A permitted `ClusterIP` backend can still be deliberately published by
  those controllers; see [Ingress enforcement](/docs/rules/enforcement/network/#ingress).

## Network-Policies

Start with native Kubernetes NetworkPolicies. In most cases they are enough to
isolate Tenants: a default-deny baseline with allowances for the same Tenant,
DNS and platform ingress, created in every Tenant namespace with a
GlobalTenantResource. Use the
[advanced policies](#advanced-network-policies) only when tenant owners must
not be able to widen the access.

### Native NetworkPolicies with GlobalTenantResource

Use [GlobalTenantResource](/docs/replications/global/) to distribute a common
network profile across Tenant namespaces. Start with default-deny ingress and
egress, then allow the flows applications need. The CNI must support and enforce
native Kubernetes [NetworkPolicies](https://kubernetes.io/docs/concepts/services-networking/network-policies/).

Native NetworkPolicies are additive: an additional allow policy can widen the
effective access. Protecting the replicated baseline alone is therefore not a
mandatory isolation boundary. Restrict tenant permissions to create additional
NetworkPolicies when the platform must own that boundary, or use an
[administrator-enforced policy](#advanced-network-policies) supported by your
CNI. Both source egress and destination ingress must allow a connection. See the
Kubernetes
[policy-combination rules](https://kubernetes.io/docs/concepts/services-networking/network-policies/#the-two-sorts-of-pod-isolation).

This example creates four policies per selected namespace. Verify replication
readiness and test same-Tenant access, cross-Tenant denial, DNS, and platform
ingress before relying on the profile. Replication readiness confirms resource
delivery; it does not prove the CNI has applied the rules. Tune
`resyncPeriod` for the number of namespaces you manage.

This complete, cluster-scoped GlobalTenantResource creates four native
`networking.k8s.io/v1` NetworkPolicies in every namespace of every selected
Tenant. It has no `metadata.namespace`. `tenantSelector: {}` selects all
Tenants; replace it with a label selector to roll out the profile gradually.
Use `resources[].namespaceSelector` when only some namespaces need this profile.
The default Capsule ServiceAccount (`cluster-admin`) can manage them. A
dedicated [replication ServiceAccount](/docs/replications/global/#required-permissions)
needs permission to manage NetworkPolicies in the destination namespaces.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-network-baseline
spec:
  scope: Namespace
  tenantSelector: {}
  resyncPeriod: 60s
  resources:
    - policy:
        creation: Owner
        protect: true
        deletion: Remove
      rawItems:
        - apiVersion: networking.k8s.io/v1
          kind: NetworkPolicy
          metadata:
            name: capsule-default-deny
          spec:
            podSelector: {}
            policyTypes: [Ingress, Egress]

        - apiVersion: networking.k8s.io/v1
          kind: NetworkPolicy
          metadata:
            name: capsule-allow-same-tenant
          spec:
            podSelector: {}
            policyTypes: [Ingress, Egress]
            ingress:
              - from:
                  - namespaceSelector:
                      matchLabels:
                        capsule.clastix.io/tenant: "{{tenant.name}}"
            egress:
              - to:
                  - namespaceSelector:
                      matchLabels:
                        capsule.clastix.io/tenant: "{{tenant.name}}"

        - apiVersion: networking.k8s.io/v1
          kind: NetworkPolicy
          metadata:
            name: capsule-allow-dns
          spec:
            podSelector: {}
            policyTypes: [Egress]
            egress:
              - to:
                  # Both selectors apply to the same destination Pod.
                  - namespaceSelector:
                      matchLabels:
                        kubernetes.io/metadata.name: kube-system
                    podSelector:
                      matchLabels:
                        k8s-app: kube-dns
                ports:
                  - protocol: UDP
                    port: 53
                  - protocol: TCP
                    port: 53

        - apiVersion: networking.k8s.io/v1
          kind: NetworkPolicy
          metadata:
            name: capsule-allow-platform-ingress
          spec:
            podSelector: {}
            policyTypes: [Ingress]
            ingress:
              - from:
                  - namespaceSelector:
                      matchLabels:
                        company.com/system: "true"
```

Capsule renders `{{tenant.name}}` separately for each destination Tenant using
[Fast Templates](/docs/operating/concepts/templating/#fast-templates), and sets
the destination namespace on each generated policy. The selector uses Capsule's
namespace membership label, `capsule.clastix.io/tenant`.

The resulting profile permits:

| Traffic | Allowance in this profile |
|---|---|
| Between Pods in the same Tenant, including the same namespace | Ingress and egress on all ports. |
| From Tenant Pods to cluster DNS | TCP and UDP port 53 to the selected DNS Pods. |
| From Pods in trusted platform namespaces to Tenant Pods | Ingress on all ports; narrow the Pod selectors and ports for your monitoring or ingress controllers. |
| To another Tenant, the internet, or other platform destinations | No allowance from this profile; add a reviewed policy for required flows. |

For namespace-level isolation within a Tenant, replace the same-tenant peers
with `podSelector: {}` so they select Pods only in the policy's namespace.
Install the [namespace metadata restriction](#deny-namespace-metadata) below
on every application Tenant before trusting `company.com/system`.

Check your DNS deployment's namespace and labels; the example assumes
`kube-system` and `k8s-app: kube-dns`. See [DNS
troubleshooting](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/).
NodeLocal DNSCache or host-networked DNS may need different CNI-specific
allowances. Test DNS over both UDP and TCP instead of relying on a fixed Service
IP. The platform workloads also need an egress policy permitting their
connections if their own namespaces isolate egress.

`protect: true` protects the replicated objects from tenant modification or
deletion through Capsule admission. It does not stop someone from creating
another NetworkPolicy. With `deletion: Remove`, removing the replication or a
destination from its selection removes the policies it created; plan those
changes as changes to network access.

### CiliumNetworkPolicies

With Cilium, the same baseline can be distributed as a single namespaced
`CiliumNetworkPolicy` per namespace. CiliumNetworkPolicies have no
`namespaceSelector` and no `fromNamespaces` or `toNamespaces` fields. Instead,
Cilium exposes the labels of a Pod's namespace as endpoint labels with the
`io.cilium.k8s.namespace.labels.` prefix, so peers are selected through
`fromEndpoints` and `toEndpoints`.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-cilium-baseline
spec:
  scope: Namespace
  tenantSelector: {}
  resyncPeriod: 60s
  serviceAccount:
    name: capsule-cilium-baseline
    namespace: capsule-system
  resources:
    - policy:
        creation: Owner
        protect: true
        deletion: Remove
      rawItems:
        - apiVersion: cilium.io/v2
          kind: CiliumNetworkPolicy
          metadata:
            name: capsule-tenant-baseline
          spec:
            endpointSelector: {}  # All Pods in the namespace
            ingress:
              # Pods in any namespace of the same Tenant, including this one.
              - fromEndpoints:
                  - matchLabels:
                      io.cilium.k8s.namespace.labels.capsule.clastix.io/tenant: "{{tenant.name}}"
              # Pods in trusted platform namespaces.
              - fromEndpoints:
                  - matchLabels:
                      io.cilium.k8s.namespace.labels.company.com/system: "true"
            egress:
              # Pods in any namespace of the same Tenant, including this one.
              - toEndpoints:
                  - matchLabels:
                      io.cilium.k8s.namespace.labels.capsule.clastix.io/tenant: "{{tenant.name}}"
              # Cluster DNS.
              - toEndpoints:
                  - matchLabels:
                      io.kubernetes.pod.namespace: kube-system
                      k8s-app: kube-dns
                toPorts:
                  - ports:
                      - port: "53"
                        protocol: UDP
                      - port: "53"
                        protocol: TCP
                    rules:
                      dns:
                        - matchPattern: "*"
```

Once a CiliumNetworkPolicy selects a Pod with ingress or egress rules, traffic
in that direction that no rule allows is denied, so this single policy has the
same effect as the four native policies above. The DNS rule follows the
[Cilium DNS policy documentation](https://docs.cilium.io/en/latest/security/dns/),
which recommends allowing the DNS lookups explicitly. The same caveats apply: tenants
that may create their own CiliumNetworkPolicies can widen the access, the
`company.com/system` label must be reserved for platform namespaces, and the
DNS selector must match your DNS deployment. Test the profile with the Cilium
version you run, for example with `cilium policy get` and connectivity checks
between Tenants.

### Calico NetworkPolicies

With Calico, the same baseline can be distributed as a single namespaced
Calico `NetworkPolicy` (`projectcalico.org/v3`) per namespace. Calico policies
select peers with selector expressions, so the Tenant and platform namespaces
are matched on their labels with `namespaceSelector`. The policy lives in
Calico's `default` tier, next to native NetworkPolicies.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-calico-baseline
spec:
  scope: Namespace
  tenantSelector: {}
  resyncPeriod: 60s
  resources:
    - policy:
        creation: Owner
        protect: true
        deletion: Remove
      rawItems:
        - apiVersion: projectcalico.org/v3
          kind: NetworkPolicy
          metadata:
            name: capsule-tenant-baseline
          spec:
            selector: all()  # All Pods in the namespace
            types: [Ingress, Egress]
            ingress:
              # Pods in any namespace of the same Tenant, including this one.
              - action: Allow
                source:
                  namespaceSelector: "capsule.clastix.io/tenant == '{{tenant.name}}'"
              # Pods in trusted platform namespaces.
              - action: Allow
                source:
                  namespaceSelector: "company.com/system == 'true' && !has(capsule.clastix.io/tenant)"
            egress:
              # Pods in any namespace of the same Tenant, including this one.
              - action: Allow
                destination:
                  namespaceSelector: "capsule.clastix.io/tenant == '{{tenant.name}}'"
              # Cluster DNS.
              - action: Allow
                protocol: UDP
                destination:
                  namespaceSelector: "kubernetes.io/metadata.name == 'kube-system'"
                  selector: "k8s-app == 'kube-dns'"
                  ports: [53]
              - action: Allow
                protocol: TCP
                destination:
                  namespaceSelector: "kubernetes.io/metadata.name == 'kube-system'"
                  selector: "k8s-app == 'kube-dns'"
                  ports: [53]
```

Once a Calico policy with `types: [Ingress, Egress]` selects a Pod, traffic in
that direction that no rule allows is denied, so this single policy has the same
effect as the four native policies above. The platform selector requires the
absence of the `capsule.clastix.io/tenant` label, so a Tenant owner cannot make
their namespace trusted by adding `company.com/system`. Still
[deny that label](#deny-namespace-metadata) on Tenant namespaces. DNS is limited
to port 53 on the DNS Pods. Check that the DNS selector matches your DNS Pods.

Tenant owners have no Calico API permissions through Capsule, so they cannot
create, change or delete Calico policies, and `protect: true` also rejects
changes by cluster administrators. They can still create native
NetworkPolicies, and those are additive to this policy. An owner can widen the
access, including across Tenants, with an allow-all NetworkPolicy. When the
platform must own the isolation boundary, use the
[Calico tiers](#calico-tiers) below.

### Deny Namespace Metadata

The platform-ingress policy trusts namespaces carrying
`company.com/system: "true"`. Reserve that label for administrator-managed
platform namespaces outside application Tenants. Restrict who can label those
namespaces through RBAC.

Use a [metadata enforcement rule](/docs/rules/enforcement/metadata/#namespace)
to deny the label on application Tenant namespaces. This complete Tenant
replaces the legacy `namespaceOptions.forbiddenLabels` configuration:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - kind: User
      name: solar-owner
  rules:
    - enforce:
        action: deny
        metadata:
          - apiGroups: [v1]
            kinds: [Namespace]
            labels:
              company.com/system:
                values:
                  - exp: ".*"
```

The explicit `Namespace` kind targets the Namespace object itself. The rule
rejects the label on creation and when an update adds or changes its value,
including `"true"`, `"false"`, and an empty value. Namespaces without the label
and updates removing it remain allowed. Apply this rule to every application
Tenant and merge it with the Service rules above when using both profiles.
Keep it unconditional so changing a namespace label cannot opt out of the
restriction. Review later rules that could override this denial.

Metadata validation skips unchanged values on updates. This rule therefore
does not remove an existing label or reject an update that leaves its value
unchanged. Remove any existing tenant-controlled `company.com/system` labels
before enabling the platform-ingress allowance.

## Advanced Network Policies

Native NetworkPolicies are namespaced, so a tenant owner with NetworkPolicy
permissions can always widen the access. When the platform must own the
isolation boundary, enforce it with a cluster-level policy that is evaluated
before any NetworkPolicy a tenant owner writes, and let Capsule create it once
per Tenant with a [GlobalTenantResource](/docs/replications/global/) using
`scope: Tenant`. The Tenant label `capsule.clastix.io/tenant` on every Tenant
namespace is what the policies select on, and Capsule resets changes to it.

The mechanism depends on what enforces policies in your cluster:

| Your cluster | Choose | Why |
|---|---|---|
| kube-network-policies, Calico, Cilium or kube-ovn, and you want one portable manifest | [ClusterNetworkPolicies](#clusternetworkpolicies) | One upstream API that all of these implement. The API is still alpha (`v1alpha2`). |
| Cilium and you prefer its stable API | [Cilium policies](#cilium) | `cilium.io/v2` is stable, but there are no tiers and `enableDefaultDeny` must be set carefully. |
| Calico and you prefer a stable API | [Calico tiers](#calico-tiers) | `projectcalico.org/v3` is stable. |
| Calico and tenants need their own ordered or deny rules | [Calico tier per Tenant](#calico-tier-per-tenant) | Owners get a tier they alone can use. Tenants can write deny rules and ordered rules that run before native NetworkPolicies and cannot override the platform tier. |

All approaches below give the same isolation. See
[Verify the Behavior](#verify-the-behavior) for what to check on your cluster.

### ClusterNetworkPolicies

Native NetworkPolicies are namespaced, so a tenant owner can always create
another one that widens access. The upstream
[ClusterNetworkPolicy](https://network-policy-api.sigs.k8s.io/api-overview/)
API (`policy.networking.k8s.io/v1alpha2`) adds cluster-scoped policies that
are evaluated in tiers:

| Tier | Evaluated | Overridable by tenant NetworkPolicies |
|---|---|---|
| `Admin` | First. `Accept` and `Deny` are final decisions. | No |
| NetworkPolicy | Second. Namespaced policies written by tenant owners. | n/a |
| `Baseline` | Last. Default connectivity for traffic nothing else decided. | Yes |

Use the `Admin` tier for the isolation boundary the platform owns. Tenant
owners have no permissions on cluster-scoped `ClusterNetworkPolicy` objects
through Capsule, and nothing a tenant creates in its namespaces is evaluated
before the `Admin` tier. Do not grant `policy.networking.k8s.io` write access
to tenant users or groups in any other ClusterRole.

#### Choose an Implementation

The API is alpha, and the examples only use fields from the standard channel.
These policies only take effect when a component in your cluster implements the
API. A CNI that only enforces native NetworkPolicies accepts the objects but
ignores them without reporting an error, so always test that traffic is
actually denied. The upstream
[implementation list](https://network-policy-api.sigs.k8s.io/implementations/)
has more.

| Implementation | What to enable |
|---|---|
| [kube-network-policies](https://github.com/kubernetes-sigs/kube-network-policies) | Adds ClusterNetworkPolicy support to a CNI that has none, and enforces native NetworkPolicies as well. Disable the CNI's own NetworkPolicy enforcement so it is the only enforcer, as explained below. Install the `ClusterNetworkPolicy` CRD, then its [`install-cnp.yaml`](https://github.com/kubernetes-sigs/kube-network-policies/blob/main/install-cnp.yaml) manifest. |
| [kube-ovn](https://github.com/kubeovn/kube-ovn), v1.16 and later | Supported, but disabled by default. Install with `ENABLE_ANP=true` (Helm: `func.ENABLE_ANP=true`). The installer does not ship the CRDs. Install the `ClusterNetworkPolicy` CRD yourself, plus the `AdminNetworkPolicy` and `BaselineAdminNetworkPolicy` v1alpha1 CRDs, because the controller watches all three. kube-ovn enforces native NetworkPolicies itself, so there is no second enforcer to disable. Priorities must be between 0 and 399 and a policy can have at most 25 rules. A policy outside these limits is only reported in the `kube-ovn-controller` log. |
| Calico, v3.32 and later | Supported. The Tigera operator installs the CRD, and the policies run in Calico's `kube-admin` tier. |
| Cilium, v1.20 and later | Disabled by default. Set the Helm value `k8sClusterNetworkPolicy.enabled=true`, install the [CRD](https://github.com/kubernetes-sigs/network-policy-api/tree/main/config/crd/standard) yourself because the chart does not ship it, and set `policyCIDRMatchMode: nodes` so CIDR rules match node IPs. See the [Cilium documentation](https://docs.cilium.io/en/stable/network/kubernetes/policy/#kubernetes-clusternetworkpolicy). |

Let a single component enforce both ClusterNetworkPolicies and native
NetworkPolicies. If a second component enforces NetworkPolicies on its own, it
cannot see an `Accept` from the first and still drops the traffic, so the
allowances below have no effect. This matters when you add
kube-network-policies to a CNI that has its own NetworkPolicy enforcement, such
as kindnet in a default kind cluster.

With Cilium, the agents read `policyCIDRMatchMode` at startup. A `helm upgrade`
does not restart them, so restart the `cilium` DaemonSet after changing it. Only
the value `nodes` is accepted; other values, such as `pods,nodes`, make the
agent exit on startup.

#### Baseline per Tenant

This cluster-scoped GlobalTenantResource creates two ClusterNetworkPolicies
for every Tenant, named after it. `scope: Tenant` renders the templates once
per Tenant instead of once per namespace, and `{{tenant.name}}` is replaced with
the Tenant name. `tenantSelector: {}` selects all Tenants; use a label
selector to roll the baseline out gradually.

* `tenant-<name>-infrastructure` (priority `5`) accepts what every Tenant needs:
  DNS, the Kubernetes API server, and traffic to and from platform namespaces.
* `tenant-<name>-isolation` (priority `10`) denies traffic to and from every
  other Tenant, in both directions.

Lower priorities win within a tier, so the `Accept` rules run before the `Deny`
rules.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-clusternetworkpolicy-baseline
spec:
  scope: Tenant
  tenantSelector: {}
  resyncPeriod: 60s
  resources:
    - policy:
        deletion: Remove
      rawItems:
        - apiVersion: policy.networking.k8s.io/v1alpha2
          kind: ClusterNetworkPolicy
          metadata:
            name: tenant-{{tenant.name}}-infrastructure
          spec:
            tier: Admin
            priority: 5
            subject:
              namespaces:
                matchLabels:
                  capsule.clastix.io/tenant: "{{tenant.name}}"
            ingress:
              - name: allow-platform-ingress
                action: Accept
                from:
                  - namespaces:
                      matchLabels:
                        company.com/system: "true"
                      matchExpressions:
                        - key: capsule.clastix.io/tenant
                          operator: DoesNotExist
            egress:
              - name: allow-platform-egress
                action: Accept
                to:
                  - namespaces:
                      matchLabels:
                        company.com/system: "true"
                      matchExpressions:
                        - key: capsule.clastix.io/tenant
                          operator: DoesNotExist
              - name: allow-dns
                action: Accept
                to:
                  - pods:
                      namespaceSelector:
                        matchLabels:
                          kubernetes.io/metadata.name: kube-system
                      podSelector:
                        matchLabels:
                          k8s-app: kube-dns
                protocols:
                  - udp:
                      destinationPort:
                        number: 53
                  - tcp:
                      destinationPort:
                        number: 53
              - name: allow-kube-api
                action: Accept
                to:
                  - networks:
                      - 10.0.0.10/32
                protocols:
                  - tcp:
                      destinationPort:
                        number: 6443

        - apiVersion: policy.networking.k8s.io/v1alpha2
          kind: ClusterNetworkPolicy
          metadata:
            name: tenant-{{tenant.name}}-isolation
          spec:
            tier: Admin
            priority: 10
            subject:
              namespaces:
                matchLabels:
                  capsule.clastix.io/tenant: "{{tenant.name}}"
            ingress:
              - name: deny-from-other-tenants
                action: Deny
                from:
                  - namespaces:
                      matchExpressions:
                        - key: capsule.clastix.io/tenant
                          operator: Exists
                        - key: capsule.clastix.io/tenant
                          operator: NotIn
                          values: ["{{tenant.name}}"]
            egress:
              - name: deny-to-other-tenants
                action: Deny
                to:
                  - namespaces:
                      matchExpressions:
                        - key: capsule.clastix.io/tenant
                          operator: Exists
                        - key: capsule.clastix.io/tenant
                          operator: NotIn
                          values: ["{{tenant.name}}"]
```

Replace `10.0.0.10/32` and port `6443` with the API server endpoint address
and port. The API server cannot be selected by labels, so the policy selects
it by address. CNIs evaluate the destination after Service translation, so use
the endpoint from
`kubectl get endpointslices -n default -l kubernetes.io/service-name=kubernetes`,
not the `kubernetes` Service IP. Update the policy if the endpoints change.
On Cilium without `policyCIDRMatchMode: nodes`, the `allow-kube-api` rule does
not match: DNS keeps working and API access stays blocked. The
[Calico](#calico-tiers) and [Cilium](#cilium) sections select the API server
without an address. As with the
[native DNS policy](#native-networkpolicies-with-globaltenantresource), check
the labels of your DNS Pods.

What the policies do:

* **Platform namespaces.** Namespaces labeled `company.com/system: "true"` and
  without the `capsule.clastix.io/tenant` label are trusted in both
  directions, for example monitoring or ingress controllers. The
  `DoesNotExist` expression matters: without it, two Tenant owners could each
  label their own namespace `company.com/system: "true"` and bypass the
  isolation. Still reserve the label and
  [deny it on Tenant namespaces](#deny-namespace-metadata). Narrow the peers
  and ports for your platform components.
* **Isolation scope.** The standard API cannot compare a label value between
  two namespaces, so each Tenant gets its own policy naming itself. A
  namespace without the Tenant label, such as a platform namespace, is not
  affected by the `Deny` rules.
* **Within a Tenant.** Traffic inside a Tenant, including between its
  namespaces, stays under the control of the Tenant's NetworkPolicies. Add the
  [native baseline](#native-networkpolicies-with-globaltenantresource) if you
  also want default-deny and same-Tenant allowances.
* **New and removed Tenants.** A new Tenant gets its policies within seconds
  of creation, and the existing Tenants are denied from it immediately.
  Deleting a Tenant removes its policies (`deletion: Remove`).
* **Protection.** By default `protect: true` makes Capsule reject changes to
  the generated policies through its admission webhook, including changes by
  cluster administrators. Change the GlobalTenantResource instead.
* **Policy order.** Policies selecting the same Pod and the same connection
  need different priorities because the order between equal priorities is
  not defined. Policies of different Tenants can share a priority.

### Cilium

Cilium's own `CiliumClusterwideNetworkPolicy` (`cilium.io/v2`) is a stable
alternative to the alpha ClusterNetworkPolicy. It has no tiers, which changes
how you write the policies:

* Any rule, including a deny rule, puts the selected Pods into default deny
  for that direction. Without `enableDefaultDeny` set to `false` for both
  directions, the policies would block all other traffic of every Tenant Pod,
  including traffic within the Tenant.
* A deny rule takes precedence over allow rules, so tenant NetworkPolicies
  cannot override the isolation.
* Selectors use the `io.cilium.k8s.namespace.labels.` prefix for namespace
  labels.
* The `kube-apiserver` entity selects the API server without a CIDR, so
  `policyCIDRMatchMode` is not needed. A `toServices` rule for the
  `kubernetes` Service in the `default` namespace also works.

This GlobalTenantResource creates the same baseline as the
[ClusterNetworkPolicies](#baseline-per-tenant), once per Tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-cilium-clusterwide-baseline
spec:
  scope: Tenant
  tenantSelector: {}
  resyncPeriod: 60s
  resources:
    - policy:
        deletion: Remove
      rawItems:
        - apiVersion: cilium.io/v2
          kind: CiliumClusterwideNetworkPolicy
          metadata:
            name: tenant-{{tenant.name}}-infrastructure
          spec:
            endpointSelector:
              matchLabels:
                io.cilium.k8s.namespace.labels.capsule.clastix.io/tenant: "{{tenant.name}}"
            enableDefaultDeny:
              ingress: false
              egress: false
            ingress:
              - fromEndpoints:
                  - matchLabels:
                      io.cilium.k8s.namespace.labels.company.com/system: "true"
                    matchExpressions:
                      - key: io.cilium.k8s.namespace.labels.capsule.clastix.io/tenant
                        operator: DoesNotExist
            egress:
              - toEndpoints:
                  - matchLabels:
                      io.cilium.k8s.namespace.labels.company.com/system: "true"
                    matchExpressions:
                      - key: io.cilium.k8s.namespace.labels.capsule.clastix.io/tenant
                        operator: DoesNotExist
              - toEndpoints:
                  - matchLabels:
                      io.kubernetes.pod.namespace: kube-system
                      k8s-app: kube-dns
                toPorts:
                  - ports:
                      - port: "53"
                        protocol: ANY
              - toEntities:
                  - kube-apiserver

        - apiVersion: cilium.io/v2
          kind: CiliumClusterwideNetworkPolicy
          metadata:
            name: tenant-{{tenant.name}}-isolation
          spec:
            endpointSelector:
              matchLabels:
                io.cilium.k8s.namespace.labels.capsule.clastix.io/tenant: "{{tenant.name}}"
            enableDefaultDeny:
              ingress: false
              egress: false
            ingressDeny:
              - fromEndpoints:
                  - matchExpressions:
                      - key: io.cilium.k8s.namespace.labels.capsule.clastix.io/tenant
                        operator: Exists
                      - key: io.cilium.k8s.namespace.labels.capsule.clastix.io/tenant
                        operator: NotIn
                        values: ["{{tenant.name}}"]
            egressDeny:
              - toEndpoints:
                  - matchExpressions:
                      - key: io.cilium.k8s.namespace.labels.capsule.clastix.io/tenant
                        operator: Exists
                      - key: io.cilium.k8s.namespace.labels.capsule.clastix.io/tenant
                        operator: NotIn
                        values: ["{{tenant.name}}"]
```

Tenant owners have no permissions on `ciliumclusterwidenetworkpolicies`.

### Calico Tiers

Calico evaluates policies in ordered tiers, like the ClusterNetworkPolicy
tiers, but with the stable `projectcalico.org/v3` API. Policies in a tier that
is ordered before the `default` tier, where Calico stores native
NetworkPolicies, cannot be changed or overridden by tenant owners. Prefer this
over ClusterNetworkPolicies on Calico if you want a stable API.

Create one tier for the platform. `order: 500` places it after Calico's own
`calico-system` tier (100) and before `kube-admin` (1000, the tier used for
ClusterNetworkPolicies). `defaultAction: Pass` is required: the default is
`Deny`, which blocks all tenant traffic that no policy in the tier matches.

```yaml
apiVersion: projectcalico.org/v3
kind: Tier
metadata:
  name: capsule-tenancy
spec:
  order: 500
  defaultAction: Pass
```

This GlobalTenantResource creates two GlobalNetworkPolicies per Tenant. Policy
names must start with the tier name. The `services` destination selects the
endpoints of the `kubernetes` Service and follows them when they change, so
there is no API server address to maintain. DNS is selected by Pod labels and
limited to port 53, because Calico does not allow `ports` together with
`services`; a `services` rule for `kube-dns` would open every port of the DNS
Pods, including their metrics port. Check the labels of your DNS Pods. The
platform namespaces and the isolation work like in the
[ClusterNetworkPolicy baseline](#baseline-per-tenant), including the
`!has(capsule.clastix.io/tenant)` guard.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-calico-platform-baseline
spec:
  scope: Tenant
  tenantSelector: {}
  resyncPeriod: 60s
  resources:
    - policy:
        deletion: Remove
      rawItems:
        - apiVersion: projectcalico.org/v3
          kind: GlobalNetworkPolicy
          metadata:
            name: capsule-tenancy.{{tenant.name}}-infrastructure
          spec:
            tier: capsule-tenancy
            order: 5
            namespaceSelector: "capsule.clastix.io/tenant == '{{tenant.name}}'"
            selector: all()
            types: [Ingress, Egress]
            ingress:
              - action: Allow
                source:
                  namespaceSelector: "company.com/system == 'true' && !has(capsule.clastix.io/tenant)"
            egress:
              - action: Allow
                destination:
                  namespaceSelector: "company.com/system == 'true' && !has(capsule.clastix.io/tenant)"
              - action: Allow
                protocol: UDP
                destination:
                  namespaceSelector: "kubernetes.io/metadata.name == 'kube-system'"
                  selector: "k8s-app == 'kube-dns'"
                  ports: [53]
              - action: Allow
                protocol: TCP
                destination:
                  namespaceSelector: "kubernetes.io/metadata.name == 'kube-system'"
                  selector: "k8s-app == 'kube-dns'"
                  ports: [53]
              - action: Allow
                destination:
                  services:
                    name: kubernetes
                    namespace: default

        - apiVersion: projectcalico.org/v3
          kind: GlobalNetworkPolicy
          metadata:
            name: capsule-tenancy.{{tenant.name}}-isolation
          spec:
            tier: capsule-tenancy
            order: 10
            namespaceSelector: "capsule.clastix.io/tenant == '{{tenant.name}}'"
            selector: all()
            types: [Ingress, Egress]
            ingress:
              - action: Deny
                source:
                  namespaceSelector: "has(capsule.clastix.io/tenant) && capsule.clastix.io/tenant != '{{tenant.name}}'"
            egress:
              - action: Deny
                destination:
                  namespaceSelector: "has(capsule.clastix.io/tenant) && capsule.clastix.io/tenant != '{{tenant.name}}'"
```

Tenant owners cannot create policies in this tier. Calico denies the request
unless the user may `get` the tier, which Capsule does not grant. Note that
`kubectl auth can-i` only checks the resource and reports `yes`; the real
request is forbidden.

#### Calico Tier per Tenant

Let each Tenant also have a tier that its owners can use. Owners then write
Calico `NetworkPolicy` objects with explicit `Allow`, `Deny` and `Pass` rules
and an order, which native NetworkPolicies cannot express. Tier order `2000`
places the Tenant tiers after the platform tier and `kube-admin`, and before
the `default` tier.

Calico needs two permissions, and they have different scopes:

* `get` on the Tier. Tiers are cluster-scoped, so this needs a
  ClusterRoleBinding. Limit it with `resourceNames` to the Tenant's own tier.
* Access to `tier.networkpolicies` with `resourceNames: ["<tier>.*"]`. Bind
  this role in the Tenant namespaces only. A ClusterRoleBinding would let the
  owner create policies in the namespaces of other Tenants, where a deny rule
  could break their traffic.

A RoleBinding to a role that allows `get` on the Tier does not work: Calico
denies the request with `user cannot get tier`.

This GlobalTenantResource creates, per Tenant, the Tier, both ClusterRoles, and
a ClusterRoleBinding for the Tenant owners. The template iterates over
`status.owners`, the resolved owner list, which also contains owners selected
through `spec.permissions.matchOwners`. A ServiceAccount owner is stored with
its canonical user name (`system:serviceaccount:<namespace>:<name>`), so the
template binds it as a `User` subject.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-calico-tiers
spec:
  scope: Tenant
  tenantSelector: {}
  resyncPeriod: 60s
  resources:
    - policy:
        deletion: Remove
      rawItems:
        - apiVersion: projectcalico.org/v3
          kind: Tier
          metadata:
            name: tenant-{{tenant.name}}
          spec:
            order: 2000
            defaultAction: Pass

        - apiVersion: rbac.authorization.k8s.io/v1
          kind: ClusterRole
          metadata:
            name: tenant-{{tenant.name}}-calico-tier
          rules:
            - apiGroups: ["projectcalico.org"]
              resources: ["tiers"]
              resourceNames: ["tenant-{{tenant.name}}"]
              verbs: ["get"]

        - apiVersion: rbac.authorization.k8s.io/v1
          kind: ClusterRole
          metadata:
            name: tenant-{{tenant.name}}-calico-policies
          rules:
            - apiGroups: ["projectcalico.org"]
              resources: ["tier.networkpolicies"]
              resourceNames: ["tenant-{{tenant.name}}.*"]
              verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
      generators:
        - missingKey: error
          template: |
            apiVersion: rbac.authorization.k8s.io/v1
            kind: ClusterRoleBinding
            metadata:
              name: tenant-{{ $.tenant.metadata.name }}-calico-tier
            roleRef:
              apiGroup: rbac.authorization.k8s.io
              kind: ClusterRole
              name: tenant-{{ $.tenant.metadata.name }}-calico-tier
            subjects:
            {{- range $.tenant.status.owners }}
              - kind: {{ if eq .kind "ServiceAccount" }}User{{ else }}{{ .kind }}{{ end }}
                name: {{ .name | quote }}
                apiGroup: rbac.authorization.k8s.io
            {{- end }}
```

Then bind the policy role in the Tenant namespaces with
`additionalRoleBindings`. Capsule creates the RoleBinding in every namespace of
the Tenant, including future ones. The ClusterRole is named after the Tenant,
so every Tenant references its own:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - kind: User
      name: solar-owner
  additionalRoleBindings:
    - clusterRoleName: tenant-solar-calico-policies
      subjects:
        - kind: User
          name: solar-owner
          apiGroup: rbac.authorization.k8s.io
```

The owner can now create namespaced policies in the `tenant-solar` tier, for
example to deny `solar-dev` towards `solar-prod` without a default-deny policy:

```yaml
apiVersion: projectcalico.org/v3
kind: NetworkPolicy
metadata:
  name: tenant-solar.deny-dev-to-prod
  namespace: solar-prod
spec:
  tier: tenant-solar
  order: 10
  selector: all()
  types: [Ingress]
  ingress:
    - action: Deny
      source:
        namespaceSelector: kubernetes.io/metadata.name == 'solar-dev'
```

Owners can only use their own tier, and only in their own namespaces. An
`Allow` in a tenant tier cannot override the platform `Deny`, because the
platform tier is evaluated first. A `Pass` defers to native NetworkPolicies.

When to use it instead of the platform tier alone:

* Tenants need deny rules, rule ordering or `Pass`, for example to block one
  namespace from another without a default-deny policy that also blocks
  everything else.
* Different Tenants need different tier semantics without the platform
  editing policies for them.

It does not give a stronger isolation boundary than the platform tier, and it
ties the tenant workloads' policies to Calico.

### Verify the Behavior

Support differs between CNIs, so test the baseline on your cluster, for example
with `curl` between Pods. Use at least two Tenants, a platform namespace
labeled `company.com/system: "true"`, and an unlabeled namespace, each with a
web Pod, a Service and a client Pod. Expect:

| Check | Expected result |
|---|---|
| Cross-Tenant traffic, by Pod IP and by Service, with the baseline | Denied in both directions |
| Cross-Tenant traffic after owners applied allow-all NetworkPolicies | Still denied |
| Traffic within a Tenant | Allowed, controlled by NetworkPolicies |
| DNS and API server access with an owner default-deny policy for ingress and egress | Allowed |
| Traffic from and to the platform namespace with that owner default-deny policy | Allowed in both directions |
| Traffic from and to an unlabeled namespace with that policy | Denied |
| Other egress from that namespace, such as the internet | Still blocked by the owner's policy |
| Owner labels own namespaces `company.com/system: "true"`, one Tenant or both | Still isolated |
| Owner `create`, `update`, `patch` and `delete` on the policy resources | Forbidden |
| Owner removing or changing the Tenant label on a namespace | Reverted by Capsule |
| New Tenant | Policies exist within seconds, and the Tenant is isolated from the others |
| Deleted Tenant, or deleted GlobalTenantResource | Generated policies removed |

A cluster administrator cannot edit a generated policy either while
`protect: true` is set; change the GlobalTenantResource.
