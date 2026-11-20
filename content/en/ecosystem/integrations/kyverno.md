---
title: Kyverno
description: Capsule integration with Kyverno
logo: "https://github.com/cncf/artwork/raw/refs/heads/main/projects/kyverno/icon/color/kyverno-icon-color.svg"
type: single
display: true
integration: true
---

[Kyverno](https://kyverno.io) is a policy engine designed for Kubernetes. It provides the ability to validate, mutate, and generate Kubernetes resources using admission control. Kyverno policies are managed as Kubernetes resources and can be applied to a cluster using kubectl. Capsule integrates with Kyverno to provide a set of policies that can be used to improve the security and governance of the Kubernetes cluster.

## Permissions

Some policies query Capsule specific information, such as the Tenant status. Therefore, we need to ensure that Kyverno has the necessary permissions to read Capsule resources. This can be achieved by extending the Kyverno ClusterRole to include Capsule resources:

```yaml
admissionController:
  rbac:
    clusterRole:
      extraResources:
       - apiGroups: ["capsule.clastix.io"]
         resources: ["*"]
         verbs: ["get", "list"]
```

## Recommended Policies

Not all relevant settings are covered by Capsule. We recommend to use Kyverno to enforce additional policies, as their policy implementation is of a very high standard. Here are some policies you might want to consider in multi-tenant environments:

[Moved to new page](/docs/operating/concepts/architecture/)

## References

Here are some policies for reference. We do not provide a complete list of policies, but we provide some examples to get you started. This policies are not meant to be used in production. You may adopt principles shown here to create your own policies.

The examples use the `policies.kyverno.io/v1` API (`ValidatingPolicy` and `MutatingPolicy`). The legacy `kyverno.io/v1` `ClusterPolicy` is deprecated, and Kyverno 1.20 no longer accepts it.

### Extract tenant based on namespace

To get the tenant name based on the namespace, you can use the `namespaceObject` variable, which holds the Namespace of the requested resource. The `capsule.clastix.io/tenant` label is read optionally. You could assign a default if nothing was found, in this case it's an empty string. To read other objects, use the `resource.Get` and `resource.List` functions of the [Kyverno CEL libraries](https://kyverno.io/docs/policy-types/cel-libraries/):

```yaml
  variables:
    - name: tenant_name
      expression: namespaceObject.metadata.?labels[?'capsule.clastix.io/tenant'].orValue('')
```


### Select namespaces with label `capsule.clastix.io/tenant`

When you are performing a policy on namespaced objects, you can select the objects, which are within a tenant namespace by using the `namespaceSelector`. In this example we select all `Kustomization` and `HelmRelease` resources which are within a tenant namespace and default `targetNamespace` and `serviceAccountName`, if they are not set:

```yaml
apiVersion: policies.kyverno.io/v1
kind: MutatingPolicy
metadata:
  name: flux-policies
spec:
  evaluation:
    background:
      enabled: false
  matchConstraints:
    namespaceSelector:
      matchExpressions:
        - key: capsule.clastix.io/tenant
          operator: Exists
    resourceRules:
      - apiGroups: ["kustomize.toolkit.fluxcd.io"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["kustomizations"]
      - apiGroups: ["helm.toolkit.fluxcd.io"]
        apiVersions: ["v2"]
        operations: ["CREATE", "UPDATE"]
        resources: ["helmreleases"]
  mutations:
    - patchType: JSONPatch
      jsonPatch:
        expression: >-
          has(object.spec.targetNamespace) ? [] :
          [JSONPatch{op: "add", path: "/spec/targetNamespace", value: object.metadata.namespace}]
    - patchType: JSONPatch
      jsonPatch:
        expression: >-
          has(object.spec.serviceAccountName) ? [] :
          [JSONPatch{op: "add", path: "/spec/serviceAccountName", value: "default"}]
```


### Compare Source and Destination Tenant

With this policy we try to enforce, that HelmReleases and Kustomizations within a tenant can only use targetNamespaces, which are within the same tenant or the same namespace the resource is deployed in. A HelmRelease without `spec.targetNamespace` is deployed in its own namespace. A Kustomization without it can deploy into any namespace named in its manifests, so `spec.targetNamespace` is required for Kustomizations:

```yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: tenant-compare
spec:
  validationActions: [Deny]
  evaluation:
    background:
      enabled: false
  matchConstraints:
    namespaceSelector:
      matchExpressions:
        - key: capsule.clastix.io/tenant
          operator: Exists
    resourceRules:
      - apiGroups: ["kustomize.toolkit.fluxcd.io"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["kustomizations"]
      - apiGroups: ["helm.toolkit.fluxcd.io"]
        apiVersions: ["v2"]
        operations: ["CREATE", "UPDATE"]
        resources: ["helmreleases"]
  variables:
    - name: source
      expression: namespaceObject.metadata.labels['capsule.clastix.io/tenant']
    # Only a HelmRelease is deployed in its own namespace by default.
    - name: target
      expression: >-
        object.spec.?targetNamespace.orValue(object.kind == 'HelmRelease' ? object.metadata.namespace : '')
    - name: destination
      expression: >-
        variables.target == '' ? '' :
        dyn(resource.Get("v1", "namespaces", "", variables.target)).?metadata.labels[?'capsule.clastix.io/tenant'].orValue('')
  validations:
    - expression: >-
        variables.target != '' &&
        (variables.target == object.metadata.namespace || variables.destination == variables.source)
      messageExpression: "'spec.targetNamespace must be set to a namespace in the same tenant (' + variables.source + ')'"
```

### Using Global Configuration


When creating a lot of policies, you might want to abstract your configuration into a global configuration. This is a good practice to avoid duplication and to have a single source of truth. Also if we introduce breaking changes (like changing the label name), we only have to change it in one place. Here is an example of a global configuration:

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

This configuration can be read in your policies with `resource.Get`. Let's extend the above policy with the global configuration. Additionally we would like to allow the usage of public namespaces:

```yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: tenant-compare
spec:
  validationActions: [Deny]
  evaluation:
    background:
      enabled: false
  matchConstraints:
    namespaceSelector:
      matchExpressions:
        - key: capsule.clastix.io/tenant
          operator: Exists
    resourceRules:
      - apiGroups: ["kustomize.toolkit.fluxcd.io"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["kustomizations"]
      - apiGroups: ["helm.toolkit.fluxcd.io"]
        apiVersions: ["v2"]
        operations: ["CREATE", "UPDATE"]
        resources: ["helmreleases"]
  variables:
    # Load Global Configuration
    - name: global
      expression: dyn(resource.Get("v1", "configmaps", "kyverno-system", "kyverno-global-config")).data
    # Only a HelmRelease is deployed in its own namespace by default.
    - name: target
      expression: >-
        object.spec.?targetNamespace.orValue(object.kind == 'HelmRelease' ? object.metadata.namespace : '')
    # Labels of the target namespace
    - name: destination
      expression: >-
        variables.target == '' ? dyn({}) :
        dyn(resource.Get("v1", "namespaces", "", variables.target)).?metadata.labels.orValue({})
    # Defaults to a character, which can't be a label value
    - name: source_tenant
      expression: namespaceObject.metadata.?labels[?variables.global.tenant_identifier_label].orValue('?')
  validations:
    - expression: >-
        variables.target != '' && (
          variables.target == object.metadata.namespace ||
          variables.destination[?variables.global.public_identifier_label].orValue('') == variables.global.public_identifier_value ||
          variables.destination[?variables.global.tenant_identifier_label].orValue('') == variables.source_tenant)
      messageExpression: >-
        variables.target == '' ? 'spec.targetNamespace must be set' :
        'Can not use namespace ' + variables.target + ' as target namespace!'
```

### Extended Validation and Defaulting

Here's extended examples for using validation and defaulting. The first policy is used to validate the tenant name. The second policy is used to default the tenant properties, you as cluster-administrator would like to enforce for each tenant. The class selectors of the Tenant are atomic and can't be applied, therefore they are patched. Existing values are kept:

```yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: tenant-name
spec:
  validationActions: [Deny]
  evaluation:
    background:
      enabled: false
  matchConstraints:
    resourceRules:
      - apiGroups: ["capsule.clastix.io"]
        apiVersions: ["v1beta2"]
        operations: ["CREATE", "UPDATE"]
        resources: ["tenants"]
  validations:
    - expression: "!(object.metadata.name in ['default', 'cluster-system'])"
      message: "Using this tenant name is not allowed."
---
apiVersion: policies.kyverno.io/v1
kind: MutatingPolicy
metadata:
  name: tenant-properties
spec:
  evaluation:
    background:
      enabled: false
  matchConstraints:
    resourceRules:
      - apiGroups: ["capsule.clastix.io"]
        apiVersions: ["v1beta2"]
        operations: ["CREATE", "UPDATE"]
        resources: ["tenants"]
  mutations:
    - patchType: ApplyConfiguration
      applyConfiguration:
        expression: >-
          Object{
            spec: Object.spec{
              namespaceOptions: Object.spec.namespaceOptions{
                forbiddenLabels: Object.spec.namespaceOptions.forbiddenLabels{deniedRegex: ".*company.ch"}
              },
              serviceOptions: Object.spec.serviceOptions{
                allowedServices: Object.spec.serviceOptions.allowedServices{nodePort: false}
              },
              nodeSelector: {"nodepool": "workers"}
            }
          }
    # The class selectors are atomic, they can't be applied, only patched.
    - patchType: JSONPatch
      jsonPatch:
        expression: >-
          [
            has(object.spec.priorityClasses)
              ? JSONPatch{op: "add", path: "/spec/priorityClasses/matchLabels", value: {"consumer": "customer"}}
              : JSONPatch{op: "add", path: "/spec/priorityClasses", value: {"matchLabels": {"consumer": "customer"}}},
            has(object.spec.storageClasses)
              ? JSONPatch{op: "add", path: "/spec/storageClasses/matchLabels", value: {"consumer": "customer"}}
              : JSONPatch{op: "add", path: "/spec/storageClasses", value: {"matchLabels": {"consumer": "customer"}}},
            !has(object.spec.ingressOptions)
              ? JSONPatch{op: "add", path: "/spec/ingressOptions", value: {"allowedClasses": {"matchLabels": {"consumer": "customer"}}}}
              : !has(object.spec.ingressOptions.allowedClasses)
                ? JSONPatch{op: "add", path: "/spec/ingressOptions/allowedClasses", value: {"matchLabels": {"consumer": "customer"}}}
                : JSONPatch{op: "add", path: "/spec/ingressOptions/allowedClasses/matchLabels", value: {"consumer": "customer"}}
          ]
```

### Adding Default Owners/Permissions to Tenant

Since the [Owners Spec](/docs/tenants/permissions/#ownership) is a list, it's a bit more trickier to add a default owner without causing recursions. You must make sure, to validate if the value you are setting is already present. Otherwise you will create a loop. Here is an example of a policy, which adds the `cluster:admin` as owner to a tenant and sets default ProxySettings for all owners:

```yaml
apiVersion: policies.kyverno.io/v1
kind: MutatingPolicy
metadata:
  name: tenant-policy
spec:
  evaluation:
    background:
      enabled: false
  matchConstraints:
    resourceRules:
      - apiGroups: ["capsule.clastix.io"]
        apiVersions: ["v1beta2"]
        operations: ["CREATE", "UPDATE"]
        resources: ["tenants"]
  mutations:
    # With this policy for each tenant cluster:admin is added as owner.
    # Only append if it is not present yet, otherwise it would be added on every update.
    # Both spec and spec.owners are optional, create them if they are missing.
    - patchType: JSONPatch
      jsonPatch:
        expression: >-
          object.?spec.owners.orValue([]).exists(o, o.kind == 'Group' && o.name == 'cluster:admin') ? [] :
          !has(object.spec)
            ? [JSONPatch{op: "add", path: "/spec", value: {"owners": [{"name": "cluster:admin", "kind": "Group"}]}}]
            : !has(object.spec.owners)
              ? [JSONPatch{op: "add", path: "/spec/owners", value: [{"name": "cluster:admin", "kind": "Group"}]}]
              : [JSONPatch{op: "add", path: "/spec/owners/-", value: {"name": "cluster:admin", "kind": "Group"}}]
    # With this policy each owner gets default ProxySettings.
    # Completely overwrites the ProxySettings, if they are already present.
    - patchType: JSONPatch
      jsonPatch:
        expression: >-
          lists.range(size(object.?spec.owners.orValue([]))).map(i,
            JSONPatch{
              op: "add",
              path: "/spec/owners/" + string(i) + "/proxySettings",
              value: [
                {"kind": dyn("IngressClasses"), "operations": dyn(["List"])},
                {"kind": dyn("StorageClasses"), "operations": dyn(["List"])},
                {"kind": dyn("PriorityClasses"), "operations": dyn(["List"])},
                {"kind": dyn("Nodes"), "operations": dyn(["List"])}
              ]
            })
```
