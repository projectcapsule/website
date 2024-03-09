---
title: Kyverno
describtion: Capsule interation with Kyverno
---

[Kyverno](https://kyverno.io) is a policy engine designed for Kubernetes. It provides the ability to validate, mutate, and generate Kubernetes resources using admission control. Kyverno policies are managed as Kubernetes resources and can be applied to a cluster using kubectl. Capsule integrates with Kyverno to provide a set of policies that can be used to improve the security and governance of the Kubernetes cluster.

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