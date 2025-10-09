---
title: Headlamp
description: Capsule Integration with Headlamp
logo: https://raw.githubusercontent.com/cncf/artwork/refs/heads/main/projects/headlamp/icon/color/headlamp-icon-color.svg
type: single
display: true
integration: true
---

[Headlamp](https://headlamp.dev/) is an easy-to-use and extensible Kubernetes web UI.

Headlamp was created to blend the traditional feature set of other web UIs/dashboards (i.e., to list and view resources) with added functionality.

## Prerequisites

1. You will need a running [Capsule Proxy](/docs/proxy/) instance.
2. For Authentication you will need a Confidential OIDC client configured in your OIDC provider, such as [Keycloak](https://www.keycloak.org/), [Dex](https://dexidp.io/), or [Google Cloud Identity](https://cloud.google.com/identity/docs/openid-connect-protocol). By default the Kubernetes API only validates tokens against a Public OIDC client, so you will need to configure your OIDC provider to allow the Headlamp client to issue tokens. You must make use of the Kubernetes Authentication Configuration, which allows to define multiple audiences (clients). This way we can issue tokens for a **headlamp** client, which is Confidential (Client Secret), and a **kubernetes** client, which is Public. The Kubernetes API will validate the tokens against both clients. The Config might look like this:

```yaml
apiVersion: apiserver.config.k8s.io/v1beta1
kind: AuthenticationConfiguration
jwt:
- issuer:
    url: https://keycloak/realms/realm-name
    audiences:
    - kubernetes
    - headlamp
    audienceMatchPolicy: MatchAny # This one is important
  claimMappings:
    username:
      claim: 'email'
      prefix: ""
    groups:
      claim: 'groups'
      prefix: ""
```

[Read More](/docs/operating/authentication/#configuring-kubernetes-api-server)

## Integration

To install Headlamp, you can use the Helm chart provided in the [Headlamp repository](https://artifacthub.io/packages/helm/headlamp/headlamp). It's a bit special how Headlamp handles Certificate Authorities. We need to inject the capsule-proxy CA into the trust store for Headlamp. In the below example we are using the CA Bundle from alpine (because we also need to trust the CA of the OIDC Issuer, in this case it uses Let's Encrypt). See the issues [#3707](https://github.com/kubernetes-sigs/headlamp/issues/3707#issuecomment-3174280356) and [#127](https://github.com/kubernetes-sigs/headlamp/issues/127). Essentially Golang uses some environment variables to allow specifying cert files/dirs overriding the system defaults. By Default this is under `/etc/ssl/`. You can change this behavior by defining the environment variables `SSL_CERT_FILE` or/and `SSL_CERT_DIR`.

It's recommended to install headlamp in the `capsule-system` namespace. Otherwise you need to somehow replicate the internal ca secret to the namespace, where headlamp is deployed to. For this case [Cert-Manager Trust-Bundles](https://cert-manager.io/docs/trust/trust-manager/) might be useful.

With the following values we got it to work:

```yaml
config:
  inCluster: true
  extraArgs:
  - -insecure-ssl
env:
  - name: KUBERNETES_SERVICE_HOST
    value: "capsule-proxy.capsule-system.svc"
  - name: KUBERNETES_SERVICE_PORT
    value: "9001"
  - name: "OIDC_ISSUER_URL"
    value: "https://keycloak/realms/realm-name"
  - name: "OIDC_CLIENT_ID"
    value: "headlamp"
  - name: "OIDC_CLIENT_SECRET"
    value: "<SECRET>"
  - name: "OIDC_USE_ACCESS_TOKEN"
    value: "false"
  - name: "OIDC_SCOPES"
    value: "openid profile email groups offline_access"
volumeMounts:
  - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
    name: token-ca
  - name: ca-store
    mountPath: /etc/ssl/
volumes:
  - name: ca-store
    emptyDir: {}
  - name: capsule-proxy
    secret:
      secretName: capsule-proxy
  - name: token-ca
    projected:
      sources:
        - serviceAccountToken:
            path: token
        - secret:
            items:
              - key: ca
                path: ca.crt
            name: capsule-proxy
        - downwardAPI:
            items:
              - fieldRef:
                  apiVersion: v1
                  fieldPath: metadata.namespace
                path: namespace
initContainers:
- name: add-ca
  image: alpine:3
  command: ["/bin/sh","-c"]
  args:
  - |
    set -e
    cp -R /etc/ssl/* /work/
    cat /ca/ca.crt >> /work/certs/ca-certificates.crt
  volumeMounts:
  - name: ca-store
    mountPath: /work
  - name: capsule-proxy
    mountPath: /ca
  securityContext:
    capabilities:
      drop:
      - ALL
    readOnlyRootFilesystem: false
    allowPrivilegeEscalation: false
    privileged: false
    runAsUser: 65534
    runAsGroup: 65534
    fsGroup: 65534
    fsGroupChangePolicy: "Always"
podSecurityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
securityContext:
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: false
  allowPrivilegeEscalation: false
  privileged: false
  runAsUser: 100
  runAsGroup: 101
  fsGroup: 101
  fsGroupChangePolicy: "Always"
```

**Note**: The secret `capsule-proxy` refers to the secret which is being used by the capsule-proxy instance directly, not the self-signed-ca secret.

## Plugins

We are commitet to provide a set of plugins to enhance the user experience with Capsule and Headlamp. Any community contribution is welcome, so feel free to open a PR with your plugin.
