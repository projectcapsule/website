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
