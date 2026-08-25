---
title: Ingress
weight: 4
description: >
  Ingress enforcement
---

Ingress enforcement allows administrators to allow, deny, or audit hostnames on
Kubernetes Ingresses, OpenShift Routes, and Gateway API resources in Tenant
namespaces.

Ingress rules are configured under `spec.rules[].enforce.ingress`. Each rule
selects one or more resource `types` and defines hostname match expressions:

```yaml
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

| Field | Description |
|---|---|
| `types` | Resource kinds to which the rule applies. At least one type is required. |
| `hostnames` | One or more common match expressions using `exact`, `exp`, and optional `negate`. |

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
resource types are unaffected.

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

## Allow selected hostnames

The following rule allows one exact hostname and any single-label hostname
under `example.com` for Kubernetes Ingress and Gateway API HTTPRoute resources:

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

## Gateway API and OpenShift Route examples

A single rule can target several supported resource shapes:

```yaml
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

## Deny hostnames and add exceptions

Allow a hostname family, then deny a sensitive hostname with a later rule:

```yaml
rules:
  - enforce:
      action: allow
      ingress:
        types:
          - Ingress
          - HTTPRoute
        hostnames:
          - exp: "^[a-z0-9-]+\\.example\\.com$"

  - enforce:
      action: deny
      ingress:
        types:
          - Ingress
          - HTTPRoute
        hostnames:
          - exact:
              - admin.example.com
```

`api.example.com` is admitted, while `admin.example.com` is denied because the
later matching deny rule wins.

A still later namespace-specific rule can allow that hostname as an exception:

```yaml
  - namespaceSelector:
      matchLabels:
        ingress-admin: "true"
    enforce:
      action: allow
      ingress:
        types:
          - Ingress
          - HTTPRoute
        hostnames:
          - exact:
              - admin.example.com
```

Namespaces labeled `ingress-admin=true` can use `admin.example.com`; the earlier
deny rule still applies in other namespaces.

You can also use negation to deny every hostname outside a trusted suffix:

```yaml
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

## Audit hostname usage

Use `action: audit` to observe selected hostnames without blocking them:

```yaml
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

## Missing hostnames

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
