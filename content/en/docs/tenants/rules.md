---
title: Rules
weight: 5
description: >
  Configure policies and restrictions on tenant-basis with Rules
---

Enforcement rules allow Bill, the cluster admin, to set policies and restrictions on a per-`Tenant` basis. These rules are enforced by Capsule Admission Webhooks when Alice, the `TenantOwner`, creates or modifies resources in her `Namespaces`. With the Rule Construct we can profile namespaces within a tenant to adhere to specific policies, depending on metadata.

## Namespace Selector

By default a rule is applied to all namespaces within a `Tenant`. However you can select a subset of namespaces to apply the rule on, by using a `namespaceSelector`. This selector works the same way as a standard Kubernetes label selector:

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  ...
  rules:
    # Matches all Namespaces and enforces the rule for all of them
    - enforce:
        workload:
          registries:
          -  exp: "harbor/v2/customer-registry/.*"
             policy: [ "ifNotPresent" ]

    # Select a subset of namespaces (enviornment=prod) to allow further registries
    - namespaceSelector:
        matchExpressions:
          - key: env
            operator: In
            values: ["prod"]
      enforce:
        workloads:
          registries:
           -  exp: "harbor/v2/prod-registry/.*"
              policy: [ "ifNotPresent" ]
```

Note that rules are combined together. In the above example, all namespaces within the `solar` tenant will be enforced to use images from `harbor/v2/customer-registry/*`, while namespaces labeled with `env=prod` will also be allowed to pull images from `harbor/v2/prod-registry/*`.

## Permissions

Declare permission distribution rules for the selected namespaces.

### Promotions

As an administrator, you can define promotion rules . A promotion rule selects ServiceAccounts within a Tenant based on specified conditions and assigns them predefined ClusterRoles.

The selected ClusterRoles are then applied across all namespaces belonging to the Tenant (or a subset), with the corresponding ServiceAccounts configured as subjects. This allows a ServiceAccount in one namespace to automatically receive equivalent permissions in all other namespaces of the same Tenant.

This feature is particularly useful in scenarios involving [Tenant Replications](/docs/replications/#tenantresource), where consistent permissions across namespaces are required.

```yaml
---
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  ...
  rules:
    - permissions:
        promotions:
          # With this rule every promoted ServiceAccount get's the ClusterRole "tenant-replicator" in all Namespaces of the Tenant solar
          - clusterRoles:
              - "configmap-replicator"

          # With this rule every promoted ServiceAccount with the matching labels get's the ClusterRole "tenant-replicator" in all Namespaces of the Tenant solar
          - clusterRoles:
              - "secret-replicator"
            selector:
              matchLabels:
                super: "account"

    - namespaceSelector:
        matchExpressions:
          - key: env
            operator: In
            values: ["prod"]
      permissions:
        promotions:
          # With this rule every promoted ServiceAccount with the matching labels get's the ClusterRole "tenant-replicator" in namespaces of the Tenant solar matching the selector (env=prod)
          - clusterRoles:
              - "secret-replicator:prod"
```

Make sure the `ClusterRoles` exist, otherwise you will get a reconcile error for the corresponding `Tenant`:

```shell
  conditions:
  - lastTransitionTime: "2026-02-16T23:08:59Z"
    message: 'cannot sync rolebindings items: rolebindings.rbac.authorization.k8s.io
      "tenant-replicator" not found'
```

If you are running capsule in [Strict Mode](/docs/operating/setup/installation/#strict-rbac) we must ensure the controller can grant the corresponding permissions to the `ServiceAccount` in all of the `Namespaces` in the `Tenant`. We can simply aggregate the same `ClusterRoles` to the controller:

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: configmap-replicator
  labels:
    projectcapsule.dev/aggregate-to-controller: "true"
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "create", "patch", "watch", "list", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-replicator
  labels:
    projectcapsule.dev/aggregate-to-controller: "true"
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "create", "patch", "watch", "list", "delete"]
```

Now as [Tenant Owner](#ownership) we can start promoting `ServiceAccounts` by labeling them with the label `projectcapsule.dev/promote` and the value `true`. This feature must be enabled in the [CapsuleConfiguration](/docs/operating/setup/configuration/#allowserviceaccountpromotion). You will get the following admission error if the feature is disabled:

```shell
Error from server (Forbidden): admission webhook "serviceaccounts.projectcapsule.dev" denied the request: service account promotion is disabled. Contact cluster administrators
```

When the feature is enabled the following command will succeded (assuming `alice` is a [Tenant Owner](#ownership) of the `Tenant` solar):

```yaml
kubectl label sa gitops-reconcile -n solar-test projectcapsule.dev/promote=true --as alice --as-group projectcapsule.dev
```

We can now verify if the promotion was successful by checking the `Tenant` status:

```yaml
kubectl get tnt solar  -o jsonpath='{.status.promotions}' | jq

[
  {
    "clusterRoles": [
      "tenant-replicator"
    ],
    "kind": "ServiceAccount",
    "name": "system:serviceaccount:solar-test:gitops-reconcile"
    "targets": [
      "solar-test",
      "solar-prod"
    ]
  }
]
```

we can verify the rolebinding was distributed to other `Namespaces` of the `Tenant` solar:

```shell
kubectl get rolebinding -n solar-prod

NAME                               ROLE                                    AGE
..
capsule:managed:7ad688b586eada40   ClusterRole/configmap-replicator        21s
..
```

To revoke the promotion, Alice can just remove the label:

```yaml
kubectl label sa gitops-reconcile -n solar-test projectcapsule.dev/promote-  --as alice --as-group projectcapsule.dev
```

## Enforcement

Namespace rules can enforce admission behavior for selected resources in Tenant namespaces. Each rule block can define an `action` and one or more matchers. For registry enforcement, matchers are evaluated against the full OCI reference string, including registry, path, tag, or digest.

Rules are evaluated in declaration order. If multiple `allow` or `deny` rules match the same reference, the later matching `allow` or `deny` rule has higher precedence. `audit` rules do not deny the request; they emit an event and add a warning to the admission response.

### Action

Each `enforce` block supports an `action` field:

| Action | Behavior |
|---|---|
| `allow` | Allows the matching reference. If `policy` is configured, the pull policy must also be one of the configured values. |
| `deny` | Denies the matching reference. A later matching `allow` rule can override it. |
| `audit` | Allows the request, emits a Kubernetes event, and returns an admission warning. |

If `action` is omitted, it defaults to `deny`.

This precedence model allows both broad defaults and specific exceptions. For example, you can allow all Harbor images but deny a customer path afterwards:

```yaml
rules:
  - enforce:
      action: allow
      workloads:
        registries:
          - exp: "harbor/.*"

  - enforce:
      action: deny
      workloads:
        registries:
          - exp: "harbor/customer/.*"
```

In this example, `harbor/nginx:1.14.2` is allowed, while `harbor/customer/app:1.0.0` is denied because the later, more specific deny rule also matches.

You can also deny broadly and allow a more specific exception afterwards:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        registries:
          - exp: "harbor/customer/.*"

  - enforce:
      action: allow
      workloads:
        registries:
          - exp: "harbor/customer/prod-image/.*"
```

In this example, `harbor/customer/test-image/app:1.0.0` is denied, while `harbor/customer/prod-image/app:1.0.0` is allowed.

#### Audit

Use `action: audit` to observe workload usage without blocking the request. Audit rules allow the admission request, emit a Kubernetes event, and add a warning to the admission response.

For registry enforcement:

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
        action: audit
        workloads:
          targets:
            - pod/containers
          registries:
            - exp: "docker.io/.*"
```

Applying a Pod with `docker.io/library/nginx:latest` succeeds, but the API server response contains an admission warning and Capsule emits a related event for the Pod.

For QoS enforcement:

```yaml
rules:
  - enforce:
      action: audit
      workloads:
        qosClasses:
          - Burstable
```

Applying a `Burstable` Pod succeeds, but Capsule emits an event and returns an admission warning.



### Workloads

Enforcement for workloads mainly targets `Pods` and their associated resources.

Workload enforcement is configured under `spec.rules[].enforce.workloads`. Each rule can define an `action`, optional workload `targets`, and one or more workload matchers such as registry expressions or QoS classes.

Rules are evaluated in declaration order. If multiple `allow` or `deny` rules match the same request, the **last matching allow or deny rule wins**. `audit` rules do not block the request; they emit a Kubernetes event and add an admission warning.

Supported actions are:

| Action | Behavior |
|---|---|
| `allow` | Allows the matching request. If the matcher defines additional constraints, such as image pull policy, those constraints must also be satisfied. |
| `deny` | Denies the matching request. |
| `audit` | Allows the request, emits a Kubernetes event, and returns an admission warning. |

If `action` is omitted, Capsule treats the rule as `deny`.

---

#### Targets

The `targets` field defines which parts of a workload a rule applies to.

Targets are configured under `enforce.workloads.targets` and are authoritative for target-aware workload enforcement. Registry entries no longer define their own validation targets.

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

Targets are currently used only by a subset of workload hooks. For example, the registry enforcement hook uses targets to decide which Pod image references are validated. The QoS enforcement hook also respects workload targets when evaluating QoS rules. Other hooks may ignore `targets` until they explicitly support target-aware enforcement.

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

This rule applies to regular containers and ephemeral containers, but not to init containers or image volumes.

---

#### QoS Classes

QoS class enforcement allows tenants to allow, deny, or audit Pods based on their [computed Kubernetes QoS class](https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/).

QoS rules are configured under `enforce.workloads.qosClasses`.

Supported QoS classes are:

| QoS class | Description |
|---|---|
| `Guaranteed` | The Pod has CPU and memory requests and limits set so that requests equal limits. |
| `Burstable` | The Pod has at least one CPU or memory request or limit, but does not qualify as `Guaranteed`. |
| `BestEffort` | The Pod has no CPU or memory requests or limits. |

Capsule evaluates the QoS class of the incoming Pod during create and update admission. Pod-level resources are considered when present. If Kubernetes has already populated `status.qosClass`, Capsule can use that value; otherwise it computes the QoS class from the Pod specification.

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
Error from server (Forbidden): error when creating "pod.yaml": admission webhook "pods.projectcapsule.dev" denied the request: pod "best-effort" uses QoS class "BestEffort" which is denied by namespace rule
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

A matching Pod is admitted, but Capsule emits an event and the API server response contains an admission warning.

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

You can also combine QoS rules with targets:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        targets:
          - pod/containers
        qosClasses:
          - BestEffort
```

If `targets` is omitted, the QoS rule applies to all workload targets supported by the QoS hook.

---

#### Registries

Define image registry rules for `Pods` with regular expressions. The `exp` field is matched against the full OCI reference string. This includes the registry, repository path, image name, tag, and digest if present.

Registry rules are configured under `enforce.workloads.registries`. The workload-level `targets` field under `enforce.workloads.targets` controls which Pod image references are validated.

The following example allows Harbor images by default, denies a more specific customer path for regular containers and image volumes, audits regular container images from an audit registry, and allows a production image path only for namespaces matching `env=prod`:

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

Let's try to apply the following Pod in namespace `solar-test`, which does not match the `env=prod` selector:

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

**What do you expect to happen?**

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

##### Policy

Define the allowed image pull policies for a matching registry expression. Supported policies are:

* `Always`: The image is always pulled.
* `IfNotPresent`: The image is pulled only if it is not already present on the node.
* `Never`: The image is never pulled. If the image is not present on the node, the Pod fails to start.

The `policy` field is optional. If no policy is specified, all image pull policies are accepted for the matching registry expression.

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

If a matching `allow` rule defines `policy`, the Pod must use one of the configured pull policies. For example, this rule allows the registry but only with `Always`:

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

##### Negated regular expressions

A registry expression can be negated with `negate: true`. This means the rule matches references that do **not** match the expression.

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

* `trusted/backend/api:1.0.0` is allowed because it does not match the negated rule.
* `docker.io/library/nginx:latest` is denied because it does not match `trusted/.*`, so the negated expression evaluates to true.

You can combine negation with namespace selectors and action precedence. For example, deny all untrusted container images by default, but allow a controlled exception in production namespaces:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        targets:
          - pod/containers
        registries:
          - exp: "trusted/.*"
            negate: true

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

In a namespace labeled `env=prod`, `partner-registry/prod-approved/app:1.0.0` is allowed because the later matching allow rule overrides the earlier deny rule.
