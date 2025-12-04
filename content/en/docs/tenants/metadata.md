---
title: Metadata
weight: 5
description: >
  Inherit additional metadata on Tenant resources.
---

## Namespaces

### AdditionalMetadataList
{{% alert title="Information" color="info" %}}
Starting from v0.10.8, it is possible to use templated values for labels and annotations.
Currently, `{{ tenant.name }}` and `{{ namespace }}` placeholders are available.
{{% /alert %}}
```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - name: alice
      kind: User
  namespaceOptions:
    additionalMetadataList:
      - annotations:
          templated-annotation: {{ tenant.name }}
        labels:
          templated-label: {{ namespace }}
```
The cluster admin can "taint" the namespaces created by tenant owners with additional metadata as labels and annotations. There is no specific semantic assigned to these labels and annotations: they will be assigned to the namespaces in the tenant as they are created. However you have the option to be more specific by selecting to which namespaces you want to assign what kind of metadata:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  namespaceOptions:
    additionalMetadataList:
    # An item without any further selectors is applied to all namspaces
    - annotations:
        storagelocationtype: s3
      labels:
        projectcapsule.dev/backup: "true"

    # Select a subset of namespaces to apply metadata on
    - namespaceSelector:
        matchExpressions:
          - key: projectcapsule.dev/low_security_profile
            operator: NotIn
            values: ["true"]
      labels:
        pod-security.kubernetes.io/enforce: baseline

    - namespaceSelector:
        matchExpressions:
          - key: projectcapsule.dev/low_security_profile
            operator: In
            values: ["true"]
      labels:
        pod-security.kubernetes.io/enforce: privileged
```

### AdditionalMetadata

{{% alert title="Deprecated" color="info" %}}
This feature is deprecated and  will be removed in a future release of Capsule. Migrate to using [AdditionalMetadataList](#additionalmetadatalist)
{{% /alert %}}

The cluster admin can "taint" the namespaces created by tenant owners with additional metadata as labels and annotations. There is no specific semantic assigned to these labels and annotations: they will be assigned to the namespaces in the tenant as they are created. This can help the cluster admin to implement specific use cases as, for example, leave only a given tenant to be backed up by a backup service.

Assigns additional labels and annotations to all namespaces created in the `solar` tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  namespaceOptions:
    additionalMetadata:
      annotations:
        storagelocationtype: s3
      labels:
        projectcapsule.dev/backup: "true"
```

When the tenant owner creates a namespace, it inherits the given label and/or annotation:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    storagelocationtype: s3
  labels:
    capsule.clastix.io/tenant: solar
    kubernetes.io/metadata.name: solar-production
    name: solar-production
    projectcapsule.dev/backup: "true"
  name: solar-production
  ownerReferences:
  - apiVersion: capsule.clastix.io/v1beta2
    blockOwnerDeletion: true
    controller: true
    kind: Tenant
    name: solar
spec:
  finalizers:
  - kubernetes
status:
  phase: Active
```

### Deny labels and annotations on Namespaces

By default, capsule allows tenant owners to add and modify any label or annotation on their namespaces.

But there are some scenarios, when tenant owners should not have an ability to add or modify specific labels or annotations (for example, this can be labels used in [Kubernetes network policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) which are added by cluster administrator).

Bill, the cluster admin, can deny Alice to add specific labels and annotations on namespaces:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  namespaceOptions:
    forbiddenAnnotations:
      denied:
          - foo.acme.net
          - bar.acme.net
      deniedRegex: .*.acme.net
    forbiddenLabels:
      denied:
          - foo.acme.net
          - bar.acme.net
      deniedRegex: .*.acme.net
  owners:
  - name: alice
    kind: User
```

## Nodes

{{% alert title="Warning" color="warning" %}}
Due to [CVE-2021-25735](https://github.com/kubernetes/kubernetes/issues/100096) this feature is only supported for Kubernetes version older than: v1.18.18, v1.19.10, v1.20.6, v1.21.0
{{% /alert %}}

When using capsule together with [capsule-proxy](/docs/integrations/capsule-proxy), Bill can allow Tenant Owners to modify Nodes.

By default, it will allow tenant owners to add and modify any label or annotation on their nodes.

But there are some scenarios, when tenant owners should not have an ability to add or modify specific labels or annotations (there are some types of labels or annotations, which must be protected from modifications - for example, which are set by cloud-providers or autoscalers).

Bill, the cluster admin, can deny Tenant Owners to add or modify specific labels and annotations on Nodes:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: CapsuleConfiguration
metadata:
  name: default
spec:
  nodeMetadata:
    forbiddenAnnotations:
      denied:
        - foo.acme.net
        - bar.acme.net
      deniedRegex: .*.acme.net
    forbiddenLabels:
      denied:
        - foo.acme.net
        - bar.acme.net
      deniedRegex: .*.acme.net
  userGroups:
    - projectcapsule.dev
    - system:serviceaccounts:default
```

## Services

The cluster admin can "taint" the services created by the tenant owners with additional metadata as labels and annotations.

Assigns additional labels and annotations to all services created in the `solar` tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  serviceOptions:
    additionalMetadata:
      annotations:
        storagelocationtype: s3
      labels:
        projectcapsule.dev/backup: "true"
```

When the tenant owner creates a service in a tenant namespace, it inherits the given label and/or annotation:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: solar-production
  labels:
    projectcapsule.dev/backup: "true"
  annotations:
    storagelocationtype: s3
spec:
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  selector:
    run: nginx
  type: ClusterIP
```

## Pods

The cluster admin can "taint" the pods created by the tenant owners with additional metadata as labels and annotations.

Assigns additional labels and annotations to all services created in the `solar` tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  podOptions:
    additionalMetadata:
      annotations:
        storagelocationtype: s3
      labels:
        projectcapsule.dev/backup: "true"
```

When the tenant owner creates a service in a tenant namespace, it inherits the given label and/or annotation:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace: solar-production
  labels:
    projectcapsule.dev/backup: "true"
  annotations:
    storagelocationtype: s3
...
```