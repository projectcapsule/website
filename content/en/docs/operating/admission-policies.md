---
title: Admission Policies
weight: 2
description: Recommended Admission Policies to enforce best practices in multi-tenant environments.
---

As Capsule we try to provide a secure multi-tenant environment out of the box, there are however some additional Admission Policies you should consider to enforce best practices in your cluster. Since Capsule only covers the core multi-tenancy features, such as Namespaces, Resource Quotas, Network Policies, and Container Registries, Classes, you should consider using an additional Admission Controller to enforce best practices on workloads and other resources.

## Custom

Create custom Policies and reuse data provided via Tenant Status to enforce your own rules.

### Owner Validation


### Class Validation

Let's say we have the following namespaced [`ObjectBucketClaim`](https://rook.io/docs/rook/v1.12/Storage-Configuration/Object-Storage-RGW/object-storage/#create-a-bucket) resource:

```yaml
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: admission-class
  namespace: solar-production
  finalizers:
    - objectbucket.io/finalizer
  labels:
    bucket-provisioner: openshift-storage.ceph.rook.io-bucket
spec:
  additionalConfig:
    maxSize: 2G
  bucketName: test-some-uid
  generateBucketName: test
  objectBucketName: obc-test-test
  storageClassName: ocs-storagecluster-ceph-rgw
```

However since we are allowing Tenant Users to create these [`ObjectBucketClaims`](https://rook.io/docs/rook/v1.12/Storage-Configuration/Object-Storage-RGW/object-storage/#create-a-bucket) we might want to consider validating the `storageClassName` field to ensure that only allowed StorageClasses are used.


{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-tenant-class
spec:
  validationFailureAction: Enforce
  rules:
  - name: restrict-storage-class
    context:
      - name: classes
        apiCall:
          urlPath: "/apis/capsule.clastix.io/v1beta2/tenants"
          jmesPath: "items[?contains(status.namespaces, '{{ request.namespace }}')].status.classes | [0]"

      - name: storageClass
        variable:
          jmesPath: "request.object.spec.storageClassName || 'NONE'"
    match:
      resources:
        kinds:
        - ObjectBucketClaim
        namespaceSelector:
          matchExpressions:
          - key: capsule.clastix.io/tenant
            operator: Exists
    validate:
      message: "storageclass {{ storageClass }} is not allowed in tenant ({{classes.storage}})"
      deny:
        conditions:
          - key:   "{{classes.storage}}"
            operator: AnyNotIn
            value:  "{{ storageClass }}"{{< /tab >}}
{{% /tabpane %}}

## Workloads

Policies to harden workloads running in a multi-tenant environment.

### Disallow Scheduling on Control Planes

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
    node-role.kubernetes.io/worker: ''{{< /tab >}}
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

### Pod Disruption Budgets

[Pod Disruption Budgets]([/docs/concepts/workloads/pods/disruptions/](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)) (PDBs) are a way to limit the number of concurrent disruptions to your Pods. In multi-tenant environments, it is recommended to enforce the usage of PDBs to ensure that tenants do not accidentally or maliciously block cluster operations.

#### MaxUnavailable

 A PodDisruptionBudget which sets its maxUnavailable value to zero prevents all voluntary evictions including Node drains which may impact maintenance tasks. This policy enforces that if a PodDisruptionBudget specifies the maxUnavailable field it must be greater than zero.

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
# Source: https://kyverno.io/policies/other/pdb-maxunavailable/pdb-maxunavailable/
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pdb-maxunavailable
  annotations:
    policies.kyverno.io/title: PodDisruptionBudget maxUnavailable Non-Zero
    policies.kyverno.io/category: Other
    kyverno.io/kyverno-version: 1.9.0
    kyverno.io/kubernetes-version: "1.24"
    policies.kyverno.io/subject: PodDisruptionBudget
    policies.kyverno.io/description: >-
      A PodDisruptionBudget which sets its maxUnavailable value to zero prevents
      all voluntary evictions including Node drains which may impact maintenance tasks.
      This policy enforces that if a PodDisruptionBudget specifies the maxUnavailable field
      it must be greater than zero.
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: pdb-maxunavailable
      match:
        any:
          - resources:
              kinds:
                - PodDisruptionBudget
              namespaceSelector:
                matchExpressions:
                - key: capsule.clastix.io/tenant
                  operator: Exists
      validate:
        message: "The value of maxUnavailable must be greater than zero."
        pattern:
          spec:
            =(maxUnavailable): ">0"{{< /tab >}}
  {{< tab header="VAP" >}}
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: pdb-maxunavailable
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: ["policy"]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["poddisruptionbudgets"]
    namespaceSelector:
      matchExpressions:
      - key: capsule.clastix.io/tenant
        operator: Exists
  validations:
  - expression: |
      !has(object.spec.maxUnavailable) ||
      string(object.spec.maxUnavailable).contains('%') ||
      object.spec.maxUnavailable > 0
    message: "The value of maxUnavailable must be greater than zero or a percentage."
    reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: pdb-maxunavailable-binding
spec:
  policyName: pdb-maxunavailable
  validationActions: ["Deny"]{{< /tab >}}
{{% /tabpane %}}

#### MinAvailable

When a Pod controller which can run multiple replicas is subject to an active PodDisruptionBudget, if the replicas field has a value equal to the minAvailable value of the PodDisruptionBudget it may prevent voluntary disruptions including Node drains which may impact routine maintenance tasks and disrupt operations. This policy checks incoming Deployments and StatefulSets which have a matching PodDisruptionBudget to ensure these two values do not match.

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
# Source: https://kyverno.io/policies/other/pdb-minavailable/pdb-minavailable/
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pdb-minavailable-check
  annotations:
    policies.kyverno.io/title: Check PodDisruptionBudget minAvailable
    policies.kyverno.io/category: Other
    kyverno.io/kyverno-version: 1.9.0
    kyverno.io/kubernetes-version: "1.24"
    policies.kyverno.io/subject: PodDisruptionBudget, Deployment, StatefulSet
    policies.kyverno.io/description: >-
      When a Pod controller which can run multiple replicas is subject to an active PodDisruptionBudget,
      if the replicas field has a value equal to the minAvailable value of the PodDisruptionBudget
      it may prevent voluntary disruptions including Node drains which may impact routine maintenance
      tasks and disrupt operations. This policy checks incoming Deployments and StatefulSets which have
      a matching PodDisruptionBudget to ensure these two values do not match.
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: pdb-minavailable
      match:
        any:
          - resources:
              kinds:
                - Deployment
                - StatefulSet
              namespaceSelector:
                matchExpressions:
                - key: capsule.clastix.io/tenant
                  operator: Exists
      preconditions:
        all:
        - key: "{{`{{ request.operation | 'BACKGROUND' }}`}}"
          operator: AnyIn
          value:
          - CREATE
          - UPDATE
        - key: "{{`{{ request.object.spec.replicas | '1' }}`}}"
          operator: GreaterThan
          value: 0
      context:
        - name: minavailable
          apiCall:
            urlPath: "/apis/policy/v1/namespaces/{{`{{ request.namespace }}`}}/poddisruptionbudgets"
            jmesPath: "items[?label_match(spec.selector.matchLabels, `{{`{{ request.object.spec.template.metadata.labels }}`}}`)] | [0].spec.minAvailable | default(`0`)"
      validate:
        message: >-
          The matching PodDisruptionBudget for this resource has its minAvailable value equal to the replica count
          which is not permitted.
        deny:
          conditions:
            any:
              - key: "{{`{{ request.object.spec.replicas }}`}}"
                operator: Equals
                value: "{{`{{ minavailable }}`}}"{{< /tab >}}
{{% /tabpane %}}

#### Deployment Replicas higher than PDB 

PodDisruptionBudget resources are useful to ensuring minimum availability is maintained at all times.Introducing a PDB where there are already matching Pod controllers may pose a problem if the author is unaware of the existing replica count. This policy ensures that the minAvailable value is not greater or equal to the replica count of any matching existing Deployment. If other Pod controllers should also be included in this check, additional rules may be added to the policy which match those controllers.

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
# Source: https://kyverno.io/policies/other/deployment-replicas-higher-than-pdb/deployment-replicas-higher-than-pdb/
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: deployment-replicas-higher-than-pdb
  annotations:
    policies.kyverno.io/title: Ensure Deployment Replicas Higher Than PodDisruptionBudget
    policies.kyverno.io/category: Other
    policies.kyverno.io/subject: PodDisruptionBudget, Deployment
    kyverno.io/kyverno-version: 1.11.4
    kyverno.io/kubernetes-version: "1.27"
    policies.kyverno.io/description: >-
      PodDisruptionBudget resources are useful to ensuring minimum availability is maintained at all times.
      Introducing a PDB where there are already matching Pod controllers may pose a problem if the author
      is unaware of the existing replica count. This policy ensures that the minAvailable value is not
      greater or equal to the replica count of any matching existing Deployment. If other Pod controllers
      should also be included in this check, additional rules may be added to the policy which match those
      controllers.
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: deployment-replicas-greater-minAvailable
    match:
      any:
      - resources:
          kinds:
          - PodDisruptionBudget
          operations:
          - CREATE
          - UPDATE
          namespaceSelector:
            matchExpressions:
            - key: capsule.clastix.io/tenant
              operator: Exists
    context:
    - name: deploymentreplicas
      apiCall:
        jmesPath: items[?label_match(`{{`{{ request.object.spec.selector.matchLabels }}`}}`, spec.template.metadata.labels)] || `[]`
        urlPath: /apis/apps/v1/namespaces/{{`{{request.namespace}}`}}/deployments
    preconditions:
      all:
      - key: '{{`{{ length(deploymentreplicas) }}`}}'
        operator: GreaterThan
        value: 0
      - key: '{{`{{ request.object.spec.minAvailable || "" }}`}}'
        operator: NotEquals
        value: ''
    validate:
      message: >-
        PodDisruption budget minAvailable ({{`{{ request.object.spec.minAvailable }}`}}) cannot be
        greater than or equal to the replica count of any matching existing Deployment.
        There are {{`{{ length(deploymentreplicas) }}`}} Deployments which match this labelSelector
        having {{`{{ deploymentreplicas[*].spec.replicas }}`}} replicas.
      foreach:
        - list: deploymentreplicas
          deny:
            conditions:
              all:
              - key: "{{`{{ request.object.spec.minAvailable }}`}}"
                operator: GreaterThanOrEquals
                value: "{{`{{ element.spec.replicas }}`}}"{{< /tab >}}
{{% /tabpane %}}

#### CNPG Cluster

When a Pod controller which can run multiple replicas is subject to an active PodDisruptionBudget, if the replicas field has a value equal to the minAvailable value of the PodDisruptionBudget it may prevent voluntary disruptions including Node drains which may impact routine maintenance tasks and disrupt operations. This policy checks incoming CNPG Clusters and their `.spec.enablePDB` setting.

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pdb-cnpg-cluster-validation
  annotations:
    policies.kyverno.io/title: Check PodDisruptionBudget minAvailable for cnpgCluster
    policies.kyverno.io/category: Other
    kyverno.io/kyverno-version: 1.9.0
    kyverno.io/kubernetes-version: "1.24"
    policies.kyverno.io/subject: PodDisruptionBudget, Cluster
    policies.kyverno.io/description: >-
      When a Pod controller which can run multiple replicas is subject to an active PodDisruptionBudget,
      if the replicas field has a value equal to the minAvailable value of the PodDisruptionBudget
      it may prevent voluntary disruptions including Node drains which may impact routine maintenance
      tasks and disrupt operations. This policy checks incoming CNPG Clusters and their .spec.enablePDB setting.
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: pdb-cnpg-cluster-validation
      match:
        any:
          - resources:
              kinds:
                - postgresql.cnpg.io/v1/Cluster
              namespaceSelector:
                matchExpressions:
                - key: capsule.clastix.io/tenant
                  operator: Exists
      preconditions:
        any:
        - key: "{{request.operation || 'BACKGROUND'}}"
          operator: AnyIn
          value:
          - CREATE
          - UPDATE
      validate:
        message: >-
          Set `.spec.enablePDB` to `false` for CNPG Clusters when the number of instances is lower than 2.
        deny:
          conditions:
            all:
              - key: "{{request.object.spec.enablePDB }}"
                operator: Equals
                value: true
              - key: "{{request.object.spec.instances }}"
                operator: LessThan
                value: 2{{< /tab >}}
  {{< tab header="VAP" >}}
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: pdb-cnpg-cluster-validation
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: ["postgresql.cnpg.io"]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["clusters"]
    namespaceSelector:
      matchExpressions:
      - key: capsule.clastix.io/tenant
        operator: Exists
  validations:
  - expression: |
      !has(object.spec.enablePDB) ||
      object.spec.enablePDB == false ||
      (has(object.spec.instances) && object.spec.instances >= 2)
    message: "Set `.spec.enablePDB` to `false` for CNPG Clusters when the number of instances is lower than 2."
    messageExpression: |
      'Set `.spec.enablePDB` to `false` for CNPG Clusters when the number of instances is lower than 2. Current instances: ' + 
      string(has(object.spec.instances) ? object.spec.instances : 1)
    reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: pdb-cnpg-cluster-validation-binding
spec:
  policyName: pdb-cnpg-cluster-validation
  validationActions: ["Deny"]{{< /tab >}}
{{% /tabpane %}}

### Mutate User Namespace

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

### Disallow Daemonsets

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

### Enforce EmptDir Requests/Limits

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

### Block Ephemeral Containers

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

### QOS Classes

You may consider the upstream policies, depending on your needs:

* [QoS Burstable](https://kyverno.io/policies/other/require-qos-burstable/require-qos-burstable/)
* [QoS Guaranteed](https://kyverno.io/policies/other/require-qos-guaranteed/require-qos-guaranteed/)


## Images

### Allowed Registries

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

### Allowed PullPolicy

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
