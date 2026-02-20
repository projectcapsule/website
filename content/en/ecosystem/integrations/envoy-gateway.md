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

## Gateway 









---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: itbs-tenant-{{ $.Values.name }}-gateway
  namespace: itbs-tenant-{{ $.Values.name }}-system
spec:
  logging:
    level:
      default: debug
  provider:
    type: Kubernetes
    kubernetes:
      envoyDeployment:
        replicas: 2
      {{- if $.Values.networking.gateway.loadbalancer }}
      envoyService:
        loadBalancerIP: {{ $.Values.networking.ingress.loadbalancer }}
      {{- end }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: itbs-tenant-{{ $.Values.name }}-gateway
  namespace: itbs-tenant-{{ $.Values.name }}-system
  {{- if $.Values.networking.gateway.issuer.enabled }}
  annotations:
    cert-manager.io/issuer: itbs-tenant-{{ $.Values.name }}-http
    cert-manager.io/private-key-size: "4096"
    cert-manager.io/private-key-algorithm: RSA
  {{- end }}
spec:
  gatewayClassName: {{$.Values.cluster.gateway.classes.platform}}
  infrastructure:
    parametersRef:
      group: gateway.envoyproxy.io
      kind: EnvoyProxy
      name: itbs-tenant-{{ $.Values.name }}-gateway
  listeners:
    - name: http-challenge
      port: 80
      protocol: HTTP
      hostname: "*.{{ $.Values.name }}.{{ $.Values.cluster.name }}.{{ $.Values.infrastructure.dns.zone }}"
      allowedRoutes:  # Only this tenant's capsule namespaces can attach routes to this listener
        namespaces:
          from: Selector
          selector:
            matchLabels:
              tenant.itbs.ch/tenant: "{{ $.Values.name }}"

    {{- if $.Values.metrics.enabled }}
    - name: https-alertmanager
      protocol: HTTPS
      port: 443
      hostname: "alertmanager.{{ $.Values.name }}.{{ .Values.cluster.name }}.{{ .Values.infrastructure.dns.zone }}"
      tls:
        mode: Terminate
        certificateRefs:
          - group: ''
            kind: Secret
            name: alertmanager-tls
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              tenant.itbs.ch/tenant-system: "{{ $.Values.name }}"
    - name: https-prometheus
      protocol: HTTPS
      port: 443
      hostname: "prometheus.{{ $.Values.name }}.{{ .Values.cluster.name }}.{{ .Values.infrastructure.dns.zone }}"
      tls:
        mode: Terminate
        certificateRefs:
          - group: ''
            kind: Secret
            name: prometheus-tls
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              tenant.itbs.ch/tenant-system: "{{ $.Values.name }}"
    {{- end }}
    {{- if $.Values.grafana.enabled }}
    - name: https-grafana
      protocol: HTTPS
      port: 443
      hostname: "grafana.{{ $.Values.name }}.{{ .Values.cluster.name }}.{{ .Values.infrastructure.dns.zone }}"
      tls:
        mode: Terminate
        certificateRefs:
          - group: ''
            kind: Secret
            name: grafana-tls
      allowedRoutes:
        namespaces:
          from: Selector
          selector:
            matchLabels:
              tenant.itbs.ch/tenant-system: "{{ $.Values.name }}"
    {{- end }}



## EnvoyProxy


## Certificate Management

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

