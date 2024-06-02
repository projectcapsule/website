---
title: Controller Options
weight: 20
description: >
  Understand the Capsule configuration options and how to use them.
---

The configuration for the capsule controller is done via it's dedicated configration Custom Resource. You can explain the configuration options and how to use them:



## CapsuleConfiguration

The configuration for Capsule is done via it's dedicated configration Custom Resource. You can explain the configuration options and how to use them:

```bash
kubectl explain capsuleConfiguration.spec
```

### enableTLSReconciler
Toggles the TLS reconciler, the controller that is able to generate CA and certificates for the webhooks when not using an already provided CA and certificate, or when these are managed externally with Vault, or cert-manager.

### forceTenantPrefix
Enforces the Tenant owner, during Namespace creation, to name it using the selected Tenant name as prefix, separated by a dash. This is useful to avoid Namespace name collision in a public CaaS environment.

### nodeMetadata
Allows to set the forbidden metadata for the worker nodes that could be patched by a Tenant. This applies only if the Tenant has an active NodeSelector, and the Owner have right to patch their nodes.

### overrides
Allows to set different name rather than the canonical one for the Capsule configuration objects, such as webhook secret or configurations.

### protectedNamespaceRegex
Disallow creation of namespaces, whose name matches this regexp

### userGroups
Names of the groups for Capsule users. Users must have this group to be considered for the Capsule tenancy. If a user does not have any group mentioned here, they are not recognized as a Capsule user.


## Controller Options

Depending on the version of the Capsule Controller, the configuration options may vary. You can view the options for the latest version of the Capsule Controller [here]() or by executing the controller locally:

```bash
$ docker run ghcr.io/projectcapsule/capsule:v0.6.0-rc0 -h
2024/02/25 13:21:21 maxprocs: Leaving GOMAXPROCS=4: CPU quota undefined
Usage of /ko-app/capsule:
      --configuration-name string         The CapsuleConfiguration resource name to use (default "default")
      --enable-leader-election            Enable leader election for controller manager. Enabling this will ensure there is only one active controller manager.
      --metrics-addr string               The address the metric endpoint binds to. (default ":8080")
      --version                           Print the Capsule version and exit
      --webhook-port int                  The port the webhook server binds to. (default 9443)
      --zap-devel                         Development Mode defaults(encoder=consoleEncoder,logLevel=Debug,stackTraceLevel=Warn). Production Mode defaults(encoder=jsonEncoder,logLevel=Info,stackTraceLevel=Error)
      --zap-encoder encoder               Zap log encoding (one of 'json' or 'console')
      --zap-log-level level               Zap Level to configure the verbosity of logging. Can be one of 'debug', 'info', 'error', or any integer value > 0 which corresponds to custom debug levels of increasing verbosity
      --zap-stacktrace-level level        Zap Level at and above which stacktraces are captured (one of 'info', 'error', 'panic').
      --zap-time-encoding time-encoding   Zap time encoding (one of 'epoch', 'millis', 'nano', 'iso8601', 'rfc3339' or 'rfc3339nano'). Defaults to 'epoch'.
```

