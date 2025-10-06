---
title: Kyverno
describtion: Capsule interation with Kyverno
logo: "https://github.com/cncf/artwork/raw/refs/heads/main/projects/kyverno/icon/color/kyverno-icon-color.svg"
type: single
display: true
integration: true
---

[Kyverno](https://kyverno.io) is a policy engine designed for Kubernetes. It provides the ability to validate, mutate, and generate Kubernetes resources using admission control. Kyverno policies are managed as Kubernetes resources and can be applied to a cluster using kubectl. Capsule integrates with Kyverno to provide a set of policies that can be used to improve the security and governance of the Kubernetes cluster.

## Recommended Policies

Not all relevant settings are covered by Capsule. We recommend to use Kyverno to enforce additional policies, as their policy implementation is of a very high standard. Here are some policies you might want to consider in multi-tenant environments:

### Workloads (Pods)

Admission Rules for Pods are a good way to enforce security best practices.

#### Mutate User Namespace

You should enforce the usage of [User Namespaces](/docs/operating/best-practices/workloads/#user-namespaces). Most Helm-Charts currently don't support this out of the box. With Kyverno you can enforce this on Pod level:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: tenant-workload-restrictions
spec:
  rules:
    - name: enforce-no-host-users
      match:
        any:
        - resources:
            kinds:
            - Pod
            namespaceSelector:
              matchExpressions:
              - key: capsule.clastix.io/tenant
                operator: Exists
            # selector:
            #   matchExpressions:
            #     - key: company.com/allow-host-users
            #       operator: NotIn
            #       values:
            #         - "true"
      preconditions:
        all:
        - key: "{{request.operation || 'BACKGROUND'}}"
          operator: AnyIn
          value:
            - CREATE
            - UPDATE
      skipBackgroundRequests: true
      mutate:
        patchStrategicMerge:
          spec:
            hostUsers: false
```

Note that users still can override this setting by adding the label `company.com/allow-host-users=true` to their namespace. You can change the label to your needs. This is because NFS does not support user namespaces and you might want to allow this for specific tenants.

#### Disallow Daemonsets

Tenant's should not be allowed to create Daemonsets, unless they have dedicated nodes:

```yaml

apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: tenant-workload-restrictions
spec: 
  validationFailureAction: Enforce
  rules:
  - name: block-daemonset-create
    match:
      any:
      - resources:
          kinds:
          - DaemonSet
          namespaceSelector:
            matchExpressions:
            - key: capsule.clastix.io/tenant
              operator: Exists
    preconditions:
      all:
      - key: "{{ request.operation || 'BACKGROUND' }}"
        operator: Equals
        value: CREATE
    validate:
      message: "Creating DaemonSets is not allowed in this cluster."
      deny:
        conditions:
          any:
          - key: "true"
            operator: Equals
            value: "true"
```

#### Disallow Scheduling on Controle Planes

If a Pods are not scoped to specific nodes, they could be scheduled on control plane nodes. You should disallow this by enforcing that Pods do not use tolerations for control plane nodes:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: tenant-workload-restrictions
spec: 
  validationFailureAction: Enforce
  rules:
  - name: restrict-controlplane-scheduling-master
    match:
      resources:
        kinds:
        - Pod
        namespaceSelector:
          matchExpressions:
          - key: capsule.clastix.io/tenant
            operator: Exists
    validate:
      message: Pods may not use tolerations which schedule on control plane nodes.
      pattern:
        spec:
          =(tolerations):
            - key: "!node-role.kubernetes.io/master"

  - name: restrict-controlplane-scheduling-control-plane
    match:
      resources:
        kinds:
        - Pod
        namespaceSelector:
          matchExpressions:
          - key: capsule.clastix.io/tenant
            operator: Exists
    validate:
      message: Pods may not use tolerations which schedule on control plane nodes.
      pattern:
        spec:
          =(tolerations):
            - key: "!node-role.kubernetes.io/control-plane"
```

#### Enforce EmptDir Requests/Limits

By Defaults `emptyDir` Volumes do not have any limits. This could lead to a situation, where a tenant fills up the node disk. To avoid this, you can enforce limits on `emptyDir` volumes. You may also consider restricting the usage of `emptyDir` with the `medium: Memory` option, as this could lead to memory exhaustion on the node.

```yaml

apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: tenant-workload-restrictions
spec:
  rules:
    - name: default-emptydir-sizelimit
      match:
        any:
        - resources:
            kinds:
            - Pod
            namespaceSelector:
              matchExpressions:
              - key: capsule.clastix.io/tenant
                operator: Exists
      mutate:
        foreach:
        - list: "request.object.spec.volumes[]"
          preconditions:
            all:
            - key: "{{element.keys(@)}}"
              operator: AnyIn
              value: emptyDir
            - key: "{{element.emptyDir.sizeLimit || ''}}"
              operator: Equals
              value: ''
          patchesJson6902: |-
            - path: "/spec/volumes/{{elementIndex}}/emptyDir/sizeLimit"
              op: add
              value: 250Mi
```

### Block Ephemeral Containers

Ephemeral containers, enabled by default in Kubernetes 1.23, allow users to use the `kubectl debug` functionality and attach a temporary container to an existing Pod. This may potentially be used to gain access to unauthorized information executing inside one or more containers in that Pod. This policy blocks the use of ephemeral containers.

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-ephemeral-containers
  annotations:
    policies.kyverno.io/title: Block Ephemeral Containers
    policies.kyverno.io/category: Other
    policies.kyverno.io/severity: medium
    kyverno.io/kyverno-version: 1.6.0
    policies.kyverno.io/minversion: 1.6.0
    kyverno.io/kubernetes-version: "1.23"
    policies.kyverno.io/subject: Pod
    policies.kyverno.io/description: >-
      Ephemeral containers, enabled by default in Kubernetes 1.23, allow users to use the
      `kubectl debug` functionality and attach a temporary container to an existing Pod.
      This may potentially be used to gain access to unauthorized information executing inside
      one or more containers in that Pod. This policy blocks the use of ephemeral containers.
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: block-ephemeral-containers
    match:
      any:
      - resources:
          kinds:
            - Pod
    validate:
      message: "Ephemeral (debug) containers are not permitted."
      pattern:
        spec:
          X(ephemeralContainers): "null"
```

[Source](https://kyverno.io/policies/other/block-ephemeral-containers/block-ephemeral-containers/)

### Image Registry

This can alos be achieved using Capsule's [Container Registries](/docs/tenants/enforcement/#images-registries) feature. Here is an example of allowing specific registries for a tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  containerRegistries:
    allowed:
    - "docker.io"
    - "public.ecr.aws"
    - "quay.io"
    - "mcr.microsoft.com"
```

Or with a Kyverno Policy. Here the default registry is `docker.io`, when no registry prefix is specified:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-image-registries
  annotations:
    policies.kyverno.io/title: Restrict Image Registries
    policies.kyverno.io/category: Best Practices, EKS Best Practices
    policies.kyverno.io/severity: medium
spec:
  validationFailureAction: Audit
  background: true
  rules:
  - name: validate-registries
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Using unknown image registry."
      foreach:
      - list: "request.object.spec.initContainers"
        deny:
          conditions:
          - key: '{{images.initContainers."{{element.name}}".registry }}'
            operator: NotIn
            value:
            - "docker.io"
            - "public.ecr.aws"
            - "quay.io"
            - "mcr.microsoft.com"

      - list: "request.object.spec.ephemeralContainers"
        deny:
          conditions:
          - key: '{{images.ephemeralContainers."{{element.name}}".registry }}'
            operator: NotIn
            value:
            - "docker.io"
            - "public.ecr.aws"
            - "quay.io"
            - "mcr.microsoft.com"

      - list: "request.object.spec.containers"
        deny:
          conditions:
          - key: '{{images.containers."{{element.name}}".registry }}'
            operator: NotIn
            value:
            - "docker.io"
            - "public.ecr.aws"
            - "quay.io"
            - "mcr.microsoft.com"
```

### Image PullPolicy

As stated [here](/docs/operating/best-practices/images/) on shared nodes you must use the `Always` pull policy. You can enforce this with the following policy:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: always-pull-images
  annotations:
    policies.kyverno.io/title: Always Pull Images
    policies.kyverno.io/category: Sample
    policies.kyverno.io/severity: medium
    policies.kyverno.io/subject: Pod
    policies.kyverno.io/minversion: 1.6.0
    policies.kyverno.io/description: >-
      By default, images that have already been pulled can be accessed by other
      Pods without re-pulling them if the name and tag are known. In multi-tenant scenarios,
      this may be undesirable. This policy mutates all incoming Pods to set their
      imagePullPolicy to Always. An alternative to the Kubernetes admission controller
      AlwaysPullImages.
spec:
  rules:
  - name: always-pull-images
    match:
      any:
      - resources:
          kinds:
          - Pod
          namespaceSelector:
            matchExpressions:
            - key: capsule.clastix.io/tenant
              operator: Exists
    mutate:
      patchStrategicMerge:
        spec:
          initContainers:
          - (name): "?*"
            imagePullPolicy: Always
          containers:
          - (name): "?*"
            imagePullPolicy: Always
          ephemeralContainers:
          - (name): "?*"
            imagePullPolicy: Always
```

### QOS Classes

You may consider the upstream policies, depending on your needs:

* [QoS Burstable](https://kyverno.io/policies/other/require-qos-burstable/require-qos-burstable/)
* [QoS Guaranteed](https://kyverno.io/policies/other/require-qos-guaranteed/require-qos-guaranteed/)

## References

Here are some policies for reference. We do not provide a complete list of policies, but we provide some examples to get you started. This policies are not meant to be used in production. You may adopt principles shown here to create your own policies.

### Extract tenant based on namespace

To get the tenant name based on the namespace, you can use a [context](https://kyverno.io/docs/writing-policies/external-data-sources/#variables-from-kubernetes-api-server-calls). With this context we resolve the tenant, based on the `{{request.namespace}}` for the requested resource. The context calls `/api/v1/namespaces/` API with the `{{request.namespace}}`. The `jmesPath` is used to check if the tenant label is present. You could assign a default if nothing was found, in this case it's empty string:


```yaml
    context:
      - name: tenant_name
        apiCall:
          method: GET
          urlPath: "/api/v1/namespaces/{{request.namespace}}"
          jmesPath: "not_null(metadata.labels.\"capsule.clastix.io/tenant\" || '')"
```


### Select namespaces with label `capsule.clastix.io/tenant`

When you are performing a policy on namespaced objects, you can select the objects, which are within a tenant namespace by using the `namespaceSelector`. In this example we select all `Kustomization` and `HelmRelease` resources which are within a tenant namespace:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: flux-policies
spec:
  validationFailureAction: Enforce
  rules:
    # Enforcement (Mutate to Default)
    - name: Defaults Kustomizations/HelmReleases
      match:
        any:
        - resources:
            kinds:
              - Kustomization
              - HelmRelease
            operations:
              - CREATE
              - UPDATE
            namespaceSelector:
              matchExpressions:
                - key: "capsule.clastix.io/tenant"
                  operator: Exists
      mutate:
        patchStrategicMerge:
          spec:
            +(targetNamespace): "{{ request.object.metadata.namespace }}"
            +(serviceAccountName): "default"
```


### Compare Source and Destination Tenant

With this policy we try to enforce, that helmreleases within a tenant can only use targetNamespaces, which are within the same tenant or the same namespace the resource is deployed in:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: tenant-compare
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: Validate HelmRelease/Kustomization Target Namespace
      context:

        # Get tenant based on target namespace
        - name: destination_tenant
          apiCall:
            urlPath: "/api/v1/namespaces/{{request.object.spec.targetNamespace}}"
            jmesPath: "metadata.labels.\"capsule.clastix.io/tenant\""

        # Get tenant based on resource namespace    
        - name: source_tenant
          apiCall:
            urlPath: "/api/v1/namespaces/{{request.object.metadata.namespace}}"
            jmesPath: "metadata.labels.\"capsule.clastix.io/tenant\""
      match:
        any:
        - resources:
            kinds:
              - HelmRelease
              - Kustomization
            operations:
              - CREATE
              - UPDATE
            namespaceSelector:
              matchExpressions:
                - key: "capsule.clastix.io/tenant"
                  operator: Exists
      preconditions:
        all:
          - key: "{{request.object.spec.targetNamespace}}"
            operator: NotIn
            values: [ "{{request.object.metadata.namespace}}" ]
      validate:
        message: "spec.targetNamespace must be in the same tenant ({{source_tenant}})"
        deny:
          conditions:
            - key: "{{source_tenant}}"
              operator: NotEquals
              value:  "{{destination_tenant}}"
```

### Using Global Configuration


When creating a a lot of policies, you might want to abstract your configuration into a global configuration. This is a good practice to avoid duplication and to have a single source of truth. Also if we introduce breaking changes (like changing the label name), we only have to change it in one place. Here is an example of a global configuration:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kyverno-global-config
  namespace: kyverno-system
data:
  # Label for public namespaces
  public_identifier_label: "company.com/public"
  # Value for Label for public namespaces
  public_identifier_value: "yeet"
  # Label which is used to select the tenant name
  tenant_identifier_label: "capsule.clastix.io/tenant"
```

This configuration can be referenced via [context](https://kyverno.io/docs/writing-policies/external-data-sources/#variables-from-configmaps) in your policies. Let's extend the above policy with the global configuration. Additionally we would like to allow the usage of public namespaces:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: tenant-compare
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: Validate HelmRelease/Kustomization Target Namespace
      context:

        # Load Gloabl Configuration
        - name: global
          configMap:
            name: kyverno-global-config
            namespace: kyverno-system

        # Get All Public Namespaces based on the label and it's value from the global configuration
        - name: public_namespaces
          apiCall:
            urlPath: "/api/v1/namespaces"
            jmesPath: "items[?metadata.labels.\"{{global.data.public_identifier_label}}\" == '{{global.data.public_identifier_value}}'].metadata.name | []" 

        # Get Tenant information from source namespace
        # Defaults to a character, which can't be a label value
        - name: source_tenant
          apiCall:
            urlPath: "/api/v1/namespaces/{{request.object.metadata.namespace}}"
            jmesPath: "metadata.labels.\"{{global.data.tenant_identifier_label}}\" | '?'"

        # Get Tenant information from destination namespace
        # Returns Array with Tenant Name or Empty
        - name: destination_tenant
          apiCall:
            urlPath: "/api/v1/namespaces"
            jmesPath: "items[?metadata.name == '{{request.object.spec.targetNamespace}}'].metadata.labels.\"{{global.data.tenant_identifier_label}}\""

      preconditions:
        all:
          - key: "{{request.object.spec.targetNamespace}}"
            operator: NotIn
            values: [ "{{request.object.metadata.namespace}}" ]
        any: 
          # Source is not Self-Reference  
          - key: "{{request.object.spec.targetNamespace}}"
            operator: NotEquals
            value: "{{request.object.metadata.namespace}}"

          # Source not in Public Namespaces
          - key: "{{request.object.spec.targetNamespace}}"
            operator: NotIn
            value: "{{public_namespaces}}"

          # Source not in Destination
          - key: "{{request.object.spec.targetNamespace}}"
            operator: NotIn
            value: "{{destination_tenant}}"
      match:
        any:
        - resources:
            kinds:
              - HelmRelease
              - Kustomization
            operations:
              - CREATE
              - UPDATE
            namespaceSelector:
              matchExpressions:
                - key: "capsule.clastix.io/tenant"
                  operator: Exists
      validate:
        message: "Can not use namespace {{request.object.spec.chart.spec.sourceRef.namespace}} as source reference!"
        deny: {}

```

### Extended Validation and Defaulting

Here's extended examples for using validation and defaulting. The first policy is used to validate the tenant name. The second policy is used to default the tenant properties, you as cluster-administrator would like to enforce for each tenant.

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: tenant-core
spec:
  validationFailureAction: Enforce
  rules:
  - name: tenant-name
    match:
      all:
      - resources:
          kinds:
          - "capsule.clastix.io/v1beta2/Tenant"
          operations:
          - CREATE
          - UPDATE
    validate:
      message: "Using this tenant name is not allowed."
      deny:
        conditions:
          - key: "{{ request.object.metadata.name }}"
            operator: In
            value: ["default", "cluster-system" ]

  - name: tenant-properties
    match:
      any:
      - resources:
          kinds:
          - "capsule.clastix.io/v1beta2/Tenant"
          operations:
          - CREATE
          - UPDATE
    mutate:
      patchesJson6902: |-
        - op: add
          path: "/spec/namespaceOptions/forbiddenLabels/deniedRegex"
          value: ".*company.ch"
        - op: add
          path: "/spec/priorityClasses/matchLabels"
          value:
            consumer: "customer"
        - op: add
          path: "/spec/serviceOptions/allowedServices/nodePort"
          value: false
        - op: add
          path: "/spec/ingressOptions/allowedClasses/matchLabels"
          value:
            consumer: "customer"
        - op: add
          path: "/spec/storageClasses/matchLabels"
          value:
            consumer: "customer"
        - op: add
          path: "/spec/nodeSelector"
          value:
            nodepool: "workers"
  


```

### Adding Default Owners/Permissions to Tenant

Since the [Owners Spec](/docs/tenants/permissions/#ownership) is a list, it's a bit more trickier to add a default owner without causing recursions. You must make sure, to validate if the value you are setting is already present. Otherwise you will create a loop. Here is an example of a policy, which adds the `cluster:admin` as owner to a tenant:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: tenant-policy
spec:
  validationFailureAction: Enforce
  background: true
  rules:

  # With this policy for each tenant cluster:admin is added as owner.
  # Only Append these on CREATE, otherwise they will be added per reconciliation and create a loop.
  - name: tenant-owner
    preconditions:
      all:
      - key: "cluster:admin"
        operator: NotIn
        value: "{{ request.object.spec.owners[?kind == 'Group'].name }}"
    match:
      all:
      - resources:
          kinds:
          - "capsule.clastix.io/v1beta2/Tenant"
          operations:
          - CREATE
          - UPDATE
    mutate:
      patchesJson6902: |-
        - op: add
          path: "/spec/owners/-"
          value:
            name: "cluster:admin"
            kind: "Group"

  # With this policy for each tenant a default ProxySettings are added.
  # Completely overwrites the ProxySettings, if they are already present.
  - name: tenant-proxy-settings
    match:
      any:
      - resources:
          kinds:
          - "capsule.clastix.io/v1beta2/Tenant"
          operations:
          - CREATE
          - UPDATE
    mutate:
      foreach:
      - list: "request.object.spec.owners"
        patchesJson6902: |-
          - path: /spec/owners/{{elementIndex}}/proxySettings
            op: add
            value:
              - kind: IngressClasses
                operations:
                - List
              - kind: StorageClasses
                operations:
                - List
              - kind: PriorityClasses
                operations:
                - List
              - kind: Nodes
                operations:
                - List
```