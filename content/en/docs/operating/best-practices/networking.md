---
title: Networking
weight: 4
description: Control Service exposure and network isolation in tenant namespaces
---

## Services

For ordinary application namespaces, start with `ClusterIP` Services and expose
applications through a platform-managed Gateway or Ingress. Give namespaces
that need other Service types an explicit profile through
[Service enforcement rules](/docs/rules/enforcement/services/).

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
  [LoadBalancer CIDR checks](/docs/rules/enforcement/services/#loadbalancer)
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
  those controllers; see [Ingress enforcement](/docs/rules/enforcement/ingress/).

## Network-Policies

Use [GlobalTenantResource](/docs/replications/global/) to distribute a common
network profile across Tenant namespaces. Start with default-deny ingress and
egress, then allow the flows applications need. The CNI must support and enforce
native Kubernetes [NetworkPolicies](https://kubernetes.io/docs/concepts/services-networking/network-policies/).

### Native NetworkPolicies with GlobalTenantResource

Native NetworkPolicies are additive: an additional allow policy can widen the
effective access. Protecting the replicated baseline alone is therefore not a
mandatory isolation boundary. Restrict tenant permissions to create additional
NetworkPolicies when the platform must own that boundary, or use an
administrator-enforced policy mechanism supported by your CNI. Both source
egress and destination ingress must allow a connection. See the Kubernetes
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
The [replication identity](/docs/replications/global/#required-permissions) must
have permission to manage NetworkPolicies in the destination namespaces.

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
