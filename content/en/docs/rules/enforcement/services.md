---
title: Services
weight: 3
description: >
  Service enforcement
---

Service enforcement allows administrators to allow, deny, or audit Kubernetes `Service` resources in Tenant namespaces.

Service rules are configured under `spec.rules[].enforce.services`. Each rule can define an `action`, a list of allowed or denied Service `types`, and optional type-specific constraints for `LoadBalancer`, `ExternalName`, and `NodePort` Services.

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

Service enforcement follows the same action and precedence model as other namespace rules:

* `allow` creates an allow-list for the evaluated Service value.
* `deny` denies matching values.
* `audit` emits events and admission warnings but does not allow or deny the request.
* If multiple `allow` or `deny` rules match the same value, the last matching allow or deny rule wins.
* If at least one `allow` rule exists for a Service matcher and no allow or deny rule matches the evaluated value, Capsule denies the request.
* Audit rules never satisfy allow-list behavior.

Service rules are evaluated during Service create and update admission.

## Service Types

The `services.types` field controls which Kubernetes Service types are allowed, denied, or audited by a rule.

Supported values are:

| Type           | Description                                                |
| -------------- | ---------------------------------------------------------- |
| `ClusterIP`    | Allows, denies, or audits Services of type `ClusterIP`.    |
| `NodePort`     | Allows, denies, or audits Services of type `NodePort`.     |
| `LoadBalancer` | Allows, denies, or audits Services of type `LoadBalancer`. |
| `ExternalName` | Allows, denies, or audits Services of type `ExternalName`. |

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

The `services.types` field is the Service capability gate. Type-specific sections such as `loadBalancers`, `externalNames`, and `nodePorts` do not automatically allow a Service type by themselves.

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

## Advanced

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

Service rules can be split across multiple rule blocks. This is useful when type permissions, LoadBalancer CIDR rules, hostname rules, and NodePort ranges should be managed independently.

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

### Service Rule Caveats

Service enforcement is intentionally explicit. Keep the following behavior in mind:

| Behavior                                                      | Explanation                                                                                                                                                      |
| ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `services.types` is the type gate                             | Type-specific sections do not automatically grant the Service type. Include the Service type in `services.types` when an allow-list for Service types is active. |
| Type-specific constraints create allow-lists for their values | If `loadBalancers.cidrs`, `externalNames.hostnames`, or `nodePorts.ports` is configured with `action: allow`, non-matching values are denied.                    |
| `loadBalancers.cidrs` requires explicit values                | When CIDR constraints are configured, `LoadBalancer` Services must set `spec.loadBalancerIP` or `spec.loadBalancerSourceRanges`.                                 |
| `nodePorts.ports` requires explicit node ports                | When port constraints are configured, `NodePort` Services and LoadBalancer Services with node port allocation enabled must set `spec.ports[].nodePort`.          |
| LoadBalancer node port allocation matters                     | `LoadBalancer` Services are subject to NodePort range checks unless `spec.allocateLoadBalancerNodePorts: false` is set.                                          |
| Audit does not allow                                          | A matching `audit` rule emits events and warnings but does not satisfy an allow-list.                                                                            |
| Last matching allow or deny wins                              | Later matching `allow` or `deny` rules override earlier matching allow or deny rules.                                                                            |
| Negation applies to the whole matcher                         | `negate: true` inverts the result of both `exact` and `exp`.                                                                                                     |
| Namespace selectors affect projected rules                    | Rules with `namespaceSelector` only apply to namespaces matching the selector.                                                                                   |

### Complete Service Enforcement Example

The following example combines type enforcement, LoadBalancer CIDR restrictions, ExternalName hostname restrictions, NodePort range restrictions, audit rules, and namespace-specific exceptions:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  ...
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
* LoadBalancer IPs must be contained in `10.0.0.2/32` or `10.0.1.0/24`.
* Namespaces labeled `environment=prod` can also use LoadBalancer IPs in `10.0.171.0/24`.
* ExternalName hostnames must be `internal.git.com` or match `.*\\.example\\.com`.
* Explicit node ports must be in `30000-30100` or equal to `30500`.
* Node port `30090` is denied even though it is inside the broader allowed range.
* ExternalName hostnames matching `audit\\..*` emit audit events and warnings.
* Audit matches do not allow values that fail the allow-list.
