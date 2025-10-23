---
title: Admission Policies
weight: 2
description: Recommended Admission Policies to enforce best practices in multi-tenant environments.
---

As Capsule we try to provide a secure multi-tenant environment out of the box, there are however some additional Admission Policies you should consider to enforce best practices in your cluster. Since Capsule only covers the core multi-tenancy features, such as Namespaces, Resource Quotas, Network Policies, and Container Registries, Classes, you should consider using an additional Admission Controller to enforce best practices on workloads and other resources.

## Mutate User Namespace

You should enforce the usage of [User Namespaces](/docs/operating/best-practices/workloads/#user-namespaces). Most Helm-Charts currently don't support this out of the box. With Kyverno you can enforce this on Pod level.

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: tenants-user-namespace
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
            hostUsers: false{{< /tab >}}
{{% /tabpane %}}

Note that users still can override this setting by adding the label `company.com/allow-host-users=true` to their namespace. You can change the label to your needs. This is because NFS does not support user namespaces and you might want to allow this for specific tenants.

## Disallow Daemonsets

Tenant's should not be allowed to create Daemonsets, unless they have dedicated nodes.

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="VAP" >}}
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: deny-daemonset-create
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: ["apps"]
        apiVersions: ["v1"]
        resources: ["daemonsets"]
        operations: ["CREATE"]
        scope: "Namespaced"
  validations:
    - expression: "false"
      message: "Creating DaemonSets is not allowed in this cluster."
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: deny-daemonset-create-binding
spec:
  policyName: deny-daemonset-create
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchExpressions:
        - key: capsule.clastix.io/tenant
          operator: Exists{{< /tab >}}
  {{< tab header="Kyverno" >}}
---
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
            value: "true"{{< /tab >}}
{{% /tabpane %}}

## Disallow Scheduling on Control Planes

If a Pods are not scoped to specific nodes, they could be scheduled on control plane nodes. You should disallow this by enforcing that Pods do not use tolerations for control plane nodes.

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Capsule" >}}
---
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  nodeSelector:
    customer: public-services{{< /tab >}}
  {{< tab header="VAP" >}}
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: disallow-controlplane-scheduling
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        resources: ["pods"]
        operations: ["CREATE","UPDATE"]
        scope: "Namespaced"
  validations:
    - expression: >
        // deny if any toleration targets control-plane taints
        !has(object.spec.tolerations) ||
        !exists(object.spec.tolerations, t,
          t.key in ['node-role.kubernetes.io/master','node-role.kubernetes.io/control-plane']
        )
      message: "Pods may not use tolerations which schedule on control-plane nodes."
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: disallow-controlplane-scheduling
spec:
  policyName: disallow-controlplane-scheduling
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchExpressions:
        - key: capsule.clastix.io/tenant
          operator: Exists{{< /tab >}}
  {{< tab header="Kyverno" >}}
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-controlplane-scheduling
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
            - key: "!node-role.kubernetes.io/control-plane"{{< /tab >}}
{{% /tabpane %}}

## Enforce EmptDir Requests/Limits

By Defaults `emptyDir` Volumes do not have any limits. This could lead to a situation, where a tenant fills up the node disk. To avoid this, you can enforce limits on `emptyDir` volumes. You may also consider restricting the usage of `emptyDir` with the `medium: Memory` option, as this could lead to memory exhaustion on the node.

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
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
              value: 250Mi{{< /tab >}}
{{% /tabpane %}}

## Block Ephemeral Containers

Ephemeral containers, enabled by default in Kubernetes 1.23, allow users to use the `kubectl debug` functionality and attach a temporary container to an existing Pod. This may potentially be used to gain access to unauthorized information executing inside one or more containers in that Pod. This policy blocks the use of ephemeral containers.

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
    {{< tab header="VAP" >}}
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: block-ephemeral-containers
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      # 1) Regular Pods (ensure spec doesn't carry ephemeralContainers)
      - apiGroups: [""]
        apiVersions: ["v1"]
        resources: ["pods"]
        operations: ["CREATE","UPDATE"]
        scope: "Namespaced"
      # 2) Subresource used by `kubectl debug` to inject ephemeral containers
      - apiGroups: [""]
        apiVersions: ["v1"]
        resources: ["pods/ephemeralcontainers"]
        operations: ["UPDATE","CREATE"]  # UPDATE is typical, CREATE included for future-proofing
        scope: "Namespaced"
  validations:
    # Deny any request that targets the pods/ephemeralcontainers subresource
    - expression: request.subResource != "ephemeralcontainers"
      message: "Ephemeral (debug) containers are not permitted (subresource)."
    # For direct Pod create/update, allow only if the field is absent or empty
    - expression: >
        !has(object.spec.ephemeralContainers) ||
        size(object.spec.ephemeralContainers) == 0
      message: "Ephemeral (debug) containers are not permitted in Pod specs."
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: block-ephemeral-containers-binding
spec:
  policyName: block-ephemeral-containers
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchExpressions:
        - key: capsule.clastix.io/tenant
          operator: Exists{{< /tab >}}
  {{< tab header="Kyverno" >}}
# Source: https://kyverno.io/policies/other/block-ephemeral-containers/block-ephemeral-containers/
---
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
          namespaceSelector:
            matchExpressions:
            - key: capsule.clastix.io/tenant
              operator: Exists
    validate:
      message: "Ephemeral (debug) containers are not permitted."
      pattern:
        spec:
          X(ephemeralContainers): "null"{{< /tab >}}
{{% /tabpane %}}

## Image Registry

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Capsule" >}}
---
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
    - "mcr.microsoft.com"{{< /tab >}}
  {{< tab header="Kyverno" >}}
# Or with a Kyverno Policy. Here the default registry is `docker.io`, when no registry prefix is specified:
---
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
            - "mcr.microsoft.com"{{< /tab >}}
{{% /tabpane %}}

## Image PullPolicy

[Read More](/docs/operating/best-practices/images/).


{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Capsule" >}}
---
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  imagePullPolicies:
  - Always{{< /tab >}}
  {{< tab header="Kyverno" >}}
---
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
            imagePullPolicy: Always{{< /tab >}}
{{% /tabpane %}}

## QOS Classes

You may consider the upstream policies, depending on your needs:

* [QoS Burstable](https://kyverno.io/policies/other/require-qos-burstable/require-qos-burstable/)
* [QoS Guaranteed](https://kyverno.io/policies/other/require-qos-guaranteed/require-qos-guaranteed/)
