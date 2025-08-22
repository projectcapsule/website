---
title: Gangplank
description: Capsule Integration with Gangplank
logo: https://avatars.githubusercontent.com/u/29403644?s=280&v=4
type: single
display: true
integration: true
---

[Gangplank](https://github.com/sighupio/gangplank) is a web application that allows users to authenticate with an OIDC provider and configure their kubectl configuration file with the [OpenID Connect Tokens](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens). Gangplank is based on [Gangway](https://github.com/vmware-archive/gangway), which is no longer maintained.

## Prerequisites

1. You will need a running [Capsule Proxy](/docs/proxy/) instance.
2. For Authentication you will need a Confidential OIDC client configured in your OIDC provider, such as [Keycloak](https://www.keycloak.org/), [Dex](https://dexidp.io/), or [Google Cloud Identity](https://cloud.google.com/identity/docs/openid-connect-protocol). By default the Kubernetes API only validates tokens against a Public OIDC client, so you will need to configure your OIDC provider to allow the Gangplank client to issue tokens. You must make use of the Kubernetes Authentication Configuration, which allows to define multiple audiences (clients). This way we can issue tokens for a gangplank client, which is Confidential, and a kubernetes client, which is Public. The Kubernetes API will validate the tokens against both clients. The Config might look like this:

```yaml
apiVersion: apiserver.config.k8s.io/v1beta1
kind: AuthenticationConfiguration
jwt:
- issuer:
    url: https://keycloak/realms/realm-name
    audiences:
    - kubernetes
    - gangplank
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

To install Gangplank, you can use the Helm chart provided in the [Gangplank repository](https://github.com/sighupio/gangplank/blob/main/deployments/helm/values.yaml) or use your own custom values file. The following Environment Variables are required:

* `GANGPLANK_CONFIG_AUTHORIZE_URL`: `https://keycloak/realms/realm-name/protocol/openid-connect/auth`
* `GANGPLANK_CONFIG_TOKEN_URL`: `https://keycloak/realms/realm-name/protocol/openid-connect/token`
* `GANGPLANK_CONFIG_REDIRECT_URL`: `https://gangplank.example.com/callback`
* `GANGPLANK_CONFIG_CLIENT_ID`: `gangplank`
* `GANGPLANK_CONFIG_CLIENT_SECRET`: `<SECRET>`
* `GANGPLANK_CONFIG_USERNAME_CLAIM`: The JWT claim to use as the username. (we use `email` in the authentication config above, so this should also be `email`)
* `GANGPLANK_CONFIG_APISERVER_URL`: The URL **Capsule Proxy Ingress**. Since the users probably want to access the Kubernetes API from outside the cluster, you should use the Capsule Proxy Ingress URL here.

When using the Helm chart, you can set these values in the `values.yaml` file:

```yaml
config:
   clusterName: "tenant-cluster"
   apiServerURL: "https://capsule-proxy.company.com:443"
   scopes: ["openid", "profile", "email", "groups", "offline_access"]
   redirectURL: "https://gangplank.company.com/callback"
   usernameClaim: "email"
   clientID: "gangplank"
   authorizeURL: "https://keycloak/realms/realm-name/protocol/openid-connect/auth"
   tokenURL: "https://keycloak/realms/realm-name/protocol/openid-connect/token"

# Mount The Client Secret as Environment Variables (GANGPLANK_CONFIG_CLIENT_SECRET)
envFrom:
- secretRef:
     name: gangplank-secrets
```

Now the only thing left to do is to change the CA certificate which is provided. By default the CA certificate is set to the Kubernetes API server CA certificate, which is not valid for the Capsule Proxy Ingress. For this we can simply override the CA certificate in the Helm chart. You can do this by creating a Kubernetes Secret with the CA certificate and mounting it as a volume in the Gangplank deployment.

```yaml
volumeMounts:
  - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
    name: token-ca
volumes:
  - name: token-ca
    projected:
      sources:
      - serviceAccountToken:
          path: token
      - secret:
          name: proxy-ingress-tls
          items:
          - key: tls.crt
            path: ca.crt
```

**Note**: In this example we used the `tls.crt` key of the `proxy-ingress-tls` secret. This is a classic [Cert-Manager](https://cert-manager.io/) TLS secret, which contains only the Certificate and Key for the Capsule Proxy Ingress. However the Certificate contains the CA certificate as well (Certificate Chain), so we can use it to verify the Capsule Proxy Ingress. If you use a different secret, make sure to adjust the key accordingly.

If that's not possible you can also set the CA certificate as an environment variable:

```yaml
config:
  clusterCAPath: "/capsule-proxy/ca.crt"
volumeMounts:
  - mountPath: /capsule-proxy/
    name: token-ca
volumes:
  - name: token-ca
    projected:
      sources:
      - secret:
          name: proxy-ingress-tls
          items:
          - key: tls.crt
            path: ca.crt











