---
title: Controller Options
description: >
  Configure the Capsule Proxy Controller
weight: 2
---

You can customize the Capsule Proxy with the following configurations.

## Controller Options

You can provide additional options via the helm chart:

```yaml
options:
  extraArgs:
    - --disable-caching=true
```

Options are also available as dedicated configuration values:

```yaml
# Controller Options
options:
  # -- Set the listening port of the capsule-proxy
  listeningPort: 9001
  # -- Set leader election to true if you are running n-replicas
  leaderElection: false
  # -- Set the log verbosity of the capsule-proxy with a value from 1 to 10
  logLevel: 4
  # -- Name of the CapsuleConfiguration custom resource used by Capsule, required to identify the user groups
  capsuleConfigurationName: default
  # -- Define which groups must be ignored while proxying requests
  ignoredUserGroups: []
  # -- Specify if capsule-proxy will use SSL
  oidcUsernameClaim: preferred_username
  # -- Specify if capsule-proxy will use SSL
  enableSSL: true
  # -- Set the directory, where SSL certificate and keyfile will be located
  SSLDirectory: /opt/capsule-proxy
  # -- Set the name of SSL certificate file
  SSLCertFileName: tls.crt
  # -- Set the name of SSL key file
  SSLKeyFileName: tls.key
  # -- Specify if capsule-proxy will generate self-signed SSL certificates
  generateCertificates: false
  # -- Specify additional subject alternative names for the self-signed SSL
  additionalSANs: []
  # -- Specify an override for the Secret containing the certificate for SSL. Default value is empty and referring to the generated certificate.
  certificateVolumeName: ""
  # -- Set the role bindings reflector resync period, a local cache to store mappings between users and their namespaces. [Use a lower value in case of flaky etcd server connections.](https://github.com/projectcapsule/capsule-proxy/issues/174)
  rolebindingsResyncPeriod: 10h
  # -- Disable the go-client caching to hit directly the Kubernetes API Server, it disables any local caching as the rolebinding reflector.
  disableCaching: false
  # -- Enable the rolebinding reflector, which allows to list the namespaces, where a rolebinding mentions a user.
  roleBindingReflector: false
  # -- Authentication types to be used for requests. Possible Auth Types: [BearerToken, TLSCertificate]
  authPreferredTypes: "BearerToken,TLSCertificate"
  # -- QPS to use for interacting with Kubernetes API Server.
  clientConnectionQPS: 20
  # -- Burst to use for interacting with kubernetes API Server.
  clientConnectionBurst: 30
  # -- Enable Pprof for profiling
  pprof: false
```

The following options are available for the Capsule Proxy Controller:

```shell
      --auth-preferred-types string           Authentication types to be used for requests. Possible Auth Types: [BearerToken, TLSCertificate]
                                              First match is used and can be specified multiple times as comma separated values or by using the flag multiple times. (default "[TLSCertificate,BearerToken]")
      --capsule-configuration-name string     Name of the CapsuleConfiguration used to retrieve the Capsule user groups names (default "default")
      --capsule-user-group strings            Names of the groups for capsule users (deprecated: use capsule-configuration-name)
      --client-connection-burst int32         Burst to use for interacting with kubernetes apiserver. (default 30)
      --client-connection-qps float32         QPS to use for interacting with kubernetes apiserver. (default 20)
      --disable-caching                       Disable the go-client caching to hit directly the Kubernetes API Server, it disables any local caching as the rolebinding reflector (default: false)
      --enable-leader-election                Enable leader election for controller manager. Enabling this will ensure there is only one active controller manager.
      --enable-pprof                          Enables Pprof endpoint for profiling (not recommend in production)
      --enable-reflector                      Enable rolebinding reflector. The reflector allows to list the namespaces, where a rolebinding mentions a user
      --enable-ssl                            Enable the bind on HTTPS for secure communication (default: true) (default true)
      --feature-gates mapStringBool           A set of key=value pairs that describe feature gates for alpha/experimental features. Options are:
                                              AllAlpha=true|false (ALPHA - default=false)
                                              AllBeta=true|false (BETA - default=false)
                                              ProxyAllNamespaced=true|false (ALPHA - default=false)
                                              ProxyClusterScoped=true|false (ALPHA - default=false)
                                              SkipImpersonationReview=true|false (ALPHA - default=false)
      --ignored-impersonation-group strings   Names of the groups which are not used for impersonation (considered after impersonation-group-regexp)
      --ignored-user-group strings            Names of the groups which requests must be ignored and proxy-passed to the upstream server
      --impersonation-group-regexp string     Regular expression to match the groups which are considered for impersonation
      --listening-port uint                   HTTP port the proxy listens to (default: 9001) (default 9001)
      --metrics-addr string                   The address the metric endpoint binds to. (default ":8080")
      --oidc-username-claim string            The OIDC field name used to identify the user (default: preferred_username) (default "preferred_username")
      --rolebindings-resync-period duration   Resync period for rolebindings reflector (default 10h0m0s)
      --ssl-cert-path string                  Path to the TLS certificate (default: /opt/capsule-proxy/tls.crt)
      --ssl-key-path string                   Path to the TLS certificate key (default: /opt/capsule-proxy/tls.key)
      --webhook-port int                      The port the webhook server binds to. (default 9443)
      --zap-devel                             Development Mode defaults(encoder=consoleEncoder,logLevel=Debug,stackTraceLevel=Warn). Production Mode defaults(encoder=jsonEncoder,logLevel=Info,stackTraceLevel=Error)
      --zap-encoder encoder                   Zap log encoding (one of 'json' or 'console')
      --zap-log-level level                   Zap Level to configure the verbosity of logging. Can be one of 'debug', 'info', 'error', 'panic'or any integer value > 0 which corresponds to custom debug levels of increasing verbosity
      --zap-stacktrace-level level            Zap Level at and above which stacktraces are captured (one of 'info', 'error', 'panic').
      --zap-time-encoding time-encoding       Zap time encoding (one of 'epoch', 'millis', 'nano', 'iso8601', 'rfc3339' or 'rfc3339nano'). Defaults to 'epoch'.
```

## Feature Gates

Feature Gates are a set of key/value pairs that can be used to enable or disable certain features of the Capsule Proxy. The following feature gates are available:

| **Feature Gate** | **Default Value** | **Description** |
| :--- | :--- | :--- |
| `SkipImpersonationReview` | `false` | `SkipImpersonationReview` allows to skip the impersonation review for all requests containing impersonation headers (user and groups). **DANGER:** Enabling this flag allows any user to impersonate as any user or group essentially bypassing any authorization. Only use this option in trusted environments where authorization/authentication is offloaded to external systems. |
| `ProxyClusterScoped` | `false` | `ProxyClusterScoped` allows to proxy all clusterScoped objects for all tenant users. These can be defined via [ProxySettings](./proxysettings) |
