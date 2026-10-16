---
title: Network
weight: 5
aliases:
  - /docs/rules/enforcement/services/
  - /docs/rules/enforcement/ingress/
description: >
  Enforcement for NetworkPolicies, Services, and ingress hostnames
---

Network enforcement covers three policy groups under `spec.rules[].enforce`:

| Policy | Configuration path |
|---|---|
| [Network Policies](#policies) | `network.policies.ingress.cidrs`, `network.policies.egress.cidrs` |
| [Services](#services) | `services` |
| [Ingress](#ingress) | `ingress` |

Use these policies to control ingress and egress CIDR grants, Service types and addresses,
and hostnames on ingress resources. [Reference](#reference) provides a complete
Tenant example for each policy group.

Rules use the shared [namespace selection](/docs/tenants/rules/),
[audiences](/docs/rules/#audience),
[conditions](/docs/rules/#enforcement-conditions), and
[actions and order](/docs/rules/enforcement/#action).

## Rule Composition

<span id="advanced"></span>

### Actions and order

<span id="actions-and-order-1"></span>

Rules are evaluated in declaration order after namespace selection, audience,
and condition filtering. The last matching `allow` or `deny` wins for each
evaluated value. If `action` is omitted, it defaults to `deny`.

| Action | Behavior |
|---|---|
| `allow` | Creates an allow-list for the evaluated matcher. Values outside the allow-list are denied unless another applicable allow or deny rule matches. |
| `deny` | Rejects matching values. A later matching allow rule can override that decision. |
| `audit` | Reports matches without allowing or denying the request. It never satisfies an allow-list. |

The three policy groups evaluate different values. Every applicable check must
pass; an allow decision in one group does not bypass another.

| Policy | Unit of evaluation | Audit reporting |
|---|---|---|
| NetworkPolicy ingress and egress CIDRs | Every address granted after subtracting `ipBlock.except`. All granted addresses must pass. | `NamespaceRuleAudit` Kubernetes events; no admission warnings. |
| Services | Each Service type, IP address, ExternalName hostname, and node port covered by a matcher. Type and value allow-lists are independent. | Kubernetes events and admission warnings. |
| Ingress | Each hostname on the selected resource types, including both routing and TLS hosts on an Ingress. | Kubernetes events, including reports of missing hostname fields. |

<span id="actions-and-ordering"></span>

For NetworkPolicies, ordering applies **per address and direction**. A later allow for
`10.20.0.0/17` overrides an earlier deny for `10.20.0.0/16` only within the
smaller range. Several allowed CIDRs can together cover one grant. See
[Combine CIDR rules](#combine-cidr-rules). Ingress and egress have independent
allow-lists: an allow in one direction cannot override a deny or satisfy an
allow-list in the other. When an enforcement block includes both directions,
its `action` and `conditions` apply to both.

For Services, type-specific constraints do not grant the Service type. If a
`services.types` allow-list is active, it must allow the type independently of
any matching address or port rule. See [Combining Service Rules](#combining-service-rules).

### Admission scope and limits

These policies validate creation and updates in the selected namespaces.
They do not install network configuration or repair existing resources when a
rule or namespace label changes. Those changes affect subsequent admissions.

#### NetworkPolicies {#scope-and-limits}

- These policies check ingress source addresses and egress destination addresses.
  They do not constrain `podSelector`, `namespaceSelector`, or ports.
- An omitted direction in the Capsule rule imposes no constraint in that
  direction. Existing egress-only rules keep their behavior.
- An empty NetworkPolicy `ingress` or `egress` list contains no grants in that
  direction and passes its CIDR check. Only directions enabled by the
  NetworkPolicy's `policyTypes` are evaluated, including Kubernetes defaults.
- A rule with omitted peers (`ingress: [{}]` or `egress: [{}]`) grants every
  IPv4 and IPv6 address. An empty peer (`from: [{}]` or `to: [{}]`) does too.
  Restricting ports does not reduce this address grant.
- Policy updates are checked against the new object, including metadata changes
  that affect enforcement conditions. This check does not block deletion.
- CIDRs must include a prefix length and be valid IPv4 or IPv6 prefixes.
  IPv4-mapped IPv6 prefixes are unsupported. Host bits are normalized to the
  containing network. Each list accepts up to 64 unique CIDRs.

This is admission validation of NetworkPolicy grants. It does not itself install
a policy or enforce packet filtering. Traffic behavior still depends on the
NetworkPolicies present and the cluster's network implementation.

#### Services {#service-rule-caveats}

| Behavior                                                      | Explanation                                                                                                                                                      |
| ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `services.types` is the type gate                             | Type-specific sections do not automatically grant the Service type. Include the Service type in `services.types` when an allow-list for Service types is active. |
| Value constraints create allow-lists for their values        | If `loadBalancers.cidrs`, `externalIPs.cidrs`, `externalNames.hostnames`, or `nodePorts.ports` is configured with `action: allow`, non-matching values are denied. |
| External IP rules do not require a value                     | `externalIPs.cidrs` is evaluated only when a Service supplies `spec.externalIPs`; every supplied address is evaluated independently.                              |
| An empty external IP deny rule denies all external IPs       | `action: deny` with `externalIPs: {}` or `externalIPs.cidrs: []` denies any Service that supplies an external IP.                                                 |
| `loadBalancers.cidrs` requires explicit values                | When CIDR constraints are configured, `LoadBalancer` Services must set `spec.loadBalancerIP` or `spec.loadBalancerSourceRanges`.                                 |
| `nodePorts.ports` requires explicit node ports                | When port constraints are configured, `NodePort` Services and LoadBalancer Services with node port allocation enabled must set `spec.ports[].nodePort`.          |
| LoadBalancer node port allocation matters                     | `LoadBalancer` Services are subject to NodePort range checks unless `spec.allocateLoadBalancerNodePorts: false` is set.                                          |
| Negation applies to the whole matcher                         | `negate: true` inverts the result of both `exact` and `exp`.                                                                                                     |

#### Ingress {#admission-scope}

Ingress rules are evaluated during create and update admission. A rule only
participates when its `types` list contains the incoming resource kind. Other
resource types are unaffected. For example, `types: [Ingress, HTTPRoute]`
applies the hostname policy to those two kinds; it does not prohibit Gateways
or other omitted kinds. The `action` applies to the selected resources'
hostnames, not to the resource kinds themselves.

[Ingress Types](#ingress-types) lists the API versions handled by Capsule. Gateway API and OpenShift
resources require their respective APIs to be installed in the cluster.

When an `allow` or `deny` hostname rule targets a resource type, its expected
hostname fields must be non-empty. Audit-only rules report missing values
without making hostnames mandatory. See [Missing hostnames](#missing-hostnames).

## Network Policies {#policies}

NetworkPolicy enforcement applies to native `networking.k8s.io/v1`
NetworkPolicies in the namespaces selected by the rule.

### Ingress CIDRs

Configure ingress source constraints under
`spec.rules[].enforce.network.policies.ingress.cidrs`. Capsule checks the
addresses granted by `spec.ingress[].from[].ipBlock` during NetworkPolicy
creation and updates, after subtracting `ipBlock.except`.

This controls source addresses in NetworkPolicies. Hostname enforcement for
Ingress, Gateway API, and OpenShift Route resources is covered under
[Ingress](#ingress).

#### Disallow CIDR sources

To prevent users from granting ingress from any CIDR source, deny both address
families. This rule applies to every namespace in the Tenant:

```yaml
rules:
  - enforce:
      action: deny
      network:
        policies:
          ingress:
            cidrs:
              - 0.0.0.0/0
              - ::/0
```

With this rule, the following NetworkPolicy is rejected:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-cidr-ingress
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
    - from:
        - ipBlock:
            cidr: 192.0.2.0/24
```

A rejection identifies the source grant, field path, and matching rule:

```text
networkPolicy ingress CIDR "192.0.2.0/24" at spec.ingress[0].from[0].ipBlock.cidr matches deny rule for CIDR 0.0.0.0/0
```

| NetworkPolicy ingress grant | Result with the rule above |
|---|---|
| Any IPv4 or IPv6 `ipBlock` granting addresses | Denied |
| `ingress: [{}]`, including a rule with only ports | Denied: omitted `from` grants every source address |
| `from: [{}]` | Denied: the empty peer grants every source address |
| Peers using `podSelector` or `namespaceSelector` | Passes the CIDR check |
| `ingress: []` | Passes: no ingress addresses are granted |
| An IP block whose exceptions exclude every address | Passes: the block grants no addresses |

Setting `ingress: {}` or `ingress.cidrs: []` in the **Capsule rule** applies no
source constraint. The rule above leaves egress unchanged; configure
`network.policies.egress.cidrs` separately to constrain destinations.

#### Allow approved source ranges

Allow ingress CIDR grants only from approved source networks in selected
namespaces, then exclude a reserved subnet with a later deny:

```yaml
rules:
  - namespaceSelector:
      matchLabels:
        network-profile: internal
    enforce:
      action: allow
      network:
        policies:
          ingress:
            cidrs:
              - 10.20.0.0/16
              - fd00:1234::/48
  - namespaceSelector:
      matchLabels:
        network-profile: internal
    enforce:
      action: deny
      network:
        policies:
          ingress:
            cidrs:
              - 10.20.66.0/24
```

| NetworkPolicy source | Exceptions | Result in a selected namespace |
|---|---|---|
| `10.20.1.0/24` or `fd00:1234::/64` | None | Allowed |
| `10.20.0.0/16` | None | Denied: includes the reserved subnet |
| `10.20.0.0/16` | `10.20.66.0/24` | Allowed: the reserved subnet is fully excluded |
| `10.0.0.0/8` | None | Denied: extends outside the approved sources |
| `192.0.2.0/24` | None | Denied: outside the allow-list |
| Omitted `from` | None | Denied: grants all IPv4 and IPv6 sources |

Namespaces without `network-profile: internal` are unaffected by these rules.
Partial exceptions leave any remaining prohibited addresses subject to denial.
Multiple allowed ranges can together cover a source grant, using the same
[CIDR composition](#combine-cidr-rules) as egress. Use `action: audit` to report
matching ingress grants without allowing or denying them; audit-only matches
emit `NamespaceRuleAudit` events and do not satisfy an allow-list.

### Egress CIDRs

Configure egress CIDR constraints under
`spec.rules[].enforce.network.policies.egress.cidrs`. Capsule checks these grants
during NetworkPolicy creation and updates.

#### Disallow CIDR destinations

To prevent users from granting egress to any CIDR destination, deny both address
families. `0.0.0.0/0` covers every IPv4 address; `::/0` covers every IPv6 address.
This example applies to every namespace in the Tenant:

```yaml
rules:
  - enforce:
      action: deny
      network:
        policies:
          egress:
            cidrs:
              - 0.0.0.0/0
              - ::/0
```

With this rule, the following NetworkPolicy is rejected:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-cidr-egress
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - ipBlock:
            cidr: 192.0.2.0/24
```

An egress rule with no `to` destinations, such as `egress: [{}]`, grants access
to all destinations. Capsule checks it against both address families and rejects
it too. Restricting such a rule to particular ports does not bypass the CIDR
restriction.

Selector-based peers remain permitted by this check. For example, this policy
allows egress to matching Pods in the same namespace:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-selected-pods
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: backend
```

Use both universal CIDRs when blocking all CIDR destinations. Denying only
`0.0.0.0/0` leaves explicit IPv6 grants unaffected. Setting `egress: {}` or
`cidrs: []` in the Capsule rule applies no CIDR constraint.

This check evaluates the addresses a policy grants, rather than the presence of
the `ipBlock` field. If `except` excludes every address in an IP block, that
block grants nothing and passes this check.

#### Disallow selected CIDRs

List specific CIDRs to protect only those ranges. This rule applies only to
namespaces labeled `network-profile: restricted`:

```yaml
rules:
  - namespaceSelector:
      matchLabels:
        network-profile: restricted
    enforce:
      action: deny
      network:
        policies:
          egress:
            cidrs:
              - 10.20.0.0/16
              - fd00:1234::/48
```

Matching uses address overlap, including subnets and broader ranges. Capsule
subtracts `ipBlock.except` before evaluating the remaining grant:

| NetworkPolicy destination | Exceptions | Result with the rule above |
|---|---|---|
| `10.20.4.0/24` | None | Denied: inside the protected range |
| `10.0.0.0/8` | None | Denied: includes the protected range |
| `0.0.0.0/0` | None | Denied: includes the protected range |
| `10.0.0.0/8` | `10.20.0.0/16` | Allowed: the protected range is fully excluded |
| `10.0.0.0/8` | `10.20.0.0/17` | Denied: part of the protected range remains |
| `10.0.0.0/8` | `10.20.0.0/17`, `10.20.128.0/17` | Allowed: the exceptions together exclude the protected range |
| `192.0.2.0/24` | None | Allowed: no overlap |
| `::/0` | None | Denied: includes the protected IPv6 range |
| `::/0` | `fd00:1234::/48` | Allowed: the protected IPv6 range is fully excluded |

For example, this policy passes the CIDR check:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: exclude-protected-range
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - ipBlock:
            cidr: 10.0.0.0/8
            except:
              - 10.20.0.0/16
```

A rejection identifies the destination, its field path, and the matched rule:

```text
networkPolicy egress CIDR "10.0.0.0/8" at spec.egress[0].to[0].ipBlock.cidr matches deny rule for CIDR 10.20.0.0/16
```

#### Combine CIDR rules

For example, these two allowed ranges together cover `192.0.2.0/24`:

```yaml
rules:
  - enforce:
      action: allow
      network:
        policies:
          egress:
            cidrs:
              - 192.0.2.0/25
              - 192.0.2.128/25
```

A grant to `192.0.2.0/24` passes. A grant to `0.0.0.0/0` fails because it
includes addresses outside the allow-list. An unrestricted egress rule requires
complete coverage of both IPv4 and IPv6 address space.

To observe matching grants without blocking them, use an audit-only rule:

```yaml
rules:
  - enforce:
      action: audit
      network:
        policies:
          egress:
            cidrs:
              - 10.20.0.0/16
```

This rule admits a grant to `10.20.0.0/16` and emits an audit event. NetworkPolicy
CIDR audit rules report through events; they do not add admission warnings.

## Services

Service enforcement is configured under `spec.rules[].enforce.services`.
Use [Service Types](#types) to control which types can be created, then constrain
[LoadBalancer addresses](#loadbalancer), [External IPs](#external-ips),
[ExternalName hostnames](#externalname), and [NodePort ranges](#nodeport).

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - ClusterIP
          - NodePort
          - LoadBalancer
          - ExternalName
        loadBalancers:
          cidrs:
            - 10.0.0.2/32
        externalIPs:
          cidrs:
            - 10.20.0.0/16
        externalNames:
          hostnames:
            - exp: ".*\\.example\\.com"
              exact:
                - internal.git.com
        nodePorts:
          ports:
            - from: 30000
              to: 32767
```

### Service Types {#types}

The `services.types` field controls which Kubernetes Service types are allowed, denied, or audited by a rule.

Supported values are:

| Type           | Description                                                |
| -------------- | ---------------------------------------------------------- |
| `ClusterIP`    | Allows, denies, or audits Services of type `ClusterIP`.    |
| `NodePort`     | Allows, denies, or audits Services of type `NodePort`.     |
| `LoadBalancer` | Allows, denies, or audits Services of type `LoadBalancer`. |
| `ExternalName` | Allows, denies, or audits Services of type `ExternalName`. |

#### Allow selected types

Allow only `ClusterIP` Services:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - ClusterIP
```

With this rule, a `ClusterIP` Service is admitted:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: internal-api
spec:
  type: ClusterIP
  ports:
    - name: http
      port: 8080
      targetPort: 8080
```

A Service of another type, for example `ExternalName`, is denied because an allow-list exists for Service types and `ExternalName` is not listed:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  type: ExternalName
  externalName: internal.git.com
  ports:
    - name: http
      port: 443
      targetPort: 443
```

Example rejection:

```bash
Error from server (Forbidden): error when creating "svc.yaml": admission webhook "services.validating.projectcapsule.dev" denied the request: service type "ExternalName" at spec.type is not allowed by namespace rule: value did not match any allowed rule. Allowed service types: ClusterIP
```

#### Deny selected types

Deny `LoadBalancer` Services:

```yaml
rules:
  - enforce:
      action: deny
      services:
        types:
          - LoadBalancer
```

Allow `ClusterIP` and `ExternalName`, but deny `ExternalName` again for selected namespaces:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - ClusterIP
          - ExternalName

  - namespaceSelector:
      matchLabels:
        external-services: blocked
    enforce:
      action: deny
      services:
        types:
          - ExternalName
```

Because later matching allow or deny decisions win, namespaces labeled `external-services=blocked` cannot create `ExternalName` Services, while other matching namespaces can.

#### Combine types and value constraints

The `services.types` field is the Service capability gate. Constraint sections such as `loadBalancers`, `externalIPs`, `externalNames`, and `nodePorts` do not automatically allow a Service type by themselves. The `externalIPs` constraint is type-independent and applies to any allowed Service that specifies `spec.externalIPs`.

For example, this rule restricts LoadBalancer CIDRs, but it does not by itself allow `LoadBalancer` Services if another type allow-list exists that excludes `LoadBalancer`:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - ClusterIP

  - enforce:
      action: allow
      services:
        loadBalancers:
          cidrs:
            - 10.0.0.2/32
```

In this example, a `LoadBalancer` Service is denied by the Service type allow-list because `LoadBalancer` is not included in `services.types`.

To allow and constrain `LoadBalancer` Services, configure both:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - LoadBalancer
        loadBalancers:
          cidrs:
            - 10.0.0.2/32
```

### LoadBalancer

LoadBalancer rules allow administrators to restrict the IPs and source ranges used by Services of type `LoadBalancer`.

LoadBalancer constraints are configured under `enforce.services.loadBalancers.cidrs`.

Capsule evaluates the following Service fields:

| Field                             | Description                                            |
| --------------------------------- | ------------------------------------------------------ |
| `spec.loadBalancerIP`             | Explicit LoadBalancer IP requested by the Service.     |
| `spec.loadBalancerSourceRanges[]` | Source CIDR ranges allowed to access the LoadBalancer. |

Allow LoadBalancer Services only with a specific IP:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - LoadBalancer
        loadBalancers:
          cidrs:
            - 10.0.0.2/32
```

This Service is admitted:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: public-api
spec:
  type: LoadBalancer
  loadBalancerIP: 10.0.0.2
  ports:
    - name: http
      port: 80
      targetPort: 8080
```

This Service is denied because the requested IP is outside the allowed CIDR:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: public-api
spec:
  type: LoadBalancer
  loadBalancerIP: 10.0.171.239
  ports:
    - name: http
      port: 80
      targetPort: 8080
```

Example rejection:

```bash
Error from server (Forbidden): error when creating "svc.yaml": admission webhook "services.validating.projectcapsule.dev" denied the request: loadBalancer CIDR "10.0.171.239" at spec.loadBalancerIP is not allowed by namespace rule: value did not match any allowed rule. Allowed CIDRs: 10.0.0.2/32
```

Allow a LoadBalancer IP range:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - LoadBalancer
        loadBalancers:
          cidrs:
            - 10.0.1.0/24
```

The following Service is admitted because `10.0.1.44` is contained in `10.0.1.0/24`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: public-api
spec:
  type: LoadBalancer
  loadBalancerIP: 10.0.1.44
  ports:
    - name: http
      port: 80
      targetPort: 8080
```

Restrict `loadBalancerSourceRanges`:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - LoadBalancer
        loadBalancers:
          cidrs:
            - 10.0.1.0/24
```

This Service is admitted because the requested source range is fully contained in the allowed CIDR:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: public-api
spec:
  type: LoadBalancer
  loadBalancerSourceRanges:
    - 10.0.1.0/25
  ports:
    - name: http
      port: 80
      targetPort: 8080
```

This Service is denied because the requested source range is not fully contained in the allowed CIDR:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: public-api
spec:
  type: LoadBalancer
  loadBalancerSourceRanges:
    - 10.0.1.0/23
  ports:
    - name: http
      port: 80
      targetPort: 8080
```

#### Required LoadBalancer fields when CIDRs are configured

If any matching rule configures `loadBalancers.cidrs`, then a `LoadBalancer` Service must explicitly set at least one of:

* `spec.loadBalancerIP`
* `spec.loadBalancerSourceRanges`

This is intentional. If CIDR restrictions are configured, Capsule requires the Service request to provide a value that can be evaluated.

For example, this Service is denied when `loadBalancers.cidrs` is configured:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: public-api
spec:
  type: LoadBalancer
  ports:
    - name: http
      port: 80
      targetPort: 8080
```

Example rejection:

```bash
Error from server (Forbidden): error when creating "svc.yaml": admission webhook "services.validating.projectcapsule.dev" denied the request: loadBalancer service requires spec.loadBalancerIP or spec.loadBalancerSourceRanges because loadBalancer CIDR constraints are enforced by namespace rule
```

If no `loadBalancers.cidrs` constraint is configured, Capsule does not require these fields. In that case, a `LoadBalancer` Service can be admitted as long as the Service type itself is allowed.

#### Denying selected LoadBalancer CIDRs

You can also deny specific LoadBalancer CIDRs:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - LoadBalancer
        loadBalancers:
          cidrs:
            - 10.0.0.0/8

  - enforce:
      action: deny
      services:
        loadBalancers:
          cidrs:
            - 10.0.66.0/24
```

A Service using `10.0.66.10` is denied because the later deny rule matches:

```bash
Error from server (Forbidden): error when creating "svc.yaml": admission webhook "services.validating.projectcapsule.dev" denied the request: loadBalancer CIDR "10.0.66.10" at spec.loadBalancerIP is denied by namespace rule: 10.0.66.10 is contained in 10.0.66.0/24
```

A later namespace-specific allow rule can override an earlier allow miss or deny decision:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - LoadBalancer
        loadBalancers:
          cidrs:
            - 10.0.0.2/32

  - namespaceSelector:
      matchLabels:
        environment: prod
    enforce:
      action: allow
      services:
        loadBalancers:
          cidrs:
            - 10.0.171.0/24
```

In namespaces labeled `environment=prod`, a Service using `10.0.171.239` is admitted. In other namespaces, it is denied because it does not match the default allowed CIDR.

### External IPs

External IP rules allow administrators to restrict the addresses supplied in `spec.externalIPs`.

External IP constraints are configured under `enforce.services.externalIPs.cidrs`. They are admission rules only: Capsule does not allocate addresses, add entries to `spec.externalIPs`, or configure routing for them.

The constraint applies to any Service type that specifies `spec.externalIPs`. Individual addresses in a rule are treated as host CIDRs:

* an IPv4 address without a prefix is treated as `/32`;
* an IPv6 address without a prefix is treated as `/128`.

Allow external IPs from selected networks:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - ClusterIP
        externalIPs:
          cidrs:
            - 10.20.0.0/16
            - 192.168.1.2
            - 2001:db8::/32
```

This Service is admitted because both requested addresses match an allowed CIDR:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: internal-api
spec:
  type: ClusterIP
  externalIPs:
    - 10.20.1.44
    - 192.168.1.2
  ports:
    - name: http
      port: 8080
      targetPort: 8080
```

Every entry in `spec.externalIPs` must satisfy the rule evaluation. The following Service is denied because `8.8.8.8` is outside the allowed CIDRs:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: public-dns
spec:
  type: ClusterIP
  externalIPs:
    - 10.20.1.44
    - 8.8.8.8
  ports:
    - name: dns
      protocol: UDP
      port: 53
      targetPort: 5353
```

Example rejection:

```bash
Error from server (Forbidden): error when creating "svc.yaml": admission webhook "services.validating.projectcapsule.dev" denied the request: external IP "8.8.8.8" at spec.externalIPs[1] is not allowed by namespace rule: value did not match any allowed rule. Allowed CIDRs: 10.20.0.0/16, 192.168.1.2, 2001:db8::/32
```

Unlike LoadBalancer CIDR and NodePort range constraints, an external IP rule does not require the Service to specify a value. A Service without `spec.externalIPs` is admitted if it satisfies the other applicable Service rules.

#### Denying selected external IPs

You can combine a broad allow-list with a later deny rule:

```yaml
rules:
  - enforce:
      action: allow
      services:
        externalIPs:
          cidrs:
            - 10.20.0.0/16

  - enforce:
      action: deny
      services:
        externalIPs:
          cidrs:
            - 10.20.66.0/24
```

An address such as `10.20.1.44` is admitted, while `10.20.66.4` is denied because the later deny rule matches.

#### Denying all external IPs

For a deny rule, an empty `cidrs` array matches every value in `spec.externalIPs`:

```yaml
rules:
  - enforce:
      action: deny
      services:
        externalIPs:
          cidrs: []
```

The equivalent short form is:

```yaml
rules:
  - enforce:
      action: deny
      services:
        externalIPs: {}
```

Both forms deny any Service that supplies one or more external IPs. Services that omit `spec.externalIPs` remain unaffected. An empty `cidrs` array in an `allow` or `audit` rule does not create an external IP restriction.

### ExternalName

ExternalName rules allow administrators to restrict `spec.externalName` for Services of type `ExternalName`.

ExternalName constraints are configured under `enforce.services.externalNames.hostnames`.

Each hostname matcher uses the common match expression structure with `exact`, `exp`, and optional `negate`.

Allow selected ExternalName hostnames:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - ExternalName
        externalNames:
          hostnames:
            - exact:
                - internal.git.com
            - exp: ".*\\.example\\.com"
```

The following Services are admitted:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: git
spec:
  type: ExternalName
  externalName: internal.git.com
  ports:
    - name: https
      port: 443
      targetPort: 443
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  type: ExternalName
  externalName: api.example.com
  ports:
    - name: https
      port: 443
      targetPort: 443
```

A non-matching hostname is denied:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  type: ExternalName
  externalName: api.bad.com
  ports:
    - name: https
      port: 443
      targetPort: 443
```

Example rejection:

```bash
Error from server (Forbidden): error when creating "svc.yaml": admission webhook "services.validating.projectcapsule.dev" denied the request: externalName hostname "api.bad.com" at spec.externalName is not allowed by namespace rule: value did not match any allowed rule. Allowed hostnames: exact: internal.git.com, exp: .*\.example\.com
```

Use `exact` and `exp` together in the same matcher:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - ExternalName
        externalNames:
          hostnames:
            - exact:
                - combined.internal.git.com
              exp: "combined\\..*\\.example\\.com"
```

This matcher allows both:

* `combined.internal.git.com`
* hostnames matching `combined\\..*\\.example\\.com`

#### Negation for ExternalName hostnames

`negate: true` inverts the final matcher result. This applies to both `exact` and `exp`.

Deny every ExternalName except trusted hostnames:

```yaml
rules:
  - enforce:
      action: deny
      services:
        externalNames:
          hostnames:
            - exp: "trusted\\..*"
              negate: true

  - enforce:
      action: allow
      services:
        types:
          - ExternalName
        externalNames:
          hostnames:
            - exp: "trusted\\..*"
```

With these rules:

* `trusted.api` is admitted.
* `api.example.com` is denied by the negated deny rule.

Example rejection:

```bash
Error from server (Forbidden): error when creating "svc.yaml": admission webhook "services.validating.projectcapsule.dev" denied the request: externalName hostname "api.example.com" at spec.externalName is denied by namespace rule: "api.example.com" matched hostname rule not exp: trusted\..*
```

Important: when an allow-list exists for ExternalName hostnames, values excluded from a negated deny rule still need a matching allow rule. The deny rule prevents untrusted values, while the allow rule satisfies allow-list behavior for trusted values.

#### Namespace-specific ExternalName rules

You can use `namespaceSelector` to apply ExternalName restrictions only to selected namespaces:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - ExternalName
        externalNames:
          hostnames:
            - exp: ".*\\.example\\.com"

  - namespaceSelector:
      matchLabels:
        external-policy: restricted
    enforce:
      action: deny
      services:
        externalNames:
          hostnames:
            - exact:
                - blocked.example.com
```

In namespaces labeled `external-policy=restricted`, `blocked.example.com` is denied. Other hostnames matching `.*\\.example\\.com` remain allowed.

### NodePort

NodePort rules allow administrators to restrict explicitly requested `spec.ports[].nodePort` values.

NodePort constraints are configured under `enforce.services.nodePorts.ports`.

Each port range contains:

| Field  | Description                                |
| ------ | ------------------------------------------ |
| `from` | First allowed or denied port in the range. |
| `to`   | Last allowed or denied port in the range.  |

The `from` value must be lower than or equal to `to`. Equal values are valid and represent a single port.

Allow selected NodePort ranges:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - NodePort
        nodePorts:
          ports:
            - from: 30000
              to: 30100
            - from: 30500
              to: 30500
```

This Service is admitted because `30080` is in the allowed range:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: tenant-api
spec:
  type: NodePort
  ports:
    - name: http
      port: 8080
      targetPort: 8080
      nodePort: 30080
```

This Service is also admitted because `30500` matches the single-port range:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: tenant-api-single
spec:
  type: NodePort
  ports:
    - name: http
      port: 8080
      targetPort: 8080
      nodePort: 30500
```

This Service is denied because `32080` is outside the allowed ranges:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: tenant-api
spec:
  type: NodePort
  ports:
    - name: http
      port: 8080
      targetPort: 8080
      nodePort: 32080
```

Example rejection:

```bash
Error from server (Forbidden): error when creating "svc.yaml": admission webhook "services.validating.projectcapsule.dev" denied the request: nodePort "32080" at spec.ports[0].nodePort is not allowed by namespace rule: value did not match any allowed rule. Allowed ranges: 30000-30100, 30500
```

#### Required explicit nodePort when ranges are configured

If any matching rule configures `nodePorts.ports`, then a `NodePort` Service must explicitly set `spec.ports[].nodePort`.

This is intentional. Kubernetes can allocate a node port automatically when the field is omitted, but the validating webhook cannot know the allocated value at admission time. To enforce configured port ranges reliably, Capsule requires the requested node port to be explicit.

The following Service is denied when `nodePorts.ports` is configured:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: tenant-api
spec:
  type: NodePort
  ports:
    - name: http
      port: 8080
      targetPort: 8080
```

Example rejection:

```bash
Error from server (Forbidden): error when creating "svc.yaml": admission webhook "services.validating.projectcapsule.dev" denied the request: service requires explicit spec.ports[*].nodePort because nodePort ranges are enforced by namespace rule
```

If no `nodePorts.ports` constraint is configured, Capsule does not require explicit `nodePort` values. In that case, a `NodePort` Service can be admitted as long as the Service type itself is allowed.

#### Denying selected NodePorts

You can allow a broad range and deny a specific port afterwards:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - NodePort
        nodePorts:
          ports:
            - from: 30000
              to: 30100

  - enforce:
      action: deny
      services:
        nodePorts:
          ports:
            - from: 30090
              to: 30090
```

A Service using `30080` is admitted. A Service using `30090` is denied because the later deny rule also matches.

Example rejection:

```bash
Error from server (Forbidden): error when creating "svc.yaml": admission webhook "services.validating.projectcapsule.dev" denied the request: nodePort "30090" at spec.ports[0].nodePort is denied by namespace rule: nodePort 30090 is within allowed range 30090
```

Although the detail says the port is within the matched range, the rule action is `deny`, so the request is rejected.

#### LoadBalancer Services and NodePorts

Kubernetes `LoadBalancer` Services may allocate node ports unless `spec.allocateLoadBalancerNodePorts` is explicitly set to `false`.

Therefore, NodePort range enforcement also applies to `LoadBalancer` Services when node port allocation is enabled.

This rule allows LoadBalancer Services, restricts the LoadBalancer IP, and restricts the allocated node port:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - LoadBalancer
        loadBalancers:
          cidrs:
            - 10.0.0.2/32
        nodePorts:
          ports:
            - from: 30000
              to: 30100
```

This Service is admitted because the LoadBalancer IP and node port are both allowed:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: public-api
spec:
  type: LoadBalancer
  loadBalancerIP: 10.0.0.2
  ports:
    - name: http
      port: 80
      targetPort: 8080
      nodePort: 30080
```

This Service is denied because the explicit node port is outside the allowed range:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: public-api
spec:
  type: LoadBalancer
  loadBalancerIP: 10.0.0.2
  ports:
    - name: http
      port: 80
      targetPort: 8080
      nodePort: 32080
```

When `nodePorts.ports` is configured and LoadBalancer node port allocation is enabled, Capsule requires explicit `spec.ports[].nodePort` values:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: public-api
spec:
  type: LoadBalancer
  loadBalancerIP: 10.0.0.2
  ports:
    - name: http
      port: 80
      targetPort: 8080
```

Example rejection:

```bash
Error from server (Forbidden): error when creating "svc.yaml": admission webhook "services.validating.projectcapsule.dev" denied the request: service requires explicit spec.ports[*].nodePort because nodePort ranges are enforced by namespace rule
```

To avoid node port enforcement for a LoadBalancer Service, disable node port allocation explicitly:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: public-api
spec:
  type: LoadBalancer
  allocateLoadBalancerNodePorts: false
  loadBalancerIP: 10.0.0.2
  ports:
    - name: http
      port: 80
      targetPort: 8080
```

With `allocateLoadBalancerNodePorts: false`, Capsule does not require or validate `spec.ports[].nodePort` for that LoadBalancer Service. The Service must still satisfy any configured LoadBalancer CIDR rules.

### Auditing Services

Use `action: audit` to observe Service usage without directly blocking the request. Audit rules emit Kubernetes events and return admission warnings, but they do not allow or deny the request.

Audit ExternalName usage:

```yaml
rules:
  - enforce:
      action: audit
      services:
        types:
          - ExternalName
        externalNames:
          hostnames:
            - exp: "audit\\..*"
```

A matching Service is admitted in this audit-only example because no Service type or hostname allow-list is configured:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: audited-external
spec:
  type: ExternalName
  externalName: audit.internal
  ports:
    - name: https
      port: 443
      targetPort: 443
```

If an allow-list is also configured, audit does not satisfy it:

```yaml
rules:
  - enforce:
      action: audit
      services:
        externalNames:
          hostnames:
            - exp: "audit\\..*"

  - enforce:
      action: allow
      services:
        types:
          - ExternalName
        externalNames:
          hostnames:
            - exp: "allowed\\..*"
```

With these rules, `audit.internal` emits an audit event but is still denied because it does not match the allowed hostname rule.

### Combining Service Rules

Service rules can be split across multiple rule blocks. This is useful when type permissions, external IP rules, LoadBalancer CIDR rules, hostname rules, and NodePort ranges should be managed independently.

For example:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - ClusterIP
          - ExternalName

  - enforce:
      action: allow
      services:
        externalNames:
          hostnames:
            - exp: ".*\\.example\\.com"
```

This configuration:

* allows `ClusterIP` Services;
* allows `ExternalName` Services as a type;
* allows only ExternalName hostnames matching `.*\\.example\\.com`.

A Service of type `ExternalName` with `externalName: api.example.com` is admitted. A Service of type `ExternalName` with `externalName: api.bad.com` is denied by the hostname allow-list.

A later deny rule can override an earlier allow rule:

```yaml
rules:
  - enforce:
      action: allow
      services:
        types:
          - ExternalName
        externalNames:
          hostnames:
            - exp: ".*\\.example\\.com"

  - enforce:
      action: deny
      services:
        externalNames:
          hostnames:
            - exact:
                - blocked.example.com
```

Here, `api.example.com` is allowed, but `blocked.example.com` is denied because the later deny rule matches.

A later allow rule can override an earlier deny rule:

```yaml
rules:
  - enforce:
      action: deny
      services:
        nodePorts:
          ports:
            - from: 30080
              to: 30080

  - namespaceSelector:
      matchLabels:
        allow-special-nodeport: "true"
    enforce:
      action: allow
      services:
        types:
          - NodePort
        nodePorts:
          ports:
            - from: 30080
              to: 30080
```

In namespaces labeled `allow-special-nodeport=true`, a `NodePort` Service using `30080` is admitted because the namespace-specific allow rule matches later.

## Ingress

Ingress enforcement is configured under `spec.rules[].enforce.ingress`.
Use [Ingress Types](#ingress-types) to select Kubernetes Ingresses, OpenShift Routes,
and Gateway API resources, then configure [Hostnames](#hostnames) to allow,
deny, or audit their hostname values.

### Ingress Types {#ingress-types}

The `types` list selects the resource kinds whose hostnames the rule evaluates.
Configure at least one type and one hostname expression together. A rule with
only `types` or only `hostnames` is rejected at admission.

Capsule supports the following resource types and hostname fields:

| Type | API | Evaluated fields |
|---|---|---|
| `Ingress` | `networking.k8s.io/v1` | `spec.rules[].host` and `spec.tls[].hosts[]` |
| `Route` | `route.openshift.io/v1` | `spec.host` |
| `Gateway` | `gateway.networking.k8s.io/v1` | `spec.listeners[].hostname` |
| `ListenerSet` | `gateway.networking.k8s.io/v1` | `spec.listeners[].hostname` |
| `HTTPRoute` | `gateway.networking.k8s.io/v1` | `spec.hostnames[]` |
| `TLSRoute` | `gateway.networking.k8s.io/v1` | `spec.hostnames[]` |
| `GRPCRoute` | `gateway.networking.k8s.io/v1` | `spec.hostnames[]` |

### Hostnames

The `hostnames` list contains match expressions. Each entry supports:

| Field | Matching behavior |
|---|---|
| `exact` | Match one of the listed hostname strings exactly. |
| `exp` | Match a regular expression. Use `^` and `$` to match the complete hostname. |
| `negate` | Invert the entry's match result. Defaults to `false`. |

An entry can use `exact`, `exp`, or both. When both are set, either match is
sufficient before applying `negate`. Multiple entries provide alternative
matches for the rule's action.

Each hostname on a targeted resource is evaluated independently. The entire
request is denied if any hostname is denied or does not satisfy an active
allow-list. For an `Ingress`, this includes both routing hosts and TLS hosts, so
all values in `spec.rules[].host` and `spec.tls[].hosts[]` must satisfy the
policy.

#### Allow selected hostnames

The following rule allows one exact hostname and any single-label hostname
under `example.com` for Kubernetes Ingress and Gateway API HTTPRoute resources:

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
        ingress:
          types:
            - Ingress
            - HTTPRoute
          hostnames:
            - exact:
                - internal.example.com
            - exp: "^[a-z0-9-]+\\.example\\.com$"
```

This Ingress is admitted because both its routing hostname and TLS hostname
match the allow-list:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tenant-api
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: tenant-api
                port:
                  number: 8080
  tls:
    - hosts:
        - api.example.com
      secretName: tenant-api-tls
```

Changing either occurrence to `api.example.net` denies the request. A rejection
for the routing hostname includes the object path and configured allow-list:

```text
ingress hostname "api.example.net" at spec.rules[0].host is not allowed by namespace rule: value did not match any allowed rule. Allowed hostnames: exact: internal.example.com, exp: ^[a-z0-9-]+\.example\.com$
```

An `Ingress` TLS entry is not exempt from enforcement. For example, the
following object is denied even though its routing hostname is allowed, because
`legacy.example.net` in `spec.tls[0].hosts[0]` is not allowed:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mixed-hostnames
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: tenant-api
                port:
                  number: 8080
  tls:
    - hosts:
        - legacy.example.net
      secretName: tenant-api-tls
```

#### Gateway API and OpenShift Route examples

A single rule can target several supported resource shapes:

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
        ingress:
          types:
            - Route
            - Gateway
            - ListenerSet
            - HTTPRoute
            - TLSRoute
            - GRPCRoute
          hostnames:
            - exp: "^([a-z0-9-]+\\.)*apps\\.example\\.com$"
```

For an `HTTPRoute`, Capsule evaluates every entry in `spec.hostnames`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: store
spec:
  hostnames:
    - store.apps.example.com
    - checkout.apps.example.com
  rules:
    - backendRefs:
        - name: store
          port: 8080
```

Both values match the expression, so the request is admitted. If one hostname
does not match, Capsule denies the entire `HTTPRoute`.

For a `Gateway` or `ListenerSet`, Capsule evaluates the hostname of every
listener:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: tenant-gateway
spec:
  gatewayClassName: shared
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      hostname: gateway.apps.example.com
      tls:
        mode: Terminate
        certificateRefs:
          - name: gateway-tls
```

For an OpenShift `Route`, the same rule evaluates `spec.host`:

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: tenant-api
spec:
  host: api.apps.example.com
  to:
    kind: Service
    name: tenant-api
```

#### Deny hostnames and add exceptions

This Tenant allows a hostname family, denies a reserved hostname with a later
rule, and allows that hostname again in namespaces selected by the final rule:

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
        ingress:
          types: [Ingress, HTTPRoute]
          hostnames:
            - exp: '^[a-z0-9-]+\.example\.com$'

    - enforce:
        action: deny
        ingress:
          types: [Ingress, HTTPRoute]
          hostnames:
            - exact: [admin.example.com]

    - namespaceSelector:
        matchLabels:
          ingress-admin: "true"
      enforce:
        action: allow
        ingress:
          types: [Ingress, HTTPRoute]
          hostnames:
            - exact: [admin.example.com]
```

`api.example.com` is admitted in every namespace in this Tenant.
`admin.example.com` is admitted only in namespaces labeled
`ingress-admin=true`; the later deny rule blocks it in other namespaces.
Keep permission to change exception-selecting labels with the administrators
who manage the policy.

#### Negated matches

You can also use negation to deny every hostname outside a trusted suffix:

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
        ingress:
          types:
            - Ingress
          hostnames:
            - exp: "^([a-z0-9-]+\\.)*example\\.com$"
              negate: true
```

This deny rule matches hostnames that do not match the expression. Because it
does not create an allow-list, matching `example.com` hostnames pass unless
another rule denies them.

#### Audit hostname usage

Use `action: audit` to observe selected hostnames without blocking them:

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
        action: audit
        ingress:
          types:
            - Ingress
            - HTTPRoute
          hostnames:
            - exp: "^preview-.*\\.example\\.com$"
```

A matching hostname is admitted in this audit-only example, and Capsule emits a
Kubernetes event for it. If an allow-list is also configured and the hostname
does not match an allow rule, the request is still denied; the audit rule does
not grant access.

#### Missing hostnames

As soon as at least one `allow` or `deny` hostname rule targets a resource type,
every expected hostname field on that resource must contain a non-empty value.
Omitted, empty, and whitespace-only values are treated as missing.

Examples of missing values include:

* an `Ingress` with no routing or TLS hostname, an Ingress rule without `host`,
  or a TLS entry without `hosts`;
* a `Route` without `spec.host`;
* a `Gateway` or `ListenerSet` listener without `hostname`;
* an `HTTPRoute`, `TLSRoute`, or `GRPCRoute` without `spec.hostnames`.

For example, this Gateway is denied when an `allow` or `deny` hostname rule
targets `Gateway`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: hostless
spec:
  gatewayClassName: shared
  listeners:
    - name: http
      protocol: HTTP
      port: 80
```

The rejection identifies the missing field:

```text
hostname is required at spec.listeners[0].hostname because hostname rules target Gateway
```

If no ingress rule targets the resource type, Capsule does not apply this
hostname requirement.

Audit-only rules do not make hostnames mandatory. When an expected hostname is
missing, Capsule admits the request and emits an audit event that identifies the
empty field, for example:

```text
empty hostname detected at spec.listeners[0].hostname for Gateway by audit namespace rule
```

If audit and `allow` or `deny` rules target the same resource type, Capsule emits
the empty-hostname audit event and enforces the non-audit rule, which denies the
request.

## Reference

The following Tenant examples combine the policies in each group. Use the
configuration paths at the start of this chapter to combine them in one Tenant.

### Network Policies {#policies-reference}

This complete Tenant blocks CIDR-based ingress and egress grants by default, permits approved
ranges in selected namespaces, and denies a reserved subnet in those namespaces.
Replace `solar-owner` with your owner identity.

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
        network:
          policies:
            ingress:
              cidrs:
                - 0.0.0.0/0
                - ::/0
            egress:
              cidrs:
                - 0.0.0.0/0
                - ::/0

    - namespaceSelector:
        matchLabels:
          network-profile: approved-cidrs
      enforce:
        action: allow
        network:
          policies:
            ingress:
              cidrs:
                - 10.20.0.0/16
                - fd00:1234::/48
            egress:
              cidrs:
                - 10.20.0.0/16
                - fd00:1234::/48

    - namespaceSelector:
        matchLabels:
          network-profile: approved-cidrs
      enforce:
        action: deny
        network:
          policies:
            ingress:
              cidrs:
                - 10.20.66.0/24
            egress:
              cidrs:
                - 10.20.66.0/24
```

| Namespace profile | NetworkPolicy grant in either direction | Result |
|---|---|---|
| Without `network-profile: approved-cidrs` | Any CIDR granting addresses | Denied |
| `network-profile: approved-cidrs` | `10.20.1.0/24` or `fd00:1234::/64` | Allowed by the later allow rule |
| `network-profile: approved-cidrs` | `10.20.66.0/24` | Denied by the final deny rule |
| `network-profile: approved-cidrs` | `10.20.0.0/16` without exceptions | Denied: includes the reserved subnet |
| `network-profile: approved-cidrs` | `10.20.0.0/16` except `10.20.66.0/24` | Allowed |
| `network-profile: approved-cidrs` | `192.0.2.0/24` | Denied: outside the approved ranges |
| Any namespace in this Tenant | Ingress or egress rule with omitted peers | Denied |
| Any namespace in this Tenant | Selector-based peers or no grants in that direction | Passes the CIDR check |

Other applicable enforcement rules must also pass. Rules from this Tenant do not
apply to namespaces belonging to another Tenant.

### Services {#service-reference}

This complete Tenant combines type enforcement, external IP restrictions, LoadBalancer CIDR restrictions, ExternalName hostname restrictions, NodePort range restrictions, audit rules, and namespace-specific exceptions. Replace `solar-owner` with your owner identity.

```yaml
---
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
          types:
            - ClusterIP
            - NodePort
            - LoadBalancer
            - ExternalName

    - enforce:
        action: allow
        services:
          externalIPs:
            cidrs:
              - 10.20.0.0/16
              - 192.168.1.2

    - enforce:
        action: allow
        services:
          loadBalancers:
            cidrs:
              - 10.0.0.2/32
              - 10.0.1.0/24

    - enforce:
        action: allow
        services:
          externalNames:
            hostnames:
              - exact:
                  - internal.git.com
              - exp: ".*\\.example\\.com"

    - enforce:
        action: allow
        services:
          nodePorts:
            ports:
              - from: 30000
                to: 30100
              - from: 30500
                to: 30500

    - enforce:
        action: deny
        services:
          nodePorts:
            ports:
              - from: 30090
                to: 30090

    - enforce:
        action: deny
        services:
          externalIPs:
            cidrs:
              - 10.20.66.0/24

    - enforce:
        action: deny
        services:
          loadBalancers:
            cidrs:
              - 10.0.66.0/24

    - enforce:
        action: audit
        services:
          externalNames:
            hostnames:
              - exp: "audit\\..*"

    - namespaceSelector:
        matchLabels:
          environment: prod
      enforce:
        action: allow
        services:
          loadBalancers:
            cidrs:
              - 10.0.171.0/24
```

With this configuration:

* `ClusterIP`, `NodePort`, `LoadBalancer`, and `ExternalName` Services are valid Service types.
* External IPs must be contained in `10.20.0.0/16` or match `192.168.1.2`.
* External IPs in `10.20.66.0/24` are denied even though they are inside the broader allowed range.
* LoadBalancer IPs must be contained in `10.0.0.2/32` or `10.0.1.0/24`.
* Namespaces labeled `environment=prod` can also use LoadBalancer IPs in `10.0.171.0/24`.
* ExternalName hostnames must be `internal.git.com` or match `.*\\.example\\.com`.
* Explicit node ports must be in `30000-30100` or equal to `30500`.
* Node port `30090` is denied even though it is inside the broader allowed range.
* ExternalName hostnames matching `audit\\..*` emit audit events and warnings.
* Audit matches do not allow values that fail the allow-list.

### Ingress {#ingress-reference}

This complete Tenant allows a hostname family, denies a reserved hostname,
audits preview hostnames, and grants a namespace-specific exception. Replace
`solar-owner` with your owner identity. It covers every resource kind listed
under [Ingress Targets](#types), including Gateway API and OpenShift resources when those
APIs are installed.

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
        ingress:
          types: [Ingress, Route, Gateway, ListenerSet, HTTPRoute, TLSRoute, GRPCRoute]
          hostnames:
            - exact: [internal.example.com]
            - exp: '^[a-z0-9-]+\.solar\.example\.com$'

    - enforce:
        action: deny
        ingress:
          types: [Ingress, Route, Gateway, ListenerSet, HTTPRoute, TLSRoute, GRPCRoute]
          hostnames:
            - exact: [admin.solar.example.com]

    - enforce:
        action: audit
        ingress:
          types: [Ingress, Route, Gateway, ListenerSet, HTTPRoute, TLSRoute, GRPCRoute]
          hostnames:
            - exp: '^preview-[a-z0-9-]+\.solar\.example\.com$'

    - namespaceSelector:
        matchLabels:
          ingress-admin: "true"
      enforce:
        action: allow
        ingress:
          types: [Ingress, Route, Gateway, ListenerSet, HTTPRoute, TLSRoute, GRPCRoute]
          hostnames:
            - exact: [admin.solar.example.com]
```

Each routing, TLS, or listener hostname is checked independently:

| Hostname | Namespace | Result |
|---|---|---|
| `api.solar.example.com` or `internal.example.com` | Any namespace in this Tenant | Allowed |
| `admin.solar.example.com` | Without `ingress-admin: "true"` | Denied by the later deny rule |
| `admin.solar.example.com` | With `ingress-admin: "true"` | Allowed by the final exception |
| `preview-api.solar.example.com` | Any namespace in this Tenant | Allowed and audited |
| `api.example.net` | Any namespace in this Tenant | Denied because it does not match the allow-list |
| A required hostname is missing | Any namespace in this Tenant | Denied because non-audit hostname rules target the resource type |

Every hostname on a resource must pass. For example, an Ingress with an allowed
routing host and a disallowed TLS host is denied. If you narrow the `types`
lists, omitted resource kinds remain unaffected by these rules.

