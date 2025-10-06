---
title: Controller Options
weight: 100
description: >
  Understand the Capsule configuration options and how to use them.
---

The configuration for the capsule controller is done via it's dedicated configration Custom Resource. You can explain the configuration options and how to use them:

## CapsuleConfiguration

The configuration for Capsule is done via it's dedicated configration Custom Resource. You can explain the configuration options and how to use them:

```shell
kubectl explain capsuleConfiguration.spec
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

### `userGroups`
Names of the groups for Capsule users. Users must have this group to be considered for the Capsule tenancy. If a user does not have any group mentioned here, they are not recognized as a Capsule user.

```yaml
manager:
  options:
    capsuleUserGroups:
      - system:serviceaccounts:tenants-gitops
      - company:org:users
```

### `userNames`
Names of the users for Capsule users. Users must have this name to be considered for the Capsule tenancy. If userGroups are set, the properties are ORed, meaning that a user can be recognized as a Capsule user if they have one of the groups or one of the names.

```yaml
manager:
  options:
    userNames:
      - system:serviceaccount:crossplane-system:crossplane-k8s-provider
```

### `ignoreUserWithGroups`
Define groups which when found in the request of a user will be ignored by the Capsule. This might be useful if you have one group where all the users are in, but you want to separate administrators from normal users with additional groups.

```yaml
manager:
  options:
    ignoreUserWithGroups:
      - company:org:administrators
```

### `allowServiceAccountPromotion`

ServiceAccounts within tenant namespaces can be promoted to owners of the given tenant this can be achieved by labeling the serviceaccount and then they are considered owners. This can only be done by other owners of the tenant. However ServiceAccounts which have been promoted to owner can not promote further serviceAccounts.

[Read More](/docs/tenants/permissions/#serviceaccount-promotion)

```yaml
manager:
  options:
    allowServiceAccountPromotion: true
```

## Controller Options

Depending on the version of the Capsule Controller, the configuration options may vary. You can view the options for the latest version of the Capsule Controller or by executing the controller locally:

```bash
$ go run ./cmd/. --zap-log-level 7 -h
2025/09/13 23:50:30 maxprocs: Leaving GOMAXPROCS=8: CPU quota undefined
Usage of /var/folders/ts/43yg7sk56ls3r3xjf66npgpm0000gn/T/go-build2624543463/b001/exe/cmd:
      --configuration-name string         The CapsuleConfiguration resource name to use (default "default")
      --enable-leader-election            Enable leader election for controller manager. Enabling this will ensure there is only one active controller manager.
      --metrics-addr string               The address the metric endpoint binds to. (default ":8080")
      --version                           Print the Capsule version and exit
      --webhook-port int                  The port the webhook server binds to. (default 9443)
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

