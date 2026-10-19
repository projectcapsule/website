---
title: Envoy Gateway
description: Capsule Integration with Envoy (Gateway API)
logo: https://github.com/cncf/artwork/raw/main/projects/envoy/envoy-gateway/icon/color/envoy-gateway-icon-color.svg
type: single
display: true
integration: true
---

With [Envoy Gateway](https://gateway.envoyproxy.io/), tenants can publish their
applications through the [Gateway API](https://gateway-api.sigs.k8s.io/) while the
platform manages the Gateway infrastructure. This guide covers protecting
platform Gateways, generating a managed Gateway per Tenant, and delegating
listeners with Capsule hostname rules. Before starting, review the upstream
documentation:

- [Gateway API roles and personas](https://gateway-api.sigs.k8s.io/docs/concepts/roles-and-personas/)
- [Envoy Gateway deployment modes and multi-tenancy](https://gateway.envoyproxy.io/docs/tasks/operations/deployment-mode/)
- [Gateway API ListenerSets](https://gateway-api.sigs.k8s.io/guides/user-guides/listener-set/)

The examples assume Envoy Gateway is installed and a `tenants` GatewayClass is
available. Examples using `allowedListeners` also require Gateway API CRDs and
an Envoy Gateway release supporting `gateway.networking.k8s.io/v1` ListenerSets.

## Secure Gateways

For Gateways that are reserved for platform services, exclude Tenant namespaces
from `allowedRoutes`. Capsule labels Tenant namespaces with
`capsule.clastix.io/tenant`, so a `DoesNotExist` selector allows routes only from
namespaces outside Capsule Tenants. Disable delegated listeners with
`allowedListeners.namespaces.from: None`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: platform-gateway
  namespace: platform-system
spec:
  gatewayClassName: tenants
  allowedListeners:
    namespaces:
      from: None
  listeners:
    - name: http
      port: 80
      protocol: HTTP
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchExpressions:
              - key: capsule.clastix.io/tenant
                operator: DoesNotExist
```

Keep these Gateways and their infrastructure in platform-owned namespaces that
Tenant owners cannot modify. For Gateways intended for a Tenant, select that
Tenant's namespace label instead, as shown below. Capsule
[ingress rules](/docs/rules/enforcement/network/#ingress) then restrict the
hostnames used by resources inside those namespaces.

## Managed Gateways

One approach is to generate a dedicated Gateway for each Tenant. The platform
creates a `tenant-<tenant-name>-system` namespace outside the Tenant, where it
manages the `Gateway`, `EnvoyProxy`, and TLS certificates. Tenant owners manage
HTTPRoutes in their own namespaces:

![Platform-managed Envoy Gateway per Tenant](/images/ecosystem/envoy-gateway.drawio.png)

### Gateway generation

The following [GlobalTenantResource](/docs/replications/global/) generates the
managed Gateway and `EnvoyProxy`. The `EnvoyProxy` configures the Envoy instances;
the Gateway defines listeners and their allowed routes. Create the platform
namespaces and the `tenant-critical` PriorityClass before using this example.

The resource collects HTTPRoutes labeled
`projectcapsule.dev/tenant: <tenant-name>` and generates an HTTPS listener for
each hostname. [Tenant data](/docs/operating/concepts/templating/#data) can supply
bandwidth limits and a load balancer address. The Gateway annotations reference
the namespaced Issuer configured under [Certificate management](#certificate-management).

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: managed-envoy-gateway
spec:
  scope: Tenant
  resyncPeriod: 30s
  resources:
    - context:
        resources:
          - apiVersion: gateway.networking.k8s.io/v1
            kind: HTTPRoute
            index: https
            selector:
              matchLabels:
                projectcapsule.dev/tenant: "{{tenant.name}}"
      generators:
        - missingKey: zero
          template: |
            {{- $ingressBandwidth := dig "spec" "data" "networking" "ingress" "bandwidth" "" $.tenant }}
            {{- $egressBandwidth := dig "spec" "data" "networking" "egress" "bandwidth" "" $.tenant }}
            {{- $loadBalancerIP := dig "spec" "data" "networking" "ingress" "loadbalancer" "" $.tenant }}
            ---
            apiVersion: gateway.envoyproxy.io/v1alpha1
            kind: EnvoyProxy
            metadata:
              name: tenant-{{ $.tenant.metadata.name }}-gateway
              namespace: tenant-{{ $.tenant.metadata.name }}-system
            spec:
              logging:
                level:
                  default: info
              provider:
                type: Kubernetes
                kubernetes:
                  envoyDeployment:
                    replicas: 2
                    pod:
                      priorityClassName: tenant-critical
                      {{- if or $ingressBandwidth $egressBandwidth }}
                      annotations:
                        {{- with $ingressBandwidth }}
                        kubernetes.io/ingress-bandwidth: {{ . }}
                        {{- end }}
                        {{- with $egressBandwidth }}
                        kubernetes.io/egress-bandwidth: {{ . }}
                        {{- end }}
                      {{- end }}
                  {{- with $loadBalancerIP }}
                  envoyService:
                    loadBalancerIP: {{ . }}
                  {{- end }}

        - missingKey: zero
          template: |
            ---
            apiVersion: gateway.networking.k8s.io/v1
            kind: Gateway
            metadata:
              name: tenant-{{ $.tenant.metadata.name }}-gateway
              namespace: tenant-{{ $.tenant.metadata.name }}-system
              annotations:
                cert-manager.io/issuer: tenant-{{ $.tenant.metadata.name }}-acme-http
                cert-manager.io/private-key-size: "4096"
                cert-manager.io/private-key-algorithm: RSA
            spec:
              gatewayClassName: tenants
              infrastructure:
                parametersRef:
                  group: gateway.envoyproxy.io
                  kind: EnvoyProxy
                  name: tenant-{{ $.tenant.metadata.name }}-gateway
              listeners:
                - name: http-challenge
                  port: 80
                  protocol: HTTP
                  allowedRoutes:
                    namespaces:
                      from: Same
                {{- range $_, $http := $.https }}
                  {{- range $i, $hostname := $http.spec.hostnames }}
                - name: {{ $http.metadata.namespace }}-{{ $http.metadata.name }}-{{ $i }}
                  port: 443
                  protocol: HTTPS
                  hostname: {{ $hostname }}
                  tls:
                    mode: Terminate
                    certificateRefs:
                      - group: ''
                        kind: Secret
                        name: {{ $http.metadata.namespace }}-{{ $http.metadata.name }}-{{ $i }}-tls
                  allowedRoutes:
                    namespaces:
                      from: Selector
                      selector:
                        matchLabels:
                          kubernetes.io/metadata.name: "{{ $http.metadata.namespace }}"
                  {{- end }}
                {{- end }}
```

### Certificate management

To manage certificates with [cert-manager](https://cert-manager.io/docs/), enable
its Gateway API support and generate an `Issuer` in each platform namespace.
This Issuer uses [ACME HTTP-01 challenges](https://cert-manager.io/docs/configuration/acme/http01/)
through the managed Gateway's `http-challenge` listener, which accepts solver
routes from the same platform namespace. The
[Gateway annotations](https://cert-manager.io/docs/usage/gateway/) above let
cert-manager create the certificates for its generated HTTPS listeners:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-acme-issuer
spec:
  scope: Tenant
  resources:
    - rawItems:
        - apiVersion: cert-manager.io/v1
          kind: Issuer
          metadata:
            name: "tenant-{{tenant.name}}-acme-http"
            namespace: "tenant-{{tenant.name}}-system"
          spec:
            acme:
              email: platform@email.com
              server: https://acme-staging-v02.api.letsencrypt.org/directory
              privateKeySecretRef:
                name: cert-letsencrypt-staging
              solvers:
                - http01:
                    gatewayHTTPRoute:
                      parentRefs:
                        - group: gateway.networking.k8s.io
                          kind: Gateway
                          name: "tenant-{{tenant.name}}-gateway"
                          namespace: "tenant-{{tenant.name}}-system"
                          sectionName: http-challenge
```

## Tenant ListenerSets

Another approach is to let tenants define listeners and certificates while the
platform manages the Gateway and its Envoy infrastructure. The Gateway allows
ListenerSets from the Tenant's namespaces;
a Capsule ingress rule restricts their hostnames to subdomains of
`solar.example.com`.

Reuse the managed `EnvoyProxy` and `tenants` GatewayClass from
[Managed Gateways](#managed-gateways), and replace the generated Gateway
configuration with the one below. If using a `GlobalTenantResource`, update its
Gateway generator and remove the HTTPRoute context lookup and the loop that
generates HTTPS listeners. Tenants now provide those listeners themselves.

### Tenant hostname rule

The platform administrator configures the `solar` Tenant with an allow rule for
both ListenerSets and HTTPRoutes:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - kind: User
      name: alice
  rules:
    - enforce:
        action: allow
        ingress:
          types:
            - ListenerSet
            - HTTPRoute
          hostnames:
            - exp: '^.+\.solar\.example\.com$'
```

The rule applies to every namespace belonging to `solar`. Capsule checks each
listener's `hostname` and every entry in an HTTPRoute's `spec.hostnames` during
creation and updates. The anchored expression allows hostnames at any depth
below `solar.example.com`, including wildcard hostnames within that domain.
It excludes the parent hostname `solar.example.com` itself. Targeting both
resource types ensures that the same policy also applies to routes attached
directly to the Gateway.

| Hostname | Rule result |
| --- | --- |
| `web.solar.example.com` | Allowed |
| `api.prod.solar.example.com` | Allowed |
| `*.solar.example.com` | Allowed |
| `solar.example.com` | Denied |
| `web.lunar.example.com` | Denied |
| `web.solar.example.com.evil.com` | Denied |

### Allow tenant ListenerSets on the managed Gateway

The platform owns this Gateway in `tenant-solar-system`, outside the Tenant.
`allowedListeners` selects namespaces by Capsule's tenant label, allowing
ListenerSets from `solar` namespaces to attach without listing their hostnames
on the Gateway:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: tenant-solar-gateway
  namespace: tenant-solar-system
spec:
  gatewayClassName: tenants
  infrastructure:
    parametersRef:
      group: gateway.envoyproxy.io
      kind: EnvoyProxy
      name: tenant-solar-gateway
  allowedListeners:
    namespaces:
      from: Selector
      selector:
        matchLabels:
          capsule.clastix.io/tenant: solar
  listeners:
    - name: http-challenge
      port: 80
      protocol: HTTP
      allowedRoutes:
        kinds:
          - group: gateway.networking.k8s.io
            kind: HTTPRoute
        namespaces:
          from: Selector
          selector:
            matchLabels:
              capsule.clastix.io/tenant: solar
```

`allowedListeners` controls which namespaces can attach ListenerSets;
`allowedRoutes` controls which routes can attach to an individual listener.
The Capsule rule supplies the hostname restriction in the tenant namespaces.
The platform-owned Gateway is outside that rule's scope, so its HTTP challenge
listener can omit `hostname`.

### Tenant listener and route

Assume `solar-production` belongs to `solar`, contains a `solar-web` Service on
port `8080`, and has a TLS Secret named `solar-web-tls` with a certificate for
`web.solar.example.com`. Alice creates an HTTPS listener in that namespace:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: ListenerSet
metadata:
  name: solar-web
  namespace: solar-production
spec:
  parentRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: tenant-solar-gateway
    namespace: tenant-solar-system
  listeners:
    - name: https
      hostname: web.solar.example.com
      port: 443
      protocol: HTTPS
      tls:
        mode: Terminate
        certificateRefs:
          - group: ""
            kind: Secret
            name: solar-web-tls
      allowedRoutes:
        kinds:
          - group: gateway.networking.k8s.io
            kind: HTTPRoute
        namespaces:
          from: Same
```

The Secret is in the ListenerSet's namespace. The HTTPRoute attaches to that
ListenerSet, selecting its `https` listener:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: solar-web
  namespace: solar-production
spec:
  parentRefs:
    - group: gateway.networking.k8s.io
      kind: ListenerSet
      name: solar-web
      sectionName: https
  hostnames:
    - web.solar.example.com
  rules:
    - backendRefs:
        - name: solar-web
          port: 8080
```

Capsule admits both resources because all their hostnames match the Tenant rule.
Changing the ListenerSet hostname or any HTTPRoute hostname to `web.lunar.example.com`
is denied at admission, even though the Gateway allows ListenerSets from that
namespace. Adding a disallowed hostname alongside `web.solar.example.com` also
denies the entire request. Omitting a listener hostname or the route's
`spec.hostnames` is denied because an allow rule targets these resource types.
