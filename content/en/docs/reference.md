---
title: API Reference
description: >
  API Reference
weight: 100
---
Packages:

- [capsule.clastix.io/v1beta2](#capsuleclastixiov1beta2)
- [capsule.clastix.io/v1beta1](#capsuleclastixiov1beta1)

# capsule.clastix.io/v1beta2

Resource Types:

- [CapsuleConfiguration](#capsuleconfiguration)

- [GlobalTenantResource](#globaltenantresource)

- [TenantResource](#tenantresource)

- [Tenant](#tenant)




## CapsuleConfiguration






CapsuleConfiguration is the Schema for the Capsule configuration API.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta2 | true |
| **kind** | string | CapsuleConfiguration | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#capsuleconfigurationspec)** | object | CapsuleConfigurationSpec defines the Capsule configuration. | false |


### CapsuleConfiguration.spec



CapsuleConfigurationSpec defines the Capsule configuration.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **enableTLSReconciler** | boolean | Toggles the TLS reconciler, the controller that is able to generate CA and certificates for the webhooks<br>when not using an already provided CA and certificate, or when these are managed externally with Vault, or cert-manager.<br/>*Default*: true<br/> | true |
| **forceTenantPrefix** | boolean | Enforces the Tenant owner, during Namespace creation, to name it using the selected Tenant name as prefix,<br>separated by a dash. This is useful to avoid Namespace name collision in a public CaaS environment.<br/>*Default*: false<br/> | false |
| **[nodeMetadata](#capsuleconfigurationspecnodemetadata)** | object | Allows to set the forbidden metadata for the worker nodes that could be patched by a Tenant.<br>This applies only if the Tenant has an active NodeSelector, and the Owner have right to patch their nodes. | false |
| **[overrides](#capsuleconfigurationspecoverrides)** | object | Allows to set different name rather than the canonical one for the Capsule configuration objects,<br>such as webhook secret or configurations.<br/>*Default*: map[TLSSecretName:capsule-tls mutatingWebhookConfigurationName:capsule-mutating-webhook-configuration validatingWebhookConfigurationName:capsule-validating-webhook-configuration]<br/> | false |
| **protectedNamespaceRegex** | string | Disallow creation of namespaces, whose name matches this regexp | false |
| **userGroups** | []string | Names of the groups for Capsule users.<br/>*Default*: [capsule.clastix.io]<br/> | false |


### CapsuleConfiguration.spec.nodeMetadata



Allows to set the forbidden metadata for the worker nodes that could be patched by a Tenant.
This applies only if the Tenant has an active NodeSelector, and the Owner have right to patch their nodes.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[forbiddenAnnotations](#capsuleconfigurationspecnodemetadataforbiddenannotations)** | object | Define the annotations that a Tenant Owner cannot set for their nodes. | true |
| **[forbiddenLabels](#capsuleconfigurationspecnodemetadataforbiddenlabels)** | object | Define the labels that a Tenant Owner cannot set for their nodes. | true |


### CapsuleConfiguration.spec.nodeMetadata.forbiddenAnnotations



Define the annotations that a Tenant Owner cannot set for their nodes.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **denied** | []string |  | false |
| **deniedRegex** | string |  | false |


### CapsuleConfiguration.spec.nodeMetadata.forbiddenLabels



Define the labels that a Tenant Owner cannot set for their nodes.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **denied** | []string |  | false |
| **deniedRegex** | string |  | false |


### CapsuleConfiguration.spec.overrides



Allows to set different name rather than the canonical one for the Capsule configuration objects,
such as webhook secret or configurations.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **TLSSecretName** | string | Defines the Secret name used for the webhook server.<br>Must be in the same Namespace where the Capsule Deployment is deployed.<br/>*Default*: capsule-tls<br/> | true |
| **mutatingWebhookConfigurationName** | string | Name of the MutatingWebhookConfiguration which contains the dynamic admission controller paths and resources.<br/>*Default*: capsule-mutating-webhook-configuration<br/> | true |
| **validatingWebhookConfigurationName** | string | Name of the ValidatingWebhookConfiguration which contains the dynamic admission controller paths and resources.<br/>*Default*: capsule-validating-webhook-configuration<br/> | true |

## GlobalTenantResource






GlobalTenantResource allows to propagate resource replications to a specific subset of Tenant resources.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta2 | true |
| **kind** | string | GlobalTenantResource | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#globaltenantresourcespec)** | object | GlobalTenantResourceSpec defines the desired state of GlobalTenantResource. | false |
| **[status](#globaltenantresourcestatus)** | object | GlobalTenantResourceStatus defines the observed state of GlobalTenantResource. | false |


### GlobalTenantResource.spec



GlobalTenantResourceSpec defines the desired state of GlobalTenantResource.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[resources](#globaltenantresourcespecresourcesindex)** | []object | Defines the rules to select targeting Namespace, along with the objects that must be replicated. | true |
| **resyncPeriod** | string | Define the period of time upon a second reconciliation must be invoked.<br>Keep in mind that any change to the manifests will trigger a new reconciliation.<br/>*Default*: 60s<br/> | true |
| **pruningOnDelete** | boolean | When the replicated resource manifest is deleted, all the objects replicated so far will be automatically deleted.<br>Disable this to keep replicated resources although the deletion of the replication manifest.<br/>*Default*: true<br/> | false |
| **[tenantSelector](#globaltenantresourcespectenantselector)** | object | Defines the Tenant selector used target the tenants on which resources must be propagated. | false |


### GlobalTenantResource.spec.resources[index]





| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[additionalMetadata](#globaltenantresourcespecresourcesindexadditionalmetadata)** | object | Besides the Capsule metadata required by TenantResource controller, defines additional metadata that must be<br>added to the replicated resources. | false |
| **[namespaceSelector](#globaltenantresourcespecresourcesindexnamespaceselector)** | object | Defines the Namespace selector to select the Tenant Namespaces on which the resources must be propagated.<br>In case of nil value, all the Tenant Namespaces are targeted. | false |
| **[namespacedItems](#globaltenantresourcespecresourcesindexnamespaceditemsindex)** | []object | List of the resources already existing in other Namespaces that must be replicated. | false |
| **rawItems** | []RawExtension | List of raw resources that must be replicated. | false |


### GlobalTenantResource.spec.resources[index].additionalMetadata



Besides the Capsule metadata required by TenantResource controller, defines additional metadata that must be
added to the replicated resources.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **annotations** | map[string]string |  | false |
| **labels** | map[string]string |  | false |


### GlobalTenantResource.spec.resources[index].namespaceSelector



Defines the Namespace selector to select the Tenant Namespaces on which the resources must be propagated.
In case of nil value, all the Tenant Namespaces are targeted.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#globaltenantresourcespecresourcesindexnamespaceselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### GlobalTenantResource.spec.resources[index].namespaceSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### GlobalTenantResource.spec.resources[index].namespacedItems[index]





| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | string | Kind of the referent.<br>More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds | true |
| **namespace** | string | Namespace of the referent.<br>More info: https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/ | true |
| **[selector](#globaltenantresourcespecresourcesindexnamespaceditemsindexselector)** | object | Label selector used to select the given resources in the given Namespace. | true |
| **apiVersion** | string | API version of the referent. | false |


### GlobalTenantResource.spec.resources[index].namespacedItems[index].selector



Label selector used to select the given resources in the given Namespace.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#globaltenantresourcespecresourcesindexnamespaceditemsindexselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### GlobalTenantResource.spec.resources[index].namespacedItems[index].selector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### GlobalTenantResource.spec.tenantSelector



Defines the Tenant selector used target the tenants on which resources must be propagated.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#globaltenantresourcespectenantselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### GlobalTenantResource.spec.tenantSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### GlobalTenantResource.status



GlobalTenantResourceStatus defines the observed state of GlobalTenantResource.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[processedItems](#globaltenantresourcestatusprocesseditemsindex)** | []object | List of the replicated resources for the given TenantResource. | true |
| **selectedTenants** | []string | List of Tenants addressed by the GlobalTenantResource. | true |


### GlobalTenantResource.status.processedItems[index]





| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | string | Kind of the referent.<br>More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds | true |
| **name** | string | Name of the referent.<br>More info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names | true |
| **namespace** | string | Namespace of the referent.<br>More info: https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/ | true |
| **apiVersion** | string | API version of the referent. | false |

## TenantResource






TenantResource allows a Tenant Owner, if enabled with proper RBAC, to propagate resources in its Namespace.
The object must be deployed in a Tenant Namespace, and cannot reference object living in non-Tenant namespaces.
For such cases, the GlobalTenantResource must be used.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta2 | true |
| **kind** | string | TenantResource | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#tenantresourcespec)** | object | TenantResourceSpec defines the desired state of TenantResource. | false |
| **[status](#tenantresourcestatus)** | object | TenantResourceStatus defines the observed state of TenantResource. | false |


### TenantResource.spec



TenantResourceSpec defines the desired state of TenantResource.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[resources](#tenantresourcespecresourcesindex)** | []object | Defines the rules to select targeting Namespace, along with the objects that must be replicated. | true |
| **resyncPeriod** | string | Define the period of time upon a second reconciliation must be invoked.<br>Keep in mind that any change to the manifests will trigger a new reconciliation.<br/>*Default*: 60s<br/> | true |
| **pruningOnDelete** | boolean | When the replicated resource manifest is deleted, all the objects replicated so far will be automatically deleted.<br>Disable this to keep replicated resources although the deletion of the replication manifest.<br/>*Default*: true<br/> | false |


### TenantResource.spec.resources[index]





| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[additionalMetadata](#tenantresourcespecresourcesindexadditionalmetadata)** | object | Besides the Capsule metadata required by TenantResource controller, defines additional metadata that must be<br>added to the replicated resources. | false |
| **[namespaceSelector](#tenantresourcespecresourcesindexnamespaceselector)** | object | Defines the Namespace selector to select the Tenant Namespaces on which the resources must be propagated.<br>In case of nil value, all the Tenant Namespaces are targeted. | false |
| **[namespacedItems](#tenantresourcespecresourcesindexnamespaceditemsindex)** | []object | List of the resources already existing in other Namespaces that must be replicated. | false |
| **rawItems** | []RawExtension | List of raw resources that must be replicated. | false |


### TenantResource.spec.resources[index].additionalMetadata



Besides the Capsule metadata required by TenantResource controller, defines additional metadata that must be
added to the replicated resources.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **annotations** | map[string]string |  | false |
| **labels** | map[string]string |  | false |


### TenantResource.spec.resources[index].namespaceSelector



Defines the Namespace selector to select the Tenant Namespaces on which the resources must be propagated.
In case of nil value, all the Tenant Namespaces are targeted.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantresourcespecresourcesindexnamespaceselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### TenantResource.spec.resources[index].namespaceSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### TenantResource.spec.resources[index].namespacedItems[index]





| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | string | Kind of the referent.<br>More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds | true |
| **namespace** | string | Namespace of the referent.<br>More info: https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/ | true |
| **[selector](#tenantresourcespecresourcesindexnamespaceditemsindexselector)** | object | Label selector used to select the given resources in the given Namespace. | true |
| **apiVersion** | string | API version of the referent. | false |


### TenantResource.spec.resources[index].namespacedItems[index].selector



Label selector used to select the given resources in the given Namespace.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantresourcespecresourcesindexnamespaceditemsindexselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### TenantResource.spec.resources[index].namespacedItems[index].selector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### TenantResource.status



TenantResourceStatus defines the observed state of TenantResource.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[processedItems](#tenantresourcestatusprocesseditemsindex)** | []object | List of the replicated resources for the given TenantResource. | true |


### TenantResource.status.processedItems[index]





| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | string | Kind of the referent.<br>More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds | true |
| **name** | string | Name of the referent.<br>More info: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#names | true |
| **namespace** | string | Namespace of the referent.<br>More info: https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/ | true |
| **apiVersion** | string | API version of the referent. | false |

## Tenant






Tenant is the Schema for the tenants API.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta2 | true |
| **kind** | string | Tenant | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#tenantspec-1)** | object | TenantSpec defines the desired state of Tenant. | false |
| **[status](#tenantstatus-1)** | object | Returns the observed state of the Tenant. | false |


### Tenant.spec



TenantSpec defines the desired state of Tenant.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[owners](#tenantspecownersindex-1)** | []object | Specifies the owners of the Tenant. Mandatory. | true |
| **[additionalRoleBindings](#tenantspecadditionalrolebindingsindex-1)** | []object | Specifies additional RoleBindings assigned to the Tenant. Capsule will ensure that all namespaces in the Tenant always contain the RoleBinding for the given ClusterRole. Optional. | false |
| **[containerRegistries](#tenantspeccontainerregistries-1)** | object | Specifies the trusted Image Registries assigned to the Tenant. Capsule assures that all Pods resources created in the Tenant can use only one of the allowed trusted registries. Optional. | false |
| **cordoned** | boolean | Toggling the Tenant resources cordoning, when enable resources cannot be deleted.<br/>*Default*: false<br/> | false |
| **forceTenantPrefix** | boolean | Use this if you want to disable/enable the Tenant name prefix to specific Tenants, overriding global forceTenantPrefix in CapsuleConfiguration.<br>When set to 'true', it enforces Namespaces created for this Tenant to be named with the Tenant name prefix,<br>separated by a dash (i.e. for Tenant 'foo', namespace names must be prefixed with 'foo-'),<br>this is useful to avoid Namespace name collision.<br>When set to 'false', it allows Namespaces created for this Tenant to be named anything.<br>Overrides CapsuleConfiguration global forceTenantPrefix for the Tenant only.<br>If unset, Tenant uses CapsuleConfiguration's forceTenantPrefix<br>Optional | false |
| **imagePullPolicies** | []enum | Specify the allowed values for the imagePullPolicies option in Pod resources. Capsule assures that all Pod resources created in the Tenant can use only one of the allowed policy. Optional.<br/>*Enum*: Always, Never, IfNotPresent<br/> | false |
| **[ingressOptions](#tenantspecingressoptions-1)** | object | Specifies options for the Ingress resources, such as allowed hostnames and IngressClass. Optional. | false |
| **[limitRanges](#tenantspeclimitranges-1)** | object | Specifies the resource min/max usage restrictions to the Tenant. The assigned values are inherited by any namespace created in the Tenant. Optional. | false |
| **[namespaceOptions](#tenantspecnamespaceoptions-1)** | object | Specifies options for the Namespaces, such as additional metadata or maximum number of namespaces allowed for that Tenant. Once the namespace quota assigned to the Tenant has been reached, the Tenant owner cannot create further namespaces. Optional. | false |
| **[networkPolicies](#tenantspecnetworkpolicies-1)** | object | Specifies the NetworkPolicies assigned to the Tenant. The assigned NetworkPolicies are inherited by any namespace created in the Tenant. Optional. | false |
| **nodeSelector** | map[string]string | Specifies the label to control the placement of pods on a given pool of worker nodes. All namespaces created within the Tenant will have the node selector annotation. This annotation tells the Kubernetes scheduler to place pods on the nodes having the selector label. Optional. | false |
| **[podOptions](#tenantspecpodoptions)** | object | Specifies options for the Pods deployed in the Tenant namespaces, such as additional metadata. | false |
| **preventDeletion** | boolean | Prevent accidental deletion of the Tenant.<br>When enabled, the deletion request will be declined.<br/>*Default*: false<br/> | false |
| **[priorityClasses](#tenantspecpriorityclasses-1)** | object | Specifies the allowed priorityClasses assigned to the Tenant.<br>Capsule assures that all Pods resources created in the Tenant can use only one of the allowed PriorityClasses.<br>A default value can be specified, and all the Pod resources created will inherit the declared class.<br>Optional. | false |
| **[resourceQuotas](#tenantspecresourcequotas-1)** | object | Specifies a list of ResourceQuota resources assigned to the Tenant. The assigned values are inherited by any namespace created in the Tenant. The Capsule operator aggregates ResourceQuota at Tenant level, so that the hard quota is never crossed for the given Tenant. This permits the Tenant owner to consume resources in the Tenant regardless of the namespace. Optional. | false |
| **[runtimeClasses](#tenantspecruntimeclasses)** | object | Specifies the allowed RuntimeClasses assigned to the Tenant.<br>Capsule assures that all Pods resources created in the Tenant can use only one of the allowed RuntimeClasses.<br>Optional. | false |
| **[serviceOptions](#tenantspecserviceoptions-1)** | object | Specifies options for the Service, such as additional metadata or block of certain type of Services. Optional. | false |
| **[storageClasses](#tenantspecstorageclasses-1)** | object | Specifies the allowed StorageClasses assigned to the Tenant.<br>Capsule assures that all PersistentVolumeClaim resources created in the Tenant can use only one of the allowed StorageClasses.<br>A default value can be specified, and all the PersistentVolumeClaim resources created will inherit the declared class.<br>Optional. | false |


### Tenant.spec.owners[index]





| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | enum | Kind of tenant owner. Possible values are "User", "Group", and "ServiceAccount"<br/>*Enum*: User, Group, ServiceAccount<br/> | true |
| **name** | string | Name of tenant owner. | true |
| **clusterRoles** | []string | Defines additional cluster-roles for the specific Owner.<br/>*Default*: [admin capsule-namespace-deleter]<br/> | false |
| **[proxySettings](#tenantspecownersindexproxysettingsindex-1)** | []object | Proxy settings for tenant owner. | false |


### Tenant.spec.owners[index].proxySettings[index]





| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | enum | <br/>*Enum*: Nodes, StorageClasses, IngressClasses, PriorityClasses, RuntimeClasses, PersistentVolumes<br/> | true |
| **operations** | []enum | <br/>*Enum*: List, Update, Delete<br/> | true |


### Tenant.spec.additionalRoleBindings[index]





| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **clusterRoleName** | string |  | true |
| **[subjects](#tenantspecadditionalrolebindingsindexsubjectsindex-1)** | []object | kubebuilder:validation:Minimum=1 | true |


### Tenant.spec.additionalRoleBindings[index].subjects[index]



Subject contains a reference to the object or user identities a role binding applies to.  This can either hold a direct API object reference,
or a value for non-objects such as user and group names.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | string | Kind of object being referenced. Values defined by this API group are "User", "Group", and "ServiceAccount".<br>If the Authorizer does not recognized the kind value, the Authorizer should report an error. | true |
| **name** | string | Name of the object being referenced. | true |
| **apiGroup** | string | APIGroup holds the API group of the referenced subject.<br>Defaults to "" for ServiceAccount subjects.<br>Defaults to "rbac.authorization.k8s.io" for User and Group subjects. | false |
| **namespace** | string | Namespace of the referenced object.  If the object kind is non-namespace, such as "User" or "Group", and this value is not empty<br>the Authorizer should report an error. | false |


### Tenant.spec.containerRegistries



Specifies the trusted Image Registries assigned to the Tenant. Capsule assures that all Pods resources created in the Tenant can use only one of the allowed trusted registries. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string |  | false |
| **allowedRegex** | string |  | false |


### Tenant.spec.ingressOptions



Specifies options for the Ingress resources, such as allowed hostnames and IngressClass. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowWildcardHostnames** | boolean | Toggles the ability for Ingress resources created in a Tenant to have a hostname wildcard. | false |
| **[allowedClasses](#tenantspecingressoptionsallowedclasses-1)** | object | Specifies the allowed IngressClasses assigned to the Tenant.<br>Capsule assures that all Ingress resources created in the Tenant can use only one of the allowed IngressClasses.<br>A default value can be specified, and all the Ingress resources created will inherit the declared class.<br>Optional. | false |
| **[allowedHostnames](#tenantspecingressoptionsallowedhostnames-1)** | object | Specifies the allowed hostnames in Ingresses for the given Tenant. Capsule assures that all Ingress resources created in the Tenant can use only one of the allowed hostnames. Optional. | false |
| **hostnameCollisionScope** | enum | Defines the scope of hostname collision check performed when Tenant Owners create Ingress with allowed hostnames.<br><br>- Cluster: disallow the creation of an Ingress if the pair hostname and path is already used across the Namespaces managed by Capsule.<br><br>- Tenant: disallow the creation of an Ingress if the pair hostname and path is already used across the Namespaces of the Tenant.<br><br>- Namespace: disallow the creation of an Ingress if the pair hostname and path is already used in the Ingress Namespace.<br><br>Optional.<br/>*Enum*: Cluster, Tenant, Namespace, Disabled<br/>*Default*: Disabled<br/> | false |


### Tenant.spec.ingressOptions.allowedClasses



Specifies the allowed IngressClasses assigned to the Tenant.
Capsule assures that all Ingress resources created in the Tenant can use only one of the allowed IngressClasses.
A default value can be specified, and all the Ingress resources created will inherit the declared class.
Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string |  | false |
| **allowedRegex** | string |  | false |
| **default** | string |  | false |
| **[matchExpressions](#tenantspecingressoptionsallowedclassesmatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.ingressOptions.allowedClasses.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.spec.ingressOptions.allowedHostnames



Specifies the allowed hostnames in Ingresses for the given Tenant. Capsule assures that all Ingress resources created in the Tenant can use only one of the allowed hostnames. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string |  | false |
| **allowedRegex** | string |  | false |


### Tenant.spec.limitRanges



Specifies the resource min/max usage restrictions to the Tenant. The assigned values are inherited by any namespace created in the Tenant. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[items](#tenantspeclimitrangesitemsindex-1)** | []object |  | false |


### Tenant.spec.limitRanges.items[index]



LimitRangeSpec defines a min/max usage limit for resources that match on kind.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[limits](#tenantspeclimitrangesitemsindexlimitsindex-1)** | []object | Limits is the list of LimitRangeItem objects that are enforced. | true |


### Tenant.spec.limitRanges.items[index].limits[index]



LimitRangeItem defines a min/max usage limit for any resource that matches on kind.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **type** | string | Type of resource that this limit applies to. | true |
| **default** | map[string]int or string | Default resource requirement limit value by resource name if resource limit is omitted. | false |
| **defaultRequest** | map[string]int or string | DefaultRequest is the default resource requirement request value by resource name if resource request is omitted. | false |
| **max** | map[string]int or string | Max usage constraints on this kind by resource name. | false |
| **maxLimitRequestRatio** | map[string]int or string | MaxLimitRequestRatio if specified, the named resource must have a request and limit that are both non-zero where limit divided by request is less than or equal to the enumerated value; this represents the max burst for the named resource. | false |
| **min** | map[string]int or string | Min usage constraints on this kind by resource name. | false |


### Tenant.spec.namespaceOptions



Specifies options for the Namespaces, such as additional metadata or maximum number of namespaces allowed for that Tenant. Once the namespace quota assigned to the Tenant has been reached, the Tenant owner cannot create further namespaces. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[additionalMetadata](#tenantspecnamespaceoptionsadditionalmetadata-1)** | object | Specifies additional labels and annotations the Capsule operator places on any Namespace resource in the Tenant. Optional. | false |
| **[forbiddenAnnotations](#tenantspecnamespaceoptionsforbiddenannotations)** | object | Define the annotations that a Tenant Owner cannot set for their Namespace resources. | false |
| **[forbiddenLabels](#tenantspecnamespaceoptionsforbiddenlabels)** | object | Define the labels that a Tenant Owner cannot set for their Namespace resources. | false |
| **quota** | integer | Specifies the maximum number of namespaces allowed for that Tenant. Once the namespace quota assigned to the Tenant has been reached, the Tenant owner cannot create further namespaces. Optional.<br/>*Format*: int32<br/>*Minimum*: 1<br/> | false |


### Tenant.spec.namespaceOptions.additionalMetadata



Specifies additional labels and annotations the Capsule operator places on any Namespace resource in the Tenant. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **annotations** | map[string]string |  | false |
| **labels** | map[string]string |  | false |


### Tenant.spec.namespaceOptions.forbiddenAnnotations



Define the annotations that a Tenant Owner cannot set for their Namespace resources.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **denied** | []string |  | false |
| **deniedRegex** | string |  | false |


### Tenant.spec.namespaceOptions.forbiddenLabels



Define the labels that a Tenant Owner cannot set for their Namespace resources.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **denied** | []string |  | false |
| **deniedRegex** | string |  | false |


### Tenant.spec.networkPolicies



Specifies the NetworkPolicies assigned to the Tenant. The assigned NetworkPolicies are inherited by any namespace created in the Tenant. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[items](#tenantspecnetworkpoliciesitemsindex-1)** | []object |  | false |


### Tenant.spec.networkPolicies.items[index]



NetworkPolicySpec provides the specification of a NetworkPolicy

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[podSelector](#tenantspecnetworkpoliciesitemsindexpodselector-1)** | object | podSelector selects the pods to which this NetworkPolicy object applies.<br>The array of ingress rules is applied to any pods selected by this field.<br>Multiple network policies can select the same set of pods. In this case,<br>the ingress rules for each are combined additively.<br>This field is NOT optional and follows standard label selector semantics.<br>An empty podSelector matches all pods in this namespace. | true |
| **[egress](#tenantspecnetworkpoliciesitemsindexegressindex-1)** | []object | egress is a list of egress rules to be applied to the selected pods. Outgoing traffic<br>is allowed if there are no NetworkPolicies selecting the pod (and cluster policy<br>otherwise allows the traffic), OR if the traffic matches at least one egress rule<br>across all of the NetworkPolicy objects whose podSelector matches the pod. If<br>this field is empty then this NetworkPolicy limits all outgoing traffic (and serves<br>solely to ensure that the pods it selects are isolated by default).<br>This field is beta-level in 1.8 | false |
| **[ingress](#tenantspecnetworkpoliciesitemsindexingressindex-1)** | []object | ingress is a list of ingress rules to be applied to the selected pods.<br>Traffic is allowed to a pod if there are no NetworkPolicies selecting the pod<br>(and cluster policy otherwise allows the traffic), OR if the traffic source is<br>the pod's local node, OR if the traffic matches at least one ingress rule<br>across all of the NetworkPolicy objects whose podSelector matches the pod. If<br>this field is empty then this NetworkPolicy does not allow any traffic (and serves<br>solely to ensure that the pods it selects are isolated by default) | false |
| **policyTypes** | []string | policyTypes is a list of rule types that the NetworkPolicy relates to.<br>Valid options are ["Ingress"], ["Egress"], or ["Ingress", "Egress"].<br>If this field is not specified, it will default based on the existence of ingress or egress rules;<br>policies that contain an egress section are assumed to affect egress, and all policies<br>(whether or not they contain an ingress section) are assumed to affect ingress.<br>If you want to write an egress-only policy, you must explicitly specify policyTypes [ "Egress" ].<br>Likewise, if you want to write a policy that specifies that no egress is allowed,<br>you must specify a policyTypes value that include "Egress" (since such a policy would not include<br>an egress section and would otherwise default to just [ "Ingress" ]).<br>This field is beta-level in 1.8 | false |


### Tenant.spec.networkPolicies.items[index].podSelector



podSelector selects the pods to which this NetworkPolicy object applies.
The array of ingress rules is applied to any pods selected by this field.
Multiple network policies can select the same set of pods. In this case,
the ingress rules for each are combined additively.
This field is NOT optional and follows standard label selector semantics.
An empty podSelector matches all pods in this namespace.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantspecnetworkpoliciesitemsindexpodselectormatchexpressionsindex-1)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.networkPolicies.items[index].podSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.spec.networkPolicies.items[index].egress[index]



NetworkPolicyEgressRule describes a particular set of traffic that is allowed out of pods
matched by a NetworkPolicySpec's podSelector. The traffic must match both ports and to.
This type is beta-level in 1.8

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[ports](#tenantspecnetworkpoliciesitemsindexegressindexportsindex-1)** | []object | ports is a list of destination ports for outgoing traffic.<br>Each item in this list is combined using a logical OR. If this field is<br>empty or missing, this rule matches all ports (traffic not restricted by port).<br>If this field is present and contains at least one item, then this rule allows<br>traffic only if the traffic matches at least one port in the list. | false |
| **[to](#tenantspecnetworkpoliciesitemsindexegressindextoindex-1)** | []object | to is a list of destinations for outgoing traffic of pods selected for this rule.<br>Items in this list are combined using a logical OR operation. If this field is<br>empty or missing, this rule matches all destinations (traffic not restricted by<br>destination). If this field is present and contains at least one item, this rule<br>allows traffic only if the traffic matches at least one item in the to list. | false |


### Tenant.spec.networkPolicies.items[index].egress[index].ports[index]



NetworkPolicyPort describes a port to allow traffic on

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **endPort** | integer | endPort indicates that the range of ports from port to endPort if set, inclusive,<br>should be allowed by the policy. This field cannot be defined if the port field<br>is not defined or if the port field is defined as a named (string) port.<br>The endPort must be equal or greater than port.<br/>*Format*: int32<br/> | false |
| **port** | int or string | port represents the port on the given protocol. This can either be a numerical or named<br>port on a pod. If this field is not provided, this matches all port names and<br>numbers.<br>If present, only traffic on the specified protocol AND port will be matched. | false |
| **protocol** | string | protocol represents the protocol (TCP, UDP, or SCTP) which traffic must match.<br>If not specified, this field defaults to TCP. | false |


### Tenant.spec.networkPolicies.items[index].egress[index].to[index]



NetworkPolicyPeer describes a peer to allow traffic to/from. Only certain combinations of
fields are allowed

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[ipBlock](#tenantspecnetworkpoliciesitemsindexegressindextoindexipblock-1)** | object | ipBlock defines policy on a particular IPBlock. If this field is set then<br>neither of the other fields can be. | false |
| **[namespaceSelector](#tenantspecnetworkpoliciesitemsindexegressindextoindexnamespaceselector-1)** | object | namespaceSelector selects namespaces using cluster-scoped labels. This field follows<br>standard label selector semantics; if present but empty, it selects all namespaces.<br><br>If podSelector is also set, then the NetworkPolicyPeer as a whole selects<br>the pods matching podSelector in the namespaces selected by namespaceSelector.<br>Otherwise it selects all pods in the namespaces selected by namespaceSelector. | false |
| **[podSelector](#tenantspecnetworkpoliciesitemsindexegressindextoindexpodselector-1)** | object | podSelector is a label selector which selects pods. This field follows standard label<br>selector semantics; if present but empty, it selects all pods.<br><br>If namespaceSelector is also set, then the NetworkPolicyPeer as a whole selects<br>the pods matching podSelector in the Namespaces selected by NamespaceSelector.<br>Otherwise it selects the pods matching podSelector in the policy's own namespace. | false |


### Tenant.spec.networkPolicies.items[index].egress[index].to[index].ipBlock



ipBlock defines policy on a particular IPBlock. If this field is set then
neither of the other fields can be.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **cidr** | string | cidr is a string representing the IPBlock<br>Valid examples are "192.168.1.0/24" or "2001:db8::/64" | true |
| **except** | []string | except is a slice of CIDRs that should not be included within an IPBlock<br>Valid examples are "192.168.1.0/24" or "2001:db8::/64"<br>Except values will be rejected if they are outside the cidr range | false |


### Tenant.spec.networkPolicies.items[index].egress[index].to[index].namespaceSelector



namespaceSelector selects namespaces using cluster-scoped labels. This field follows
standard label selector semantics; if present but empty, it selects all namespaces.

If podSelector is also set, then the NetworkPolicyPeer as a whole selects
the pods matching podSelector in the namespaces selected by namespaceSelector.
Otherwise it selects all pods in the namespaces selected by namespaceSelector.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantspecnetworkpoliciesitemsindexegressindextoindexnamespaceselectormatchexpressionsindex-1)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.networkPolicies.items[index].egress[index].to[index].namespaceSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.spec.networkPolicies.items[index].egress[index].to[index].podSelector



podSelector is a label selector which selects pods. This field follows standard label
selector semantics; if present but empty, it selects all pods.

If namespaceSelector is also set, then the NetworkPolicyPeer as a whole selects
the pods matching podSelector in the Namespaces selected by NamespaceSelector.
Otherwise it selects the pods matching podSelector in the policy's own namespace.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantspecnetworkpoliciesitemsindexegressindextoindexpodselectormatchexpressionsindex-1)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.networkPolicies.items[index].egress[index].to[index].podSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.spec.networkPolicies.items[index].ingress[index]



NetworkPolicyIngressRule describes a particular set of traffic that is allowed to the pods
matched by a NetworkPolicySpec's podSelector. The traffic must match both ports and from.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[from](#tenantspecnetworkpoliciesitemsindexingressindexfromindex-1)** | []object | from is a list of sources which should be able to access the pods selected for this rule.<br>Items in this list are combined using a logical OR operation. If this field is<br>empty or missing, this rule matches all sources (traffic not restricted by<br>source). If this field is present and contains at least one item, this rule<br>allows traffic only if the traffic matches at least one item in the from list. | false |
| **[ports](#tenantspecnetworkpoliciesitemsindexingressindexportsindex-1)** | []object | ports is a list of ports which should be made accessible on the pods selected for<br>this rule. Each item in this list is combined using a logical OR. If this field is<br>empty or missing, this rule matches all ports (traffic not restricted by port).<br>If this field is present and contains at least one item, then this rule allows<br>traffic only if the traffic matches at least one port in the list. | false |


### Tenant.spec.networkPolicies.items[index].ingress[index].from[index]



NetworkPolicyPeer describes a peer to allow traffic to/from. Only certain combinations of
fields are allowed

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[ipBlock](#tenantspecnetworkpoliciesitemsindexingressindexfromindexipblock-1)** | object | ipBlock defines policy on a particular IPBlock. If this field is set then<br>neither of the other fields can be. | false |
| **[namespaceSelector](#tenantspecnetworkpoliciesitemsindexingressindexfromindexnamespaceselector-1)** | object | namespaceSelector selects namespaces using cluster-scoped labels. This field follows<br>standard label selector semantics; if present but empty, it selects all namespaces.<br><br>If podSelector is also set, then the NetworkPolicyPeer as a whole selects<br>the pods matching podSelector in the namespaces selected by namespaceSelector.<br>Otherwise it selects all pods in the namespaces selected by namespaceSelector. | false |
| **[podSelector](#tenantspecnetworkpoliciesitemsindexingressindexfromindexpodselector-1)** | object | podSelector is a label selector which selects pods. This field follows standard label<br>selector semantics; if present but empty, it selects all pods.<br><br>If namespaceSelector is also set, then the NetworkPolicyPeer as a whole selects<br>the pods matching podSelector in the Namespaces selected by NamespaceSelector.<br>Otherwise it selects the pods matching podSelector in the policy's own namespace. | false |


### Tenant.spec.networkPolicies.items[index].ingress[index].from[index].ipBlock



ipBlock defines policy on a particular IPBlock. If this field is set then
neither of the other fields can be.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **cidr** | string | cidr is a string representing the IPBlock<br>Valid examples are "192.168.1.0/24" or "2001:db8::/64" | true |
| **except** | []string | except is a slice of CIDRs that should not be included within an IPBlock<br>Valid examples are "192.168.1.0/24" or "2001:db8::/64"<br>Except values will be rejected if they are outside the cidr range | false |


### Tenant.spec.networkPolicies.items[index].ingress[index].from[index].namespaceSelector



namespaceSelector selects namespaces using cluster-scoped labels. This field follows
standard label selector semantics; if present but empty, it selects all namespaces.

If podSelector is also set, then the NetworkPolicyPeer as a whole selects
the pods matching podSelector in the namespaces selected by namespaceSelector.
Otherwise it selects all pods in the namespaces selected by namespaceSelector.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantspecnetworkpoliciesitemsindexingressindexfromindexnamespaceselectormatchexpressionsindex-1)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.networkPolicies.items[index].ingress[index].from[index].namespaceSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.spec.networkPolicies.items[index].ingress[index].from[index].podSelector



podSelector is a label selector which selects pods. This field follows standard label
selector semantics; if present but empty, it selects all pods.

If namespaceSelector is also set, then the NetworkPolicyPeer as a whole selects
the pods matching podSelector in the Namespaces selected by NamespaceSelector.
Otherwise it selects the pods matching podSelector in the policy's own namespace.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantspecnetworkpoliciesitemsindexingressindexfromindexpodselectormatchexpressionsindex-1)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.networkPolicies.items[index].ingress[index].from[index].podSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.spec.networkPolicies.items[index].ingress[index].ports[index]



NetworkPolicyPort describes a port to allow traffic on

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **endPort** | integer | endPort indicates that the range of ports from port to endPort if set, inclusive,<br>should be allowed by the policy. This field cannot be defined if the port field<br>is not defined or if the port field is defined as a named (string) port.<br>The endPort must be equal or greater than port.<br/>*Format*: int32<br/> | false |
| **port** | int or string | port represents the port on the given protocol. This can either be a numerical or named<br>port on a pod. If this field is not provided, this matches all port names and<br>numbers.<br>If present, only traffic on the specified protocol AND port will be matched. | false |
| **protocol** | string | protocol represents the protocol (TCP, UDP, or SCTP) which traffic must match.<br>If not specified, this field defaults to TCP. | false |


### Tenant.spec.podOptions



Specifies options for the Pods deployed in the Tenant namespaces, such as additional metadata.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[additionalMetadata](#tenantspecpodoptionsadditionalmetadata)** | object | Specifies additional labels and annotations the Capsule operator places on any Pod resource in the Tenant. Optional. | false |


### Tenant.spec.podOptions.additionalMetadata



Specifies additional labels and annotations the Capsule operator places on any Pod resource in the Tenant. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **annotations** | map[string]string |  | false |
| **labels** | map[string]string |  | false |


### Tenant.spec.priorityClasses



Specifies the allowed priorityClasses assigned to the Tenant.
Capsule assures that all Pods resources created in the Tenant can use only one of the allowed PriorityClasses.
A default value can be specified, and all the Pod resources created will inherit the declared class.
Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string |  | false |
| **allowedRegex** | string |  | false |
| **default** | string |  | false |
| **[matchExpressions](#tenantspecpriorityclassesmatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.priorityClasses.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.spec.resourceQuotas



Specifies a list of ResourceQuota resources assigned to the Tenant. The assigned values are inherited by any namespace created in the Tenant. The Capsule operator aggregates ResourceQuota at Tenant level, so that the hard quota is never crossed for the given Tenant. This permits the Tenant owner to consume resources in the Tenant regardless of the namespace. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[items](#tenantspecresourcequotasitemsindex-1)** | []object |  | false |
| **scope** | enum | Define if the Resource Budget should compute resource across all Namespaces in the Tenant or individually per cluster. Default is Tenant<br/>*Enum*: Tenant, Namespace<br/>*Default*: Tenant<br/> | false |


### Tenant.spec.resourceQuotas.items[index]



ResourceQuotaSpec defines the desired hard limits to enforce for Quota.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **hard** | map[string]int or string | hard is the set of desired hard limits for each named resource.<br>More info: https://kubernetes.io/docs/concepts/policy/resource-quotas/ | false |
| **[scopeSelector](#tenantspecresourcequotasitemsindexscopeselector-1)** | object | scopeSelector is also a collection of filters like scopes that must match each object tracked by a quota<br>but expressed using ScopeSelectorOperator in combination with possible values.<br>For a resource to match, both scopes AND scopeSelector (if specified in spec), must be matched. | false |
| **scopes** | []string | A collection of filters that must match each object tracked by a quota.<br>If not specified, the quota matches all objects. | false |


### Tenant.spec.resourceQuotas.items[index].scopeSelector



scopeSelector is also a collection of filters like scopes that must match each object tracked by a quota
but expressed using ScopeSelectorOperator in combination with possible values.
For a resource to match, both scopes AND scopeSelector (if specified in spec), must be matched.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantspecresourcequotasitemsindexscopeselectormatchexpressionsindex-1)** | []object | A list of scope selector requirements by scope of the resources. | false |


### Tenant.spec.resourceQuotas.items[index].scopeSelector.matchExpressions[index]



A scoped-resource selector requirement is a selector that contains values, a scope name, and an operator
that relates the scope name and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **operator** | string | Represents a scope's relationship to a set of values.<br>Valid operators are In, NotIn, Exists, DoesNotExist. | true |
| **scopeName** | string | The name of the scope that the selector applies to. | true |
| **values** | []string | An array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty.<br>This array is replaced during a strategic merge patch. | false |


### Tenant.spec.runtimeClasses



Specifies the allowed RuntimeClasses assigned to the Tenant.
Capsule assures that all Pods resources created in the Tenant can use only one of the allowed RuntimeClasses.
Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string |  | false |
| **allowedRegex** | string |  | false |
| **default** | string |  | false |
| **[matchExpressions](#tenantspecruntimeclassesmatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.runtimeClasses.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.spec.serviceOptions



Specifies options for the Service, such as additional metadata or block of certain type of Services. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[additionalMetadata](#tenantspecserviceoptionsadditionalmetadata-1)** | object | Specifies additional labels and annotations the Capsule operator places on any Service resource in the Tenant. Optional. | false |
| **[allowedServices](#tenantspecserviceoptionsallowedservices-1)** | object | Block or deny certain type of Services. Optional. | false |
| **[externalIPs](#tenantspecserviceoptionsexternalips-1)** | object | Specifies the external IPs that can be used in Services with type ClusterIP. An empty list means no IPs are allowed. Optional. | false |
| **[forbiddenAnnotations](#tenantspecserviceoptionsforbiddenannotations-1)** | object | Define the annotations that a Tenant Owner cannot set for their Service resources. | false |
| **[forbiddenLabels](#tenantspecserviceoptionsforbiddenlabels-1)** | object | Define the labels that a Tenant Owner cannot set for their Service resources. | false |


### Tenant.spec.serviceOptions.additionalMetadata



Specifies additional labels and annotations the Capsule operator places on any Service resource in the Tenant. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **annotations** | map[string]string |  | false |
| **labels** | map[string]string |  | false |


### Tenant.spec.serviceOptions.allowedServices



Block or deny certain type of Services. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **externalName** | boolean | Specifies if ExternalName service type resources are allowed for the Tenant. Default is true. Optional.<br/>*Default*: true<br/> | false |
| **loadBalancer** | boolean | Specifies if LoadBalancer service type resources are allowed for the Tenant. Default is true. Optional.<br/>*Default*: true<br/> | false |
| **nodePort** | boolean | Specifies if NodePort service type resources are allowed for the Tenant. Default is true. Optional.<br/>*Default*: true<br/> | false |


### Tenant.spec.serviceOptions.externalIPs



Specifies the external IPs that can be used in Services with type ClusterIP. An empty list means no IPs are allowed. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string |  | true |


### Tenant.spec.serviceOptions.forbiddenAnnotations



Define the annotations that a Tenant Owner cannot set for their Service resources.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **denied** | []string |  | false |
| **deniedRegex** | string |  | false |


### Tenant.spec.serviceOptions.forbiddenLabels



Define the labels that a Tenant Owner cannot set for their Service resources.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **denied** | []string |  | false |
| **deniedRegex** | string |  | false |


### Tenant.spec.storageClasses



Specifies the allowed StorageClasses assigned to the Tenant.
Capsule assures that all PersistentVolumeClaim resources created in the Tenant can use only one of the allowed StorageClasses.
A default value can be specified, and all the PersistentVolumeClaim resources created will inherit the declared class.
Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string |  | false |
| **allowedRegex** | string |  | false |
| **default** | string |  | false |
| **[matchExpressions](#tenantspecstorageclassesmatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.storageClasses.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.status



Returns the observed state of the Tenant.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **size** | integer | How many namespaces are assigned to the Tenant. | true |
| **state** | enum | The operational state of the Tenant. Possible values are "Active", "Cordoned".<br/>*Enum*: Cordoned, Active<br/>*Default*: Active<br/> | true |
| **namespaces** | []string | List of namespaces assigned to the Tenant. | false |

# capsule.clastix.io/v1beta1

Resource Types:

- [Tenant](#tenant)




## Tenant






Tenant is the Schema for the tenants API.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta1 | true |
| **kind** | string | Tenant | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#tenantspec)** | object | TenantSpec defines the desired state of Tenant. | false |
| **[status](#tenantstatus)** | object | Returns the observed state of the Tenant. | false |


### Tenant.spec



TenantSpec defines the desired state of Tenant.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[owners](#tenantspecownersindex)** | []object | Specifies the owners of the Tenant. Mandatory. | true |
| **[additionalRoleBindings](#tenantspecadditionalrolebindingsindex)** | []object | Specifies additional RoleBindings assigned to the Tenant. Capsule will ensure that all namespaces in the Tenant always contain the RoleBinding for the given ClusterRole. Optional. | false |
| **[containerRegistries](#tenantspeccontainerregistries)** | object | Specifies the trusted Image Registries assigned to the Tenant. Capsule assures that all Pods resources created in the Tenant can use only one of the allowed trusted registries. Optional. | false |
| **imagePullPolicies** | []enum | Specify the allowed values for the imagePullPolicies option in Pod resources. Capsule assures that all Pod resources created in the Tenant can use only one of the allowed policy. Optional.<br/>*Enum*: Always, Never, IfNotPresent<br/> | false |
| **[ingressOptions](#tenantspecingressoptions)** | object | Specifies options for the Ingress resources, such as allowed hostnames and IngressClass. Optional. | false |
| **[limitRanges](#tenantspeclimitranges)** | object | Specifies the resource min/max usage restrictions to the Tenant. The assigned values are inherited by any namespace created in the Tenant. Optional. | false |
| **[namespaceOptions](#tenantspecnamespaceoptions)** | object | Specifies options for the Namespaces, such as additional metadata or maximum number of namespaces allowed for that Tenant. Once the namespace quota assigned to the Tenant has been reached, the Tenant owner cannot create further namespaces. Optional. | false |
| **[networkPolicies](#tenantspecnetworkpolicies)** | object | Specifies the NetworkPolicies assigned to the Tenant. The assigned NetworkPolicies are inherited by any namespace created in the Tenant. Optional. | false |
| **nodeSelector** | map[string]string | Specifies the label to control the placement of pods on a given pool of worker nodes. All namespaces created within the Tenant will have the node selector annotation. This annotation tells the Kubernetes scheduler to place pods on the nodes having the selector label. Optional. | false |
| **[priorityClasses](#tenantspecpriorityclasses)** | object | Specifies the allowed priorityClasses assigned to the Tenant. Capsule assures that all Pods resources created in the Tenant can use only one of the allowed PriorityClasses. Optional. | false |
| **[resourceQuotas](#tenantspecresourcequotas)** | object | Specifies a list of ResourceQuota resources assigned to the Tenant. The assigned values are inherited by any namespace created in the Tenant. The Capsule operator aggregates ResourceQuota at Tenant level, so that the hard quota is never crossed for the given Tenant. This permits the Tenant owner to consume resources in the Tenant regardless of the namespace. Optional. | false |
| **[serviceOptions](#tenantspecserviceoptions)** | object | Specifies options for the Service, such as additional metadata or block of certain type of Services. Optional. | false |
| **[storageClasses](#tenantspecstorageclasses)** | object | Specifies the allowed StorageClasses assigned to the Tenant. Capsule assures that all PersistentVolumeClaim resources created in the Tenant can use only one of the allowed StorageClasses. Optional. | false |


### Tenant.spec.owners[index]





| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | enum | Kind of tenant owner. Possible values are "User", "Group", and "ServiceAccount"<br/>*Enum*: User, Group, ServiceAccount<br/> | true |
| **name** | string | Name of tenant owner. | true |
| **[proxySettings](#tenantspecownersindexproxysettingsindex)** | []object | Proxy settings for tenant owner. | false |


### Tenant.spec.owners[index].proxySettings[index]





| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | enum | <br/>*Enum*: Nodes, StorageClasses, IngressClasses, PriorityClasses<br/> | true |
| **operations** | []enum | <br/>*Enum*: List, Update, Delete<br/> | true |


### Tenant.spec.additionalRoleBindings[index]





| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **clusterRoleName** | string |  | true |
| **[subjects](#tenantspecadditionalrolebindingsindexsubjectsindex)** | []object | kubebuilder:validation:Minimum=1 | true |


### Tenant.spec.additionalRoleBindings[index].subjects[index]



Subject contains a reference to the object or user identities a role binding applies to.  This can either hold a direct API object reference,
or a value for non-objects such as user and group names.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | string | Kind of object being referenced. Values defined by this API group are "User", "Group", and "ServiceAccount".<br>If the Authorizer does not recognized the kind value, the Authorizer should report an error. | true |
| **name** | string | Name of the object being referenced. | true |
| **apiGroup** | string | APIGroup holds the API group of the referenced subject.<br>Defaults to "" for ServiceAccount subjects.<br>Defaults to "rbac.authorization.k8s.io" for User and Group subjects. | false |
| **namespace** | string | Namespace of the referenced object.  If the object kind is non-namespace, such as "User" or "Group", and this value is not empty<br>the Authorizer should report an error. | false |


### Tenant.spec.containerRegistries



Specifies the trusted Image Registries assigned to the Tenant. Capsule assures that all Pods resources created in the Tenant can use only one of the allowed trusted registries. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string |  | false |
| **allowedRegex** | string |  | false |


### Tenant.spec.ingressOptions



Specifies options for the Ingress resources, such as allowed hostnames and IngressClass. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[allowedClasses](#tenantspecingressoptionsallowedclasses)** | object | Specifies the allowed IngressClasses assigned to the Tenant. Capsule assures that all Ingress resources created in the Tenant can use only one of the allowed IngressClasses. Optional. | false |
| **[allowedHostnames](#tenantspecingressoptionsallowedhostnames)** | object | Specifies the allowed hostnames in Ingresses for the given Tenant. Capsule assures that all Ingress resources created in the Tenant can use only one of the allowed hostnames. Optional. | false |
| **hostnameCollisionScope** | enum | Defines the scope of hostname collision check performed when Tenant Owners create Ingress with allowed hostnames.<br><br>- Cluster: disallow the creation of an Ingress if the pair hostname and path is already used across the Namespaces managed by Capsule.<br><br>- Tenant: disallow the creation of an Ingress if the pair hostname and path is already used across the Namespaces of the Tenant.<br><br>- Namespace: disallow the creation of an Ingress if the pair hostname and path is already used in the Ingress Namespace.<br><br>Optional.<br/>*Enum*: Cluster, Tenant, Namespace, Disabled<br/>*Default*: Disabled<br/> | false |


### Tenant.spec.ingressOptions.allowedClasses



Specifies the allowed IngressClasses assigned to the Tenant. Capsule assures that all Ingress resources created in the Tenant can use only one of the allowed IngressClasses. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string |  | false |
| **allowedRegex** | string |  | false |


### Tenant.spec.ingressOptions.allowedHostnames



Specifies the allowed hostnames in Ingresses for the given Tenant. Capsule assures that all Ingress resources created in the Tenant can use only one of the allowed hostnames. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string |  | false |
| **allowedRegex** | string |  | false |


### Tenant.spec.limitRanges



Specifies the resource min/max usage restrictions to the Tenant. The assigned values are inherited by any namespace created in the Tenant. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[items](#tenantspeclimitrangesitemsindex)** | []object |  | false |


### Tenant.spec.limitRanges.items[index]



LimitRangeSpec defines a min/max usage limit for resources that match on kind.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[limits](#tenantspeclimitrangesitemsindexlimitsindex)** | []object | Limits is the list of LimitRangeItem objects that are enforced. | true |


### Tenant.spec.limitRanges.items[index].limits[index]



LimitRangeItem defines a min/max usage limit for any resource that matches on kind.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **type** | string | Type of resource that this limit applies to. | true |
| **default** | map[string]int or string | Default resource requirement limit value by resource name if resource limit is omitted. | false |
| **defaultRequest** | map[string]int or string | DefaultRequest is the default resource requirement request value by resource name if resource request is omitted. | false |
| **max** | map[string]int or string | Max usage constraints on this kind by resource name. | false |
| **maxLimitRequestRatio** | map[string]int or string | MaxLimitRequestRatio if specified, the named resource must have a request and limit that are both non-zero where limit divided by request is less than or equal to the enumerated value; this represents the max burst for the named resource. | false |
| **min** | map[string]int or string | Min usage constraints on this kind by resource name. | false |


### Tenant.spec.namespaceOptions



Specifies options for the Namespaces, such as additional metadata or maximum number of namespaces allowed for that Tenant. Once the namespace quota assigned to the Tenant has been reached, the Tenant owner cannot create further namespaces. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[additionalMetadata](#tenantspecnamespaceoptionsadditionalmetadata)** | object | Specifies additional labels and annotations the Capsule operator places on any Namespace resource in the Tenant. Optional. | false |
| **quota** | integer | Specifies the maximum number of namespaces allowed for that Tenant. Once the namespace quota assigned to the Tenant has been reached, the Tenant owner cannot create further namespaces. Optional.<br/>*Format*: int32<br/>*Minimum*: 1<br/> | false |


### Tenant.spec.namespaceOptions.additionalMetadata



Specifies additional labels and annotations the Capsule operator places on any Namespace resource in the Tenant. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **annotations** | map[string]string |  | false |
| **labels** | map[string]string |  | false |


### Tenant.spec.networkPolicies



Specifies the NetworkPolicies assigned to the Tenant. The assigned NetworkPolicies are inherited by any namespace created in the Tenant. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[items](#tenantspecnetworkpoliciesitemsindex)** | []object |  | false |


### Tenant.spec.networkPolicies.items[index]



NetworkPolicySpec provides the specification of a NetworkPolicy

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[podSelector](#tenantspecnetworkpoliciesitemsindexpodselector)** | object | podSelector selects the pods to which this NetworkPolicy object applies.<br>The array of ingress rules is applied to any pods selected by this field.<br>Multiple network policies can select the same set of pods. In this case,<br>the ingress rules for each are combined additively.<br>This field is NOT optional and follows standard label selector semantics.<br>An empty podSelector matches all pods in this namespace. | true |
| **[egress](#tenantspecnetworkpoliciesitemsindexegressindex)** | []object | egress is a list of egress rules to be applied to the selected pods. Outgoing traffic<br>is allowed if there are no NetworkPolicies selecting the pod (and cluster policy<br>otherwise allows the traffic), OR if the traffic matches at least one egress rule<br>across all of the NetworkPolicy objects whose podSelector matches the pod. If<br>this field is empty then this NetworkPolicy limits all outgoing traffic (and serves<br>solely to ensure that the pods it selects are isolated by default).<br>This field is beta-level in 1.8 | false |
| **[ingress](#tenantspecnetworkpoliciesitemsindexingressindex)** | []object | ingress is a list of ingress rules to be applied to the selected pods.<br>Traffic is allowed to a pod if there are no NetworkPolicies selecting the pod<br>(and cluster policy otherwise allows the traffic), OR if the traffic source is<br>the pod's local node, OR if the traffic matches at least one ingress rule<br>across all of the NetworkPolicy objects whose podSelector matches the pod. If<br>this field is empty then this NetworkPolicy does not allow any traffic (and serves<br>solely to ensure that the pods it selects are isolated by default) | false |
| **policyTypes** | []string | policyTypes is a list of rule types that the NetworkPolicy relates to.<br>Valid options are ["Ingress"], ["Egress"], or ["Ingress", "Egress"].<br>If this field is not specified, it will default based on the existence of ingress or egress rules;<br>policies that contain an egress section are assumed to affect egress, and all policies<br>(whether or not they contain an ingress section) are assumed to affect ingress.<br>If you want to write an egress-only policy, you must explicitly specify policyTypes [ "Egress" ].<br>Likewise, if you want to write a policy that specifies that no egress is allowed,<br>you must specify a policyTypes value that include "Egress" (since such a policy would not include<br>an egress section and would otherwise default to just [ "Ingress" ]).<br>This field is beta-level in 1.8 | false |


### Tenant.spec.networkPolicies.items[index].podSelector



podSelector selects the pods to which this NetworkPolicy object applies.
The array of ingress rules is applied to any pods selected by this field.
Multiple network policies can select the same set of pods. In this case,
the ingress rules for each are combined additively.
This field is NOT optional and follows standard label selector semantics.
An empty podSelector matches all pods in this namespace.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantspecnetworkpoliciesitemsindexpodselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.networkPolicies.items[index].podSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.spec.networkPolicies.items[index].egress[index]



NetworkPolicyEgressRule describes a particular set of traffic that is allowed out of pods
matched by a NetworkPolicySpec's podSelector. The traffic must match both ports and to.
This type is beta-level in 1.8

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[ports](#tenantspecnetworkpoliciesitemsindexegressindexportsindex)** | []object | ports is a list of destination ports for outgoing traffic.<br>Each item in this list is combined using a logical OR. If this field is<br>empty or missing, this rule matches all ports (traffic not restricted by port).<br>If this field is present and contains at least one item, then this rule allows<br>traffic only if the traffic matches at least one port in the list. | false |
| **[to](#tenantspecnetworkpoliciesitemsindexegressindextoindex)** | []object | to is a list of destinations for outgoing traffic of pods selected for this rule.<br>Items in this list are combined using a logical OR operation. If this field is<br>empty or missing, this rule matches all destinations (traffic not restricted by<br>destination). If this field is present and contains at least one item, this rule<br>allows traffic only if the traffic matches at least one item in the to list. | false |


### Tenant.spec.networkPolicies.items[index].egress[index].ports[index]



NetworkPolicyPort describes a port to allow traffic on

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **endPort** | integer | endPort indicates that the range of ports from port to endPort if set, inclusive,<br>should be allowed by the policy. This field cannot be defined if the port field<br>is not defined or if the port field is defined as a named (string) port.<br>The endPort must be equal or greater than port.<br/>*Format*: int32<br/> | false |
| **port** | int or string | port represents the port on the given protocol. This can either be a numerical or named<br>port on a pod. If this field is not provided, this matches all port names and<br>numbers.<br>If present, only traffic on the specified protocol AND port will be matched. | false |
| **protocol** | string | protocol represents the protocol (TCP, UDP, or SCTP) which traffic must match.<br>If not specified, this field defaults to TCP. | false |


### Tenant.spec.networkPolicies.items[index].egress[index].to[index]



NetworkPolicyPeer describes a peer to allow traffic to/from. Only certain combinations of
fields are allowed

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[ipBlock](#tenantspecnetworkpoliciesitemsindexegressindextoindexipblock)** | object | ipBlock defines policy on a particular IPBlock. If this field is set then<br>neither of the other fields can be. | false |
| **[namespaceSelector](#tenantspecnetworkpoliciesitemsindexegressindextoindexnamespaceselector)** | object | namespaceSelector selects namespaces using cluster-scoped labels. This field follows<br>standard label selector semantics; if present but empty, it selects all namespaces.<br><br>If podSelector is also set, then the NetworkPolicyPeer as a whole selects<br>the pods matching podSelector in the namespaces selected by namespaceSelector.<br>Otherwise it selects all pods in the namespaces selected by namespaceSelector. | false |
| **[podSelector](#tenantspecnetworkpoliciesitemsindexegressindextoindexpodselector)** | object | podSelector is a label selector which selects pods. This field follows standard label<br>selector semantics; if present but empty, it selects all pods.<br><br>If namespaceSelector is also set, then the NetworkPolicyPeer as a whole selects<br>the pods matching podSelector in the Namespaces selected by NamespaceSelector.<br>Otherwise it selects the pods matching podSelector in the policy's own namespace. | false |


### Tenant.spec.networkPolicies.items[index].egress[index].to[index].ipBlock



ipBlock defines policy on a particular IPBlock. If this field is set then
neither of the other fields can be.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **cidr** | string | cidr is a string representing the IPBlock<br>Valid examples are "192.168.1.0/24" or "2001:db8::/64" | true |
| **except** | []string | except is a slice of CIDRs that should not be included within an IPBlock<br>Valid examples are "192.168.1.0/24" or "2001:db8::/64"<br>Except values will be rejected if they are outside the cidr range | false |


### Tenant.spec.networkPolicies.items[index].egress[index].to[index].namespaceSelector



namespaceSelector selects namespaces using cluster-scoped labels. This field follows
standard label selector semantics; if present but empty, it selects all namespaces.

If podSelector is also set, then the NetworkPolicyPeer as a whole selects
the pods matching podSelector in the namespaces selected by namespaceSelector.
Otherwise it selects all pods in the namespaces selected by namespaceSelector.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantspecnetworkpoliciesitemsindexegressindextoindexnamespaceselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.networkPolicies.items[index].egress[index].to[index].namespaceSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.spec.networkPolicies.items[index].egress[index].to[index].podSelector



podSelector is a label selector which selects pods. This field follows standard label
selector semantics; if present but empty, it selects all pods.

If namespaceSelector is also set, then the NetworkPolicyPeer as a whole selects
the pods matching podSelector in the Namespaces selected by NamespaceSelector.
Otherwise it selects the pods matching podSelector in the policy's own namespace.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantspecnetworkpoliciesitemsindexegressindextoindexpodselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.networkPolicies.items[index].egress[index].to[index].podSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.spec.networkPolicies.items[index].ingress[index]



NetworkPolicyIngressRule describes a particular set of traffic that is allowed to the pods
matched by a NetworkPolicySpec's podSelector. The traffic must match both ports and from.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[from](#tenantspecnetworkpoliciesitemsindexingressindexfromindex)** | []object | from is a list of sources which should be able to access the pods selected for this rule.<br>Items in this list are combined using a logical OR operation. If this field is<br>empty or missing, this rule matches all sources (traffic not restricted by<br>source). If this field is present and contains at least one item, this rule<br>allows traffic only if the traffic matches at least one item in the from list. | false |
| **[ports](#tenantspecnetworkpoliciesitemsindexingressindexportsindex)** | []object | ports is a list of ports which should be made accessible on the pods selected for<br>this rule. Each item in this list is combined using a logical OR. If this field is<br>empty or missing, this rule matches all ports (traffic not restricted by port).<br>If this field is present and contains at least one item, then this rule allows<br>traffic only if the traffic matches at least one port in the list. | false |


### Tenant.spec.networkPolicies.items[index].ingress[index].from[index]



NetworkPolicyPeer describes a peer to allow traffic to/from. Only certain combinations of
fields are allowed

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[ipBlock](#tenantspecnetworkpoliciesitemsindexingressindexfromindexipblock)** | object | ipBlock defines policy on a particular IPBlock. If this field is set then<br>neither of the other fields can be. | false |
| **[namespaceSelector](#tenantspecnetworkpoliciesitemsindexingressindexfromindexnamespaceselector)** | object | namespaceSelector selects namespaces using cluster-scoped labels. This field follows<br>standard label selector semantics; if present but empty, it selects all namespaces.<br><br>If podSelector is also set, then the NetworkPolicyPeer as a whole selects<br>the pods matching podSelector in the namespaces selected by namespaceSelector.<br>Otherwise it selects all pods in the namespaces selected by namespaceSelector. | false |
| **[podSelector](#tenantspecnetworkpoliciesitemsindexingressindexfromindexpodselector)** | object | podSelector is a label selector which selects pods. This field follows standard label<br>selector semantics; if present but empty, it selects all pods.<br><br>If namespaceSelector is also set, then the NetworkPolicyPeer as a whole selects<br>the pods matching podSelector in the Namespaces selected by NamespaceSelector.<br>Otherwise it selects the pods matching podSelector in the policy's own namespace. | false |


### Tenant.spec.networkPolicies.items[index].ingress[index].from[index].ipBlock



ipBlock defines policy on a particular IPBlock. If this field is set then
neither of the other fields can be.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **cidr** | string | cidr is a string representing the IPBlock<br>Valid examples are "192.168.1.0/24" or "2001:db8::/64" | true |
| **except** | []string | except is a slice of CIDRs that should not be included within an IPBlock<br>Valid examples are "192.168.1.0/24" or "2001:db8::/64"<br>Except values will be rejected if they are outside the cidr range | false |


### Tenant.spec.networkPolicies.items[index].ingress[index].from[index].namespaceSelector



namespaceSelector selects namespaces using cluster-scoped labels. This field follows
standard label selector semantics; if present but empty, it selects all namespaces.

If podSelector is also set, then the NetworkPolicyPeer as a whole selects
the pods matching podSelector in the namespaces selected by namespaceSelector.
Otherwise it selects all pods in the namespaces selected by namespaceSelector.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantspecnetworkpoliciesitemsindexingressindexfromindexnamespaceselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.networkPolicies.items[index].ingress[index].from[index].namespaceSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.spec.networkPolicies.items[index].ingress[index].from[index].podSelector



podSelector is a label selector which selects pods. This field follows standard label
selector semantics; if present but empty, it selects all pods.

If namespaceSelector is also set, then the NetworkPolicyPeer as a whole selects
the pods matching podSelector in the Namespaces selected by NamespaceSelector.
Otherwise it selects the pods matching podSelector in the policy's own namespace.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantspecnetworkpoliciesitemsindexingressindexfromindexpodselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.networkPolicies.items[index].ingress[index].from[index].podSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.spec.networkPolicies.items[index].ingress[index].ports[index]



NetworkPolicyPort describes a port to allow traffic on

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **endPort** | integer | endPort indicates that the range of ports from port to endPort if set, inclusive,<br>should be allowed by the policy. This field cannot be defined if the port field<br>is not defined or if the port field is defined as a named (string) port.<br>The endPort must be equal or greater than port.<br/>*Format*: int32<br/> | false |
| **port** | int or string | port represents the port on the given protocol. This can either be a numerical or named<br>port on a pod. If this field is not provided, this matches all port names and<br>numbers.<br>If present, only traffic on the specified protocol AND port will be matched. | false |
| **protocol** | string | protocol represents the protocol (TCP, UDP, or SCTP) which traffic must match.<br>If not specified, this field defaults to TCP. | false |


### Tenant.spec.priorityClasses



Specifies the allowed priorityClasses assigned to the Tenant. Capsule assures that all Pods resources created in the Tenant can use only one of the allowed PriorityClasses. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string |  | false |
| **allowedRegex** | string |  | false |


### Tenant.spec.resourceQuotas



Specifies a list of ResourceQuota resources assigned to the Tenant. The assigned values are inherited by any namespace created in the Tenant. The Capsule operator aggregates ResourceQuota at Tenant level, so that the hard quota is never crossed for the given Tenant. This permits the Tenant owner to consume resources in the Tenant regardless of the namespace. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[items](#tenantspecresourcequotasitemsindex)** | []object |  | false |
| **scope** | enum | Define if the Resource Budget should compute resource across all Namespaces in the Tenant or individually per cluster. Default is Tenant<br/>*Enum*: Tenant, Namespace<br/>*Default*: Tenant<br/> | false |


### Tenant.spec.resourceQuotas.items[index]



ResourceQuotaSpec defines the desired hard limits to enforce for Quota.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **hard** | map[string]int or string | hard is the set of desired hard limits for each named resource.<br>More info: https://kubernetes.io/docs/concepts/policy/resource-quotas/ | false |
| **[scopeSelector](#tenantspecresourcequotasitemsindexscopeselector)** | object | scopeSelector is also a collection of filters like scopes that must match each object tracked by a quota<br>but expressed using ScopeSelectorOperator in combination with possible values.<br>For a resource to match, both scopes AND scopeSelector (if specified in spec), must be matched. | false |
| **scopes** | []string | A collection of filters that must match each object tracked by a quota.<br>If not specified, the quota matches all objects. | false |


### Tenant.spec.resourceQuotas.items[index].scopeSelector



scopeSelector is also a collection of filters like scopes that must match each object tracked by a quota
but expressed using ScopeSelectorOperator in combination with possible values.
For a resource to match, both scopes AND scopeSelector (if specified in spec), must be matched.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantspecresourcequotasitemsindexscopeselectormatchexpressionsindex)** | []object | A list of scope selector requirements by scope of the resources. | false |


### Tenant.spec.resourceQuotas.items[index].scopeSelector.matchExpressions[index]



A scoped-resource selector requirement is a selector that contains values, a scope name, and an operator
that relates the scope name and values.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **operator** | string | Represents a scope's relationship to a set of values.<br>Valid operators are In, NotIn, Exists, DoesNotExist. | true |
| **scopeName** | string | The name of the scope that the selector applies to. | true |
| **values** | []string | An array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty.<br>This array is replaced during a strategic merge patch. | false |


### Tenant.spec.serviceOptions



Specifies options for the Service, such as additional metadata or block of certain type of Services. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[additionalMetadata](#tenantspecserviceoptionsadditionalmetadata)** | object | Specifies additional labels and annotations the Capsule operator places on any Service resource in the Tenant. Optional. | false |
| **[allowedServices](#tenantspecserviceoptionsallowedservices)** | object | Block or deny certain type of Services. Optional. | false |
| **[externalIPs](#tenantspecserviceoptionsexternalips)** | object | Specifies the external IPs that can be used in Services with type ClusterIP. An empty list means no IPs are allowed. Optional. | false |
| **[forbiddenAnnotations](#tenantspecserviceoptionsforbiddenannotations)** | object | Define the annotations that a Tenant Owner cannot set for their Service resources. | false |
| **[forbiddenLabels](#tenantspecserviceoptionsforbiddenlabels)** | object | Define the labels that a Tenant Owner cannot set for their Service resources. | false |


### Tenant.spec.serviceOptions.additionalMetadata



Specifies additional labels and annotations the Capsule operator places on any Service resource in the Tenant. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **annotations** | map[string]string |  | false |
| **labels** | map[string]string |  | false |


### Tenant.spec.serviceOptions.allowedServices



Block or deny certain type of Services. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **externalName** | boolean | Specifies if ExternalName service type resources are allowed for the Tenant. Default is true. Optional.<br/>*Default*: true<br/> | false |
| **loadBalancer** | boolean | Specifies if LoadBalancer service type resources are allowed for the Tenant. Default is true. Optional.<br/>*Default*: true<br/> | false |
| **nodePort** | boolean | Specifies if NodePort service type resources are allowed for the Tenant. Default is true. Optional.<br/>*Default*: true<br/> | false |


### Tenant.spec.serviceOptions.externalIPs



Specifies the external IPs that can be used in Services with type ClusterIP. An empty list means no IPs are allowed. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string |  | true |


### Tenant.spec.serviceOptions.forbiddenAnnotations



Define the annotations that a Tenant Owner cannot set for their Service resources.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **denied** | []string |  | false |
| **deniedRegex** | string |  | false |


### Tenant.spec.serviceOptions.forbiddenLabels



Define the labels that a Tenant Owner cannot set for their Service resources.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **denied** | []string |  | false |
| **deniedRegex** | string |  | false |


### Tenant.spec.storageClasses



Specifies the allowed StorageClasses assigned to the Tenant. Capsule assures that all PersistentVolumeClaim resources created in the Tenant can use only one of the allowed StorageClasses. Optional.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string |  | false |
| **allowedRegex** | string |  | false |


### Tenant.status



Returns the observed state of the Tenant.

| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **size** | integer | How many namespaces are assigned to the Tenant. | true |
| **state** | enum | The operational state of the Tenant. Possible values are "Active", "Cordoned".<br/>*Enum*: Cordoned, Active<br/>*Default*: Active<br/> | true |
| **namespaces** | []string | List of namespaces assigned to the Tenant. | false |

