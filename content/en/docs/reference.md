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

- [CustomQuota](#customquota)

- [GlobalCustomQuota](#globalcustomquota)

- [GlobalTenantResource](#globaltenantresource)

- [QuantityLedger](#quantityledger)

- [ResourcePoolClaim](#resourcepoolclaim)

- [ResourcePool](#resourcepool)

- [RuleStatus](#rulestatus)

- [TenantOwner](#tenantowner)

- [TenantResource](#tenantresource)

- [Tenant](#tenant)




## CapsuleConfiguration






CapsuleConfiguration is the Schema for the Capsule configuration API.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta2 | true |
| **kind** | string | CapsuleConfiguration | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#capsuleconfigurationspec)** | object | CapsuleConfigurationSpec defines the Capsule configuration. | true |
| **[status](#capsuleconfigurationstatus)** | object | CapsuleConfigurationStatus defines the Capsule configuration status. | false |


### CapsuleConfiguration.spec



CapsuleConfigurationSpec defines the Capsule configuration.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **cacheInvalidation** | string | Define the period of time upon a cache invalidation is executed for all caches.<br/>*Default*: 24h<br/> | true |
| **enableTLSReconciler** | boolean | Toggles the TLS reconciler, the controller that is able to generate CA and certificates for the webhooks<br>when not using an already provided CA and certificate, or when these are managed externally with Vault, or cert-manager.<br/>*Default*: false<br/> | true |
| **[rbac](#capsuleconfigurationspecrbac)** | object | Define Properties for managed ClusterRoles by Capsule<br/>*Default*: map[]<br/> | true |
| **[administrators](#capsuleconfigurationspecadministratorsindex)** | []object | Define entities which can act as Administrators in the capsule construct<br>These entities are automatically owners for all existing tenants. Meaning they can add namespaces to any tenant. However they must be specific by using the capsule label<br>for interacting with namespaces. Because if that label is not defined, it's assumed that namespace interaction was not targeted towards a tenant and will therefore<br>be ignored by capsule. | false |
| **[admission](#capsuleconfigurationspecadmission)** | object | Configuration for dynamic Validating and Mutating Admission webhooks managed by Capsule. | false |
| **allowServiceAccountPromotion** | boolean | ServiceAccounts within tenant namespaces can be promoted to owners of the given tenant<br>this can be achieved by labeling the serviceaccount and then they are considered owners. This can only be done by other owners of the tenant.<br>However ServiceAccounts which have been promoted to owner can not promote further serviceAccounts.<br/>*Default*: false<br/> | false |
| **[events](#capsuleconfigurationspecevents)** | object | Event (Audit) Configuration<br/>*Default*: map[namespace:default]<br/> | false |
| **forceTenantPrefix** | boolean | Enforces the Tenant owner, during Namespace creation, to name it using the selected Tenant name as prefix,<br>separated by a dash. This is useful to avoid Namespace name collision in a public CaaS environment.<br/>*Default*: false<br/> | false |
| **ignoreUserWithGroups** | []string | Define groups which when found in the request of a user will be ignored by the Capsule<br>this might be useful if you have one group where all the users are in, but you want to separate administrators from normal users with additional groups. | false |
| **[impersonation](#capsuleconfigurationspecimpersonation)** | object | Service Account Client configuration for impersonation properties | false |
| **[nodeMetadata](#capsuleconfigurationspecnodemetadata)** | object | Allows to set the forbidden metadata for the worker nodes that could be patched by a Tenant.<br>This applies only if the Tenant has an active NodeSelector, and the Owner have right to patch their nodes. | false |
| **[overrides](#capsuleconfigurationspecoverrides)** | object | Allows to set different name rather than the canonical one for the Capsule configuration objects,<br>such as webhook secret or configurations.<br/>*Default*: map[TLSSecretName:capsule-tls mutatingWebhookConfigurationName:capsule-mutating-webhook-configuration validatingWebhookConfigurationName:capsule-validating-webhook-configuration]<br/> | false |
| **protectedNamespaceRegex** | string | Disallow creation of namespaces, whose name matches this regexp | false |
| **userGroups** | []string | <span style="color:red;font-weight:bold">Deprecated: use users property instead (https://projectcapsule.dev/docs/operating/setup/configuration/#users)<br><br>Names of the groups considered as Capsule users.</span> | false |
| **userNames** | []string | <span style="color:red;font-weight:bold">Deprecated: use users property instead (https://projectcapsule.dev/docs/operating/setup/configuration/#users)<br><br>Names of the users considered as Capsule users.</span> | false |
| **[users](#capsuleconfigurationspecusersindex)** | []object | Define entities which are considered part of the Capsule construct<br>Users not mentioned here will be ignored by Capsule | false |


### CapsuleConfiguration.spec.rbac



Define Properties for managed ClusterRoles by Capsule


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **administrationClusterRoles** | []string | The ClusterRoles applied for Administrators<br/>*Default*: [capsule-namespace-deleter]<br/> | false |
| **deleter** | string | Name for the ClusterRole required to grant Namespace Deletion permissions.<br/>*Default*: capsule-namespace-deleter<br/> | false |
| **promotionClusterRoles** | []string | The ClusterRoles applied for ServiceAccounts which had owner Promotion<br/>*Default*: [capsule-namespace-provisioner capsule-namespace-deleter]<br/> | false |
| **provisioner** | string | Name for the ClusterRole required to grant Namespace Provision permissions.<br/>*Default*: capsule-namespace-provisioner<br/> | false |


### CapsuleConfiguration.spec.administrators[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | enum | Kind of entity. Possible values are "User", "Group", and "ServiceAccount"<br/>*Enum*: User, Group, ServiceAccount<br/> | true |
| **name** | string | Name of the entity. | true |


### CapsuleConfiguration.spec.admission



Configuration for dynamic Validating and Mutating Admission webhooks managed by Capsule.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[mutating](#capsuleconfigurationspecadmissionmutating)** | object | Configure dynamic Mutating Admission for Capsule | false |
| **serviceName** | string | Service Name of the Admission Service<br/>*Default*: capsule-webhook-service<br/> | false |
| **[validating](#capsuleconfigurationspecadmissionvalidating)** | object | Configure dynamic Validating Admission for Capsule | false |


### CapsuleConfiguration.spec.admission.mutating



Configure dynamic Mutating Admission for Capsule


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[client](#capsuleconfigurationspecadmissionmutatingclient)** | object | whats the problem | true |
| **annotations** | map[string]string | Annotations added to the Admission Webhook | false |
| **labels** | map[string]string | Labels added to the Admission Webhook | false |
| **name** | string | Name the Admission Webhook | false |
| **[webhooks](#capsuleconfigurationspecadmissionmutatingwebhooksindex)** | []object | Define Dynamic Admission Webhooks | false |


### CapsuleConfiguration.spec.admission.mutating.client



whats the problem


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **caBundle** | string | `caBundle` is a PEM encoded CA bundle which will be used to validate the webhook's server certificate.<br>If unspecified, system trust roots on the apiserver are used.<br/>*Format*: byte<br/> | false |
| **[service](#capsuleconfigurationspecadmissionmutatingclientservice)** | object | `service` is a reference to the service for this webhook. Either<br>`service` or `url` must be specified.<br><br>If the webhook is running within the cluster, then you should use `service`. | false |
| **url** | string | `url` gives the location of the webhook, in standard URL form<br>(`scheme://host:port/path`). Exactly one of `url` or `service`<br>must be specified.<br><br>The `host` should not refer to a service running in the cluster; use<br>the `service` field instead. The host might be resolved via external<br>DNS in some apiservers (e.g., `kube-apiserver` cannot resolve<br>in-cluster DNS as that would be a layering violation). `host` may<br>also be an IP address.<br><br>Please note that using `localhost` or `127.0.0.1` as a `host` is<br>risky unless you take great care to run this webhook on all hosts<br>which run an apiserver which might need to make calls to this<br>webhook. Such installs are likely to be non-portable, i.e., not easy<br>to turn up in a new cluster.<br><br>The scheme must be "https"; the URL must begin with "https://".<br><br>A path is optional, and if present may be any string permissible in<br>a URL. You may use the path to pass an arbitrary string to the<br>webhook, for example, a cluster identifier.<br><br>Attempting to use a user or basic auth e.g. "user:password@" is not<br>allowed. Fragments ("#...") and query parameters ("?...") are not<br>allowed, either. | false |


### CapsuleConfiguration.spec.admission.mutating.client.service



`service` is a reference to the service for this webhook. Either
`service` or `url` must be specified.

If the webhook is running within the cluster, then you should use `service`.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **name** | string | `name` is the name of the service.<br>Required | true |
| **namespace** | string | `namespace` is the namespace of the service.<br>Required | true |
| **path** | string | `path` is an optional URL path which will be sent in any request to<br>this service. | false |
| **port** | integer | If specified, the port on the service that hosting webhook.<br>Default to 443 for backward compatibility.<br>`port` should be a valid port number (1-65535, inclusive).<br/>*Format*: int32<br/> | false |


### CapsuleConfiguration.spec.admission.mutating.webhooks[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **admissionReviewVersions** | []string | AdmissionReviewVersions is an ordered list of preferred `AdmissionReview`<br>versions the Webhook expects. API server will try to use first version in<br>the list which it supports. If none of the versions specified in this list<br>supported by API server, validation will fail for this object.<br>If a persisted webhook configuration specifies allowed versions and does not<br>include any versions known to the API Server, calls to the webhook will fail<br>and be subject to the failure policy. | true |
| **name** | string | The name of the admission webhook.<br>Name should be fully qualified, e.g., imagepolicy.kubernetes.io, where<br>"imagepolicy" is the name of the webhook, and kubernetes.io is the name<br>of the organization.<br>Required. | true |
| **path** | string | `path` is the URL path which will be sent in any request to<br>this service. | true |
| **sideEffects** | string | SideEffects states whether this webhook has side effects.<br>Acceptable values are: None, NoneOnDryRun (webhooks created via v1beta1 may also specify Some or Unknown).<br>Webhooks with side effects MUST implement a reconciliation system, since a request may be<br>rejected by a future step in the admission chain and the side effects therefore need to be undone.<br>Requests with the dryRun attribute will be auto-rejected if they match a webhook with<br>sideEffects == Unknown or Some. | true |
| **failurePolicy** | string | FailurePolicy defines how unrecognized errors from the admission endpoint are handled -<br>allowed values are Ignore or Fail. Defaults to Fail. | false |
| **[matchConditions](#capsuleconfigurationspecadmissionmutatingwebhooksindexmatchconditionsindex)** | []object | MatchConditions is a list of conditions that must be met for a request to be sent to this<br>webhook. Match conditions filter requests that have already been matched by the rules,<br>namespaceSelector, and objectSelector. An empty list of matchConditions matches all requests.<br>There are a maximum of 64 match conditions allowed.<br><br>The exact matching logic is (in order):<br>  1. If ANY matchCondition evaluates to FALSE, the webhook is skipped.<br>  2. If ALL matchConditions evaluate to TRUE, the webhook is called.<br>  3. If any matchCondition evaluates to an error (but none are FALSE):<br>     - If failurePolicy=Fail, reject the request<br>     - If failurePolicy=Ignore, the error is ignored and the webhook is skipped | false |
| **matchPolicy** | string | matchPolicy defines how the "rules" list is used to match incoming requests.<br>Allowed values are "Exact" or "Equivalent".<br><br>- Exact: match a request only if it exactly matches a specified rule.<br>For example, if deployments can be modified via apps/v1, apps/v1beta1, and extensions/v1beta1,<br>but "rules" only included `apiGroups:["apps"], apiVersions:["v1"], resources: ["deployments"]`,<br>a request to apps/v1beta1 or extensions/v1beta1 would not be sent to the webhook.<br><br>- Equivalent: match a request if modifies a resource listed in rules, even via another API group or version.<br>For example, if deployments can be modified via apps/v1, apps/v1beta1, and extensions/v1beta1,<br>and "rules" only included `apiGroups:["apps"], apiVersions:["v1"], resources: ["deployments"]`,<br>a request to apps/v1beta1 or extensions/v1beta1 would be converted to apps/v1 and sent to the webhook.<br><br>Defaults to "Equivalent" | false |
| **[namespaceSelector](#capsuleconfigurationspecadmissionmutatingwebhooksindexnamespaceselector)** | object | NamespaceSelector decides whether to run the webhook on an object based<br>on whether the namespace for that object matches the selector. If the<br>object itself is a namespace, the matching is performed on<br>object.metadata.labels. If the object is another cluster scoped resource,<br>it never skips the webhook.<br><br>For example, to run the webhook on any objects whose namespace is not<br>associated with "runlevel" of "0" or "1";  you will set the selector as<br>follows:<br>"namespaceSelector": {<br>  "matchExpressions": [<br>    {<br>      "key": "runlevel",<br>      "operator": "NotIn",<br>      "values": [<br>        "0",<br>        "1"<br>      ]<br>    }<br>  ]<br>}<br><br>If instead you want to only run the webhook on any objects whose<br>namespace is associated with the "environment" of "prod" or "staging";<br>you will set the selector as follows:<br>"namespaceSelector": {<br>  "matchExpressions": [<br>    {<br>      "key": "environment",<br>      "operator": "In",<br>      "values": [<br>        "prod",<br>        "staging"<br>      ]<br>    }<br>  ]<br>}<br><br>See<br>https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/<br>for more examples of label selectors.<br><br>Default to the empty LabelSelector, which matches everything. | false |
| **[objectSelector](#capsuleconfigurationspecadmissionmutatingwebhooksindexobjectselector)** | object | ObjectSelector decides whether to run the webhook based on if the<br>object has matching labels. objectSelector is evaluated against both<br>the oldObject and newObject that would be sent to the webhook, and<br>is considered to match if either object matches the selector. A null<br>object (oldObject in the case of create, or newObject in the case of<br>delete) or an object that cannot have labels (like a<br>DeploymentRollback or a PodProxyOptions object) is not considered to<br>match.<br>Use the object selector only if the webhook is opt-in, because end<br>users may skip the admission webhook by setting the labels.<br>Default to the empty LabelSelector, which matches everything. | false |
| **[opts](#capsuleconfigurationspecadmissionmutatingwebhooksindexopts)** | object | Capsule Custom Admission Options | false |
| **reinvocationPolicy** | string | reinvocationPolicy indicates whether this webhook should be called multiple times as part of a single admission evaluation.<br>Allowed values are "Never" and "IfNeeded".<br><br>Never: the webhook will not be called more than once in a single admission evaluation.<br><br>IfNeeded: the webhook will be called at least one additional time as part of the admission evaluation<br>if the object being admitted is modified by other admission plugins after the initial webhook call.<br>Webhooks that specify this option *must* be idempotent, able to process objects they previously admitted.<br>Note:<br>* the number of additional invocations is not guaranteed to be exactly one.<br>* if additional invocations result in further modifications to the object, webhooks are not guaranteed to be invoked again.<br>* webhooks that use this option may be reordered to minimize the number of additional invocations.<br>* to validate an object after all mutations are guaranteed complete, use a validating admission webhook instead.<br><br>Defaults to "Never". | false |
| **[rules](#capsuleconfigurationspecadmissionmutatingwebhooksindexrulesindex)** | []object | Rules describes what operations on what resources/subresources the webhook cares about.<br>The webhook cares about an operation if it matches _any_ Rule.<br>However, in order to prevent ValidatingAdmissionWebhooks and MutatingAdmissionWebhooks<br>from putting the cluster in a state which cannot be recovered from without completely<br>disabling the plugin, ValidatingAdmissionWebhooks and MutatingAdmissionWebhooks are never called<br>on admission requests for ValidatingWebhookConfiguration and MutatingWebhookConfiguration objects. | false |
| **timeoutSeconds** | integer | TimeoutSeconds specifies the timeout for this webhook. After the timeout passes,<br>the webhook call will be ignored or the API call will fail based on the<br>failure policy.<br>The timeout value must be between 1 and 30 seconds.<br>Default to 10 seconds.<br/>*Format*: int32<br/> | false |


### CapsuleConfiguration.spec.admission.mutating.webhooks[index].matchConditions[index]



MatchCondition represents a condition which must by fulfilled for a request to be sent to a webhook.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **expression** | string | Expression represents the expression which will be evaluated by CEL. Must evaluate to bool.<br>CEL expressions have access to the contents of the AdmissionRequest and Authorizer, organized into CEL variables:<br><br>'object' - The object from the incoming request. The value is null for DELETE requests.<br>'oldObject' - The existing object. The value is null for CREATE requests.<br>'request' - Attributes of the admission request(/pkg/apis/admission/types.go#AdmissionRequest).<br>'authorizer' - A CEL Authorizer. May be used to perform authorization checks for the principal (user or service account) of the request.<br>  See https://pkg.go.dev/k8s.io/apiserver/pkg/cel/library#Authz<br>'authorizer.requestResource' - A CEL ResourceCheck constructed from the 'authorizer' and configured with the<br>  request resource.<br>Documentation on CEL: https://kubernetes.io/docs/reference/using-api/cel/<br><br>Required. | true |
| **name** | string | Name is an identifier for this match condition, used for strategic merging of MatchConditions,<br>as well as providing an identifier for logging purposes. A good name should be descriptive of<br>the associated expression.<br>Name must be a qualified name consisting of alphanumeric characters, '-', '_' or '.', and<br>must start and end with an alphanumeric character (e.g. 'MyName',  or 'my.name',  or<br>'123-abc', regex used for validation is '([A-Za-z0-9][-A-Za-z0-9_.]*)?[A-Za-z0-9]') with an<br>optional DNS subdomain prefix and '/' (e.g. 'example.com/MyName')<br><br>Required. | true |


### CapsuleConfiguration.spec.admission.mutating.webhooks[index].namespaceSelector



NamespaceSelector decides whether to run the webhook on an object based
on whether the namespace for that object matches the selector. If the
object itself is a namespace, the matching is performed on
object.metadata.labels. If the object is another cluster scoped resource,
it never skips the webhook.

For example, to run the webhook on any objects whose namespace is not
associated with "runlevel" of "0" or "1";  you will set the selector as
follows:
"namespaceSelector": {
  "matchExpressions": [
    {
      "key": "runlevel",
      "operator": "NotIn",
      "values": [
        "0",
        "1"
      ]
    }
  ]
}

If instead you want to only run the webhook on any objects whose
namespace is associated with the "environment" of "prod" or "staging";
you will set the selector as follows:
"namespaceSelector": {
  "matchExpressions": [
    {
      "key": "environment",
      "operator": "In",
      "values": [
        "prod",
        "staging"
      ]
    }
  ]
}

See
https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
for more examples of label selectors.

Default to the empty LabelSelector, which matches everything.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#capsuleconfigurationspecadmissionmutatingwebhooksindexnamespaceselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### CapsuleConfiguration.spec.admission.mutating.webhooks[index].namespaceSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### CapsuleConfiguration.spec.admission.mutating.webhooks[index].objectSelector



ObjectSelector decides whether to run the webhook based on if the
object has matching labels. objectSelector is evaluated against both
the oldObject and newObject that would be sent to the webhook, and
is considered to match if either object matches the selector. A null
object (oldObject in the case of create, or newObject in the case of
delete) or an object that cannot have labels (like a
DeploymentRollback or a PodProxyOptions object) is not considered to
match.
Use the object selector only if the webhook is opt-in, because end
users may skip the admission webhook by setting the labels.
Default to the empty LabelSelector, which matches everything.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#capsuleconfigurationspecadmissionmutatingwebhooksindexobjectselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### CapsuleConfiguration.spec.admission.mutating.webhooks[index].objectSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### CapsuleConfiguration.spec.admission.mutating.webhooks[index].opts



Capsule Custom Admission Options


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **administrators** | boolean | If enabled, the request is only sent to admission if the user is mentioned<br>As Part of the Capsule Administrators<br/>*Default*: false<br/> | true |
| **capsuleUsers** | boolean | If enabled, the request is only sent to admission if the user is mentioned<br>As Part of the Capsule Users<br/>*Default*: false<br/> | true |


### CapsuleConfiguration.spec.admission.mutating.webhooks[index].rules[index]



RuleWithOperations is a tuple of Operations and Resources. It is recommended to make
sure that all the tuple expansions are valid.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiGroups** | []string | APIGroups is the API groups the resources belong to. '*' is all groups.<br>If '*' is present, the length of the slice must be one.<br>Required. | false |
| **apiVersions** | []string | APIVersions is the API versions the resources belong to. '*' is all versions.<br>If '*' is present, the length of the slice must be one.<br>Required. | false |
| **operations** | []string | Operations is the operations the admission hook cares about - CREATE, UPDATE, DELETE, CONNECT or *<br>for all of those operations and any future admission operations that are added.<br>If '*' is present, the length of the slice must be one.<br>Required. | false |
| **resources** | []string | Resources is a list of resources this rule applies to.<br><br>For example:<br>'pods' means pods.<br>'pods/log' means the log subresource of pods.<br>'*' means all resources, but not subresources.<br>'pods/*' means all subresources of pods.<br>'*/scale' means all scale subresources.<br>'*/*' means all resources and their subresources.<br><br>If wildcard is present, the validation rule will ensure resources do not<br>overlap with each other.<br><br>Depending on the enclosing object, subresources might not be allowed.<br>Required. | false |
| **scope** | string | scope specifies the scope of this rule.<br>Valid values are "Cluster", "Namespaced", and "*"<br>"Cluster" means that only cluster-scoped resources will match this rule.<br>Namespace API objects are cluster-scoped.<br>"Namespaced" means that only namespaced resources will match this rule.<br>"*" means that there are no scope restrictions.<br>Subresources match the scope of their parent resource.<br>Default is "*". | false |


### CapsuleConfiguration.spec.admission.validating



Configure dynamic Validating Admission for Capsule


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[client](#capsuleconfigurationspecadmissionvalidatingclient)** | object | whats the problem | true |
| **annotations** | map[string]string | Annotations added to the Admission Webhook | false |
| **labels** | map[string]string | Labels added to the Admission Webhook | false |
| **name** | string | Name the Admission Webhook | false |
| **[webhooks](#capsuleconfigurationspecadmissionvalidatingwebhooksindex)** | []object | Define Dynamic Admission Webhooks | false |


### CapsuleConfiguration.spec.admission.validating.client



whats the problem


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **caBundle** | string | `caBundle` is a PEM encoded CA bundle which will be used to validate the webhook's server certificate.<br>If unspecified, system trust roots on the apiserver are used.<br/>*Format*: byte<br/> | false |
| **[service](#capsuleconfigurationspecadmissionvalidatingclientservice)** | object | `service` is a reference to the service for this webhook. Either<br>`service` or `url` must be specified.<br><br>If the webhook is running within the cluster, then you should use `service`. | false |
| **url** | string | `url` gives the location of the webhook, in standard URL form<br>(`scheme://host:port/path`). Exactly one of `url` or `service`<br>must be specified.<br><br>The `host` should not refer to a service running in the cluster; use<br>the `service` field instead. The host might be resolved via external<br>DNS in some apiservers (e.g., `kube-apiserver` cannot resolve<br>in-cluster DNS as that would be a layering violation). `host` may<br>also be an IP address.<br><br>Please note that using `localhost` or `127.0.0.1` as a `host` is<br>risky unless you take great care to run this webhook on all hosts<br>which run an apiserver which might need to make calls to this<br>webhook. Such installs are likely to be non-portable, i.e., not easy<br>to turn up in a new cluster.<br><br>The scheme must be "https"; the URL must begin with "https://".<br><br>A path is optional, and if present may be any string permissible in<br>a URL. You may use the path to pass an arbitrary string to the<br>webhook, for example, a cluster identifier.<br><br>Attempting to use a user or basic auth e.g. "user:password@" is not<br>allowed. Fragments ("#...") and query parameters ("?...") are not<br>allowed, either. | false |


### CapsuleConfiguration.spec.admission.validating.client.service



`service` is a reference to the service for this webhook. Either
`service` or `url` must be specified.

If the webhook is running within the cluster, then you should use `service`.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **name** | string | `name` is the name of the service.<br>Required | true |
| **namespace** | string | `namespace` is the namespace of the service.<br>Required | true |
| **path** | string | `path` is an optional URL path which will be sent in any request to<br>this service. | false |
| **port** | integer | If specified, the port on the service that hosting webhook.<br>Default to 443 for backward compatibility.<br>`port` should be a valid port number (1-65535, inclusive).<br/>*Format*: int32<br/> | false |


### CapsuleConfiguration.spec.admission.validating.webhooks[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **admissionReviewVersions** | []string | AdmissionReviewVersions is an ordered list of preferred `AdmissionReview`<br>versions the Webhook expects. API server will try to use first version in<br>the list which it supports. If none of the versions specified in this list<br>supported by API server, validation will fail for this object.<br>If a persisted webhook configuration specifies allowed versions and does not<br>include any versions known to the API Server, calls to the webhook will fail<br>and be subject to the failure policy. | true |
| **name** | string | The name of the admission webhook.<br>Name should be fully qualified, e.g., imagepolicy.kubernetes.io, where<br>"imagepolicy" is the name of the webhook, and kubernetes.io is the name<br>of the organization.<br>Required. | true |
| **path** | string | `path` is the URL path which will be sent in any request to<br>this service. | true |
| **sideEffects** | string | SideEffects states whether this webhook has side effects.<br>Acceptable values are: None, NoneOnDryRun (webhooks created via v1beta1 may also specify Some or Unknown).<br>Webhooks with side effects MUST implement a reconciliation system, since a request may be<br>rejected by a future step in the admission chain and the side effects therefore need to be undone.<br>Requests with the dryRun attribute will be auto-rejected if they match a webhook with<br>sideEffects == Unknown or Some. | true |
| **failurePolicy** | string | FailurePolicy defines how unrecognized errors from the admission endpoint are handled -<br>allowed values are Ignore or Fail. Defaults to Fail. | false |
| **[matchConditions](#capsuleconfigurationspecadmissionvalidatingwebhooksindexmatchconditionsindex)** | []object | MatchConditions is a list of conditions that must be met for a request to be sent to this<br>webhook. Match conditions filter requests that have already been matched by the rules,<br>namespaceSelector, and objectSelector. An empty list of matchConditions matches all requests.<br>There are a maximum of 64 match conditions allowed.<br><br>The exact matching logic is (in order):<br>  1. If ANY matchCondition evaluates to FALSE, the webhook is skipped.<br>  2. If ALL matchConditions evaluate to TRUE, the webhook is called.<br>  3. If any matchCondition evaluates to an error (but none are FALSE):<br>     - If failurePolicy=Fail, reject the request<br>     - If failurePolicy=Ignore, the error is ignored and the webhook is skipped | false |
| **matchPolicy** | string | matchPolicy defines how the "rules" list is used to match incoming requests.<br>Allowed values are "Exact" or "Equivalent".<br><br>- Exact: match a request only if it exactly matches a specified rule.<br>For example, if deployments can be modified via apps/v1, apps/v1beta1, and extensions/v1beta1,<br>but "rules" only included `apiGroups:["apps"], apiVersions:["v1"], resources: ["deployments"]`,<br>a request to apps/v1beta1 or extensions/v1beta1 would not be sent to the webhook.<br><br>- Equivalent: match a request if modifies a resource listed in rules, even via another API group or version.<br>For example, if deployments can be modified via apps/v1, apps/v1beta1, and extensions/v1beta1,<br>and "rules" only included `apiGroups:["apps"], apiVersions:["v1"], resources: ["deployments"]`,<br>a request to apps/v1beta1 or extensions/v1beta1 would be converted to apps/v1 and sent to the webhook.<br><br>Defaults to "Equivalent" | false |
| **[namespaceSelector](#capsuleconfigurationspecadmissionvalidatingwebhooksindexnamespaceselector)** | object | NamespaceSelector decides whether to run the webhook on an object based<br>on whether the namespace for that object matches the selector. If the<br>object itself is a namespace, the matching is performed on<br>object.metadata.labels. If the object is another cluster scoped resource,<br>it never skips the webhook.<br><br>For example, to run the webhook on any objects whose namespace is not<br>associated with "runlevel" of "0" or "1";  you will set the selector as<br>follows:<br>"namespaceSelector": {<br>  "matchExpressions": [<br>    {<br>      "key": "runlevel",<br>      "operator": "NotIn",<br>      "values": [<br>        "0",<br>        "1"<br>      ]<br>    }<br>  ]<br>}<br><br>If instead you want to only run the webhook on any objects whose<br>namespace is associated with the "environment" of "prod" or "staging";<br>you will set the selector as follows:<br>"namespaceSelector": {<br>  "matchExpressions": [<br>    {<br>      "key": "environment",<br>      "operator": "In",<br>      "values": [<br>        "prod",<br>        "staging"<br>      ]<br>    }<br>  ]<br>}<br><br>See<br>https://kubernetes.io/docs/concepts/overview/working-with-objects/labels<br>for more examples of label selectors.<br><br>Default to the empty LabelSelector, which matches everything. | false |
| **[objectSelector](#capsuleconfigurationspecadmissionvalidatingwebhooksindexobjectselector)** | object | ObjectSelector decides whether to run the webhook based on if the<br>object has matching labels. objectSelector is evaluated against both<br>the oldObject and newObject that would be sent to the webhook, and<br>is considered to match if either object matches the selector. A null<br>object (oldObject in the case of create, or newObject in the case of<br>delete) or an object that cannot have labels (like a<br>DeploymentRollback or a PodProxyOptions object) is not considered to<br>match.<br>Use the object selector only if the webhook is opt-in, because end<br>users may skip the admission webhook by setting the labels.<br>Default to the empty LabelSelector, which matches everything. | false |
| **[opts](#capsuleconfigurationspecadmissionvalidatingwebhooksindexopts)** | object | Capsule Custom Admission Options | false |
| **[rules](#capsuleconfigurationspecadmissionvalidatingwebhooksindexrulesindex)** | []object | Rules describes what operations on what resources/subresources the webhook cares about.<br>The webhook cares about an operation if it matches _any_ Rule.<br>However, in order to prevent ValidatingAdmissionWebhooks and MutatingAdmissionWebhooks<br>from putting the cluster in a state which cannot be recovered from without completely<br>disabling the plugin, ValidatingAdmissionWebhooks and MutatingAdmissionWebhooks are never called<br>on admission requests for ValidatingWebhookConfiguration and MutatingWebhookConfiguration objects. | false |
| **timeoutSeconds** | integer | TimeoutSeconds specifies the timeout for this webhook. After the timeout passes,<br>the webhook call will be ignored or the API call will fail based on the<br>failure policy.<br>The timeout value must be between 1 and 30 seconds.<br>Default to 10 seconds.<br/>*Format*: int32<br/> | false |


### CapsuleConfiguration.spec.admission.validating.webhooks[index].matchConditions[index]



MatchCondition represents a condition which must by fulfilled for a request to be sent to a webhook.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **expression** | string | Expression represents the expression which will be evaluated by CEL. Must evaluate to bool.<br>CEL expressions have access to the contents of the AdmissionRequest and Authorizer, organized into CEL variables:<br><br>'object' - The object from the incoming request. The value is null for DELETE requests.<br>'oldObject' - The existing object. The value is null for CREATE requests.<br>'request' - Attributes of the admission request(/pkg/apis/admission/types.go#AdmissionRequest).<br>'authorizer' - A CEL Authorizer. May be used to perform authorization checks for the principal (user or service account) of the request.<br>  See https://pkg.go.dev/k8s.io/apiserver/pkg/cel/library#Authz<br>'authorizer.requestResource' - A CEL ResourceCheck constructed from the 'authorizer' and configured with the<br>  request resource.<br>Documentation on CEL: https://kubernetes.io/docs/reference/using-api/cel/<br><br>Required. | true |
| **name** | string | Name is an identifier for this match condition, used for strategic merging of MatchConditions,<br>as well as providing an identifier for logging purposes. A good name should be descriptive of<br>the associated expression.<br>Name must be a qualified name consisting of alphanumeric characters, '-', '_' or '.', and<br>must start and end with an alphanumeric character (e.g. 'MyName',  or 'my.name',  or<br>'123-abc', regex used for validation is '([A-Za-z0-9][-A-Za-z0-9_.]*)?[A-Za-z0-9]') with an<br>optional DNS subdomain prefix and '/' (e.g. 'example.com/MyName')<br><br>Required. | true |


### CapsuleConfiguration.spec.admission.validating.webhooks[index].namespaceSelector



NamespaceSelector decides whether to run the webhook on an object based
on whether the namespace for that object matches the selector. If the
object itself is a namespace, the matching is performed on
object.metadata.labels. If the object is another cluster scoped resource,
it never skips the webhook.

For example, to run the webhook on any objects whose namespace is not
associated with "runlevel" of "0" or "1";  you will set the selector as
follows:
"namespaceSelector": {
  "matchExpressions": [
    {
      "key": "runlevel",
      "operator": "NotIn",
      "values": [
        "0",
        "1"
      ]
    }
  ]
}

If instead you want to only run the webhook on any objects whose
namespace is associated with the "environment" of "prod" or "staging";
you will set the selector as follows:
"namespaceSelector": {
  "matchExpressions": [
    {
      "key": "environment",
      "operator": "In",
      "values": [
        "prod",
        "staging"
      ]
    }
  ]
}

See
https://kubernetes.io/docs/concepts/overview/working-with-objects/labels
for more examples of label selectors.

Default to the empty LabelSelector, which matches everything.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#capsuleconfigurationspecadmissionvalidatingwebhooksindexnamespaceselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### CapsuleConfiguration.spec.admission.validating.webhooks[index].namespaceSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### CapsuleConfiguration.spec.admission.validating.webhooks[index].objectSelector



ObjectSelector decides whether to run the webhook based on if the
object has matching labels. objectSelector is evaluated against both
the oldObject and newObject that would be sent to the webhook, and
is considered to match if either object matches the selector. A null
object (oldObject in the case of create, or newObject in the case of
delete) or an object that cannot have labels (like a
DeploymentRollback or a PodProxyOptions object) is not considered to
match.
Use the object selector only if the webhook is opt-in, because end
users may skip the admission webhook by setting the labels.
Default to the empty LabelSelector, which matches everything.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#capsuleconfigurationspecadmissionvalidatingwebhooksindexobjectselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### CapsuleConfiguration.spec.admission.validating.webhooks[index].objectSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### CapsuleConfiguration.spec.admission.validating.webhooks[index].opts



Capsule Custom Admission Options


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **administrators** | boolean | If enabled, the request is only sent to admission if the user is mentioned<br>As Part of the Capsule Administrators<br/>*Default*: false<br/> | true |
| **capsuleUsers** | boolean | If enabled, the request is only sent to admission if the user is mentioned<br>As Part of the Capsule Users<br/>*Default*: false<br/> | true |


### CapsuleConfiguration.spec.admission.validating.webhooks[index].rules[index]



RuleWithOperations is a tuple of Operations and Resources. It is recommended to make
sure that all the tuple expansions are valid.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiGroups** | []string | APIGroups is the API groups the resources belong to. '*' is all groups.<br>If '*' is present, the length of the slice must be one.<br>Required. | false |
| **apiVersions** | []string | APIVersions is the API versions the resources belong to. '*' is all versions.<br>If '*' is present, the length of the slice must be one.<br>Required. | false |
| **operations** | []string | Operations is the operations the admission hook cares about - CREATE, UPDATE, DELETE, CONNECT or *<br>for all of those operations and any future admission operations that are added.<br>If '*' is present, the length of the slice must be one.<br>Required. | false |
| **resources** | []string | Resources is a list of resources this rule applies to.<br><br>For example:<br>'pods' means pods.<br>'pods/log' means the log subresource of pods.<br>'*' means all resources, but not subresources.<br>'pods/*' means all subresources of pods.<br>'*/scale' means all scale subresources.<br>'*/*' means all resources and their subresources.<br><br>If wildcard is present, the validation rule will ensure resources do not<br>overlap with each other.<br><br>Depending on the enclosing object, subresources might not be allowed.<br>Required. | false |
| **scope** | string | scope specifies the scope of this rule.<br>Valid values are "Cluster", "Namespaced", and "*"<br>"Cluster" means that only cluster-scoped resources will match this rule.<br>Namespace API objects are cluster-scoped.<br>"Namespaced" means that only namespaced resources will match this rule.<br>"*" means that there are no scope restrictions.<br>Subresources match the scope of their parent resource.<br>Default is "*". | false |


### CapsuleConfiguration.spec.events



Event (Audit) Configuration


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **namespace** | string | Namespace where the events are logged for cluster scoped resources or deny events (default namespace)<br/>*Default*: default<br/> | false |


### CapsuleConfiguration.spec.impersonation



Service Account Client configuration for impersonation properties


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **caSecretKey** | string | Key in the secret that holds the CA certificate (e.g., "ca.crt")<br/>*Default*: ca.crt<br/> | false |
| **caSecretName** | string | Name of the secret containing the CA certificate | false |
| **caSecretNamespace** | string | Namespace where the CA certificate secret is located | false |
| **endpoint** | string | Kubernetes API Endpoint to use for impersonation | false |
| **globalDefaultServiceAccount** | string | Default ServiceAccount for global resources (GlobalTenantResource)<br>When defined, users are required to use this ServiceAccount anywhere in the cluster<br>unless they explicitly provide their own. | false |
| **globalDefaultServiceAccountNamespace** | string | Default ServiceAccount for global resources (GlobalTenantResource)<br>When defined, users are required to use this ServiceAccount anywhere in the cluster<br>unless they explicitly provide their own. | false |
| **skipTlsVerify** | boolean | If true, TLS certificate verification is skipped (not recommended for production)<br/>*Default*: false<br/> | false |
| **tenantDefaultServiceAccount** | string | Default ServiceAccount for namespaced resources (TenantResource)<br>When defined, users are required to use this ServiceAccount within the namespace<br>where they deploy the resource, unless they explicitly provide their own. | false |


### CapsuleConfiguration.spec.nodeMetadata



Allows to set the forbidden metadata for the worker nodes that could be patched by a Tenant.
This applies only if the Tenant has an active NodeSelector, and the Owner have right to patch their nodes.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[forbiddenAnnotations](#capsuleconfigurationspecnodemetadataforbiddenannotations)** | object | Define the annotations that a Tenant Owner cannot set for their nodes. | false |
| **[forbiddenLabels](#capsuleconfigurationspecnodemetadataforbiddenlabels)** | object | Define the labels that a Tenant Owner cannot set for their nodes. | false |


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
| **mutatingWebhookConfigurationName** | string | <span style="color:red;font-weight:bold">Deprecated: use dynamic admission instead<br><br>Name of the MutatingWebhookConfiguration which contains the dynamic admission controller paths and resources.</span><br/>*Default*: capsule-mutating-webhook-configuration<br/> | true |
| **validatingWebhookConfigurationName** | string | <span style="color:red;font-weight:bold">Deprecated: use dynamic admission instead<br><br>Name of the ValidatingWebhookConfiguration which contains the dynamic admission controller paths and resources.</span><br/>*Default*: capsule-validating-webhook-configuration<br/> | true |


### CapsuleConfiguration.spec.users[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | enum | Kind of entity. Possible values are "User", "Group", and "ServiceAccount"<br/>*Enum*: User, Group, ServiceAccount<br/> | true |
| **name** | string | Name of the entity. | true |


### CapsuleConfiguration.status



CapsuleConfigurationStatus defines the Capsule configuration status.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[conditions](#capsuleconfigurationstatusconditionsindex)** | []object | Conditions holds the reconciliation conditions for this CapsuleConfiguration.<br>Includes a Ready condition indicating whether the configuration was<br>successfully validated and applied. | false |
| **observedGeneration** | integer | ObservedGeneration is the most recent generation the controller has observed.<br/>*Format*: int64<br/> | false |
| **tenants** | []string | Tenants is the sorted list of Tenant names currently present in the cluster.<br>The total count is available via len(Tenants). | false |
| **[users](#capsuleconfigurationstatususersindex)** | []object | Users which are considered Capsule Users and are bound to the Capsule Tenant construct. | false |


### CapsuleConfiguration.status.conditions[index]



Condition contains details for one aspect of the current state of this API Resource.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **lastTransitionTime** | string | lastTransitionTime is the last time the condition transitioned from one status to another.<br>This should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.<br/>*Format*: date-time<br/> | true |
| **message** | string | message is a human readable message indicating details about the transition.<br>This may be an empty string. | true |
| **reason** | string | reason contains a programmatic identifier indicating the reason for the condition's last transition.<br>Producers of specific condition types may define expected values and meanings for this field,<br>and whether the values are considered a guaranteed API.<br>The value should be a CamelCase string.<br>This field may not be empty. | true |
| **status** | enum | status of the condition, one of True, False, Unknown.<br/>*Enum*: True, False, Unknown<br/> | true |
| **type** | string | type of condition in CamelCase or in foo.example.com/CamelCase. | true |
| **observedGeneration** | integer | observedGeneration represents the .metadata.generation that the condition was set based upon.<br>For instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date<br>with respect to the current state of the instance.<br/>*Format*: int64<br/>*Minimum*: 0<br/> | false |


### CapsuleConfiguration.status.users[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | enum | Kind of entity. Possible values are "User", "Group", and "ServiceAccount"<br/>*Enum*: User, Group, ServiceAccount<br/> | true |
| **name** | string | Name of the entity. | true |

## CustomQuota









| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta2 | true |
| **kind** | string | CustomQuota | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#customquotaspec)** | object | CustomQuotaSpec. | true |
| **[status](#customquotastatus)** | object | CustomQuotaStatus defines the observed state of GlobalResourceQuota. | false |


### CustomQuota.spec



CustomQuotaSpec.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **limit** | int or string | Resource Quantity as limit | true |
| **[options](#customquotaspecoptions)** | object | Additional Options for the CustomQuotaSpecification<br/>*Default*: map[emitMetricPerClaimUsage:false]<br/> | true |
| **[sources](#customquotaspecsourcesindex)** | []object | Target resource | true |
| **[scopeSelectors](#customquotaspecscopeselectorsindex)** | []object | Select items governed by this quota | false |


### CustomQuota.spec.options



Additional Options for the CustomQuotaSpecification


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **emitMetricPerClaimUsage** | boolean | Additionally expose usage metrics for each claim contributing to the quota.<br>This is disabled by default to avoid high cardinality in the metrics, but can be enabled for more granular monitoring and alerting.<br/>*Default*: false<br/> | false |


### CustomQuota.spec.sources[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | API version of the referent. | true |
| **kind** | string | Kind of the referent.<br>More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds | true |
| **op** | enum | Operation used to evaluate usage.<br/>*Enum*: add, sub, count<br/>*Default*: add<br/> | false |
| **path** | string | Path on GVK where usage is evaluated.<br>Must be empty when op is "count".<br>Required and non-empty for all other operations. | false |
| **[selectors](#customquotaspecsourcesindexselectorsindex)** | []object | Provide more granular selectors for these sources<br>The ScopeSelector and NamespaceSelector are always applied<br>Allowing these selectors to make further selecting on the resulting subset. | false |


### CustomQuota.spec.sources[index].selectors[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **fieldSelectors** | []string | Additional boolean JSONPath expressions.<br>All must evaluate to true for this selector to match. | false |
| **[matchExpressions](#customquotaspecsourcesindexselectorsindexmatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### CustomQuota.spec.sources[index].selectors[index].matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### CustomQuota.spec.scopeSelectors[index]



A label selector is a label query over a set of resources. The result of matchLabels and
matchExpressions are ANDed. An empty label selector matches all objects. A null
label selector matches no objects.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#customquotaspecscopeselectorsindexmatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### CustomQuota.spec.scopeSelectors[index].matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### CustomQuota.status



CustomQuotaStatus defines the observed state of GlobalResourceQuota.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[conditions](#customquotastatusconditionsindex)** | []object | Conditions | true |
| **[targets](#customquotastatustargetsindex)** | []object | Targeting GVK | true |
| **[claims](#customquotastatusclaimsindex)** | []object | Objects regarding this policy | false |
| **observedGeneration** | integer | ObservedGeneration is the most recent generation the controller has observed.<br/>*Format*: int64<br/> | false |
| **[usage](#customquotastatususage)** | object | Usage measurements | false |


### CustomQuota.status.conditions[index]



Condition contains details for one aspect of the current state of this API Resource.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **lastTransitionTime** | string | lastTransitionTime is the last time the condition transitioned from one status to another.<br>This should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.<br/>*Format*: date-time<br/> | true |
| **message** | string | message is a human readable message indicating details about the transition.<br>This may be an empty string. | true |
| **reason** | string | reason contains a programmatic identifier indicating the reason for the condition's last transition.<br>Producers of specific condition types may define expected values and meanings for this field,<br>and whether the values are considered a guaranteed API.<br>The value should be a CamelCase string.<br>This field may not be empty. | true |
| **status** | enum | status of the condition, one of True, False, Unknown.<br/>*Enum*: True, False, Unknown<br/> | true |
| **type** | string | type of condition in CamelCase or in foo.example.com/CamelCase. | true |
| **observedGeneration** | integer | observedGeneration represents the .metadata.generation that the condition was set based upon.<br>For instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date<br>with respect to the current state of the instance.<br/>*Format*: int64<br/>*Minimum*: 0<br/> | false |


### CustomQuota.status.targets[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **group** | string |  | true |
| **kind** | string |  | true |
| **version** | string |  | true |
| **op** | enum | Operation used to evaluate usage.<br/>*Enum*: add, sub, count<br/>*Default*: add<br/> | false |
| **path** | string | Path on GVK where usage is evaluated.<br>Must be empty when op is "count".<br>Required and non-empty for all other operations. | false |
| **scope** | string | Path on GVK where usage is evaluated | false |
| **[selectors](#customquotastatustargetsindexselectorsindex)** | []object | Provide more granular selectors for these sources<br>The ScopeSelector and NamespaceSelector are always applied<br>Allowing these selectors to make further selecting on the resulting subset. | false |


### CustomQuota.status.targets[index].selectors[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **fieldSelectors** | []string | Additional boolean JSONPath expressions.<br>All must evaluate to true for this selector to match. | false |
| **[matchExpressions](#customquotastatustargetsindexselectorsindexmatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### CustomQuota.status.targets[index].selectors[index].matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### CustomQuota.status.claims[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **group** | string |  | true |
| **kind** | string |  | true |
| **name** | string | Name of the referent. | true |
| **uid** | string | UID of the tracked Tenant to pin point tracking | true |
| **usage** | int or string | Resource Quantity for given item | true |
| **version** | string |  | true |
| **namespace** | string | Namespace of the referent, when not specified it acts as LocalObjectReference. | false |


### CustomQuota.status.usage



Usage measurements


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **available** | int or string | Used is the current observed total available of the resource (limit - used). | false |
| **used** | int or string | Used is the current observed total usage of the resource. | false |

## GlobalCustomQuota









| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta2 | true |
| **kind** | string | GlobalCustomQuota | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#globalcustomquotaspec)** | object | ClusterCustomQuotaSpec. | true |
| **[status](#globalcustomquotastatus)** | object | CustomQuotaStatus defines the observed state of GlobalResourceQuota. | false |


### GlobalCustomQuota.spec



ClusterCustomQuotaSpec.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **limit** | int or string | Resource Quantity as limit | true |
| **[options](#globalcustomquotaspecoptions)** | object | Additional Options for the CustomQuotaSpecification<br/>*Default*: map[emitMetricPerClaimUsage:false]<br/> | true |
| **[sources](#globalcustomquotaspecsourcesindex)** | []object | Target resource | true |
| **[namespaceSelectors](#globalcustomquotaspecnamespaceselectorsindex)** | []object | Select specifc namespaces where this Quota selects items. | false |
| **[scopeSelectors](#globalcustomquotaspecscopeselectorsindex)** | []object | Select items governed by this quota | false |


### GlobalCustomQuota.spec.options



Additional Options for the CustomQuotaSpecification


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **emitMetricPerClaimUsage** | boolean | Additionally expose usage metrics for each claim contributing to the quota.<br>This is disabled by default to avoid high cardinality in the metrics, but can be enabled for more granular monitoring and alerting.<br/>*Default*: false<br/> | false |


### GlobalCustomQuota.spec.sources[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | API version of the referent. | true |
| **kind** | string | Kind of the referent.<br>More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds | true |
| **op** | enum | Operation used to evaluate usage.<br/>*Enum*: add, sub, count<br/>*Default*: add<br/> | false |
| **path** | string | Path on GVK where usage is evaluated.<br>Must be empty when op is "count".<br>Required and non-empty for all other operations. | false |
| **[selectors](#globalcustomquotaspecsourcesindexselectorsindex)** | []object | Provide more granular selectors for these sources<br>The ScopeSelector and NamespaceSelector are always applied<br>Allowing these selectors to make further selecting on the resulting subset. | false |


### GlobalCustomQuota.spec.sources[index].selectors[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **fieldSelectors** | []string | Additional boolean JSONPath expressions.<br>All must evaluate to true for this selector to match. | false |
| **[matchExpressions](#globalcustomquotaspecsourcesindexselectorsindexmatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### GlobalCustomQuota.spec.sources[index].selectors[index].matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### GlobalCustomQuota.spec.namespaceSelectors[index]



Selector for resources and their labels or selecting origin namespaces


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#globalcustomquotaspecnamespaceselectorsindexmatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### GlobalCustomQuota.spec.namespaceSelectors[index].matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### GlobalCustomQuota.spec.scopeSelectors[index]



A label selector is a label query over a set of resources. The result of matchLabels and
matchExpressions are ANDed. An empty label selector matches all objects. A null
label selector matches no objects.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#globalcustomquotaspecscopeselectorsindexmatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### GlobalCustomQuota.spec.scopeSelectors[index].matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### GlobalCustomQuota.status



CustomQuotaStatus defines the observed state of GlobalResourceQuota.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[conditions](#globalcustomquotastatusconditionsindex)** | []object | Conditions | true |
| **[targets](#globalcustomquotastatustargetsindex)** | []object | Targeting GVK | true |
| **[claims](#globalcustomquotastatusclaimsindex)** | []object | Objects regarding this policy | false |
| **namespaces** | []string | Observed Namespaces | false |
| **observedGeneration** | integer | ObservedGeneration is the most recent generation the controller has observed.<br/>*Format*: int64<br/> | false |
| **[usage](#globalcustomquotastatususage)** | object | Usage measurements | false |


### GlobalCustomQuota.status.conditions[index]



Condition contains details for one aspect of the current state of this API Resource.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **lastTransitionTime** | string | lastTransitionTime is the last time the condition transitioned from one status to another.<br>This should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.<br/>*Format*: date-time<br/> | true |
| **message** | string | message is a human readable message indicating details about the transition.<br>This may be an empty string. | true |
| **reason** | string | reason contains a programmatic identifier indicating the reason for the condition's last transition.<br>Producers of specific condition types may define expected values and meanings for this field,<br>and whether the values are considered a guaranteed API.<br>The value should be a CamelCase string.<br>This field may not be empty. | true |
| **status** | enum | status of the condition, one of True, False, Unknown.<br/>*Enum*: True, False, Unknown<br/> | true |
| **type** | string | type of condition in CamelCase or in foo.example.com/CamelCase. | true |
| **observedGeneration** | integer | observedGeneration represents the .metadata.generation that the condition was set based upon.<br>For instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date<br>with respect to the current state of the instance.<br/>*Format*: int64<br/>*Minimum*: 0<br/> | false |


### GlobalCustomQuota.status.targets[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **group** | string |  | true |
| **kind** | string |  | true |
| **version** | string |  | true |
| **op** | enum | Operation used to evaluate usage.<br/>*Enum*: add, sub, count<br/>*Default*: add<br/> | false |
| **path** | string | Path on GVK where usage is evaluated.<br>Must be empty when op is "count".<br>Required and non-empty for all other operations. | false |
| **scope** | string | Path on GVK where usage is evaluated | false |
| **[selectors](#globalcustomquotastatustargetsindexselectorsindex)** | []object | Provide more granular selectors for these sources<br>The ScopeSelector and NamespaceSelector are always applied<br>Allowing these selectors to make further selecting on the resulting subset. | false |


### GlobalCustomQuota.status.targets[index].selectors[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **fieldSelectors** | []string | Additional boolean JSONPath expressions.<br>All must evaluate to true for this selector to match. | false |
| **[matchExpressions](#globalcustomquotastatustargetsindexselectorsindexmatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### GlobalCustomQuota.status.targets[index].selectors[index].matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### GlobalCustomQuota.status.claims[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **group** | string |  | true |
| **kind** | string |  | true |
| **name** | string | Name of the referent. | true |
| **uid** | string | UID of the tracked Tenant to pin point tracking | true |
| **usage** | int or string | Resource Quantity for given item | true |
| **version** | string |  | true |
| **namespace** | string | Namespace of the referent, when not specified it acts as LocalObjectReference. | false |


### GlobalCustomQuota.status.usage



Usage measurements


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **available** | int or string | Used is the current observed total available of the resource (limit - used). | false |
| **used** | int or string | Used is the current observed total usage of the resource. | false |

## GlobalTenantResource






GlobalTenantResource allows to propagate resource replications to a specific subset of Tenant resources.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta2 | true |
| **kind** | string | GlobalTenantResource | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#globaltenantresourcespec)** | object | GlobalTenantResourceSpec defines the desired state of GlobalTenantResource. | true |
| **[status](#globaltenantresourcestatus)** | object | GlobalTenantResourceStatus defines the observed state of GlobalTenantResource. | false |


### GlobalTenantResource.spec



GlobalTenantResourceSpec defines the desired state of GlobalTenantResource.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[resources](#globaltenantresourcespecresourcesindex)** | []object | Defines the rules to select targeting Namespace, along with the objects that must be replicated. | true |
| **resyncPeriod** | string | Define the period of time upon a second reconciliation must be invoked.<br>Keep in mind that any change to the manifests will trigger a new reconciliation.<br/>*Default*: 60s<br/> | true |
| **[settings](#globaltenantresourcespecsettings)** | object | Provide additional settings<br/>*Default*: map[]<br/> | true |
| **cordoned** | boolean | When cordoning a replication it will no longer execute any applies or deletions (paused).<br>This is useful for maintenances<br/>*Default*: false<br/> | false |
| **[dependsOn](#globaltenantresourcespecdependsonindex)** | []object | DependsOn may contain a meta.NamespacedObjectReference slice<br>with references to TenantResource resources that must be ready before this<br>TenantResource can be reconciled. | false |
| **pruningOnDelete** | boolean | When the replicated resource manifest is deleted, all the objects replicated so far will be automatically deleted.<br>Disable this to keep replicated resources although the deletion of the replication manifest.<br/>*Default*: true<br/> | false |
| **scope** | enum | Resource Scope, Can either be<br>- Tenant: Create Resources for each tenant  in selected Tenants<br>- Namespace: Create Resources for each namespace in selected Tenants<br/>*Enum*: Namespace, Tenant, None<br/>*Default*: Namespace<br/> | false |
| **[serviceAccount](#globaltenantresourcespecserviceaccount)** | object | Local ServiceAccount which will perform all the actions defined in the TenantResource<br>You must provide permissions accordingly to that ServiceAccount | false |
| **[tenantSelector](#globaltenantresourcespectenantselector)** | object | Defines the Tenant selector used target the tenants on which resources must be propagated. | false |


### GlobalTenantResource.spec.resources[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[additionalMetadata](#globaltenantresourcespecresourcesindexadditionalmetadata)** | object | Besides the Capsule metadata required by TenantResource controller, defines additional metadata that must be<br>added to the replicated resources. | false |
| **[context](#globaltenantresourcespecresourcesindexcontext)** | object | Provide additional template context, which can be used throughout all<br>the declared items for the replication | false |
| **[generators](#globaltenantresourcespecresourcesindexgeneratorsindex)** | []object | Templates for advanced use cases | false |
| **[namespaceSelector](#globaltenantresourcespecresourcesindexnamespaceselector)** | object | Defines the Namespace selector to select the Tenant Namespaces on which the resources must be propagated.<br>In case of nil value, all the Tenant Namespaces are targeted. | false |
| **[namespacedItems](#globaltenantresourcespecresourcesindexnamespaceditemsindex)** | []object | List of the resources already existing in other Namespaces that must be replicated. | false |
| **rawItems** | []object | List of raw resources that must be replicated. | false |


### GlobalTenantResource.spec.resources[index].additionalMetadata



Besides the Capsule metadata required by TenantResource controller, defines additional metadata that must be
added to the replicated resources.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **annotations** | map[string]string |  | false |
| **labels** | map[string]string |  | false |


### GlobalTenantResource.spec.resources[index].context



Provide additional template context, which can be used throughout all
the declared items for the replication


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[resources](#globaltenantresourcespecresourcesindexcontextresourcesindex)** | []object |  | false |


### GlobalTenantResource.spec.resources[index].context.resources[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | API version of the referent. | true |
| **kind** | string | Kind of the referent.<br>More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds | true |
| **index** | string | Index to mount the resource in the template context | false |
| **name** | string | Name of the values referent. This is useful<br>when you traying to get a specific resource | false |
| **namespace** | string | Namespace of the values referent. | false |
| **optional** | boolean | Only relevant if name is set. If an item is not optional, there will be an error thrown when it does not exist<br/>*Default*: true<br/> | false |
| **[selector](#globaltenantresourcespecresourcesindexcontextresourcesindexselector)** | object | Selector which allows to get any amount of these resources based on labels | false |


### GlobalTenantResource.spec.resources[index].context.resources[index].selector



Selector which allows to get any amount of these resources based on labels


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#globaltenantresourcespecresourcesindexcontextresourcesindexselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### GlobalTenantResource.spec.resources[index].context.resources[index].selector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### GlobalTenantResource.spec.resources[index].generators[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **missingKey** | enum | Missing Key Option for templating<br/>*Enum*: invalid, zero, error<br/>*Default*: zero<br/> | false |
| **template** | string | Template contains any amount of yaml which is applied to Kubernetes.<br>This can be a single resource or multiple resources | false |


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



Reference


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | API version of the referent. | true |
| **kind** | string | Kind of the referent.<br>More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds | true |
| **name** | string | Name of the values referent. This is useful<br>when you traying to get a specific resource | false |
| **namespace** | string | Namespace of the values referent. | false |
| **optional** | boolean | Only relevant if name is set. If an item is not optional, there will be an error thrown when it does not exist<br/>*Default*: true<br/> | false |
| **[selector](#globaltenantresourcespecresourcesindexnamespaceditemsindexselector)** | object | Selector which allows to get any amount of these resources based on labels | false |


### GlobalTenantResource.spec.resources[index].namespacedItems[index].selector



Selector which allows to get any amount of these resources based on labels


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


### GlobalTenantResource.spec.settings



Provide additional settings


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **adopt** | boolean | Enabling this allows TenanResources to interact with objects which were not created by a TenantResource. In this case on prune no deletion of the entire object is made.<br/>*Default*: false<br/> | false |
| **force** | boolean | Force indicates that in case of conflicts with server-side apply, the client should acquire ownership of the conflicting field.<br>You may create collisions with this.<br/>*Default*: false<br/> | false |


### GlobalTenantResource.spec.dependsOn[index]



LocalObjectReference contains enough information to locate the referenced Kubernetes resource object.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **name** | string | Name of the referent. | true |


### GlobalTenantResource.spec.serviceAccount



Local ServiceAccount which will perform all the actions defined in the TenantResource
You must provide permissions accordingly to that ServiceAccount


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **name** | string | Name of the referent. | true |
| **namespace** | string | Namespace of the referent. | true |


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
| **size** | integer | How many items are being replicated by the TenantResource. | true |
| **[conditions](#globaltenantresourcestatusconditionsindex)** | []object | Condition of the GlobalTenantResource. | false |
| **observedGeneration** | integer | ObservedGeneration is the most recent generation the controller has observed.<br/>*Format*: int64<br/> | false |
| **[processedItems](#globaltenantresourcestatusprocesseditemsindex)** | []object | List of the replicated resources for the given TenantResource. | false |
| **selectedTenants** | []string | List of Tenants addressed by the GlobalTenantResource. | false |
| **[serviceAccount](#globaltenantresourcestatusserviceaccount)** | object | Serviceaccount used for impersonation | false |


### GlobalTenantResource.status.conditions[index]



Condition contains details for one aspect of the current state of this API Resource.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **lastTransitionTime** | string | lastTransitionTime is the last time the condition transitioned from one status to another.<br>This should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.<br/>*Format*: date-time<br/> | true |
| **message** | string | message is a human readable message indicating details about the transition.<br>This may be an empty string. | true |
| **reason** | string | reason contains a programmatic identifier indicating the reason for the condition's last transition.<br>Producers of specific condition types may define expected values and meanings for this field,<br>and whether the values are considered a guaranteed API.<br>The value should be a CamelCase string.<br>This field may not be empty. | true |
| **status** | enum | status of the condition, one of True, False, Unknown.<br/>*Enum*: True, False, Unknown<br/> | true |
| **type** | string | type of condition in CamelCase or in foo.example.com/CamelCase. | true |
| **observedGeneration** | integer | observedGeneration represents the .metadata.generation that the condition was set based upon.<br>For instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date<br>with respect to the current state of the instance.<br/>*Format*: int64<br/>*Minimum*: 0<br/> | false |


### GlobalTenantResource.status.processedItems[index]



Advanced Status Item for pin pointing items in tenants/namespaces.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **group** | string |  | false |
| **kind** | string |  | false |
| **name** | string |  | false |
| **namespace** | string |  | false |
| **origin** | string |  | false |
| **[status](#globaltenantresourcestatusprocesseditemsindexstatus)** | object |  | false |
| **tenant** | string |  | false |
| **version** | string |  | false |


### GlobalTenantResource.status.processedItems[index].status






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **status** | enum | status of the condition, one of True, False, Unknown.<br/>*Enum*: True, False, Unknown<br/> | true |
| **type** | string | type of condition in CamelCase or in foo.example.com/CamelCase. | true |
| **created** | boolean | Indicates wether the resource was created or adopted | false |
| **lastApply** | string | An opaque value that represents the internal version of this object that can<br>be used by clients to determine when objects have changed. May be used for optimistic<br>concurrency, change detection, and the watch operation on a resource or set of resources.<br>Clients must treat these values as opaque and passed unmodified back to the server.<br>They may only be valid for a particular resource or set of resources.<br><br>Populated by the system.<br>Read-only.<br>Value must be treated as opaque by clients and .<br>More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#concurrency-control-and-consistency<br/>*Format*: date-time<br/> | false |
| **message** | string | message is a human readable message indicating details about the transition.<br>This may be an empty string. | false |


### GlobalTenantResource.status.serviceAccount



Serviceaccount used for impersonation


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **name** | string | Name of the referent. | true |
| **namespace** | string | Namespace of the referent. | true |

## QuantityLedger









| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta2 | true |
| **kind** | string | QuantityLedger | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#quantityledgerspec)** | object | QuotaLedgerSpec contains the immutable target reference. | false |
| **[status](#quantityledgerstatus)** | object | QuantityLedgerStatus contains the mutable coordination state used by admission<br>and quota controllers. | false |


### QuantityLedger.spec



QuotaLedgerSpec contains the immutable target reference.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[targetRef](#quantityledgerspectargetref)** | object | TargetRef points to the quota object that this ledger belongs to. | true |


### QuantityLedger.spec.targetRef



TargetRef points to the quota object that this ledger belongs to.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | string | Kind of the target quota resource, for example "CustomQuota" or "GlobalCustomQuota". | true |
| **name** | string | Name of the target quota resource. | true |
| **apiGroup** | string | APIGroup of the target quota resource, for example "capsule.clastix.io". | false |
| **namespace** | string | Namespace of the target quota resource.<br>Must be empty for cluster-scoped targets. | false |
| **uid** | string | UID of the target quota resource.<br>Optional, but useful for stale reference detection. | false |


### QuantityLedger.status



QuantityLedgerStatus contains the mutable coordination state used by admission
and quota controllers.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allocated** | int or string | Allocated is the admission-owned total that has been accepted by the webhook.<br>It must be updated only through optimistic concurrency on QuantityLedger. | false |
| **[conditions](#quantityledgerstatusconditionsindex)** | []object | Conditions for the resource claim | false |
| **[pendingDeletes](#quantityledgerstatuspendingdeletesindex)** | []object | Pending delete hints carried over from admission delete handling. | false |
| **[reservations](#quantityledgerstatusreservationsindex)** | []object | Active inflight reservations for this quota. | false |
| **reserved** | int or string | Reserved is the aggregate sum of all active reservations.<br>Controllers/webhooks should treat this as derived data from Reservations. | false |


### QuantityLedger.status.conditions[index]



Condition contains details for one aspect of the current state of this API Resource.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **lastTransitionTime** | string | lastTransitionTime is the last time the condition transitioned from one status to another.<br>This should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.<br/>*Format*: date-time<br/> | true |
| **message** | string | message is a human readable message indicating details about the transition.<br>This may be an empty string. | true |
| **reason** | string | reason contains a programmatic identifier indicating the reason for the condition's last transition.<br>Producers of specific condition types may define expected values and meanings for this field,<br>and whether the values are considered a guaranteed API.<br>The value should be a CamelCase string.<br>This field may not be empty. | true |
| **status** | enum | status of the condition, one of True, False, Unknown.<br/>*Enum*: True, False, Unknown<br/> | true |
| **type** | string | type of condition in CamelCase or in foo.example.com/CamelCase. | true |
| **observedGeneration** | integer | observedGeneration represents the .metadata.generation that the condition was set based upon.<br>For instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date<br>with respect to the current state of the instance.<br/>*Format*: int64<br/>*Minimum*: 0<br/> | false |


### QuantityLedger.status.pendingDeletes[index]



QuantityLedgerPendingDelete tracks objects that are expected to disappear from claims
soon, but may still temporarily appear during rebuild due to propagation delay.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **createdAt** | string | <br/>*Format*: date-time<br/> | true |
| **[objectRef](#quantityledgerstatuspendingdeletesindexobjectref)** | object | QuotaLedgerObjectRef identifies the object for which a reservation exists.<br>UID may be empty for CREATE admission before the object is persisted. | true |


### QuantityLedger.status.pendingDeletes[index].objectRef



QuotaLedgerObjectRef identifies the object for which a reservation exists.
UID may be empty for CREATE admission before the object is persisted.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | APIVersion of the tracked object, for example "v1". | true |
| **kind** | string | Kind of the tracked object, for example "Pod". | true |
| **apiGroup** | string | APIGroup of the tracked object. | false |
| **name** | string | Name of the tracked object. | false |
| **namespace** | string | Namespace of the tracked object. | false |
| **uid** | string | UID of the tracked object. | false |


### QuantityLedger.status.reservations[index]



QuantityLedgerReservation represents one active inflight reservation.
ID should be stable for retries of the same admission request.
In practice, admission.Request.UID is a good default.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **createdAt** | string | Time the reservation was first created.<br/>*Format*: date-time<br/> | true |
| **id** | string | Unique reservation identifier. | true |
| **[objectRef](#quantityledgerstatusreservationsindexobjectref)** | object | Object that this reservation is intended to create/update. | true |
| **updatedAt** | string | Time the reservation was last refreshed or updated.<br/>*Format*: date-time<br/> | true |
| **usage** | int or string | Amount reserved for this request. | true |
| **expiresAt** | string | Time after which the reservation may be considered stale.<br/>*Format*: date-time<br/> | false |


### QuantityLedger.status.reservations[index].objectRef



Object that this reservation is intended to create/update.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | APIVersion of the tracked object, for example "v1". | true |
| **kind** | string | Kind of the tracked object, for example "Pod". | true |
| **apiGroup** | string | APIGroup of the tracked object. | false |
| **name** | string | Name of the tracked object. | false |
| **namespace** | string | Namespace of the tracked object. | false |
| **uid** | string | UID of the tracked object. | false |

## ResourcePoolClaim






ResourcePoolClaim is the Schema for the resourcepoolclaims API.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta2 | true |
| **kind** | string | ResourcePoolClaim | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#resourcepoolclaimspec)** | object |  | true |
| **[status](#resourcepoolclaimstatus)** | object | ResourceQuotaClaimStatus defines the observed state of ResourceQuotaClaim. | false |


### ResourcePoolClaim.spec






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **claim** | map[string]int or string | Amount which should be claimed for the resourcequota | true |
| **pool** | string | If there's the possability to claim from multiple global Quotas<br>You must be specific about which one you want to claim resources from<br>Once bound to a ResourcePool, this field is immutable | true |


### ResourcePoolClaim.status



ResourceQuotaClaimStatus defines the observed state of ResourceQuotaClaim.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[conditions](#resourcepoolclaimstatusconditionsindex)** | []object | Conditions for the resource claim | true |
| **[allocation](#resourcepoolclaimstatusallocation)** | object | Tracks the Usage from Claimed from this claim and available resources | false |
| **[condition](#resourcepoolclaimstatuscondition)** | object | <span style="color:red;font-weight:bold">Deprecated: Use Conditions</span> | false |
| **observedGeneration** | integer | ObservedGeneration is the most recent generation the controller has observed.<br/>*Format*: int64<br/> | false |
| **[pool](#resourcepoolclaimstatuspool)** | object | Reference to the GlobalQuota being claimed from | false |


### ResourcePoolClaim.status.conditions[index]



Condition contains details for one aspect of the current state of this API Resource.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **lastTransitionTime** | string | lastTransitionTime is the last time the condition transitioned from one status to another.<br>This should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.<br/>*Format*: date-time<br/> | true |
| **message** | string | message is a human readable message indicating details about the transition.<br>This may be an empty string. | true |
| **reason** | string | reason contains a programmatic identifier indicating the reason for the condition's last transition.<br>Producers of specific condition types may define expected values and meanings for this field,<br>and whether the values are considered a guaranteed API.<br>The value should be a CamelCase string.<br>This field may not be empty. | true |
| **status** | enum | status of the condition, one of True, False, Unknown.<br/>*Enum*: True, False, Unknown<br/> | true |
| **type** | string | type of condition in CamelCase or in foo.example.com/CamelCase. | true |
| **observedGeneration** | integer | observedGeneration represents the .metadata.generation that the condition was set based upon.<br>For instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date<br>with respect to the current state of the instance.<br/>*Format*: int64<br/>*Minimum*: 0<br/> | false |


### ResourcePoolClaim.status.allocation



Tracks the Usage from Claimed from this claim and available resources


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **available** | map[string]int or string | Used to track the usage of the resource in the pool (diff hard - claimed). May be used for further automation | false |
| **hard** | map[string]int or string | Hard is the set of enforced hard limits for each named resource.<br>More info: https://kubernetes.io/docs/concepts/policy/resource-quotas/ | false |
| **used** | map[string]int or string | Used is the current observed total usage of the resource in the namespace. | false |


### ResourcePoolClaim.status.condition



Deprecated: Use Conditions


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **lastTransitionTime** | string | lastTransitionTime is the last time the condition transitioned from one status to another.<br>This should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.<br/>*Format*: date-time<br/> | true |
| **message** | string | message is a human readable message indicating details about the transition.<br>This may be an empty string. | true |
| **reason** | string | reason contains a programmatic identifier indicating the reason for the condition's last transition.<br>Producers of specific condition types may define expected values and meanings for this field,<br>and whether the values are considered a guaranteed API.<br>The value should be a CamelCase string.<br>This field may not be empty. | true |
| **status** | enum | status of the condition, one of True, False, Unknown.<br/>*Enum*: True, False, Unknown<br/> | true |
| **type** | string | type of condition in CamelCase or in foo.example.com/CamelCase. | true |
| **observedGeneration** | integer | observedGeneration represents the .metadata.generation that the condition was set based upon.<br>For instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date<br>with respect to the current state of the instance.<br/>*Format*: int64<br/>*Minimum*: 0<br/> | false |


### ResourcePoolClaim.status.pool



Reference to the GlobalQuota being claimed from


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **name** | string | Name of the referent. | true |
| **uid** | string | UID of the tracked Tenant to pin point tracking | true |

## ResourcePool






Resourcepools allows you to define a set of resources as known from ResoureQuotas. The Resourcepools are defined at cluster-scope an should
be administrated by cluster-administrators. However they create an interface, where cluster-administrators can define
from which namespaces resources from a Resourcepool can be claimed. The claiming is done via a namespaced CRD called ResourcePoolClaim. Then
it's up the group of users within these namespaces, to manage the resources they consume per namespace. Each Resourcepool provisions a ResourceQuotainto all the selected namespaces. Then essentially the ResourcePoolClaims, when they can be assigned to the ResourcePool stack resources on top of that
ResourceQuota based on the namspace, where the ResourcePoolClaim was made from.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta2 | true |
| **kind** | string | ResourcePool | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#resourcepoolspec)** | object | ResourcePoolSpec. | true |
| **[status](#resourcepoolstatus)** | object | GlobalResourceQuotaStatus defines the observed state of GlobalResourceQuota. | false |


### ResourcePool.spec



ResourcePoolSpec.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[quota](#resourcepoolspecquota)** | object | Define the resourcequota served by this resourcepool. | true |
| **[config](#resourcepoolspecconfig)** | object | Additional Configuration<br/>*Default*: map[]<br/> | false |
| **defaults** | map[string]int or string | The Defaults given for each namespace, the default is not counted towards the total allocation<br>When you use claims it's recommended to provision Defaults as the prevent the scheduling of any resources | false |
| **[selectors](#resourcepoolspecselectorsindex)** | []object | Selector to match the namespaces that should be managed by the GlobalResourceQuota | false |


### ResourcePool.spec.quota



Define the resourcequota served by this resourcepool.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **hard** | map[string]int or string | hard is the set of desired hard limits for each named resource.<br>More info: https://kubernetes.io/docs/concepts/policy/resource-quotas/ | false |
| **[scopeSelector](#resourcepoolspecquotascopeselector)** | object | scopeSelector is also a collection of filters like scopes that must match each object tracked by a quota<br>but expressed using ScopeSelectorOperator in combination with possible values.<br>For a resource to match, both scopes AND scopeSelector (if specified in spec), must be matched. | false |
| **scopes** | []string | A collection of filters that must match each object tracked by a quota.<br>If not specified, the quota matches all objects. | false |


### ResourcePool.spec.quota.scopeSelector



scopeSelector is also a collection of filters like scopes that must match each object tracked by a quota
but expressed using ScopeSelectorOperator in combination with possible values.
For a resource to match, both scopes AND scopeSelector (if specified in spec), must be matched.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#resourcepoolspecquotascopeselectormatchexpressionsindex)** | []object | A list of scope selector requirements by scope of the resources. | false |


### ResourcePool.spec.quota.scopeSelector.matchExpressions[index]



A scoped-resource selector requirement is a selector that contains values, a scope name, and an operator
that relates the scope name and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **operator** | string | Represents a scope's relationship to a set of values.<br>Valid operators are In, NotIn, Exists, DoesNotExist. | true |
| **scopeName** | string | The name of the scope that the selector applies to. | true |
| **values** | []string | An array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty.<br>This array is replaced during a strategic merge patch. | false |


### ResourcePool.spec.config



Additional Configuration


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **defaultsZero** | boolean | With this option all resources which can be allocated are set to 0 for the resourcequota defaults. (Default false)<br/>*Default*: false<br/> | false |
| **deleteBoundResources** | boolean | When a resourcepool is deleted, the resourceclaims bound to it are disassociated from the resourcepool but not deleted.<br>By Enabling this option, the resourceclaims will be deleted when the resourcepool is deleted, if they are in bound state. (Default false)<br/>*Default*: false<br/> | false |
| **orderedQueue** | boolean | Claims are queued whenever they are allocated to a pool. A pool tries to allocate claims in order based on their<br>creation date. But no matter their creation time, if a claim is requesting too much resources it's put into the queue<br>but if a lower priority claim still has enough space in the available resources, it will be able to claim them. Eventough<br>it's priority was lower<br>Enabling this option respects to Order. Meaning the Creationtimestamp matters and if a resource is put into the queue, no<br>other claim can claim the same resources with lower priority. (Default false)<br/>*Default*: false<br/> | false |


### ResourcePool.spec.selectors[index]



Selector for resources and their labels or selecting origin namespaces


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#resourcepoolspecselectorsindexmatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### ResourcePool.spec.selectors[index].matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### ResourcePool.status



GlobalResourceQuotaStatus defines the observed state of GlobalResourceQuota.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[conditions](#resourcepoolstatusconditionsindex)** | []object | Conditions for the resource claim | true |
| **[allocation](#resourcepoolstatusallocation)** | object | Tracks the Usage from Claimed against what has been granted from the pool | false |
| **claimCount** | integer | Amount of claims<br/>*Default*: 0<br/> | false |
| **[claims](#resourcepoolstatusclaimskeyindex)** | map[string][]object | Tracks the quotas for the Resource. | false |
| **[exhaustions](#resourcepoolstatusexhaustionskey)** | map[string]object | Exhaustions from claims associated with the pool | false |
| **namespaceCount** | integer | How many namespaces are considered<br/>*Default*: 0<br/> | false |
| **namespaces** | []string | Namespaces which are considered for claims | false |
| **observedGeneration** | integer | ObservedGeneration is the most recent generation the controller has observed.<br/>*Format*: int64<br/> | false |


### ResourcePool.status.conditions[index]



Condition contains details for one aspect of the current state of this API Resource.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **lastTransitionTime** | string | lastTransitionTime is the last time the condition transitioned from one status to another.<br>This should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.<br/>*Format*: date-time<br/> | true |
| **message** | string | message is a human readable message indicating details about the transition.<br>This may be an empty string. | true |
| **reason** | string | reason contains a programmatic identifier indicating the reason for the condition's last transition.<br>Producers of specific condition types may define expected values and meanings for this field,<br>and whether the values are considered a guaranteed API.<br>The value should be a CamelCase string.<br>This field may not be empty. | true |
| **status** | enum | status of the condition, one of True, False, Unknown.<br/>*Enum*: True, False, Unknown<br/> | true |
| **type** | string | type of condition in CamelCase or in foo.example.com/CamelCase. | true |
| **observedGeneration** | integer | observedGeneration represents the .metadata.generation that the condition was set based upon.<br>For instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date<br>with respect to the current state of the instance.<br/>*Format*: int64<br/>*Minimum*: 0<br/> | false |


### ResourcePool.status.allocation



Tracks the Usage from Claimed against what has been granted from the pool


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **available** | map[string]int or string | Used to track the usage of the resource in the pool (diff hard - claimed). May be used for further automation | false |
| **hard** | map[string]int or string | Hard is the set of enforced hard limits for each named resource.<br>More info: https://kubernetes.io/docs/concepts/policy/resource-quotas/ | false |
| **used** | map[string]int or string | Used is the current observed total usage of the resource in the namespace. | false |


### ResourcePool.status.claims[key][index]



ResourceQuotaClaimStatus defines the observed state of ResourceQuotaClaim.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **name** | string | Name of the referent. | true |
| **namespace** | string | Namespace of the referent. | true |
| **uid** | string | UID of the tracked Tenant to pin point tracking | true |
| **claims** | map[string]int or string | Claimed resources | false |


### ResourcePool.status.exhaustions[key]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **available** | int or string | Available Resources to be claimed | false |
| **requesting** | int or string | Requesting Resources | false |

## RuleStatus









| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta2 | true |
| **kind** | string | RuleStatus | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#rulestatusspecindex)** | []object |  | false |
| **[status](#rulestatusstatus)** | object | RuleStatus contains the accumulated rules applying to namespace it's deployed in. | false |


### RuleStatus.spec[index]



For future implementation where users might manage RuleStatus CRs themselves


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[enforce](#rulestatusspecindexenforce)** | object | Enforcement for given rule | false |


### RuleStatus.spec[index].enforce



Enforcement for given rule


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **action** | enum | Declare the action being performed on the enforcement rule:<br>deny: On match, deny admission request<br>allow: On match, allowed admission request<br>audit: On match, audit (post event) of admission request<br/>*Enum*: allow, deny, audit<br/>*Default*: deny<br/> | false |
| **[services](#rulestatusspecindexenforceservices)** | object | Enforcement for Services. | false |
| **[workloads](#rulestatusspecindexenforceworkloads)** | object | Enforcement for Workloads (Pods) | false |


### RuleStatus.spec[index].enforce.services



Enforcement for Services.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[externalNames](#rulestatusspecindexenforceservicesexternalnames)** | object | ExternalNames defines additional constraints for Services of type ExternalName. | false |
| **[loadBalancers](#rulestatusspecindexenforceservicesloadbalancers)** | object | LoadBalancers defines additional constraints for Services of type LoadBalancer. | false |
| **[nodePorts](#rulestatusspecindexenforceservicesnodeports)** | object | NodePorts defines additional constraints for nodePort values. | false |
| **types** | []enum | Types defines the Service types matched by this rule.<br><br>Supported values:<br>- ClusterIP<br>- NodePort<br>- LoadBalancer<br>- ExternalName<br/>*Enum*: ClusterIP, NodePort, LoadBalancer, ExternalName<br/> | false |


### RuleStatus.spec[index].enforce.services.externalNames



ExternalNames defines additional constraints for Services of type ExternalName.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[hostnames](#rulestatusspecindexenforceservicesexternalnameshostnamesindex)** | []object | Hostnames restricts spec.externalName.<br>Empty means no additional hostname restriction once ExternalName is allowed by types. | false |


### RuleStatus.spec[index].enforce.services.externalNames.hostnames[index]



At least one of Exact or Exp must be set.
Both may be set together.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **exact** | []string | Exact matches one of the provided values exactly. | false |
| **exp** | string | Exp matches regular expression. | false |
| **negate** | boolean | Negate regular Expression<br/>*Default*: false<br/> | false |


### RuleStatus.spec[index].enforce.services.loadBalancers



LoadBalancers defines additional constraints for Services of type LoadBalancer.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **cidrs** | []string | CIDRs restricts spec.loadBalancerIP and spec.loadBalancerSourceRanges.<br>Empty means no additional CIDR restriction once LoadBalancer is allowed by types. | false |


### RuleStatus.spec[index].enforce.services.nodePorts



NodePorts defines additional constraints for nodePort values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[ports](#rulestatusspecindexenforceservicesnodeportsportsindex)** | []object | Ports restricts explicitly requested nodePort values.<br>Empty means no additional port restriction once NodePort is allowed by types. | false |


### RuleStatus.spec[index].enforce.services.nodePorts.ports[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **from** | integer | <br/>*Format*: int32<br/>*Minimum*: 1<br/>*Maximum*: 65535<br/> | true |
| **to** | integer | <br/>*Format*: int32<br/>*Minimum*: 1<br/>*Maximum*: 65535<br/> | true |


### RuleStatus.spec[index].enforce.workloads



Enforcement for Workloads (Pods)


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **qosClasses** | []string | Define Pod QoS classes matched by this enforcement rule.<br>Supported values are Guaranteed, Burstable and BestEffort. | false |
| **[registries](#rulestatusspecindexenforceworkloadsregistriesindex)** | []object | Define registries which are allowed to be used within this tenant<br>The rules are aggregated, since you can use Regular Expressions the match registry endpoints | false |
| **[schedulers](#rulestatusspecindexenforceworkloadsschedulersindex)** | []object | Schedulers defines schedulerName matchers for Pod admission.<br><br>The rule is evaluated against pod.spec.schedulerName.<br>Empty schedulerName is ignored and is not normalized to default-scheduler. | false |
| **targets** | []enum | Define the enforcement targets this rule applies to.<br>If empty, each webhook applies its own backwards-compatible default.<br/>*Enum*: pod/initcontainers, pod/ephemeralcontainers, pod/containers, pod/volumes<br/> | false |


### RuleStatus.spec[index].enforce.workloads.registries[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **exact** | []string | Exact matches one of the provided values exactly. | false |
| **exp** | string | Exp matches regular expression. | false |
| **negate** | boolean | Negate regular Expression<br/>*Default*: false<br/> | false |
| **policy** | []string | Allowed PullPolicy for the given registry. Supplying no value allows all policies. | false |


### RuleStatus.spec[index].enforce.workloads.schedulers[index]



At least one of Exact or Exp must be set.
Both may be set together.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **exact** | []string | Exact matches one of the provided values exactly. | false |
| **exp** | string | Exp matches regular expression. | false |
| **negate** | boolean | Negate regular Expression<br/>*Default*: false<br/> | false |


### RuleStatus.status



RuleStatus contains the accumulated rules applying to namespace it's deployed in.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[conditions](#rulestatusstatusconditionsindex)** | []object | Conditions | true |
| **observedGeneration** | integer | ObservedGeneration is the most recent generation the controller has observed.<br/>*Format*: int64<br/> | false |
| **[rule](#rulestatusstatusrule)** | object | <span style="color:red;font-weight:bold">Deprecated: use Rules.<br>Rule contains a legacy flattened view and cannot fully represent action-aware rules.</span> | false |
| **[rules](#rulestatusstatusrulesindex)** | []object | Rules contains the effective namespace rules after tenant rule selection.<br>Order is preserved from the originating Tenant rules. | false |


### RuleStatus.status.conditions[index]



Condition contains details for one aspect of the current state of this API Resource.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **lastTransitionTime** | string | lastTransitionTime is the last time the condition transitioned from one status to another.<br>This should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.<br/>*Format*: date-time<br/> | true |
| **message** | string | message is a human readable message indicating details about the transition.<br>This may be an empty string. | true |
| **reason** | string | reason contains a programmatic identifier indicating the reason for the condition's last transition.<br>Producers of specific condition types may define expected values and meanings for this field,<br>and whether the values are considered a guaranteed API.<br>The value should be a CamelCase string.<br>This field may not be empty. | true |
| **status** | enum | status of the condition, one of True, False, Unknown.<br/>*Enum*: True, False, Unknown<br/> | true |
| **type** | string | type of condition in CamelCase or in foo.example.com/CamelCase. | true |
| **observedGeneration** | integer | observedGeneration represents the .metadata.generation that the condition was set based upon.<br>For instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date<br>with respect to the current state of the instance.<br/>*Format*: int64<br/>*Minimum*: 0<br/> | false |


### RuleStatus.status.rule



Deprecated: use Rules.
Rule contains a legacy flattened view and cannot fully represent action-aware rules.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[enforce](#rulestatusstatusruleenforce)** | object | Enforcement for given rule | false |


### RuleStatus.status.rule.enforce



Enforcement for given rule


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **action** | enum | Declare the action being performed on the enforcement rule:<br>deny: On match, deny admission request<br>allow: On match, allowed admission request<br>audit: On match, audit (post event) of admission request<br/>*Enum*: allow, deny, audit<br/>*Default*: deny<br/> | false |
| **[services](#rulestatusstatusruleenforceservices)** | object | Enforcement for Services. | false |
| **[workloads](#rulestatusstatusruleenforceworkloads)** | object | Enforcement for Workloads (Pods) | false |


### RuleStatus.status.rule.enforce.services



Enforcement for Services.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[externalNames](#rulestatusstatusruleenforceservicesexternalnames)** | object | ExternalNames defines additional constraints for Services of type ExternalName. | false |
| **[loadBalancers](#rulestatusstatusruleenforceservicesloadbalancers)** | object | LoadBalancers defines additional constraints for Services of type LoadBalancer. | false |
| **[nodePorts](#rulestatusstatusruleenforceservicesnodeports)** | object | NodePorts defines additional constraints for nodePort values. | false |
| **types** | []enum | Types defines the Service types matched by this rule.<br><br>Supported values:<br>- ClusterIP<br>- NodePort<br>- LoadBalancer<br>- ExternalName<br/>*Enum*: ClusterIP, NodePort, LoadBalancer, ExternalName<br/> | false |


### RuleStatus.status.rule.enforce.services.externalNames



ExternalNames defines additional constraints for Services of type ExternalName.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[hostnames](#rulestatusstatusruleenforceservicesexternalnameshostnamesindex)** | []object | Hostnames restricts spec.externalName.<br>Empty means no additional hostname restriction once ExternalName is allowed by types. | false |


### RuleStatus.status.rule.enforce.services.externalNames.hostnames[index]



At least one of Exact or Exp must be set.
Both may be set together.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **exact** | []string | Exact matches one of the provided values exactly. | false |
| **exp** | string | Exp matches regular expression. | false |
| **negate** | boolean | Negate regular Expression<br/>*Default*: false<br/> | false |


### RuleStatus.status.rule.enforce.services.loadBalancers



LoadBalancers defines additional constraints for Services of type LoadBalancer.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **cidrs** | []string | CIDRs restricts spec.loadBalancerIP and spec.loadBalancerSourceRanges.<br>Empty means no additional CIDR restriction once LoadBalancer is allowed by types. | false |


### RuleStatus.status.rule.enforce.services.nodePorts



NodePorts defines additional constraints for nodePort values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[ports](#rulestatusstatusruleenforceservicesnodeportsportsindex)** | []object | Ports restricts explicitly requested nodePort values.<br>Empty means no additional port restriction once NodePort is allowed by types. | false |


### RuleStatus.status.rule.enforce.services.nodePorts.ports[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **from** | integer | <br/>*Format*: int32<br/>*Minimum*: 1<br/>*Maximum*: 65535<br/> | true |
| **to** | integer | <br/>*Format*: int32<br/>*Minimum*: 1<br/>*Maximum*: 65535<br/> | true |


### RuleStatus.status.rule.enforce.workloads



Enforcement for Workloads (Pods)


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **qosClasses** | []string | Define Pod QoS classes matched by this enforcement rule.<br>Supported values are Guaranteed, Burstable and BestEffort. | false |
| **[registries](#rulestatusstatusruleenforceworkloadsregistriesindex)** | []object | Define registries which are allowed to be used within this tenant<br>The rules are aggregated, since you can use Regular Expressions the match registry endpoints | false |
| **[schedulers](#rulestatusstatusruleenforceworkloadsschedulersindex)** | []object | Schedulers defines schedulerName matchers for Pod admission.<br><br>The rule is evaluated against pod.spec.schedulerName.<br>Empty schedulerName is ignored and is not normalized to default-scheduler. | false |
| **targets** | []enum | Define the enforcement targets this rule applies to.<br>If empty, each webhook applies its own backwards-compatible default.<br/>*Enum*: pod/initcontainers, pod/ephemeralcontainers, pod/containers, pod/volumes<br/> | false |


### RuleStatus.status.rule.enforce.workloads.registries[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **exact** | []string | Exact matches one of the provided values exactly. | false |
| **exp** | string | Exp matches regular expression. | false |
| **negate** | boolean | Negate regular Expression<br/>*Default*: false<br/> | false |
| **policy** | []string | Allowed PullPolicy for the given registry. Supplying no value allows all policies. | false |


### RuleStatus.status.rule.enforce.workloads.schedulers[index]



At least one of Exact or Exp must be set.
Both may be set together.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **exact** | []string | Exact matches one of the provided values exactly. | false |
| **exp** | string | Exp matches regular expression. | false |
| **negate** | boolean | Negate regular Expression<br/>*Default*: false<br/> | false |


### RuleStatus.status.rules[index]



For future implementation where users might manage RuleStatus CRs themselves


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[enforce](#rulestatusstatusrulesindexenforce)** | object | Enforcement for given rule | false |


### RuleStatus.status.rules[index].enforce



Enforcement for given rule


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **action** | enum | Declare the action being performed on the enforcement rule:<br>deny: On match, deny admission request<br>allow: On match, allowed admission request<br>audit: On match, audit (post event) of admission request<br/>*Enum*: allow, deny, audit<br/>*Default*: deny<br/> | false |
| **[services](#rulestatusstatusrulesindexenforceservices)** | object | Enforcement for Services. | false |
| **[workloads](#rulestatusstatusrulesindexenforceworkloads)** | object | Enforcement for Workloads (Pods) | false |


### RuleStatus.status.rules[index].enforce.services



Enforcement for Services.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[externalNames](#rulestatusstatusrulesindexenforceservicesexternalnames)** | object | ExternalNames defines additional constraints for Services of type ExternalName. | false |
| **[loadBalancers](#rulestatusstatusrulesindexenforceservicesloadbalancers)** | object | LoadBalancers defines additional constraints for Services of type LoadBalancer. | false |
| **[nodePorts](#rulestatusstatusrulesindexenforceservicesnodeports)** | object | NodePorts defines additional constraints for nodePort values. | false |
| **types** | []enum | Types defines the Service types matched by this rule.<br><br>Supported values:<br>- ClusterIP<br>- NodePort<br>- LoadBalancer<br>- ExternalName<br/>*Enum*: ClusterIP, NodePort, LoadBalancer, ExternalName<br/> | false |


### RuleStatus.status.rules[index].enforce.services.externalNames



ExternalNames defines additional constraints for Services of type ExternalName.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[hostnames](#rulestatusstatusrulesindexenforceservicesexternalnameshostnamesindex)** | []object | Hostnames restricts spec.externalName.<br>Empty means no additional hostname restriction once ExternalName is allowed by types. | false |


### RuleStatus.status.rules[index].enforce.services.externalNames.hostnames[index]



At least one of Exact or Exp must be set.
Both may be set together.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **exact** | []string | Exact matches one of the provided values exactly. | false |
| **exp** | string | Exp matches regular expression. | false |
| **negate** | boolean | Negate regular Expression<br/>*Default*: false<br/> | false |


### RuleStatus.status.rules[index].enforce.services.loadBalancers



LoadBalancers defines additional constraints for Services of type LoadBalancer.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **cidrs** | []string | CIDRs restricts spec.loadBalancerIP and spec.loadBalancerSourceRanges.<br>Empty means no additional CIDR restriction once LoadBalancer is allowed by types. | false |


### RuleStatus.status.rules[index].enforce.services.nodePorts



NodePorts defines additional constraints for nodePort values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[ports](#rulestatusstatusrulesindexenforceservicesnodeportsportsindex)** | []object | Ports restricts explicitly requested nodePort values.<br>Empty means no additional port restriction once NodePort is allowed by types. | false |


### RuleStatus.status.rules[index].enforce.services.nodePorts.ports[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **from** | integer | <br/>*Format*: int32<br/>*Minimum*: 1<br/>*Maximum*: 65535<br/> | true |
| **to** | integer | <br/>*Format*: int32<br/>*Minimum*: 1<br/>*Maximum*: 65535<br/> | true |


### RuleStatus.status.rules[index].enforce.workloads



Enforcement for Workloads (Pods)


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **qosClasses** | []string | Define Pod QoS classes matched by this enforcement rule.<br>Supported values are Guaranteed, Burstable and BestEffort. | false |
| **[registries](#rulestatusstatusrulesindexenforceworkloadsregistriesindex)** | []object | Define registries which are allowed to be used within this tenant<br>The rules are aggregated, since you can use Regular Expressions the match registry endpoints | false |
| **[schedulers](#rulestatusstatusrulesindexenforceworkloadsschedulersindex)** | []object | Schedulers defines schedulerName matchers for Pod admission.<br><br>The rule is evaluated against pod.spec.schedulerName.<br>Empty schedulerName is ignored and is not normalized to default-scheduler. | false |
| **targets** | []enum | Define the enforcement targets this rule applies to.<br>If empty, each webhook applies its own backwards-compatible default.<br/>*Enum*: pod/initcontainers, pod/ephemeralcontainers, pod/containers, pod/volumes<br/> | false |


### RuleStatus.status.rules[index].enforce.workloads.registries[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **exact** | []string | Exact matches one of the provided values exactly. | false |
| **exp** | string | Exp matches regular expression. | false |
| **negate** | boolean | Negate regular Expression<br/>*Default*: false<br/> | false |
| **policy** | []string | Allowed PullPolicy for the given registry. Supplying no value allows all policies. | false |


### RuleStatus.status.rules[index].enforce.workloads.schedulers[index]



At least one of Exact or Exp must be set.
Both may be set together.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **exact** | []string | Exact matches one of the provided values exactly. | false |
| **exp** | string | Exp matches regular expression. | false |
| **negate** | boolean | Negate regular Expression<br/>*Default*: false<br/> | false |

## TenantOwner






TenantOwner is the Schema for the tenantowners API.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta2 | true |
| **kind** | string | TenantOwner | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#tenantownerspec)** | object | spec defines the desired state of TenantOwner. | true |
| **[status](#tenantownerstatus)** | object | status defines the observed state of TenantOwner. | false |


### TenantOwner.spec



spec defines the desired state of TenantOwner.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **aggregate** | boolean | Adds the given subject as capsule user. When enabled this subject does not have to be<br>mentioned in the CapsuleConfiguration as Capsule User. In almost all scenarios Tenant Owners<br>must be Capsule Users.<br/>*Default*: true<br/> | true |
| **kind** | enum | Kind of entity. Possible values are "User", "Group", and "ServiceAccount"<br/>*Enum*: User, Group, ServiceAccount<br/> | true |
| **name** | string | Name of the entity. | true |
| **clusterRoles** | []string | Defines additional cluster-roles for the specific Owner.<br/>*Default*: [admin capsule-namespace-deleter]<br/> | false |


### TenantOwner.status



status defines the observed state of TenantOwner.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[conditions](#tenantownerstatusconditionsindex)** | []object | Conditions contains the reconciliation conditions for this TenantOwner. | false |
| **observedGeneration** | integer | ObservedGeneration is the most recent generation the controller has observed.<br/>*Format*: int64<br/> | false |
| **tenants** | []string | Tenants lists the names of all Tenants that this TenantOwner is currently matched to<br>via the Tenant's spec.permissions.matchOwners selectors. | false |


### TenantOwner.status.conditions[index]



Condition contains details for one aspect of the current state of this API Resource.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **lastTransitionTime** | string | lastTransitionTime is the last time the condition transitioned from one status to another.<br>This should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.<br/>*Format*: date-time<br/> | true |
| **message** | string | message is a human readable message indicating details about the transition.<br>This may be an empty string. | true |
| **reason** | string | reason contains a programmatic identifier indicating the reason for the condition's last transition.<br>Producers of specific condition types may define expected values and meanings for this field,<br>and whether the values are considered a guaranteed API.<br>The value should be a CamelCase string.<br>This field may not be empty. | true |
| **status** | enum | status of the condition, one of True, False, Unknown.<br/>*Enum*: True, False, Unknown<br/> | true |
| **type** | string | type of condition in CamelCase or in foo.example.com/CamelCase. | true |
| **observedGeneration** | integer | observedGeneration represents the .metadata.generation that the condition was set based upon.<br>For instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date<br>with respect to the current state of the instance.<br/>*Format*: int64<br/>*Minimum*: 0<br/> | false |

## TenantResource






TenantResource allows a Tenant Owner, if enabled with proper RBAC, to propagate resources in its Namespace.
The object must be deployed in a Tenant Namespace, and cannot reference object living in non-Tenant namespaces.
For such cases, the GlobalTenantResource must be used.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | capsule.clastix.io/v1beta2 | true |
| **kind** | string | TenantResource | true |
| **[metadata](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.28/#objectmeta-v1-meta)** | object | Refer to the Kubernetes API documentation for the fields of the `metadata` field. | true |
| **[spec](#tenantresourcespec)** | object | TenantResourceSpec defines the desired state of TenantResource. | true |
| **[status](#tenantresourcestatus)** | object | TenantResourceStatus defines the observed state of TenantResource. | false |


### TenantResource.spec



TenantResourceSpec defines the desired state of TenantResource.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[resources](#tenantresourcespecresourcesindex)** | []object | Defines the rules to select targeting Namespace, along with the objects that must be replicated. | true |
| **resyncPeriod** | string | Define the period of time upon a second reconciliation must be invoked.<br>Keep in mind that any change to the manifests will trigger a new reconciliation.<br/>*Default*: 60s<br/> | true |
| **[settings](#tenantresourcespecsettings)** | object | Provide additional settings<br/>*Default*: map[]<br/> | true |
| **cordoned** | boolean | When cordoning a replication it will no longer execute any applies or deletions (paused).<br>This is useful for maintenances<br/>*Default*: false<br/> | false |
| **[dependsOn](#tenantresourcespecdependsonindex)** | []object | DependsOn may contain a meta.NamespacedObjectReference slice<br>with references to TenantResource resources that must be ready before this<br>TenantResource can be reconciled. | false |
| **pruningOnDelete** | boolean | When the replicated resource manifest is deleted, all the objects replicated so far will be automatically deleted.<br>Disable this to keep replicated resources although the deletion of the replication manifest.<br/>*Default*: true<br/> | false |
| **[serviceAccount](#tenantresourcespecserviceaccount)** | object | Local ServiceAccount which will perform all the actions defined in the TenantResource<br>You must provide permissions accordingly to that ServiceAccount | false |


### TenantResource.spec.resources[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[additionalMetadata](#tenantresourcespecresourcesindexadditionalmetadata)** | object | Besides the Capsule metadata required by TenantResource controller, defines additional metadata that must be<br>added to the replicated resources. | false |
| **[context](#tenantresourcespecresourcesindexcontext)** | object | Provide additional template context, which can be used throughout all<br>the declared items for the replication | false |
| **[generators](#tenantresourcespecresourcesindexgeneratorsindex)** | []object | Templates for advanced use cases | false |
| **[namespaceSelector](#tenantresourcespecresourcesindexnamespaceselector)** | object | Defines the Namespace selector to select the Tenant Namespaces on which the resources must be propagated.<br>In case of nil value, all the Tenant Namespaces are targeted. | false |
| **[namespacedItems](#tenantresourcespecresourcesindexnamespaceditemsindex)** | []object | List of the resources already existing in other Namespaces that must be replicated. | false |
| **rawItems** | []object | List of raw resources that must be replicated. | false |


### TenantResource.spec.resources[index].additionalMetadata



Besides the Capsule metadata required by TenantResource controller, defines additional metadata that must be
added to the replicated resources.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **annotations** | map[string]string |  | false |
| **labels** | map[string]string |  | false |


### TenantResource.spec.resources[index].context



Provide additional template context, which can be used throughout all
the declared items for the replication


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[resources](#tenantresourcespecresourcesindexcontextresourcesindex)** | []object |  | false |


### TenantResource.spec.resources[index].context.resources[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | API version of the referent. | true |
| **kind** | string | Kind of the referent.<br>More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds | true |
| **index** | string | Index to mount the resource in the template context | false |
| **name** | string | Name of the values referent. This is useful<br>when you traying to get a specific resource | false |
| **namespace** | string | Namespace of the values referent. | false |
| **optional** | boolean | Only relevant if name is set. If an item is not optional, there will be an error thrown when it does not exist<br/>*Default*: true<br/> | false |
| **[selector](#tenantresourcespecresourcesindexcontextresourcesindexselector)** | object | Selector which allows to get any amount of these resources based on labels | false |


### TenantResource.spec.resources[index].context.resources[index].selector



Selector which allows to get any amount of these resources based on labels


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantresourcespecresourcesindexcontextresourcesindexselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### TenantResource.spec.resources[index].context.resources[index].selector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### TenantResource.spec.resources[index].generators[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **missingKey** | enum | Missing Key Option for templating<br/>*Enum*: invalid, zero, error<br/>*Default*: zero<br/> | false |
| **template** | string | Template contains any amount of yaml which is applied to Kubernetes.<br>This can be a single resource or multiple resources | false |


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



Reference


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **apiVersion** | string | API version of the referent. | true |
| **kind** | string | Kind of the referent.<br>More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds | true |
| **name** | string | Name of the values referent. This is useful<br>when you traying to get a specific resource | false |
| **namespace** | string | Namespace of the values referent. | false |
| **optional** | boolean | Only relevant if name is set. If an item is not optional, there will be an error thrown when it does not exist<br/>*Default*: true<br/> | false |
| **[selector](#tenantresourcespecresourcesindexnamespaceditemsindexselector)** | object | Selector which allows to get any amount of these resources based on labels | false |


### TenantResource.spec.resources[index].namespacedItems[index].selector



Selector which allows to get any amount of these resources based on labels


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


### TenantResource.spec.settings



Provide additional settings


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **adopt** | boolean | Enabling this allows TenanResources to interact with objects which were not created by a TenantResource. In this case on prune no deletion of the entire object is made.<br/>*Default*: false<br/> | false |
| **force** | boolean | Force indicates that in case of conflicts with server-side apply, the client should acquire ownership of the conflicting field.<br>You may create collisions with this.<br/>*Default*: false<br/> | false |


### TenantResource.spec.dependsOn[index]



LocalObjectReference contains enough information to locate the referenced Kubernetes resource object.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **name** | string | Name of the referent. | true |


### TenantResource.spec.serviceAccount



Local ServiceAccount which will perform all the actions defined in the TenantResource
You must provide permissions accordingly to that ServiceAccount


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **name** | string | Name of the referent. | true |


### TenantResource.status



TenantResourceStatus defines the observed state of TenantResource.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **size** | integer | How many items are being replicated by the TenantResource. | true |
| **[conditions](#tenantresourcestatusconditionsindex)** | []object | Condition of the GlobalTenantResource. | false |
| **observedGeneration** | integer | ObservedGeneration is the most recent generation the controller has observed.<br/>*Format*: int64<br/> | false |
| **[processedItems](#tenantresourcestatusprocesseditemsindex)** | []object | List of the replicated resources for the given TenantResource. | false |
| **[serviceAccount](#tenantresourcestatusserviceaccount)** | object | Serviceaccount used for impersonation | false |


### TenantResource.status.conditions[index]



Condition contains details for one aspect of the current state of this API Resource.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **lastTransitionTime** | string | lastTransitionTime is the last time the condition transitioned from one status to another.<br>This should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.<br/>*Format*: date-time<br/> | true |
| **message** | string | message is a human readable message indicating details about the transition.<br>This may be an empty string. | true |
| **reason** | string | reason contains a programmatic identifier indicating the reason for the condition's last transition.<br>Producers of specific condition types may define expected values and meanings for this field,<br>and whether the values are considered a guaranteed API.<br>The value should be a CamelCase string.<br>This field may not be empty. | true |
| **status** | enum | status of the condition, one of True, False, Unknown.<br/>*Enum*: True, False, Unknown<br/> | true |
| **type** | string | type of condition in CamelCase or in foo.example.com/CamelCase. | true |
| **observedGeneration** | integer | observedGeneration represents the .metadata.generation that the condition was set based upon.<br>For instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date<br>with respect to the current state of the instance.<br/>*Format*: int64<br/>*Minimum*: 0<br/> | false |


### TenantResource.status.processedItems[index]



Advanced Status Item for pin pointing items in tenants/namespaces.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **group** | string |  | false |
| **kind** | string |  | false |
| **name** | string |  | false |
| **namespace** | string |  | false |
| **origin** | string |  | false |
| **[status](#tenantresourcestatusprocesseditemsindexstatus)** | object |  | false |
| **tenant** | string |  | false |
| **version** | string |  | false |


### TenantResource.status.processedItems[index].status






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **status** | enum | status of the condition, one of True, False, Unknown.<br/>*Enum*: True, False, Unknown<br/> | true |
| **type** | string | type of condition in CamelCase or in foo.example.com/CamelCase. | true |
| **created** | boolean | Indicates wether the resource was created or adopted | false |
| **lastApply** | string | An opaque value that represents the internal version of this object that can<br>be used by clients to determine when objects have changed. May be used for optimistic<br>concurrency, change detection, and the watch operation on a resource or set of resources.<br>Clients must treat these values as opaque and passed unmodified back to the server.<br>They may only be valid for a particular resource or set of resources.<br><br>Populated by the system.<br>Read-only.<br>Value must be treated as opaque by clients and .<br>More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#concurrency-control-and-consistency<br/>*Format*: date-time<br/> | false |
| **message** | string | message is a human readable message indicating details about the transition.<br>This may be an empty string. | false |


### TenantResource.status.serviceAccount



Serviceaccount used for impersonation


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **name** | string | Name of the referent. | true |
| **namespace** | string | Namespace of the referent. | true |

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
| **[additionalRoleBindings](#tenantspecadditionalrolebindingsindex-1)** | []object | Specifies additional RoleBindings assigned to the Tenant. Capsule will ensure that all namespaces in the Tenant always contain the RoleBinding for the given ClusterRole. Optional. | false |
| **[containerRegistries](#tenantspeccontainerregistries-1)** | object | <span style="color:red;font-weight:bold">Deprecated: Use Enforcement.Registries instead<br><br>Specifies the trusted Image Registries assigned to the Tenant. Capsule assures that all Pods resources created in the Tenant can use only one of the allowed trusted registries. Optional.</span> | false |
| **cordoned** | boolean | Toggling the Tenant resources cordoning, when enable resources cannot be deleted.<br/>*Default*: false<br/> | false |
| **data** | JSON | Specify additional data relating to the tenant.<br>Mainly useable in templating and more accessible than labels/annotations. | false |
| **[deviceClasses](#tenantspecdeviceclasses)** | object | Specifies options for the DeviceClass resources. | false |
| **forceTenantPrefix** | boolean | Use this if you want to disable/enable the Tenant name prefix to specific Tenants, overriding global forceTenantPrefix in CapsuleConfiguration.<br>When set to 'true', it enforces Namespaces created for this Tenant to be named with the Tenant name prefix,<br>separated by a dash (i.e. for Tenant 'foo', namespace names must be prefixed with 'foo-'),<br>this is useful to avoid Namespace name collision.<br>When set to 'false', it allows Namespaces created for this Tenant to be named anything.<br>Overrides CapsuleConfiguration global forceTenantPrefix for the Tenant only.<br>If unset, Tenant uses CapsuleConfiguration's forceTenantPrefix<br>Optional | false |
| **[gatewayOptions](#tenantspecgatewayoptions)** | object | Specifies options for the GatewayClass resources. | false |
| **imagePullPolicies** | []enum | <span style="color:red;font-weight:bold">Deprecated: Use Enforcement.Registries instead<br><br>Specify the allowed values for the imagePullPolicies option in Pod resources. Capsule assures that all Pod resources created in the Tenant can use only one of the allowed policy. Optional.</span><br/>*Enum*: Always, Never, IfNotPresent<br/> | false |
| **[ingressOptions](#tenantspecingressoptions-1)** | object | Specifies options for the Ingress resources, such as allowed hostnames and IngressClass. Optional. | false |
| **[limitRanges](#tenantspeclimitranges-1)** | object | <span style="color:red;font-weight:bold">Deprecated: Use Tenant Replications instead (https://projectcapsule.dev/docs/replications/)<br><br>Specifies the resource min/max usage restrictions to the Tenant. The assigned values are inherited by any namespace created in the Tenant. Optional.</span> | false |
| **[namespaceOptions](#tenantspecnamespaceoptions-1)** | object | Specifies options for the Namespaces, such as additional metadata or maximum number of namespaces allowed for that Tenant. Once the namespace quota assigned to the Tenant has been reached, the Tenant owner cannot create further namespaces. Optional. | false |
| **[networkPolicies](#tenantspecnetworkpolicies-1)** | object | <span style="color:red;font-weight:bold">Deprecated: Use Tenant Replications instead (https://projectcapsule.dev/docs/replications/)<br><br>Specifies the NetworkPolicies assigned to the Tenant. The assigned NetworkPolicies are inherited by any namespace created in the Tenant. Optional.</span> | false |
| **nodeSelector** | map[string]string | Specifies the label to control the placement of pods on a given pool of worker nodes. All namespaces created within the Tenant will have the node selector annotation. This annotation tells the Kubernetes scheduler to place pods on the nodes having the selector label. Optional. | false |
| **[owners](#tenantspecownersindex-1)** | []object | Specifies the owners of the Tenant.<br>Optional | false |
| **[permissions](#tenantspecpermissions)** | object | Specify Permissions for the Tenant. | false |
| **[podOptions](#tenantspecpodoptions)** | object | Specifies options for the Pods deployed in the Tenant namespaces, such as additional metadata. | false |
| **preventDeletion** | boolean | Prevent accidental deletion of the Tenant.<br>When enabled, the deletion request will be declined.<br/>*Default*: false<br/> | false |
| **[priorityClasses](#tenantspecpriorityclasses-1)** | object | Specifies the allowed priorityClasses assigned to the Tenant.<br>Capsule assures that all Pods resources created in the Tenant can use only one of the allowed PriorityClasses.<br>A default value can be specified, and all the Pod resources created will inherit the declared class.<br>Optional. | false |
| **[resourceQuotas](#tenantspecresourcequotas-1)** | object | Specifies a list of ResourceQuota resources assigned to the Tenant. The assigned values are inherited by any namespace created in the Tenant. The Capsule operator aggregates ResourceQuota at Tenant level, so that the hard quota is never crossed for the given Tenant. This permits the Tenant owner to consume resources in the Tenant regardless of the namespace. Optional. | false |
| **[rules](#tenantspecrulesindex)** | []object | Specify enforcement specifications for the scope of the Tenant.<br> We are moving all configuration enforcement. per namespace into a rule construct.<br> It's currently not final.<br><br>Read More: https://projectcapsule.dev/docs/tenants/rules/ | false |
| **[runtimeClasses](#tenantspecruntimeclasses)** | object | Specifies the allowed RuntimeClasses assigned to the Tenant.<br>Capsule assures that all Pods resources created in the Tenant can use only one of the allowed RuntimeClasses.<br>Optional. | false |
| **[serviceOptions](#tenantspecserviceoptions-1)** | object | Specifies options for the Service, such as additional metadata or block of certain type of Services. Optional. | false |
| **[storageClasses](#tenantspecstorageclasses-1)** | object | Specifies the allowed StorageClasses assigned to the Tenant.<br>Capsule assures that all PersistentVolumeClaim resources created in the Tenant can use only one of the allowed StorageClasses.<br>A default value can be specified, and all the PersistentVolumeClaim resources created will inherit the declared class.<br>Optional. | false |


### Tenant.spec.additionalRoleBindings[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **clusterRoleName** | string |  | true |
| **[subjects](#tenantspecadditionalrolebindingsindexsubjectsindex-1)** | []object | kubebuilder:validation:Minimum=1 | true |
| **annotations** | map[string]string | Additional Annotations for the synchronized rolebindings | false |
| **labels** | map[string]string | Additional Labels for the synchronized rolebindings | false |


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



Deprecated: Use Enforcement.Registries instead

Specifies the trusted Image Registries assigned to the Tenant. Capsule assures that all Pods resources created in the Tenant can use only one of the allowed trusted registries. Optional.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string | Match exact elements which are allowed as class names within this tenant | false |
| **allowedRegex** | string | <span style="color:red;font-weight:bold">Deprecated: will be removed in a future release<br><br>Match elements by regex.</span> | false |


### Tenant.spec.deviceClasses



Specifies options for the DeviceClass resources.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string | Match exact elements which are allowed as class names within this tenant | false |
| **allowedRegex** | string | <span style="color:red;font-weight:bold">Deprecated: will be removed in a future release<br><br>Match elements by regex.</span> | false |
| **[matchExpressions](#tenantspecdeviceclassesmatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.deviceClasses.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.spec.gatewayOptions



Specifies options for the GatewayClass resources.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[allowedClasses](#tenantspecgatewayoptionsallowedclasses)** | object |  | false |


### Tenant.spec.gatewayOptions.allowedClasses






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string | Match exact elements which are allowed as class names within this tenant | false |
| **allowedRegex** | string | <span style="color:red;font-weight:bold">Deprecated: will be removed in a future release<br><br>Match elements by regex.</span> | false |
| **default** | string |  | false |
| **[matchExpressions](#tenantspecgatewayoptionsallowedclassesmatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.gatewayOptions.allowedClasses.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


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
| **allowed** | []string | Match exact elements which are allowed as class names within this tenant | false |
| **allowedRegex** | string | <span style="color:red;font-weight:bold">Deprecated: will be removed in a future release<br><br>Match elements by regex.</span> | false |
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
| **allowed** | []string | Match exact elements which are allowed as class names within this tenant | false |
| **allowedRegex** | string | <span style="color:red;font-weight:bold">Deprecated: will be removed in a future release<br><br>Match elements by regex.</span> | false |


### Tenant.spec.limitRanges



Deprecated: Use Tenant Replications instead (https://projectcapsule.dev/docs/replications/)

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
| **[additionalMetadata](#tenantspecnamespaceoptionsadditionalmetadata-1)** | object | <span style="color:red;font-weight:bold">Deprecated: Use additionalMetadataList instead (https://projectcapsule.dev/docs/tenants/metadata/#additionalmetadatalist)<br><br>Specifies additional labels and annotations the Capsule operator places on any Namespace resource in the Tenant. Optional.</span> | false |
| **[additionalMetadataList](#tenantspecnamespaceoptionsadditionalmetadatalistindex)** | []object | Specifies additional labels and annotations the Capsule operator places on any Namespace resource in the Tenant via a list. Optional. | false |
| **[forbiddenAnnotations](#tenantspecnamespaceoptionsforbiddenannotations)** | object | Define the annotations that a Tenant Owner cannot set for their Namespace resources. | false |
| **[forbiddenLabels](#tenantspecnamespaceoptionsforbiddenlabels)** | object | Define the labels that a Tenant Owner cannot set for their Namespace resources. | false |
| **managedMetadataOnly** | boolean | If enabled only metadata from additionalMetadata is reconciled to the namespaces.<br/>*Default*: false<br/> | false |
| **quota** | integer | Specifies the maximum number of namespaces allowed for that Tenant. Once the namespace quota assigned to the Tenant has been reached, the Tenant owner cannot create further namespaces. Optional.<br/>*Format*: int32<br/>*Minimum*: 1<br/> | false |
| **[requiredMetadata](#tenantspecnamespaceoptionsrequiredmetadata)** | object | Required Metadata for namespace within this tenant | false |


### Tenant.spec.namespaceOptions.additionalMetadata



Deprecated: Use additionalMetadataList instead (https://projectcapsule.dev/docs/tenants/metadata/#additionalmetadatalist)

Specifies additional labels and annotations the Capsule operator places on any Namespace resource in the Tenant. Optional.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **annotations** | map[string]string |  | false |
| **labels** | map[string]string |  | false |


### Tenant.spec.namespaceOptions.additionalMetadataList[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **annotations** | map[string]string |  | false |
| **labels** | map[string]string |  | false |
| **[namespaceSelector](#tenantspecnamespaceoptionsadditionalmetadatalistindexnamespaceselector)** | object | A label selector is a label query over a set of resources. The result of matchLabels and<br>matchExpressions are ANDed. An empty label selector matches all objects. A null<br>label selector matches no objects. | false |


### Tenant.spec.namespaceOptions.additionalMetadataList[index].namespaceSelector



A label selector is a label query over a set of resources. The result of matchLabels and
matchExpressions are ANDed. An empty label selector matches all objects. A null
label selector matches no objects.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantspecnamespaceoptionsadditionalmetadatalistindexnamespaceselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.namespaceOptions.additionalMetadataList[index].namespaceSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


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


### Tenant.spec.namespaceOptions.requiredMetadata



Required Metadata for namespace within this tenant


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **annotations** | map[string]string | Annotations that must be defined for each namespace | false |
| **labels** | map[string]string | Labels that must be defined for each namespace | false |


### Tenant.spec.networkPolicies



Deprecated: Use Tenant Replications instead (https://projectcapsule.dev/docs/replications/)

Specifies the NetworkPolicies assigned to the Tenant. The assigned NetworkPolicies are inherited by any namespace created in the Tenant. Optional.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[items](#tenantspecnetworkpoliciesitemsindex-1)** | []object |  | false |


### Tenant.spec.networkPolicies.items[index]



NetworkPolicySpec provides the specification of a NetworkPolicy


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[egress](#tenantspecnetworkpoliciesitemsindexegressindex-1)** | []object | egress is a list of egress rules to be applied to the selected pods. Outgoing traffic<br>is allowed if there are no NetworkPolicies selecting the pod (and cluster policy<br>otherwise allows the traffic), OR if the traffic matches at least one egress rule<br>across all of the NetworkPolicy objects whose podSelector matches the pod. If<br>this field is empty then this NetworkPolicy limits all outgoing traffic (and serves<br>solely to ensure that the pods it selects are isolated by default).<br>This field is beta-level in 1.8 | false |
| **[ingress](#tenantspecnetworkpoliciesitemsindexingressindex-1)** | []object | ingress is a list of ingress rules to be applied to the selected pods.<br>Traffic is allowed to a pod if there are no NetworkPolicies selecting the pod<br>(and cluster policy otherwise allows the traffic), OR if the traffic source is<br>the pod's local node, OR if the traffic matches at least one ingress rule<br>across all of the NetworkPolicy objects whose podSelector matches the pod. If<br>this field is empty then this NetworkPolicy does not allow any traffic (and serves<br>solely to ensure that the pods it selects are isolated by default) | false |
| **[podSelector](#tenantspecnetworkpoliciesitemsindexpodselector-1)** | object | podSelector selects the pods to which this NetworkPolicy object applies.<br>The array of rules is applied to any pods selected by this field. An empty<br>selector matches all pods in the policy's namespace.<br>Multiple network policies can select the same set of pods. In this case,<br>the ingress rules for each are combined additively.<br>This field is optional. If it is not specified, it defaults to an empty selector. | false |
| **policyTypes** | []string | policyTypes is a list of rule types that the NetworkPolicy relates to.<br>Valid options are ["Ingress"], ["Egress"], or ["Ingress", "Egress"].<br>If this field is not specified, it will default based on the existence of ingress or egress rules;<br>policies that contain an egress section are assumed to affect egress, and all policies<br>(whether or not they contain an ingress section) are assumed to affect ingress.<br>If you want to write an egress-only policy, you must explicitly specify policyTypes [ "Egress" ].<br>Likewise, if you want to write a policy that specifies that no egress is allowed,<br>you must specify a policyTypes value that include "Egress" (since such a policy would not include<br>an egress section and would otherwise default to just [ "Ingress" ]).<br>This field is beta-level in 1.8 | false |


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


### Tenant.spec.networkPolicies.items[index].podSelector



podSelector selects the pods to which this NetworkPolicy object applies.
The array of rules is applied to any pods selected by this field. An empty
selector matches all pods in the policy's namespace.
Multiple network policies can select the same set of pods. In this case,
the ingress rules for each are combined additively.
This field is optional. If it is not specified, it defaults to an empty selector.


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


### Tenant.spec.owners[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | enum | Kind of entity. Possible values are "User", "Group", and "ServiceAccount"<br/>*Enum*: User, Group, ServiceAccount<br/> | true |
| **name** | string | Name of the entity. | true |
| **annotations** | map[string]string | Additional Annotations for the synchronized rolebindings | false |
| **clusterRoles** | []string | Defines additional cluster-roles for the specific Owner.<br/>*Default*: [admin capsule-namespace-deleter]<br/> | false |
| **labels** | map[string]string | Additional Labels for the synchronized rolebindings | false |
| **[proxySettings](#tenantspecownersindexproxysettingsindex-1)** | []object | Proxy settings for tenant owner. | false |


### Tenant.spec.owners[index].proxySettings[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | enum | <br/>*Enum*: Nodes, StorageClasses, IngressClasses, PriorityClasses, RuntimeClasses, PersistentVolumes<br/> | true |
| **operations** | []enum | <br/>*Enum*: List, Update, Delete<br/> | true |


### Tenant.spec.permissions



Specify Permissions for the Tenant.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowOwnerPromotion** | boolean | ClusterRoles granted to the promoted ServiceAccounts across the Tenant<br/>*Default*: true<br/> | false |
| **[matchOwners](#tenantspecpermissionsmatchownersindex)** | []object | Matches TenantOwner objects which are promoted to owners of this tenant<br>The elements are OR operations and independent. You can see the resulting Tenant Owners<br>in the Status.Owners specification of the Tenant. | false |


### Tenant.spec.permissions.matchOwners[index]



A label selector is a label query over a set of resources. The result of matchLabels and
matchExpressions are ANDed. An empty label selector matches all objects. A null
label selector matches no objects.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantspecpermissionsmatchownersindexmatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.permissions.matchOwners[index].matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


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
| **allowed** | []string | Match exact elements which are allowed as class names within this tenant | false |
| **allowedRegex** | string | <span style="color:red;font-weight:bold">Deprecated: will be removed in a future release<br><br>Match elements by regex.</span> | false |
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


### Tenant.spec.rules[index]



Rules Distributed via Tenants


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[enforce](#tenantspecrulesindexenforce)** | object | Enforcement for given rule | false |
| **[namespaceSelector](#tenantspecrulesindexnamespaceselector)** | object | Select namespaces which are going to be targeted with this rule | false |
| **[permissions](#tenantspecrulesindexpermissions)** | object | Permissions for given rule | false |


### Tenant.spec.rules[index].enforce



Enforcement for given rule


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **action** | enum | Declare the action being performed on the enforcement rule:<br>deny: On match, deny admission request<br>allow: On match, allowed admission request<br>audit: On match, audit (post event) of admission request<br/>*Enum*: allow, deny, audit<br/>*Default*: deny<br/> | false |
| **[services](#tenantspecrulesindexenforceservices)** | object | Enforcement for Services. | false |
| **[workloads](#tenantspecrulesindexenforceworkloads)** | object | Enforcement for Workloads (Pods) | false |


### Tenant.spec.rules[index].enforce.services



Enforcement for Services.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[externalNames](#tenantspecrulesindexenforceservicesexternalnames)** | object | ExternalNames defines additional constraints for Services of type ExternalName. | false |
| **[loadBalancers](#tenantspecrulesindexenforceservicesloadbalancers)** | object | LoadBalancers defines additional constraints for Services of type LoadBalancer. | false |
| **[nodePorts](#tenantspecrulesindexenforceservicesnodeports)** | object | NodePorts defines additional constraints for nodePort values. | false |
| **types** | []enum | Types defines the Service types matched by this rule.<br><br>Supported values:<br>- ClusterIP<br>- NodePort<br>- LoadBalancer<br>- ExternalName<br/>*Enum*: ClusterIP, NodePort, LoadBalancer, ExternalName<br/> | false |


### Tenant.spec.rules[index].enforce.services.externalNames



ExternalNames defines additional constraints for Services of type ExternalName.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[hostnames](#tenantspecrulesindexenforceservicesexternalnameshostnamesindex)** | []object | Hostnames restricts spec.externalName.<br>Empty means no additional hostname restriction once ExternalName is allowed by types. | false |


### Tenant.spec.rules[index].enforce.services.externalNames.hostnames[index]



At least one of Exact or Exp must be set.
Both may be set together.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **exact** | []string | Exact matches one of the provided values exactly. | false |
| **exp** | string | Exp matches regular expression. | false |
| **negate** | boolean | Negate regular Expression<br/>*Default*: false<br/> | false |


### Tenant.spec.rules[index].enforce.services.loadBalancers



LoadBalancers defines additional constraints for Services of type LoadBalancer.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **cidrs** | []string | CIDRs restricts spec.loadBalancerIP and spec.loadBalancerSourceRanges.<br>Empty means no additional CIDR restriction once LoadBalancer is allowed by types. | false |


### Tenant.spec.rules[index].enforce.services.nodePorts



NodePorts defines additional constraints for nodePort values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[ports](#tenantspecrulesindexenforceservicesnodeportsportsindex)** | []object | Ports restricts explicitly requested nodePort values.<br>Empty means no additional port restriction once NodePort is allowed by types. | false |


### Tenant.spec.rules[index].enforce.services.nodePorts.ports[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **from** | integer | <br/>*Format*: int32<br/>*Minimum*: 1<br/>*Maximum*: 65535<br/> | true |
| **to** | integer | <br/>*Format*: int32<br/>*Minimum*: 1<br/>*Maximum*: 65535<br/> | true |


### Tenant.spec.rules[index].enforce.workloads



Enforcement for Workloads (Pods)


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **qosClasses** | []string | Define Pod QoS classes matched by this enforcement rule.<br>Supported values are Guaranteed, Burstable and BestEffort. | false |
| **[registries](#tenantspecrulesindexenforceworkloadsregistriesindex)** | []object | Define registries which are allowed to be used within this tenant<br>The rules are aggregated, since you can use Regular Expressions the match registry endpoints | false |
| **[schedulers](#tenantspecrulesindexenforceworkloadsschedulersindex)** | []object | Schedulers defines schedulerName matchers for Pod admission.<br><br>The rule is evaluated against pod.spec.schedulerName.<br>Empty schedulerName is ignored and is not normalized to default-scheduler. | false |
| **targets** | []enum | Define the enforcement targets this rule applies to.<br>If empty, each webhook applies its own backwards-compatible default.<br/>*Enum*: pod/initcontainers, pod/ephemeralcontainers, pod/containers, pod/volumes<br/> | false |


### Tenant.spec.rules[index].enforce.workloads.registries[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **exact** | []string | Exact matches one of the provided values exactly. | false |
| **exp** | string | Exp matches regular expression. | false |
| **negate** | boolean | Negate regular Expression<br/>*Default*: false<br/> | false |
| **policy** | []string | Allowed PullPolicy for the given registry. Supplying no value allows all policies. | false |


### Tenant.spec.rules[index].enforce.workloads.schedulers[index]



At least one of Exact or Exp must be set.
Both may be set together.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **exact** | []string | Exact matches one of the provided values exactly. | false |
| **exp** | string | Exp matches regular expression. | false |
| **negate** | boolean | Negate regular Expression<br/>*Default*: false<br/> | false |


### Tenant.spec.rules[index].namespaceSelector



Select namespaces which are going to be targeted with this rule


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantspecrulesindexnamespaceselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.rules[index].namespaceSelector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.spec.rules[index].permissions



Permissions for given rule


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[promotions](#tenantspecrulesindexpermissionspromotionsindex)** | []object | Define Promotion Rules which distributed additional ClusterRoles across the Tenant<br>for promoted ServiceAccounts. | false |


### Tenant.spec.rules[index].permissions.promotions[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **clusterRoles** | []string | ClusterRoles granted to the promoted ServiceAccounts across the Tenant<br>kubebuilder:validation:Minimum=1 | false |
| **[selector](#tenantspecrulesindexpermissionspromotionsindexselector)** | object | Match ServiceAccounts which are promoted which are granted these additional ClusterRoles<br>across the Tenant | false |


### Tenant.spec.rules[index].permissions.promotions[index].selector



Match ServiceAccounts which are promoted which are granted these additional ClusterRoles
across the Tenant


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[matchExpressions](#tenantspecrulesindexpermissionspromotionsindexselectormatchexpressionsindex)** | []object | matchExpressions is a list of label selector requirements. The requirements are ANDed. | false |
| **matchLabels** | map[string]string | matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels<br>map is equivalent to an element of matchExpressions, whose key field is "key", the<br>operator is "In", and the values array contains only "value". The requirements are ANDed. | false |


### Tenant.spec.rules[index].permissions.promotions[index].selector.matchExpressions[index]



A label selector requirement is a selector that contains values, a key, and an operator that
relates the key and values.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **key** | string | key is the label key that the selector applies to. | true |
| **operator** | string | operator represents a key's relationship to a set of values.<br>Valid operators are In, NotIn, Exists and DoesNotExist. | true |
| **values** | []string | values is an array of string values. If the operator is In or NotIn,<br>the values array must be non-empty. If the operator is Exists or DoesNotExist,<br>the values array must be empty. This array is replaced during a strategic<br>merge patch. | false |


### Tenant.spec.runtimeClasses



Specifies the allowed RuntimeClasses assigned to the Tenant.
Capsule assures that all Pods resources created in the Tenant can use only one of the allowed RuntimeClasses.
Optional.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string | Match exact elements which are allowed as class names within this tenant | false |
| **allowedRegex** | string | <span style="color:red;font-weight:bold">Deprecated: will be removed in a future release<br><br>Match elements by regex.</span> | false |
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
| **allowed** | []string | Match exact elements which are allowed as class names within this tenant | false |
| **allowedRegex** | string | <span style="color:red;font-weight:bold">Deprecated: will be removed in a future release<br><br>Match elements by regex.</span> | false |
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
| **[conditions](#tenantstatusconditionsindex)** | []object | Tenant Condition | true |
| **size** | integer | How many namespaces are assigned to the Tenant. | true |
| **state** | enum | The operational state of the Tenant. Possible values are "Active", "Cordoned" or "Terminating".<br/>*Enum*: Cordoned, Active, Terminating<br/>*Default*: Active<br/> | true |
| **[classes](#tenantstatusclasses)** | object | Available Class Types within Tenant | false |
| **namespaces** | []string | <span style="color:red;font-weight:bold">List of namespaces assigned to the Tenant. (Deprecated)</span> | false |
| **observedGeneration** | integer | ObservedGeneration is the most recent generation the controller has observed.<br/>*Format*: int64<br/> | false |
| **[owners](#tenantstatusownersindex)** | []object | Collected owners for this tenant | false |
| **[promotions](#tenantstatuspromotionsindex)** | []object | Promoted ServiceAccounts across the Tenant | false |
| **[spaces](#tenantstatusspacesindex)** | []object | Tracks state for the namespaces associated with this tenant | false |


### Tenant.status.conditions[index]



Condition contains details for one aspect of the current state of this API Resource.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **lastTransitionTime** | string | lastTransitionTime is the last time the condition transitioned from one status to another.<br>This should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.<br/>*Format*: date-time<br/> | true |
| **message** | string | message is a human readable message indicating details about the transition.<br>This may be an empty string. | true |
| **reason** | string | reason contains a programmatic identifier indicating the reason for the condition's last transition.<br>Producers of specific condition types may define expected values and meanings for this field,<br>and whether the values are considered a guaranteed API.<br>The value should be a CamelCase string.<br>This field may not be empty. | true |
| **status** | enum | status of the condition, one of True, False, Unknown.<br/>*Enum*: True, False, Unknown<br/> | true |
| **type** | string | type of condition in CamelCase or in foo.example.com/CamelCase. | true |
| **observedGeneration** | integer | observedGeneration represents the .metadata.generation that the condition was set based upon.<br>For instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date<br>with respect to the current state of the instance.<br/>*Format*: int64<br/>*Minimum*: 0<br/> | false |


### Tenant.status.classes



Available Class Types within Tenant


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **device** | []string | Available DeviceClasses | false |
| **gateway** | []string | Available GatewayClasses | false |
| **priority** | []string | Available PriorityClasses | false |
| **runtime** | []string | Available StorageClasses | false |
| **storage** | []string | Available Storageclasses (Only collected if any matching condition is specified) | false |


### Tenant.status.owners[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | enum | Kind of entity. Possible values are "User", "Group", and "ServiceAccount"<br/>*Enum*: User, Group, ServiceAccount<br/> | true |
| **name** | string | Name of the entity. | true |
| **clusterRoles** | []string | Defines additional cluster-roles for the specific Owner.<br/>*Default*: [admin capsule-namespace-deleter]<br/> | false |


### Tenant.status.promotions[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **kind** | enum | Kind of entity. Possible values are "User", "Group", and "ServiceAccount"<br/>*Enum*: User, Group, ServiceAccount<br/> | true |
| **name** | string | Name of the entity. | true |
| **clusterRoles** | []string | Defines additional cluster-roles for the specific Owner.<br/>*Default*: [admin capsule-namespace-deleter]<br/> | false |
| **targets** | []string | Defines additional cluster-roles for the specific Owner. | false |


### Tenant.status.spaces[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[conditions](#tenantstatusspacesindexconditionsindex)** | []object | Conditions | true |
| **name** | string | Namespace Name | true |
| **[enforce](#tenantstatusspacesindexenforce)** | object | Managed Metadata | false |
| **[metadata](#tenantstatusspacesindexmetadata)** | object | Managed Metadata | false |
| **uid** | string | Namespace UID | false |


### Tenant.status.spaces[index].conditions[index]



Condition contains details for one aspect of the current state of this API Resource.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **lastTransitionTime** | string | lastTransitionTime is the last time the condition transitioned from one status to another.<br>This should be when the underlying condition changed.  If that is not known, then using the time when the API field changed is acceptable.<br/>*Format*: date-time<br/> | true |
| **message** | string | message is a human readable message indicating details about the transition.<br>This may be an empty string. | true |
| **reason** | string | reason contains a programmatic identifier indicating the reason for the condition's last transition.<br>Producers of specific condition types may define expected values and meanings for this field,<br>and whether the values are considered a guaranteed API.<br>The value should be a CamelCase string.<br>This field may not be empty. | true |
| **status** | enum | status of the condition, one of True, False, Unknown.<br/>*Enum*: True, False, Unknown<br/> | true |
| **type** | string | type of condition in CamelCase or in foo.example.com/CamelCase. | true |
| **observedGeneration** | integer | observedGeneration represents the .metadata.generation that the condition was set based upon.<br>For instance, if .metadata.generation is currently 12, but the .status.conditions[x].observedGeneration is 9, the condition is out of date<br>with respect to the current state of the instance.<br/>*Format*: int64<br/>*Minimum*: 0<br/> | false |


### Tenant.status.spaces[index].enforce



Managed Metadata


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **[registry](#tenantstatusspacesindexenforceregistryindex)** | []object | Registries which are allowed within this namespace | false |


### Tenant.status.spaces[index].enforce.registry[index]






| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **exact** | []string | Exact matches one of the provided values exactly. | false |
| **exp** | string | Exp matches regular expression. | false |
| **negate** | boolean | Negate regular Expression<br/>*Default*: false<br/> | false |
| **policy** | []string | Allowed PullPolicy for the given registry. Supplying no value allows all policies. | false |


### Tenant.status.spaces[index].metadata



Managed Metadata


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **annotations** | map[string]string | Managed Annotations | false |
| **labels** | map[string]string | Managed Labels | false |

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
| **[spec](#tenantspec)** | object | TenantSpec defines the desired state of Tenant. | true |
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
| **annotations** | map[string]string | Additional Annotations for the synchronized rolebindings | false |
| **labels** | map[string]string | Additional Labels for the synchronized rolebindings | false |


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
| **allowed** | []string | Match exact elements which are allowed as class names within this tenant | false |
| **allowedRegex** | string | <span style="color:red;font-weight:bold">Deprecated: will be removed in a future release<br><br>Match elements by regex.</span> | false |


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
| **allowed** | []string | Match exact elements which are allowed as class names within this tenant | false |
| **allowedRegex** | string | <span style="color:red;font-weight:bold">Deprecated: will be removed in a future release<br><br>Match elements by regex.</span> | false |


### Tenant.spec.ingressOptions.allowedHostnames



Specifies the allowed hostnames in Ingresses for the given Tenant. Capsule assures that all Ingress resources created in the Tenant can use only one of the allowed hostnames. Optional.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string | Match exact elements which are allowed as class names within this tenant | false |
| **allowedRegex** | string | <span style="color:red;font-weight:bold">Deprecated: will be removed in a future release<br><br>Match elements by regex.</span> | false |


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
| **[egress](#tenantspecnetworkpoliciesitemsindexegressindex)** | []object | egress is a list of egress rules to be applied to the selected pods. Outgoing traffic<br>is allowed if there are no NetworkPolicies selecting the pod (and cluster policy<br>otherwise allows the traffic), OR if the traffic matches at least one egress rule<br>across all of the NetworkPolicy objects whose podSelector matches the pod. If<br>this field is empty then this NetworkPolicy limits all outgoing traffic (and serves<br>solely to ensure that the pods it selects are isolated by default).<br>This field is beta-level in 1.8 | false |
| **[ingress](#tenantspecnetworkpoliciesitemsindexingressindex)** | []object | ingress is a list of ingress rules to be applied to the selected pods.<br>Traffic is allowed to a pod if there are no NetworkPolicies selecting the pod<br>(and cluster policy otherwise allows the traffic), OR if the traffic source is<br>the pod's local node, OR if the traffic matches at least one ingress rule<br>across all of the NetworkPolicy objects whose podSelector matches the pod. If<br>this field is empty then this NetworkPolicy does not allow any traffic (and serves<br>solely to ensure that the pods it selects are isolated by default) | false |
| **[podSelector](#tenantspecnetworkpoliciesitemsindexpodselector)** | object | podSelector selects the pods to which this NetworkPolicy object applies.<br>The array of rules is applied to any pods selected by this field. An empty<br>selector matches all pods in the policy's namespace.<br>Multiple network policies can select the same set of pods. In this case,<br>the ingress rules for each are combined additively.<br>This field is optional. If it is not specified, it defaults to an empty selector. | false |
| **policyTypes** | []string | policyTypes is a list of rule types that the NetworkPolicy relates to.<br>Valid options are ["Ingress"], ["Egress"], or ["Ingress", "Egress"].<br>If this field is not specified, it will default based on the existence of ingress or egress rules;<br>policies that contain an egress section are assumed to affect egress, and all policies<br>(whether or not they contain an ingress section) are assumed to affect ingress.<br>If you want to write an egress-only policy, you must explicitly specify policyTypes [ "Egress" ].<br>Likewise, if you want to write a policy that specifies that no egress is allowed,<br>you must specify a policyTypes value that include "Egress" (since such a policy would not include<br>an egress section and would otherwise default to just [ "Ingress" ]).<br>This field is beta-level in 1.8 | false |


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


### Tenant.spec.networkPolicies.items[index].podSelector



podSelector selects the pods to which this NetworkPolicy object applies.
The array of rules is applied to any pods selected by this field. An empty
selector matches all pods in the policy's namespace.
Multiple network policies can select the same set of pods. In this case,
the ingress rules for each are combined additively.
This field is optional. If it is not specified, it defaults to an empty selector.


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


### Tenant.spec.priorityClasses



Specifies the allowed priorityClasses assigned to the Tenant. Capsule assures that all Pods resources created in the Tenant can use only one of the allowed PriorityClasses. Optional.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **allowed** | []string | Match exact elements which are allowed as class names within this tenant | false |
| **allowedRegex** | string | <span style="color:red;font-weight:bold">Deprecated: will be removed in a future release<br><br>Match elements by regex.</span> | false |


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
| **allowed** | []string | Match exact elements which are allowed as class names within this tenant | false |
| **allowedRegex** | string | <span style="color:red;font-weight:bold">Deprecated: will be removed in a future release<br><br>Match elements by regex.</span> | false |


### Tenant.status



Returns the observed state of the Tenant.


| **Name** | **Type** | **Description** | **Required** |
| :---- | :---- | :----------- | :-------- |
| **size** | integer | How many namespaces are assigned to the Tenant. | true |
| **state** | enum | The operational state of the Tenant. Possible values are "Active", "Cordoned".<br/>*Enum*: Cordoned, Active<br/>*Default*: Active<br/> | true |
| **namespaces** | []string | List of namespaces assigned to the Tenant. | false |

