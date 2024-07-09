---
title: API Reference
description: >
  API Reference
weight: 100
---
Packages:

- [capsule.clastix.io/v1beta2](#capsuleclastixiov1beta2)

# capsule.clastix.io/v1beta2

Resource Types:

- [CapsuleConfiguration](#capsuleconfiguration)




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
| **enableTLSReconciler** | boolean | Toggles the TLS reconciler, the controller that is able to generate CA and certificates for the webhooks
when not using an already provided CA and certificate, or when these are managed externally with Vault, or cert-manager.<br/>*Default*: true<br/> | true |
| **forceTenantPrefix** | boolean | Enforces the Tenant owner, during Namespace creation, to name it using the selected Tenant name as prefix,
separated by a dash. This is useful to avoid Namespace name collision in a public CaaS environment.<br/>*Default*: false<br/> | false |
| **[nodeMetadata](#capsuleconfigurationspecnodemetadata)** | object | Allows to set the forbidden metadata for the worker nodes that could be patched by a Tenant.
This applies only if the Tenant has an active NodeSelector, and the Owner have right to patch their nodes. | false |
| **[overrides](#capsuleconfigurationspecoverrides)** | object | Allows to set different name rather than the canonical one for the Capsule configuration objects,
such as webhook secret or configurations.<br/>*Default*: map[TLSSecretName:capsule-tls mutatingWebhookConfigurationName:capsule-mutating-webhook-configuration validatingWebhookConfigurationName:capsule-validating-webhook-configuration]<br/> | false |
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
| **TLSSecretName** | string | Defines the Secret name used for the webhook server.
Must be in the same Namespace where the Capsule Deployment is deployed.<br/>*Default*: capsule-tls<br/> | true |
| **mutatingWebhookConfigurationName** | string | Name of the MutatingWebhookConfiguration which contains the dynamic admission controller paths and resources.<br/>*Default*: capsule-mutating-webhook-configuration<br/> | true |
| **validatingWebhookConfigurationName** | string | Name of the ValidatingWebhookConfiguration which contains the dynamic admission controller paths and resources.<br/>*Default*: capsule-validating-webhook-configuration<br/> | true |