---
title: Configuration
weight: 2
description: >
  Understand the Capsule configuration options and how to use them.
---

The configuration for the capsule controller is done via its dedicated configuration Custom Resource. You can explain the configuration options and how to use them:

## CapsuleConfiguration

The configuration for Capsule is done via its dedicated configuration Custom Resource. You can explain the configuration options and how to use them:

```shell
kubectl explain capsuleConfiguration.spec
```

### `administrators`

These entities are automatically owners for all existing tenants. Meaning they can add namespaces to any tenant. However they must be specific by using the capsule label for interacting with namespaces. Because if that label is not defined, it's assumed that namespace interaction was not targeted towards a tenant and will therefore be ignored by capsule. May also be handy in GitOps scenarios where certain service accounts need to be able to manage namespaces for all tenants.

[Read More](/docs/operating/concepts/architecture/#capsule-administrators)

```yaml
manager:
  options:
    administrators:
      - kind: User
        name: admin-user
```

### `users`

These entities are automatically owners for all existing tenants. Meaning they can add namespaces to any tenant. However they must be specific by using the capsule label for interacting with namespaces. Because if that label is not defined, it's assumed that namespace interaction was not targeted towards a tenant and will therefore be ignored by capsule. May also be handy in GitOps scenarios where certain service accounts need to be able to manage namespaces for all tenants.

[Read More](/docs/operating/concepts/architecture/#capsule-users)

```yaml
manager:
  options:
    users:
      - kind: User
        name: owner-user
      - kind: Group
        name: projectcapsule.dev
```

### `ignoreUserWithGroups`
Define groups which when found in the request of a user will be ignored by the Capsule. This might be useful if you have one group where all the users are in, but you want to separate administrators from normal users with additional groups.

```yaml
manager:
  options:
    ignoreUserWithGroups:
      - company:org:administrators
```


### `enableTLSReconciler`
Toggles the TLS reconciler, the controller that is able to generate CA and certificates for the webhooks when not using an already provided CA and certificate, or when these are managed externally with Vault, or cert-manager.

```yaml
tls:
  enableController: true
```

### `forceTenantPrefix`
Enforces the Tenant owner, during Namespace creation, to name it using the selected Tenant name as prefix, separated by a dash. This is useful to avoid Namespace name collision in a public CaaS environment.

```yaml
manager:
  options:
    forceTenantPrefix: true
```

### `nodeMetadata`
Allows to set the forbidden metadata for the worker nodes that could be patched by a Tenant. This applies only if the Tenant has an active NodeSelector, and the Owner have right to patch their nodes.

```yaml
manager:
  options:
    nodeMetadata:
      forbiddenLabels:
        denied:
          - "node-role.kubernetes.io/*"
        deniedRegex: ""
      forbiddenAnnotations:
        denied:
          - "node.alpha.kubernetes.io/*"
        deniedRegex: ""
```

[Read More](/docs/tenants/enforcement/#nodes)


### `overrides`

Allows to set different name rather than the canonical one for the Capsule configuration objects, such as webhook secret or configurations.

### `protectedNamespaceRegex`
Disallow creation of namespaces, whose name matches this regexp

```yaml
manager:
  options:
    protectedNamespaceRegex: "^(kube|default|capsule|admin|system|com|org|local|localhost|io)$"
```

### `allowServiceAccountPromotion`

ServiceAccounts within tenant namespaces can be promoted to owners of the given tenant this can be achieved by labeling the serviceaccount and then they are considered owners. This can only be done by other owners of the tenant. However ServiceAccounts which have been promoted to owner can not promote further serviceAccounts.

[Read More](/docs/tenants/permissions/#serviceaccount-promotion)

```yaml
manager:
  options:
    allowServiceAccountPromotion: true
```

### `cacheInvalidation`

The reconcile periode caches are invalidated. Invalidation is already attempted when resources change, however in certain scenarios it might be necessary to do out of order cache invalidations to ensure proper garbage collection of resources.

```yaml
manager:
  options:
    cacheInvalidation: 0h30m0s
```

### `namespaceCleanup`

Configures the forced cleanup Capsule runs on a terminating `Namespace` of a `Tenant` so it does not stay stuck in `Terminating`. Once the `Namespace` has been terminating for the grace period and no Pods are left, Capsule deletes the remaining objects and removes their finalizers. With `namespaceCleanup` you decide how long the controllers owning those objects get to finish, and which finalizers Capsule never removes.

[Read More](/docs/tenants/namespaces/#termination)

Many finalizers release state outside the `Namespace`: cloud load balancers, storage volumes, network allocations, KubeVirt virtual machines, Kamaji control planes, or bare-metal hosts managed by a Cluster API infrastructure provider. When Capsule removes such a finalizer before its controller is done, that state leaks. For example, a Cluster API provider still powering off and wiping a bare-metal host loses track of it: the server stays powered on and claimed by a machine that no longer exists, until someone releases it by hand.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: CapsuleConfiguration
metadata:
  name: default
spec:
  namespaceCleanup:
    # Time left to the controllers owning the remaining objects,
    # measured from the Namespace deletionTimestamp.
    gracePeriod: 15m
    # Finalizers the cleanup never removes, on any resource.
    retainedFinalizers:
      - cluster.cluster.x-k8s.io
      - machine.cluster.x-k8s.io
```

| Field | Default | Description |
| :---- | :------ | :---------- |
| `gracePeriod` | `10s` | How long a terminating `Namespace` is left to the controllers owning its objects, measured from its `deletionTimestamp`. Once it elapses and no Pods are left, the cleanup starts. `0s` starts it as soon as no Pods are left. Negative values are rejected. |
| `retainedFinalizers` | none | Finalizers the cleanup never removes, on any resource, so their controllers can complete however long they take. At most 64 entries, without duplicates. |

Both fields are optional. Without `namespaceCleanup`, the cleanup starts 10 seconds after the `Namespace` deletion and removes every finalizer except Capsule's own on Capsule's resources.

Use them together:

* `gracePeriod` covers controllers that finish within a known time.
* `retainedFinalizers` covers controllers that must never be bypassed, whatever it takes. A `Namespace` holding a retained finalizer stays `Terminating` until its controller removes it.

Capsule's own finalizers (`controller.projectcapsule.dev/finalize` and `capsule.clastix.io/resources`) are always retained on Capsule's resources: you don't need to list them.

To find the finalizers held by the objects of a `Namespace`, inspect them while they are terminating, for example:

```shell
kubectl get clusters.cluster.x-k8s.io -n solar-production -o custom-columns=NAME:.metadata.name,FINALIZERS:.metadata.finalizers
```

Changes apply without restarting the controller, also to `Namespaces` already terminating:

* A `Namespace` within its grace period is rechecked at least once a minute, so a shortened `gracePeriod` applies within a minute.
* The cleanup runs every 5 seconds while objects are left, so a finalizer removed from `retainedFinalizers` is removed on the next pass.

{{% alert title="Warning" color="warning" %}}
Both settings trade safety for deletion speed:

* A `Tenant` is deleted only once its `Namespaces` are gone, so a longer `gracePeriod` also delays the `Tenant` deletion.
* Tenant owners can add a listed finalizer to their own objects and hold their `Namespace`, and the `Tenant`, in deletion until the finalizer is removed. List only finalizers whose controllers you trust to remove them.
{{% /alert %}}

The Helm chart does not expose `namespaceCleanup` yet. Set it on the `CapsuleConfiguration` directly; the chart does not render these fields, so a Helm upgrade keeps them:

```shell
kubectl patch capsuleconfiguration default --type merge \
  -p '{"spec":{"namespaceCleanup":{"gracePeriod":"15m","retainedFinalizers":["cluster.cluster.x-k8s.io","machine.cluster.x-k8s.io"]}}}'
```

### `rbac`

Define configurations for the RBAC which is being managed and applied by Capsule.

```yaml
manager:
  options:
    rbac:
      # -- The ClusterRoles applied for Administrators
      administrationClusterRoles:
        - capsule-namespace-deleter

      # -- The ClusterRoles applied for ServiceAccounts which had owner Promotion
      promotionClusterRoles:
        - capsule-namespace-provisioner
        - capsule-namespace-deleter

      # -- Name for the ClusterRole required to grant Namespace Deletion permissions.
      deleter: capsule-namespace-deleter

      # -- Name for the ClusterRole required to grant Namespace Provision permissions.
      provisioner: capsule-namespace-provisioner
```

### `impersonation`

Replications impersonate a ServiceAccount, falling back to the controller ServiceAccount when none is resolved. `tenantDefaultServiceAccount` is set to `default` for `TenantResource`; `GlobalTenantResource` has no default and requires both `globalDefaultServiceAccount` and `globalDefaultServiceAccountNamespace`. Within this configuration you can define properties such as the endpoint of the kube-apiserver and if service account promotion should be allowed for this client. By default the `https://kubernetes.default.svc` endpoint is used.

```yaml
manager:
  options:
    impersonation:
      # Kubernetes API Endpoint to use for the operations
      endpoint: "https://capsule-proxy.capsule-system.svc:8081"

      # Toggles if TLS verification for the endpoint is performed or not
      skipTlsVerify: false

      # Key in the secret that holds the CA certificate (e.g., "ca.crt")
      caSecretKey: "ca.crt"

      # Name of the secret containing the CA certificate
      caSecretName: "capsule-proxy-tls"

      # Namespace where the CA certificate secret is located
      caSecretNamespace: "capsule-system"

      # Default ServiceAccount for global resources (GlobalTenantResource) [Cluster Scope]
      # When defined, users are required to use this ServiceAccount anywhere in the cluster
      # unless they explicitly provide their own. Once this is set, Capsule will add this ServiceAccount
      # for all GlobalTenantResources, if they don't already have a ServiceAccount defined.
      globalDefaultServiceAccount: "capsule-global-sa"

      # Namespace of the for the ServiceAccount provided by the globalDefaultServiceAccount property
      globalDefaultServiceAccountNamespace: "tenant-system"

      # Default ServiceAccount for tenant resources (TenantResource) [Namespaced Scope]
      # Applied to every TenantResource which doesn't define its own, in that resource's
      # own Namespace.
      tenantDefaultServiceAccount: "default"
```

### `admission`

Configuration for the dynamic admission webhooks used by Capsule for mutating and validating requests. The settings are used from the static webhook configurations created during installation of Capsule and abstracted by the helm chart

```yaml
manager:
  options:
    admission:
      mutating:
        client:
          caBundle: cert
          url: https://172.24.52.212:9443
        name: capsule-dynamic
      validating:
        client:
          caBundle: cert
          url: https://172.24.52.212:9443
        name: capsule-dynamic
```

## Controller Options

Depending on the version of the Capsule Controller, the configuration options may vary. You can view the options for the latest version of the Capsule Controller or by executing the controller locally:

```bash
$ go run ./cmd/controller/ --zap-log-level 7 -h
      --cache-sync-timeout duration       The timeout used when waiting for controller cache synchronization. If unset or 0, the controller-runtime default is used.
      --client-connection-burst int32     Burst to use for interacting with kubernetes apiserver. (default 30)
      --client-connection-qps float32     QPS to use for interacting with kubernetes apiserver. (default 20)
      --configuration-name string         The CapsuleConfiguration resource name to use (default "default")
      --enable-http2                      If set, HTTP/2 will be enabled for the metrics and webhook servers
      --enable-leader-election            Enable leader election for controller manager. Enabling this will ensure there is only one active controller manager.
      --enable-pprof                      Enables Pprof endpoint for profiling (not recommend in production)
      --metrics-addr string               The address the metric endpoint binds to. (default ":8080")
      --metrics-cert-key string           The name of the metrics server key file. (default "tls.key")
      --metrics-cert-name string          The name of the metrics server certificate file. (default "tls.crt")
      --metrics-cert-path string          The directory that contains the metrics server certificate.
      --metrics-secure                    If set, the metrics endpoint is served securely via HTTPS. Use --metrics-secure=false to use HTTP instead.
      --version                           Print the Capsule version and exit
      --webhook-cert-key string           The name of the webhook key file. (default "tls.key")
      --webhook-cert-name string          The name of the webhook certificate file. (default "tls.crt")
      --webhook-cert-path string          The directory that contains the webhook certificate. (default "/tmp/k8s-webhook-server/serving-certs")
      --webhook-port int                  The port the webhook server binds to. (default 9443)
      --workers int                       MaxConcurrentReconciles is the maximum number of concurrent Reconciles which can be run. (default 1)
      --zap-devel                         Development Mode defaults(encoder=consoleEncoder,logLevel=Debug,stackTraceLevel=Warn). Production Mode defaults(encoder=jsonEncoder,logLevel=Info,stackTraceLevel=Error)
      --zap-encoder encoder               Zap log encoding (one of 'json' or 'console')
      --zap-log-level level               Zap Level to configure the verbosity of logging. Can be one of 'debug', 'info', 'error', 'panic'or any integer value > 0 which corresponds to custom debug levels of increasing verbosity
      --zap-stacktrace-level level        Zap Level at and above which stacktraces are captured (one of 'info', 'error', 'panic').
      --zap-time-encoding time-encoding   Zap time encoding (one of 'epoch', 'millis', 'nano', 'iso8601', 'rfc3339' or 'rfc3339nano'). Defaults to 'epoch'.
```

Define additional options in the `values.yaml` when installing via Helm:

```yaml
manager:
  extraArgs:
  - "--enable-leader-election=true"
```
