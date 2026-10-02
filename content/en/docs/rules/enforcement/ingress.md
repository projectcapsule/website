---
title: Ingress
weight: 4
description: >
  Ingress enforcement
---

Ingress enforcement allows administrators to allow, deny, or audit hostnames on
Kubernetes Ingresses, OpenShift Routes, and Gateway API resources in Tenant
namespaces.

Configure ingress rules under `spec.rules[].enforce.ingress`. Use
[Types](#types) to select the resources to check and [Hostnames](#hostnames) to
define the matching policy. The [Reference](#reference) combines these settings
in a complete Tenant.

See [rule order and scope](/docs/rules/#order-and-scope) for namespace selection
and precedence, and [Conditions](/docs/rules/#enforcement-conditions) for
conditional ingress policies.

## Types

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

Ingress rules are evaluated during create and update admission. A rule only
participates when its `types` list contains the incoming resource kind. Other
resource types are unaffected. For example, `types: [Ingress, HTTPRoute]`
applies the hostname policy to those two kinds; it does not prohibit Gateways
or other omitted kinds. The `action` applies to the selected resources'
hostnames, not to the resource kinds themselves.

The table lists the API versions handled by Capsule. Gateway API and OpenShift
resources require their respective APIs to be installed in the cluster.

## Hostnames

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

Ingress hostname enforcement follows the same action and precedence model as
other namespace rules:

* `allow` creates an allow-list for hostnames of the selected resource types.
* `deny` denies matching hostnames.
* `audit` emits Kubernetes events for matching hostnames and missing hostname
  fields but does not allow or deny them.
* If multiple `allow` or `deny` rules match the same hostname, the last matching
  allow or deny rule wins.
* An audit match does not satisfy an allow-list.

### Allow selected hostnames

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

### Gateway API and OpenShift Route examples

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

### Deny hostnames and add exceptions

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

### Negated matches

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

### Audit hostname usage

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

### Missing hostnames

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

This complete Tenant allows a hostname family, denies a reserved hostname,
audits preview hostnames, and grants a namespace-specific exception. Replace
`solar-owner` with your owner identity. It covers every resource kind listed
under [Types](#types), including Gateway API and OpenShift resources when those
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
