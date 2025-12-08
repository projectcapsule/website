---
title: API Reference
description: >
  API Reference
weight: 100
---
Packages:

- [capsule.clastix.io/v1beta1](#capsuleclastixiov1beta1)

# capsule.clastix.io/v1beta1

Resource Types:

- [GlobalProxySettings](#globalproxysettings)

- [ProxySetting](#proxysetting)




## GlobalProxySettings






GlobalProxySettings is the Schema for the globalproxysettings API.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta1 | true |
| **kind** | string | GlobalProxySettings | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#globalproxysettingsspec)** | object |GlobalProxySettingsSpec defines the desired state of GlobalProxySettings. 
| false |


### GlobalProxySettings.spec



GlobalProxySettingsSpec defines the desired state of GlobalProxySettings.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[rules](#globalproxysettingsspecrulesindex)** | []object |Subjects that should receive additional permissions.<br>The subjects are selected based on the oncoming requests. They don't have to relate to an existing tenant.<br>However they must be part of the capsule-user groups. 
| true |


### GlobalProxySettings.spec.rules[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[subjects](#globalproxysettingsspecrulesindexsubjectsindex)** | []object |Subjects that should receive additional permissions.<br>The subjects are selected based on the oncoming requests. They don't have to relate to an existing tenant.<br>However they must be part of the capsule-user groups. 
| true |
| **[clusterResources](#globalproxysettingsspecrulesindexclusterresourcesindex)** | []object |Cluster Resources for tenant Owner. 
| false |


### GlobalProxySettings.spec.rules[index].subjects[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | enum |Kind of tenant owner. Possible values are "User", "Group", and "ServiceAccount".<br/>*Enum*: User, Group, ServiceAccount<br/> 
| true |
| **name** | string |Name of tenant owner. 
| true |


### GlobalProxySettings.spec.rules[index].clusterResources[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiGroups** | []string |APIGroups is the name of the APIGroup that contains the resources. If multiple API groups are specified, any action requested against any resource listed will be allowed. '*' represents all resources. Empty string represents v1 api resources. 
| true |
| **resources** | []string |Resources is a list of resources this rule applies to. '*' represents all resources. 
| true |
| **[selector](#globalproxysettingsspecrulesindexclusterresourcesindexselector)** | object |Select all cluster scoped resources with the given label selector.<br>Defining a selector which does not match any resources is considered not selectable (eg. using operation NotExists). 
| true |
| **operations** | []enum |<span style="color:red;font-weight:bold">Operations which can be executed on the selected resources.<br>Deprecated: For all registered Routes only LIST ang GET requests will intercepted<br>Other permissions must be implemented via kubernetes native RBAC</span><br/>*Enum*: List, Update, Delete<br/> 
| false |


### GlobalProxySettings.spec.rules[index].clusterResources[index].selector



Select all cluster scoped resources with the given label selector.
Defining a selector which does not match any resources is considered not selectable (eg. using operation NotExists).


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#globalproxysettingsspecrulesindexclusterresourcesindexselectormatchexpressionsindex)** | []object |matchExpressions is a list of label selector requirements. The requirements are ANDed. 
| false |
| **matchLabels** | map[string]string |matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. 
| false |


### GlobalProxySettings.spec.rules[index].clusterResources[index].selector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string |key is the label key that the selector applies to. 
| true |
| **operator** | string |operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. 
| true |
| **values** | []string |values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. 
| false |

## ProxySetting






ProxySetting is the Schema for the proxysettings API.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta1 | true |
| **kind** | string | ProxySetting | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#proxysettingspec)** | object |ProxySettingSpec defines the additional Capsule Proxy settings for additional users of the Tenant.<br>Resource is Namespace-scoped and applies the settings to the belonged Tenant. 
| false |


### ProxySetting.spec



ProxySettingSpec defines the additional Capsule Proxy settings for additional users of the Tenant.
Resource is Namespace-scoped and applies the settings to the belonged Tenant.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[subjects](#proxysettingspecsubjectsindex)** | []object |Subjects that should receive additional permissions. 
| true |


### ProxySetting.spec.subjects[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | enum |Kind of tenant owner. Possible values are "User", "Group", and "ServiceAccount"<br/>*Enum*: User, Group, ServiceAccount<br/> 
| true |
| **name** | string |Name of tenant owner. 
| true |
| **[clusterResources](#proxysettingspecsubjectsindexclusterresourcesindex)** | []object |Cluster Resources for tenant Owner. 
| false |
| **[proxySettings](#proxysettingspecsubjectsindexproxysettingsindex)** | []object |Proxy settings for tenant owner. 
| false |


### ProxySetting.spec.subjects[index].clusterResources[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiGroups** | []string |APIGroups is the name of the APIGroup that contains the resources. If multiple API groups are specified, any action requested against any resource listed will be allowed. '*' represents all resources. Empty string represents v1 api resources. 
| true |
| **resources** | []string |Resources is a list of resources this rule applies to. '*' represents all resources. 
| true |
| **[selector](#proxysettingspecsubjectsindexclusterresourcesindexselector)** | object |Select all cluster scoped resources with the given label selector.<br>Defining a selector which does not match any resources is considered not selectable (eg. using operation NotExists). 
| true |
| **operations** | []enum |<span style="color:red;font-weight:bold">Operations which can be executed on the selected resources.<br>Deprecated: For all registered Routes only LIST ang GET requests will intercepted<br>Other permissions must be implemented via kubernetes native RBAC</span><br/>*Enum*: List, Update, Delete<br/> 
| false |


### ProxySetting.spec.subjects[index].clusterResources[index].selector



Select all cluster scoped resources with the given label selector.
Defining a selector which does not match any resources is considered not selectable (eg. using operation NotExists).


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#proxysettingspecsubjectsindexclusterresourcesindexselectormatchexpressionsindex)** | []object |matchExpressions is a list of label selector requirements. The requirements are ANDed. 
| false |
| **matchLabels** | map[string]string |matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. 
| false |


### ProxySetting.spec.subjects[index].clusterResources[index].selector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string |key is the label key that the selector applies to. 
| true |
| **operator** | string |operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. 
| true |
| **values** | []string |values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. 
| false |


### ProxySetting.spec.subjects[index].proxySettings[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | enum |<br/>*Enum*: Nodes, StorageClasses, IngressClasses, PriorityClasses, RuntimeClasses, PersistentVolumes<br/> 
| true |
| **operations** | []enum |<br/>*Enum*: List, Update, Delete<br/> 
| true |

