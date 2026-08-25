---
title: Workloads
weight: 2
description: >
  Workload enforcement
---

Enforcement for workloads mainly targets `Pods` and their associated resources.

Workload enforcement is configured under `spec.rules[].enforce.workloads`. Each rule can define an `action`, optional workload `targets`, and one or more workload matchers such as registry match expressions, scheduler match expressions, or QoS classes.



---
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  ...
  rules:
    - enforce:
        action: deny
        workloads:
          qosClasses:
            - BestEffort





## QoS Classes

QoS class enforcement allows administrators to allow, deny, or audit Pods based on their [computed Kubernetes QoS class](https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/).

QoS rules are configured under `enforce.workloads.qosClasses`.

Supported QoS classes are:

| QoS class | Description |
|---|---|
| `Guaranteed` | The Pod has CPU and memory requests and limits set so that requests equal limits. |
| `Burstable` | The Pod has at least one CPU or memory request or limit, but does not qualify as `Guaranteed`. |
| `BestEffort` | The Pod has no CPU or memory requests or limits. |

Capsule evaluates the QoS class of the incoming Pod during create and update admission. If Kubernetes has already populated `status.qosClass`, Capsule can use that value; otherwise it computes the QoS class from the Pod specification.

Deny `BestEffort` Pods:

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
        action: deny
        workloads:
          qosClasses:
            - BestEffort
```

With this rule, a Pod without CPU or memory requests and limits is denied:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: best-effort
spec:
  containers:
    - name: shell
      image: harbor/platform/debian:latest
      command: ["sleep", "infinity"]
```

Example rejection:

```bash
Error from server (Forbidden): error when creating "pod.yaml": admission webhook "pods.projectcapsule.dev" denied the request: QoS class "BestEffort" at status.qosClass is denied by namespace rule
```

Audit `Burstable` Pods:

```yaml
rules:
  - enforce:
      action: audit
      workloads:
        qosClasses:
          - Burstable
```

A matching Pod is admitted in this audit-only example, but Capsule emits an event and the API server response contains an admission warning. If a QoS allow-list is also configured and the Pod's QoS class is not allowed, the Pod is denied while the audit event is still emitted.

Allow `BestEffort` only for selected namespaces:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        qosClasses:
          - BestEffort

  - namespaceSelector:
      matchLabels:
        allow-best-effort: "true"
    enforce:
      action: allow
      workloads:
        qosClasses:
          - BestEffort
```

Because later matching allow or deny rules take precedence, namespaces labeled `allow-best-effort=true` can run `BestEffort` Pods, while other namespaces cannot.

## Scheduler Names

Scheduler enforcement allows administrators to allow, deny, or audit Pods based on `spec.schedulerName`.

Scheduler rules are configured under `enforce.workloads.schedulers`. Each scheduler matcher uses the common match expression structure with `exact`, `exp`, and optional `negate`.

Capsule evaluates `spec.schedulerName` during Pod create and update admission. If `spec.schedulerName` is empty or omitted, scheduler enforcement does not match it and does not normalize it to `default-scheduler`.

Allow only selected explicit schedulers:

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
        workloads:
          schedulers:
            - exact:
                - tenant-scheduler
                - batch-scheduler
```

A Pod using one of the listed schedulers is admitted:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: scheduled-by-tenant
spec:
  schedulerName: tenant-scheduler
  containers:
    - name: shell
      image: harbor/platform/debian:latest
      command: ["sleep", "infinity"]
```

A Pod using another explicit scheduler is denied:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: scheduled-by-other
spec:
  schedulerName: other-scheduler
  containers:
    - name: shell
      image: harbor/platform/debian:latest
      command: ["sleep", "infinity"]
```

Example rejection:

```bash
Error from server (Forbidden): error when creating "pod.yaml": admission webhook "pods.projectcapsule.dev" denied the request: scheduler "other-scheduler" at spec.schedulerName is not allowed by namespace rule
```

Use a regular expression to allow a scheduler family:

```yaml
rules:
  - enforce:
      action: allow
      workloads:
        schedulers:
          - exp: "tenant-[a-z0-9-]+"
```

Use `exact` and `exp` together to allow a fixed list plus a pattern:

```yaml
rules:
  - enforce:
      action: allow
      workloads:
        schedulers:
          - exact:
              - default-scheduler
              - batch-scheduler
            exp: "tenant-[a-z0-9-]+"
```

This matcher allows `default-scheduler`, `batch-scheduler`, and scheduler names matching `tenant-[a-z0-9-]+`.

Deny a known unsafe scheduler:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        schedulers:
          - exact:
              - unsafe-scheduler
```

Use `negate: true` to deny every explicit scheduler except a trusted set:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        schedulers:
          - exact:
              - default-scheduler
              - tenant-scheduler
            negate: true
```

Because `negate` applies to `exact`, this rule matches any explicit scheduler name except `default-scheduler` and `tenant-scheduler`.

Audit usage of a custom scheduler:

```yaml
rules:
  - enforce:
      action: audit
      workloads:
        schedulers:
          - exact:
              - custom-scheduler
```

A matching Pod is admitted in this audit-only example, but Capsule emits an audit event and returns an admission warning. If a scheduler allow-list is also configured and the scheduler name is not allowed, the Pod is denied while the audit event is still emitted.

## OCI Registries

Registry enforcement allows administrators to allow, deny, or audit Pod image references. Registry matchers are evaluated against the full OCI reference string, including registry, repository path, image name, tag, or digest.

Registry rules are configured under `enforce.workloads.registries`. The workload-level `targets` field under `enforce.workloads.targets` controls which Pod image references are validated.

Registry matchers use the common match expression structure:

```yaml
registries:
  - exact:
      - harbor/platform/debian:latest
      - harbor/platform/busybox:latest
  - exp: "harbor/platform/.*"
```

Use `exact` for a fixed list of complete references and `exp` for path or registry patterns. A single matcher may contain both fields:

```yaml
registries:
  - exact:
      - harbor/platform/debian:latest
    exp: "harbor/shared/.*"
```

This matcher succeeds for `harbor/platform/debian:latest` or any reference matching `harbor/shared/.*`.

The following example allows Harbor images by default, denies a more specific customer path for regular containers and image volumes, allows and audits regular container images from an audit registry, and allows a production image path only for namespaces matching `env=prod`:

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
        workloads:
          registries:
            - exp: "harbor/.*"

    - enforce:
        action: deny
        workloads:
          targets:
            - pod/containers
            - pod/volumes
          registries:
            - exp: "harbor/customer/.*"

    - enforce:
        action: allow
        workloads:
          targets:
            - pod/containers
          registries:
            - exp: "audit/.*"

    - enforce:
        action: audit
        workloads:
          targets:
            - pod/containers
          registries:
            - exp: "audit/.*"

    - namespaceSelector:
        matchExpressions:
          - key: env
            operator: In
            values: ["prod"]
      enforce:
        action: allow
        workloads:
          targets:
            - pod/containers
            - pod/volumes
          registries:
            - exp: "harbor/customer/prod-image/.*"
              policy: ["Always"]
```

Apply the following Pod in namespace `solar-test`, which does not match the `env=prod` selector:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: image-volume
spec:
  containers:
    - name: shell
      command: ["sleep", "infinity"]
      imagePullPolicy: IfNotPresent
      image: harbor/customer/test-image/debian:latest
      volumeMounts:
        - name: volume
          mountPath: /volume
  volumes:
    - name: volume
      image:
        reference: quay.io/crio/artifact:v2
        pullPolicy: IfNotPresent
```

The request is denied:

```bash
kubectl apply -f pod.yaml -n solar-test

Error from server (Forbidden): error when creating "pod.yaml": admission webhook "pods.projectcapsule.dev" denied the request: containers[0] reference "harbor/customer/test-image/debian:latest" is denied by registry rule "harbor/customer/.*"
```

The Pod is denied because the regular container image matches both `harbor/.*` and `harbor/customer/.*`. Since the deny rule is declared later, it has higher precedence.

The image volume reference is not denied by the shown deny rule because it does not match `harbor/customer/.*`. If the image volume used a matching reference, for example `harbor/customer/volume-artifact:v1`, the same deny rule would apply because it targets both `pod/containers` and `pod/volumes`.

In a namespace matching `env=prod`, the more specific production allow rule is also considered:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: prod-image
spec:
  containers:
    - name: shell
      command: ["sleep", "infinity"]
      imagePullPolicy: Always
      image: harbor/customer/prod-image/debian:latest
```

The request is allowed because the namespace-specific rule matches later and allows `harbor/customer/prod-image/.*` with `imagePullPolicy: Always`.

Target-specific registry rules allow different behavior for different parts of the same Pod. For example, this rule denies the registry only for init containers:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        targets:
          - pod/initcontainers
        registries:
          - exp: "harbor/init-only/.*"
```

A matching reference under `spec.initContainers` is denied. The same reference under `spec.containers` is ignored by this rule.

### Registry exact match examples

Use `exact` when you want to allow or deny a fixed set of complete image references:

```yaml
rules:
  - enforce:
      action: allow
      workloads:
        targets:
          - pod/containers
        registries:
          - exact:
              - harbor/platform/debian:latest
              - harbor/platform/busybox:1.36
```

A Pod using `harbor/platform/debian:latest` or `harbor/platform/busybox:1.36` is admitted. A Pod using `harbor/platform/nginx:latest` is denied because an allow rule exists for registry enforcement but does not match that reference.

You can combine `exact` and `exp` in the same registry matcher:

```yaml
rules:
  - enforce:
      action: allow
      workloads:
        registries:
          - exact:
              - harbor/platform/debian:latest
            exp: "harbor/shared/.*"
```

This rule allows the exact Debian image and any image under `harbor/shared/*`.

### PullPolicy

Define the allowed image pull policies for a matching registry rule. Supported policies are:

* `Always`: The image is always pulled.
* `IfNotPresent`: The image is pulled only if it is not already present on the node.
* `Never`: The image is never pulled. If the image is not present on the node, the Pod fails to start.

The `policy` field is optional. If no policy is specified, all image pull policies are accepted for the matching registry rule.

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
        workloads:
          targets:
            - pod/containers
          registries:
            - exp: "harbor/v2/customer-registry/.*"
              policy: ["IfNotPresent", "Always"]
```

If the final matching registry decision is `allow` and that matching registry rule defines `policy`, the Pod must use one of the configured pull policies. For example, this rule allows the registry but only with `Always`:

```yaml
rules:
  - enforce:
      action: allow
      workloads:
        targets:
          - pod/containers
        registries:
          - exp: "harbor/v2/customer-registry/.*"
            policy: ["Always"]
```

A Pod using `imagePullPolicy: Never` for that registry is rejected:

```bash
Error from server (Forbidden): error when creating "pod.yaml": admission webhook "pods.projectcapsule.dev" denied the request: containers[0] reference "harbor/v2/customer-registry/debian:latest" uses pullPolicy=Never which is not allowed (allowed: Always)
```

Policy is checked only after the final registry decision is `allow`. A final `deny` decision always denies the request, regardless of the configured pull policy.

### Negation

A registry matcher can be negated with `negate: true`. Negation applies to the final result of the matcher, including both `exact` and `exp`.

For example, the following rule denies every regular container image that is not from the trusted registry path:

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
        action: deny
        workloads:
          targets:
            - pod/containers
          registries:
            - exp: "trusted/.*"
              negate: true
```

With this rule:

* `trusted/backend/api:1.0.0` is allowed in this deny-only example because it does not match the negated deny rule and no registry allow-list is configured.
* `docker.io/library/nginx:latest` is denied because it does not match `trusted/.*`, so the negated matcher evaluates to true.

Negation also applies to exact values:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        targets:
          - pod/containers
        registries:
          - exact:
              - trusted/backend/api:1.0.0
              - trusted/frontend/web:1.0.0
            negate: true
```

This rule denies every explicit container image except the two exact references listed, as long as no separate registry allow-list requires an explicit allow. If an allow rule is configured for the same matcher scope, the excepted references must also match an allow rule.

You can combine exact values, regular expressions, negation, namespace selectors, and action precedence. For example, deny all untrusted container images by default, but allow a controlled exception in production namespaces:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        targets:
          - pod/containers
        registries:
          - exact:
              - trusted/base/debian:latest
            exp: "trusted/platform/.*"
            negate: true

  - enforce:
      action: allow
      workloads:
        targets:
          - pod/containers
        registries:
          - exact:
              - trusted/base/debian:latest
            exp: "trusted/platform/.*"

  - namespaceSelector:
      matchLabels:
        env: prod
    enforce:
      action: allow
      workloads:
        targets:
          - pod/containers
        registries:
          - exp: "partner-registry/prod-approved/.*"
```

The second rule explicitly allows the trusted references that were excluded from the negated deny rule, which is required when registry allow-list behavior is active. In a namespace labeled `env=prod`, `partner-registry/prod-approved/app:1.0.0` is allowed because the later matching allow rule overrides the earlier negated deny rule.

### Targets

The `targets` field defines which parts of a workload a rule applies to.

Targets are configured under `enforce.workloads.targets` and are authoritative for target-aware workload enforcement. Registry entries do not define their own validation targets.

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        targets:
          - pod/containers
        registries:
          - exp: "harbor/customer/.*"
```

If `targets` is omitted or empty, the rule applies to all workload targets supported by the matching hook.

Supported workload targets are:

| Target | Description |
|---|---|
| `pod/initcontainers` | Applies to images used by `spec.initContainers`. |
| `pod/containers` | Applies to images used by `spec.containers`. |
| `pod/ephemeralcontainers` | Applies to images used by `spec.ephemeralContainers`. |
| `pod/volumes` | Applies to image volumes under `spec.volumes[].image`. |

Targets are currently used only by a subset of workload hooks. For example, the registry enforcement hook uses targets to decide which Pod image references are validated. Other hooks may ignore `targets` until they explicitly support target-aware enforcement.

Examples:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        targets:
          - pod/initcontainers
        registries:
          - exp: "harbor/init-only/.*"
```

This rule denies matching images only when they are used by `initContainers`. The same image reference is not denied when used by regular containers, ephemeral containers, or image volumes unless another rule matches those targets.

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        targets:
          - pod/containers
          - pod/ephemeralcontainers
        registries:
          - exp: "debug/.*"
```

This rule applies to regular containers and ephemeral containers, but not to init containers or image volume