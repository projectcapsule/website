---
title: Envoy-Gateway
description: Capsule Integration with Envoy (Gateway API)
logo: https://github.com/cncf/artwork/raw/main/projects/envoy/envoy-gateway/icon/color/envoy-gateway-icon-color.svg
type: single
display: true
integration: true
---

There's different ways to use [Gateway API](https://gateway-api.sigs.k8s.io/) in a multi-tenant setup. This guide suggested a strong isolated implementation using the [Envoy Gateway Project](https://gateway.envoyproxy.io/). The Architecture suggested looks something like this:


![Namespace Resource Actions](/images/ecosystem/envoy-gateway.drawio.png)

Each tenant will get it's own `-system` `Namespace`. However that namespace is not managed by the `Tenant` nor part of it. It's the namespace where the platform deploys managed services for each `Tenant`, which are out of bound for `TenantOwners`.

## Example

Implementation of the above architecture looks something like this.

### Managed Gateway

With this [GlobalTenantResource](/docs/replications/global/) we generate the managed gateway for each tenant. The `EnvoyProxy` is the custom resource used by the Envoy Gateway project to manage the lifecycle of the Envoy instances. The `Gateway` is the standard resource defined by the Gateway API, which references the `EnvoyProxy` as infrastructure and defines the listeners and allowed routes.

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
                cert-manager.io/cluster-issuer: managed-cluster-issuer
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
                      from: Selector
                      selector:
                        matchLabels:
                          capsule.clastix.io/tenant: "{{ $.tenant.metadata.name }}"
                {{- range $_, $http := $.https }}
                  {{- range $i, $hostname := $http.spec.hostnames }}
                - name: {{ $http.metadata.namespace }}-{{ $http.metadata.name }}-{{ $i }}
                  port: 443
                  protocol: HTTPS
                  hostname: {{ $hostname}}
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
### Certificate Management

If we additionally would like to do Certificate Management via [cert-manager](https://cert-manager.io/docs/) in combination with [ACME HTTP-01 challenges](https://cert-manager.io/docs/configuration/acme/http01/) we probably want to provide the users with a `ClusterIssuer` per `Tenant`:

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
          name: {{tenant.name}}-acme-http
          namespace: {{tenant.name}}-system
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
                        name: {{tenant.name}}-gateway
                        namespace: {{tenant.name}}-system
                        sectionName: http-challenge
```
