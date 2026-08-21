---
title: Workloads
weight: 2
description: >
  Workload enforcement
---

Workload enforcement mainly targets `Pod` objects and the resources associated
with them. It is configured under `spec.rules[].enforce.workloads`. Each rule
can define an `action`, optional workload `targets`, and one or more workload
policies such as resource requests and limits, registry match expressions,
scheduler match expressions, or QoS classes.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  rules:
    - enforce:
        action: deny
        workloads:
          qosClasses:
            - BestEffort
```

## Resource requests and limits

Resource policies let a Tenant administrator normalize and enforce the
`requests` and `limits` of Pods created in Tenant namespaces. They cover common
requirements that a Kubernetes `LimitRange` cannot express directly, including:

* always removing a resource limit;
* making a limit equal to its request;
* defaulting a missing request or limit without replacing an explicit value;
* deriving a missing limit from a request using a maximum ratio; and
* rejecting or auditing explicit limits that exceed that ratio.

Resource policies are configured under
`spec.rules[].enforce.workloads.resources`. The `requests` and `limits` maps are
keyed by Kubernetes resource name. Each map entry contains a case-sensitive
`policy` and, for policies that need one, a `value`.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  rules:
    - enforce:
        action: deny
        workloads:
          resources:
            limits:
              cpu:
                policy: Remove
              memory:
                policy: MatchRequest
```

At every compatible resource location, this example produces the following
behavior:

* CPU limits are removed, even when the submitted Pod defines them;
* memory limits are set to the corresponding memory requests; and
* because `targets` is omitted, the policy applies to Pod-level resources,
  regular containers, and init containers.

#### Before and after admission

Consider this submitted Pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: api
spec:
  containers:
    - name: api
      image: registry.example.com/api:1.0.0
      resources:
        requests:
          cpu: 250m
          memory: 512Mi
        limits:
          cpu: "1"
          memory: 1Gi
```

Capsule admits it with the equivalent resource configuration:

```yaml
resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    memory: 512Mi
```

The CPU request is untouched, the CPU limit is removed, and the memory limit is
replaced with the memory request. Because `targets` is omitted, Capsule applies
the same policy independently to `spec.resources`, every regular container, and
every init container in the Pod. The submitted example has no Pod-level or init
container resources, so those locations remain empty.

If `MatchRequest` finds neither a request nor a limit, the resource is
compliant and remains undefined. If it finds a limit without a corresponding
request, it cannot derive a replacement and the final state violates the
policy. With `action: deny` the Pod is rejected; with `action: audit` Capsule
admits it and emits an audit event and admission warning.

### Policy reference

After starting with the common example above, use this reference to
choose the precise behavior for each request and limit.

#### Requests

The following policies are supported under `resources.requests`:

| Policy | `value` | Mutation behavior | Validation behavior |
|---|---|---|---|
| `Preserve` | Not allowed | Leaves an existing or missing request unchanged. | Adds no constraint and clears earlier constraints for the same target and resource. |
| `Default` | Required | Sets the configured quantity only when the request is absent. An explicit request is preserved. | Adds no constraint and clears earlier constraints for the same target and resource. |
| `Remove` | Not allowed | Removes the request when it is present. | Requires the request to be absent in the final Pod. |

Default a request without overriding tenant workloads that already specify it:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        resources:
          requests:
            cpu:
              policy: Default
              value: 100m
            memory:
              policy: Default
              value: 256Mi
```

If a container requests `500m` CPU, Capsule preserves `500m`. If the CPU
request is missing, Capsule adds `100m`.

Remove an extended resource request:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        targets:
          - pod/containers
        resources:
          requests:
            example.com/temporary-device:
              policy: Remove
```

Resource names must be valid Kubernetes qualified names. Custom and extended
resource names can be used for container and init-container policies, subject
to the normal Kubernetes rules for that resource.

#### Limits

The following policies are supported under `resources.limits`:

| Policy | `value` | Mutation behavior | Validation behavior |
|---|---|---|---|
| `Preserve` | Not allowed | Leaves an existing or missing limit unchanged. | Adds no constraint and clears earlier constraints for the same target and resource. |
| `Default` | Required | Sets the configured quantity only when the limit is absent. An explicit limit is preserved. | Adds no constraint and clears earlier constraints for the same target and resource. |
| `Remove` | Not allowed | Removes the limit when it is present. | Requires the limit to be absent in the final Pod. |
| `MatchRequest` | Not allowed | If a request exists, sets the limit to exactly the request, replacing a different explicit limit. If no request exists, it does not add a limit. | Requires request and limit to be equal. When the request is absent, the limit must also be absent. |
| `Ratio` | Required | If a positive request exists and the limit is absent, sets the limit to `request * value`. An explicit limit is preserved for validation. | Requires a positive request and a limit no greater than `request * value`. |

`Default` is a fill-only policy. It does not mean that every limit must equal
the configured value. Use `MatchRequest` when Capsule should own the limit and
keep it equal to the request, or `Ratio` when explicit tenant values are allowed
within a bounded range.

#### Ratio limits

`Ratio` defines the maximum permitted limit as a multiple of the request. It is
available only for limits and supports these resource names:

| Resource | Calculation precision |
|---|---|
| `cpu` | Exact decimal arithmetic, rounded down to the nearest millicore. |
| `memory` | Exact decimal arithmetic, rounded down to a whole byte. |
| `ephemeral-storage` | Exact decimal arithmetic, rounded down to a whole byte. |

The ratio must be greater than or equal to `1`. Quote fractional ratios in YAML
for clarity, for example `"1.5"`.

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        targets:
          - pod/containers
        resources:
          limits:
            memory:
              policy: Ratio
              value: "1.5"
```

For a memory request of `1Gi`, the maximum limit is `1536Mi`:

| Submitted limit | Mutation | Result with `action: deny` |
|---|---|---|
| Missing | Capsule adds `1536Mi`. | Admitted. |
| `1Gi` | Explicit value is preserved. | Admitted because it is below the maximum. |
| `1536Mi` | Explicit value is preserved. | Admitted because it equals the maximum. |
| `2Gi` | Explicit value is preserved. | Denied because it exceeds the maximum. |

An explicit limit is never reduced by `Ratio`. This is deliberate: preserving
the submitted value allows `allow`, `deny`, and `audit` to decide how a ratio
violation should be handled. Use `MatchRequest` when the limit should always be
rewritten instead.

`Ratio` requires a positive request. When the request is missing or zero,
Capsule cannot calculate a default limit. The missing or non-positive request
is therefore a policy violation. A `deny` action blocks it, an `audit` action
reports it, and an `allow` action treats it as an allow-list miss and blocks it.

Capsule calculates ratios without floating-point arithmetic and rounds down so
that the generated limit never exceeds the configured factor. For example, a
CPU request of `101m` with a ratio of `1.5` produces a limit of `151m`, not
`152m`.

### Targeting resource locations

Resource policies reuse `enforce.workloads.targets` to select the resource
locations inside the Pod:

| Target | Resource location | Supported by resource policies |
|---|---|---|
| `pod` | Pod-level `spec.resources` | Yes. |
| `pod/containers` | `spec.containers[].resources` | Yes. |
| `pod/initcontainers` | `spec.initContainers[].resources` | Yes. |
| `pod/ephemeralcontainers` | `spec.ephemeralContainers[].resources` | No. Kubernetes does not allow resources to be set on ephemeral containers. |
| `pod/volumes` | Pod volumes | No. |

When `targets` is omitted or empty, each resource policy applies to every
compatible location: Pod-level `spec.resources`, regular containers, and init
containers. An explicit `targets` list narrows that default.

Compatibility is evaluated per resource name. Kubernetes Pod-level resources
support only `cpu`, `memory`, and huge-page resources. With omitted targets,
those names apply at all three locations, while other valid names such as
`ephemeral-storage` and extended resources apply only to regular and init
containers. Capsule skips those incompatible names at `spec.resources`; it does
not reject the rule or discard their container policies.

Only regular containers:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        targets:
          - pod/containers
        resources:
          limits:
            cpu:
              policy: Remove
```

Only init containers:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        targets:
          - pod/initcontainers
        resources:
          requests:
            cpu:
              policy: Default
              value: 25m
```

Both regular and init containers, explicitly:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        targets:
          - pod/containers
          - pod/initcontainers
        resources:
          limits:
            memory:
              policy: MatchRequest
```

Only Pod-level resources:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        targets:
          - pod
        resources:
          requests:
            cpu:
              policy: Default
              value: 500m
            memory:
              policy: Default
              value: 1Gi
          limits:
            cpu:
              policy: Ratio
              value: "2"
            memory:
              policy: Ratio
              value: "1.5"
```

The Kubernetes API server must support `spec.resources` for Pod-level resource
policies to be useful. Pod-level policies support `cpu`, `memory`, and huge-page
resources. Because `Ratio` itself supports only CPU, memory, and ephemeral
storage, a pod-level ratio can be configured for CPU or memory, but not for huge
pages. Use an explicit `pod` target when the policy must not affect containers.

{{% alert title="Target compatibility" color="warning" %}}
When a workload block contains `resources`, every explicitly configured target
in that block must support resource policies. A block that combines resource
policies with `pod/ephemeralcontainers` or `pod/volumes` is invalid. Put registry
or image-volume enforcement that needs those targets in a separate rule.

If `pod` is explicitly combined with a container target, every configured
resource name must also be valid at Pod level. Omit `targets` when a policy
should use the broad default and automatically skip only its incompatible
Pod-level location.
{{% /alert %}}

```yaml
# Valid: resource and registry policies use separate target scopes.
rules:
  - enforce:
      action: deny
      workloads:
        targets:
          - pod/containers
        resources:
          limits:
            cpu:
              policy: Remove

  - enforce:
      action: deny
      workloads:
        targets:
          - pod/ephemeralcontainers
          - pod/volumes
        registries:
          - exp: "untrusted.example.com/.*"
```

### Advanced behavior

The following concepts are mainly relevant when combining multiple rules,
selectors, admission actions, or Kubernetes resource-management components.

#### Admission lifecycle

Resource policy admission has a mutation phase and a validation phase. Knowing
which phase a policy uses is important when choosing a policy and an action.

| Admission phase | Operations | Behavior |
|---|---|---|
| Mutation | Pod `CREATE` | Capsule applies the effective `Default`, `Remove`, `MatchRequest`, or `Ratio` mutation to the incoming Pod. `Preserve` does not change the field. |
| Validation | Pod `CREATE` and normal `UPDATE` | Capsule checks the final resource values for `Remove`, `MatchRequest`, and `Ratio`. `Preserve` and `Default` do not add a validation constraint. |
| Pod subresources | Any | Resource validation is skipped for Pod subresources, including `ephemeralcontainers`. Resource policies do not mutate ephemeral containers. |

Mutation is intentionally limited to Pod creation. Capsule does not try to
rewrite resource fields on existing Pods, where Kubernetes immutability rules
would normally reject the change. Normal Pod updates are still validated so
that the policy describes the accepted final state.

When a `Deployment`, `StatefulSet`, `Job`, or another workload controller
creates a Pod, Capsule mutates and validates the resulting Pod. It does not
rewrite the controller's stored `spec.template`. Consequently, inspecting the
controller can show the original template while inspecting one of its admitted
Pods shows the effective resources.

{{% alert title="Important" color="warning" %}}
The enclosing `action` does not disable mutation. A rule with `action: audit`
still applies its create-time resource mutation. The action controls the result
of a remaining validation violation. For example, `Ratio` leaves an explicit
limit unchanged, then `deny` rejects an excessive value while `audit` reports
it without blocking the Pod.
{{% /alert %}}

#### Actions and compliance

The `action` belongs to the enclosing `enforce` block and applies to
validation constraints created by `Remove`, `MatchRequest`, and `Ratio`:

| Action | When the final value complies | When the final value violates the policy |
|---|---|---|
| `deny` | No deny decision is produced. | The Pod is denied. |
| `allow` | The policy produces an allow decision. | The value does not satisfy the resource allow-list and the Pod is denied unless a later matching rule allows it. |
| `audit` | No audit is emitted. | The Pod is admitted by this rule, and Capsule emits a Kubernetes event and admission warning. Other rules can still deny it. |

As with other enforcement matchers, the last matching `allow` or `deny`
decision wins. Audit decisions never override allow or deny decisions.

The following example denies memory limits above `1.5` times the request by
default but permits up to `2` times the request in namespaces labeled
`burst-memory=true`:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        targets:
          - pod/containers
        resources:
          limits:
            memory:
              policy: Ratio
              value: "1.5"

  - namespaceSelector:
      matchLabels:
        burst-memory: "true"
    enforce:
      action: allow
      workloads:
        targets:
          - pod/containers
        resources:
          limits:
            memory:
              policy: Ratio
              value: "2"
```

A container with a `1Gi` request and a `1792Mi` limit violates the first rule
but complies with the later allow rule. It is admitted only in a namespace that
matches the selector on the second rule.

Audit explicit ratio violations without rejecting them:

```yaml
rules:
  - enforce:
      action: audit
      workloads:
        targets:
          - pod/containers
        resources:
          limits:
            ephemeral-storage:
              policy: Ratio
              value: "2"
```

Remember that a missing limit is still defaulted during create. The audit is
emitted only when the final Pod remains noncompliant, such as when it contains
an explicit excessive limit or a limit without a positive request.

#### Rule order and policy overrides

Rules are processed in declaration order after `namespaceSelector` and
`audience` filtering. Resource policies are resolved independently for every
combination of target, resource name, and field (`request` or `limit`). This
allows CPU and memory, or requests and limits, to be managed independently.

For mutation, the last applicable policy for a target, resource name, and field
is effective. A later `Preserve` therefore prevents an earlier mutation:

```yaml
rules:
  - enforce:
      action: deny
      workloads:
        resources:
          limits:
            cpu:
              policy: Remove

  - namespaceSelector:
      matchLabels:
        preserve-cpu-limit: "true"
    enforce:
      action: allow
      workloads:
        targets:
          - pod/containers
          - pod/initcontainers
        resources:
          limits:
            cpu:
              policy: Preserve
```

In matching namespaces, the later `Preserve` policy leaves CPU limits intact.
In other namespaces, the earlier `Remove` policy remains effective.

For validation, `Preserve` and `Default` also clear earlier constraints for the
same target, field, and resource. Constraints declared after that reset point
are still evaluated. This makes `Preserve` useful as a namespace-specific
escape hatch and `Default` useful when switching from enforcement back to
fill-only behavior.

Audience filtering uses the actual identity on the Pod admission request. Pods
created by a workload controller are normally submitted by that controller's
service account, not by the user who originally created the Deployment or Job.
Account for that distinction when combining `audience` with resource mutation.

#### Configuration validation

Capsule validates resource policy configuration before using it. Invalid rules
are reported on the RuleStatus and are not silently accepted.

The following requirements apply:

* At least one non-empty `requests` or `limits` map is required.
* Policy names are case-sensitive.
* `value` is required only by request `Default`, limit `Default`, and limit
  `Ratio`.
* `value` must not be supplied to `Preserve`, `Remove`, or `MatchRequest`.
* Default quantities must not be negative. A zero default is accepted, although
  Kubernetes or another admission policy can impose a stricter requirement.
* A ratio must be greater than or equal to `1`.
* `Ratio` supports only `cpu`, `memory`, and `ephemeral-storage`.
* `pod/ephemeralcontainers`, `pod/volumes`, and the deprecated `pod/images`
  target cannot be used in a workload block containing resource policies.
* A request cannot use `Remove` while the same rule uses `MatchRequest` or
  `Ratio` for that resource's limit, because those limit policies require the
  request.
* When the `pod` target is explicitly present, resource names in that block are
  restricted to `cpu`, `memory`, and huge-page resources supported by
  Kubernetes pod-level resources.
* When `targets` is omitted, Pod-incompatible resource names remain valid and
  are applied only to regular and init containers.

For example, this configuration is invalid:

```yaml
resources:
  requests:
    memory:
      policy: Remove
  limits:
    memory:
      policy: Ratio
      value: "1.5"
```

The following is also invalid because `value` is not accepted by `Remove`:

```yaml
resources:
  limits:
    cpu:
      policy: Remove
      value: "1"
```

#### Interaction with Kubernetes resource controls

Resource policies complement Kubernetes resource controls; they do not replace
or disable them.

* `LimitRange` can still apply its own defaults and min/max validation.
  Configure its constraints consistently with Capsule resource policies to
  avoid admission behavior that depends on webhook and admission-plugin order.
* `ResourceQuota`, Global Resource Quota, and Resource Pools evaluate the
  resulting Pod resources according to their own semantics.
* Other mutating webhooks can also change resources. Capsule's generic mutating
  webhook requests reinvocation when another mutator changes the Pod, and the
  validating webhook checks the final object it receives.
* Kubernetes performs its own resource validation after mutation. A resource
  configuration accepted by a Capsule policy can still be rejected by the API
  server or another admission policy.
* A Vertical Pod Autoscaler or another controller that creates replacement Pods
  is subject to the policy when those Pods are admitted. Normal updates are
  validated but not mutated.

To inspect the effective resources after admission, query the Pod rather than
only its workload-controller template:

```bash
kubectl get pod api -n solar-apps \
  -o jsonpath='{.spec.containers[*].resources}'
```

If admission is denied, Capsule's error identifies the target path, resource
field, and failed requirement. Audit violations appear as admission warnings
and Kubernetes events associated with the Pod and Tenant.

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
| `pod` | Applies to Pod-level resources under `spec.resources`. Resource policies include this target by default when `targets` is omitted. |
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

This rule applies to regular containers and ephemeral containers, but not to
init containers or image volumes.
