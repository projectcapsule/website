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
        registries:
        -  url: "harbor/v2/customer-registry/.*"
           policy: [ "ifNotPresent" ]

    # Select a subset of namespaces (enviornment=prod) to allow further registries
    - namespaceSelector:
        matchExpressions:
          - key: env
            operator: In
            values: ["prod"]
      enforce:    
        registries:
         -  url: "harbor/v2/prod-registry/.*"
            policy: [ "ifNotPresent" ]
```

Note that rules are combined together. In the above example, all namespaces within the `solar` tenant will be enforced to use images from `harbor/v2/customer-registry/*`, while namespaces labeled with `env=prod` will also be allowed to pull images from `harbor/v2/prod-registry/*`.

## Enforcement

Declare Enforcement rules for the selected namespaces.

### Registries

Define allowed image registries for `Pods` with rules. Each registry can have specific policies and validation targets. We use Regexp pattern matching for the registry URL, so you can specify patterns like `harbor/v2/customer-registry/*` to match all images from that registry. The matching is done against the full image name, including the path and tag. The ordering is based on the order of declaration, so the first matching rule will be applied. The later the match is found, the higher the precedence. This allows you to build constructs like these:

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
        registries:

        # Enforce PullPolicy "always" for all registries (For Container Images and Volume Images)
        - url: ".*"
          policy: [ "Always" ]

        # If we are pulling from a harbor registry we want to verify the images for Containers only
        - url: "harbor/.*"

    - namespaceSelector:
        matchExpressions:
          - key: env
            operator: In
            values: ["prod"]
      enforce:
        registries:
        - url: "harbor/v2/customer-registry/prod-image/.*"
          policy: [ "Always" ]
```

Let's try to apply the following pod in the namespace `solar-test` (Does not match the `env=prod` selector):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: image-volume
spec:
  containers:

  - name: shell
    command: ["sleep", "infinity"]
    imagePullPolicy: Never
    image: harbor/v2/prod-registry/debian
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

Error from server (Forbidden): error when creating "pod.yaml": admission webhook "pods.projectcapsule.dev" denied the request: containers[0] reference "harbor/v2/prod-registry/debian" uses pullPolicy=Never which is not allowed (allowed: Always)
```

Because our first rule enforces all registries to use the `always` image pull policy, the pod creation is denied because it uses the `Never` policy. We can either allow the `Never` policy for this specific registry:

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
        registries:

        # Enforce PullPolicy "always" for all registries (For Container Images and Volume Images)
        - url: ".*"
          policy: [ "Always" ]

        # If we are pulling from a harbor registry we want to verify the images for Containers only
        - url: "harbor/.*"
          policy: [ "Never" ]

    - namespaceSelector:
        matchExpressions:
          - key: env
            operator: In
            values: ["prod"]
      enforce:
        registries:
        - url: "harbor/v2/customer-registry/prod-image/.*"
          policy: [ "always" ]
```

But let's for now also remove the generic rule for all registries and only keep the harbor one:

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
        registries:

        # If we are pulling from a harbor registry we want to verify the images for Containers only
        - url: "harbor/.*"
          policy: [ "Never" ]

    - namespaceSelector:
        matchExpressions:
          - key: env
            operator: In
            values: ["prod"]
      enforce:
        registries:
        - url: "harbor/v2/customer-registry/prod-image/.*"
          policy: [ "Always" ]
```

If we try to apply the pod again, it we will still get an error. The problem is that we are mounting an image volume that is not coming from the allowed harbor registry:

```bash
Error from server (Forbidden): error when creating "pod.yaml": admission webhook "pods.projectcapsule.dev" denied the request: volumes[0](volume) reference "quay.io/crio/artifact:v2" is not allowed
```

However we would like to only validate the images used in the Pod spec (Containers, InitContainers, EphemeralContainers) and not the ones used in the Volumes. We can achieve this by specifying the [`validation`](#validation) field for the harbor registry:

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
        registries:
        # If we are pulling from a harbor registry we want to verify the images for Containers only
        - url: "harbor/.*"
          policy: [ "Never" ]
          validation:
          - "pod/images"

    - namespaceSelector:
        matchExpressions:
          - key: env
            operator: In
            values: ["prod"]
      enforce:
        registries:
        - url: "harbor/v2/customer-registry/prod-image/.*"
          policy: [ "Always" ]
```

#### Policy

Define the allowed image pull policies for the specified registry URL. Supported policies are:

* `Always`: The image is always pulled.
* `IfNotPresent`: The image is pulled only if it is not already present on the node.
* `Never`: The image is never pulled. If the image is not present on the node, the Pod will fail to start.

This configuration is optional. If no policy is specified, all image pull policies are allowed for the given registry.

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
        registries:
        - url: "harbor/v2/customer-registry/.*"
          policy: [ "IfNotPresent", "Always" ]
```


#### Validation

Define on which parts of the Pod the registry policy must be validated. Currently supported validation targets are:

* `pod/images`: Validate the images used in the Pod spec (For `Containers`, `InitContainers` and `EphemeralContainers`).
* `pod/volumes`: Validate the images used in the Pod `Volumes` ([Read More](https://kubernetes.io/docs/tasks/configure-pod-container/image-volumes/))

**By default, both targets are validated**. You can override this behavior by specifying the `validation` field for each registry:

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
        registries:
        - url: "harbor/v2/customer-registry/.*"
          validation:
          - "pod/images"
```