---
title: Admission Policies
weight: 10
description: Recommended Admission Policies to enforce best practices in multi-tenant environments.
---

As Capsule we try to provide a secure multi-tenant environment out of the box, there are however some additional Admission Policies you should consider to enforce best practices in your cluster. Since Capsule only covers the core multi-tenancy features, such as Namespaces, Resource Quotas, Network Policies, and Container Registries, Classes, you should consider using an additional Admission Controller to enforce best practices on workloads and other resources.

The Kyverno examples use the `policies.kyverno.io/v1` API (`ValidatingPolicy` and `MutatingPolicy`). The legacy `kyverno.io/v1` `ClusterPolicy` is deprecated, and Kyverno 1.20 no longer accepts it.

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

The policy only applies to Tenants with a class matching condition (`allowed`, `allowedRegex`, `matchLabels` or `matchExpressions` in `spec.storageClasses`); other Tenants, including those that only set a `default`, are skipped. For the others it reads `status.classes.storage` of the Tenant, so a class that is not listed denies the request. Kyverno needs read access to Tenants:

```yaml
admissionController:
  rbac:
    clusterRole:
      extraResources:
        - apiGroups: ["capsule.clastix.io"]
          resources: ["tenants"]
          verbs: ["get", "list", "watch"]
```

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: restrict-tenant-class
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
      - apiGroups: ["objectbucket.io"]
        apiVersions: ["v1alpha1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["objectbucketclaims"]
  variables:
    - name: tenant
      expression: >-
        dyn(resource.Get("capsule.clastix.io/v1beta2", "tenants", "", namespaceObject.metadata.labels['capsule.clastix.io/tenant']))
    - name: selectors
      expression: variables.tenant.?spec.storageClasses.orValue({})
    - name: classes
      expression: variables.tenant.?status.classes.storage.orValue([])
  validations:
    # Tenants without a class matching condition are not restricted.
    - expression: >-
        variables.tenant.?metadata.name.hasValue() && (
          !['allowed', 'allowedRegex', 'matchLabels', 'matchExpressions'].exists(f, size(variables.selectors[?f].orValue([])) > 0) ||
          object.spec.?storageClassName.orValue('NONE') in variables.classes)
      messageExpression: >-
        'storageclass ' + object.spec.?storageClassName.orValue('NONE') + ' is not allowed in tenant (' + variables.classes.join(', ') + ')'{{< /tab >}}
{{% /tabpane %}}

## Workloads

Policies to harden workloads running in a multi-tenant environment.

### Pod Disruption Budgets

[Pod Disruption Budgets](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) (PDBs) are a way to limit the number of concurrent disruptions to your Pods. In multi-tenant environments, it is recommended to enforce the usage of PDBs to ensure that tenants do not accidentally or maliciously block cluster operations.

#### MaxUnavailable

 A PodDisruptionBudget which sets its maxUnavailable value to zero prevents all voluntary evictions including Node drains which may impact maintenance tasks. This policy enforces that if a PodDisruptionBudget specifies the maxUnavailable field it must be greater than zero.

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
# Source: https://kyverno.io/policies/other-vpol/pdb-maxunavailable/pdb-maxunavailable/
# Scoped to Tenant Namespaces, enforced, and percentages are accepted.
# Values can be allowed with a PolicyException, for example 'maxUnavailable:0'.
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: pdb-maxunavailable
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
      - apiGroups: ["policy"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["poddisruptionbudgets"]
  validations:
    - expression: >-
        !has(object.spec.maxUnavailable) ||
        int(string(object.spec.maxUnavailable).replace('%', '')) > 0 ||
        exceptions.allowedValues.exists(value, value == 'maxUnavailable:' + string(object.spec.maxUnavailable))
      message: "The value of maxUnavailable must be greater than zero."{{< /tab >}}
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

When a Pod controller which can run multiple replicas is subject to an active PodDisruptionBudget, if the replicas field has a value equal to the minAvailable value of the PodDisruptionBudget it may prevent voluntary disruptions including Node drains which may impact routine maintenance tasks and disrupt operations. This policy checks incoming Deployments and StatefulSets which have a matching PodDisruptionBudget to ensure these two values do not match. PodDisruptionBudget selectors are matched on both `matchLabels` and `matchExpressions`, and percentage values are rounded up like Kubernetes does. Percentages are calculated from the replicas of this workload, so use PodDisruptionBudgets that select a single workload.

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: pdb-minavailable-check
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
      - apiGroups: ["apps"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["deployments", "statefulsets"]
  variables:
    - name: replicas
      expression: object.spec.?replicas.orValue(1)
    - name: labels
      expression: object.spec.template.metadata.?labels.orValue({})
    - name: pdbs
      expression: >-
        dyn(resource.List("policy/v1", "poddisruptionbudgets", object.metadata.namespace)).items
          .filter(p, has(p.spec.selector) &&
            p.spec.selector.?matchLabels.orValue({}).all(k, variables.labels[?k] == optional.of(p.spec.selector.matchLabels[k])) &&
            p.spec.selector.?matchExpressions.orValue([]).all(e,
              e.operator == 'In' ? variables.labels[?e.key].hasValue() && variables.labels[e.key] in e.?values.orValue([]) :
              e.operator == 'NotIn' ? !variables.labels[?e.key].hasValue() || !(variables.labels[e.key] in e.?values.orValue([])) :
              e.operator == 'Exists' ? variables.labels[?e.key].hasValue() :
              e.operator == 'DoesNotExist' ? !variables.labels[?e.key].hasValue() : false))
  validations:
    - expression: >-
        variables.replicas == 0 || !variables.pdbs.exists(p,
          (string(p.spec.?minAvailable.orValue(0)).endsWith('%')
            ? (int(string(p.spec.minAvailable).replace('%', '')) * variables.replicas + 99) / 100
            : int(p.spec.?minAvailable.orValue(0))) == variables.replicas)
      message: >-
        The matching PodDisruptionBudget for this resource has its minAvailable value equal to the replica count
        which is not permitted.{{< /tab >}}
{{% /tabpane %}}

#### Deployment Replicas higher than PDB

PodDisruptionBudget resources are useful to ensuring minimum availability is maintained at all times.Introducing a PDB where there are already matching Pod controllers may pose a problem if the author is unaware of the existing replica count. This policy ensures that the minAvailable value is not greater or equal to the replica count of any matching existing Deployment. If other Pod controllers should also be included in this check, additional rules may be added to the policy which match those controllers. Percentage values of `minAvailable` are rounded up like Kubernetes does and calculated from the replicas of each Deployment, so use PodDisruptionBudgets that select a single workload.

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: deployment-replicas-higher-than-pdb
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
      - apiGroups: ["policy"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["poddisruptionbudgets"]
  variables:
    - name: candidates
      expression: >-
        dyn(resource.List("apps/v1", "deployments", object.metadata.namespace)).items
          .map(d, {'labels': d.spec.template.metadata.?labels.orValue({}), 'replicas': d.spec.?replicas.orValue(1)})
    - name: deployments
      expression: >-
        !has(object.spec.selector) ? [] :
        variables.candidates.filter(d,
          object.spec.selector.?matchLabels.orValue({}).all(k, d.labels[?k] == optional.of(object.spec.selector.matchLabels[k])) &&
          object.spec.selector.?matchExpressions.orValue([]).all(e,
            e.operator == 'In' ? d.labels[?e.key].hasValue() && d.labels[e.key] in e.?values.orValue([]) :
            e.operator == 'NotIn' ? !d.labels[?e.key].hasValue() || !(d.labels[e.key] in e.?values.orValue([])) :
            e.operator == 'Exists' ? d.labels[?e.key].hasValue() :
            e.operator == 'DoesNotExist' ? !d.labels[?e.key].hasValue() : false))
  validations:
    - expression: >-
        !has(object.spec.minAvailable) || variables.deployments.all(d,
          (string(object.spec.minAvailable).endsWith('%')
            ? (int(string(object.spec.minAvailable).replace('%', '')) * d.replicas + 99) / 100
            : int(object.spec.minAvailable)) < d.replicas)
      messageExpression: >-
        'PodDisruption budget minAvailable (' + string(object.spec.minAvailable) + ') cannot be greater than or equal to the replica count of any matching existing Deployment. Matching Deployments have ' +
        variables.deployments.map(d, string(d.replicas)).join(', ') + ' replicas.'{{< /tab >}}
{{% /tabpane %}}

#### CNPG Cluster

When a Pod controller which can run multiple replicas is subject to an active PodDisruptionBudget, if the replicas field has a value equal to the minAvailable value of the PodDisruptionBudget it may prevent voluntary disruptions including Node drains which may impact routine maintenance tasks and disrupt operations. This policy checks incoming CNPG Clusters and their `.spec.enablePDB` setting.

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: pdb-cnpg-cluster-validation
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
      - apiGroups: ["postgresql.cnpg.io"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["clusters"]
  validations:
    - expression: >-
        object.spec.?enablePDB.orValue(false) == false || object.spec.?instances.orValue(1) >= 2
      message: "Set `.spec.enablePDB` to `false` for CNPG Clusters when the number of instances is lower than 2."{{< /tab >}}
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

### Enforce EmptDir Requests/Limits

By Defaults `emptyDir` Volumes do not have any limits. This could lead to a situation, where a tenant fills up the node disk. To avoid this, you can enforce limits on `emptyDir` volumes. You may also consider restricting the usage of `emptyDir` with the `medium: Memory` option, as this could lead to memory exhaustion on the node.

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
# Source: https://kyverno.io/policies/other-mpol/add-emptydir-sizelimit/add-emptydir-sizelimit/
# Scoped to Tenant Namespaces, sets 250Mi, and only patches emptyDir volumes
# (other volumes, such as the projected service account token, contain atomic lists and cannot be patched).
# Controllers are not mutated (autogen is disabled), their Pods are.
# CREATE only: Pod specs are immutable, so mutating on UPDATE blocks updates of existing Pods, such as finalizer removal.
apiVersion: policies.kyverno.io/v1
kind: MutatingPolicy
metadata:
  name: add-emptydir-sizelimit
spec:
  autogen:
    podControllers:
      controllers: []
  matchConstraints:
    namespaceSelector:
      matchExpressions:
        - key: capsule.clastix.io/tenant
          operator: Exists
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE"]
        resources: ["pods"]
  mutations:
    - patchType: ApplyConfiguration
      applyConfiguration:
        expression: >-
          Object{
            spec: Object.spec{
              volumes: object.spec.?volumes.orValue([]).filter(v, has(v.emptyDir)).map(v,
                Object.spec.volumes{
                  name: v.name,
                  emptyDir: Object.spec.volumes.emptyDir{
                    sizeLimit: has(v.emptyDir.sizeLimit) ? v.emptyDir.sizeLimit : "250Mi"
                  }
                }
              )
            }
          }{{< /tab >}}
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
---
# Source: https://kyverno.io/policies/other-vpol/block-ephemeral-containers/block-ephemeral-containers/
# Scoped to Tenant Namespaces and enforced. Container names can be allowed with a PolicyException.
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: block-ephemeral-containers
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
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods", "pods/ephemeralcontainers"]
  validations:
    - expression: >-
        object.spec.?ephemeralContainers.orValue([]).all(container,
          has(exceptions.allowedValues) && string(container.name) in exceptions.allowedValues)
      message: "Ephemeral (debug) containers are not permitted."{{< /tab >}}
{{% /tabpane %}}

## Certificates

### Deny ClusterIssuer in Certificates

Often when working in multi-tenant environments, you want to ensure that tenants are not using `ClusterIssuers` to issue certificates, but rather use namespaced `Issuers` within their own namespace. This policy enforces that `cert-manager.io/v1/Certificate` resources do not reference `ClusterIssuers` and that the `Issuer` referenced is in the same namespace as the `Certificate`.

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: certificates-only-local-issuer
spec:
  validationActions: [Deny]
  evaluation:
    background:
      enabled: true
  matchConstraints:
    namespaceSelector:
      matchExpressions:
        - key: capsule.clastix.io/tenant
          operator: Exists
    resourceRules:
      - apiGroups: ["cert-manager.io"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["certificates"]
  validations:
    - expression: object.spec.issuerRef.?kind.orValue('Issuer') != 'ClusterIssuer'
      message: "Certificates must not reference ClusterIssuers; use a namespaced Issuer in the same namespace."
    - expression: object.spec.issuerRef.?namespace.orValue(object.metadata.namespace) == object.metadata.namespace
      message: "Certificates must reference an Issuer in the same namespace (spec.issuerRef.namespace must be empty or equal to the Certificate namespace)."{{< /tab >}}
{{% /tabpane %}}

### Deny ClusterIssuer in Gateways

Deny to usage of ClusterIssuers in Gateways by checking for the `cert-manager.io/cluster-issuer` annotation. This ensures that tenants use namespaced issuer mechanisms instead.

The policy is evaluated at admission. To also scan existing Gateways, enable `evaluation.background` and allow the Kyverno reports controller to read Gateways:

```yaml
reportsController:
  rbac:
    clusterRole:
      extraResources:
        - apiGroups: ["gateway.networking.k8s.io"]
          resources: ["gateways"]
          verbs: ["get", "list", "watch"]
```

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: gateways-deny-cluster-issuer-annotation
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
      - apiGroups: ["gateway.networking.k8s.io"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["gateways"]
  validations:
    - expression: object.metadata.?annotations[?'cert-manager.io/cluster-issuer'].orValue('') == ''
      message: "Gateways must not use cert-manager.io/cluster-issuer; use namespaced issuer mechanisms instead."{{< /tab >}}
{{% /tabpane %}}

### Selective ClusterIssuers

Allow certain ClusterIssuers within Tenants. The policy reads the ClusterIssuer, so Kyverno needs read access to ClusterIssuers:

```yaml
admissionController:
  rbac:
    clusterRole:
      extraResources:
        - apiGroups: ["cert-manager.io"]
          resources: ["clusterissuers"]
          verbs: ["get", "list", "watch"]
```

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: certificates-restrict-clusterissuer-by-tenant-label
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
      - apiGroups: ["cert-manager.io"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["certificates"]
  matchConditions:
    - name: uses-clusterissuer
      expression: object.spec.issuerRef.?kind.orValue('Issuer') == 'ClusterIssuer'
  variables:
    - name: certManagedBy
      expression: object.metadata.?labels[?'capsule.clastix.io/managed-by'].orValue('')
    - name: clusterIssuerManagedBy
      expression: >-
        dyn(resource.Get("cert-manager.io/v1", "clusterissuers", "", object.spec.issuerRef.name))
          .?metadata.labels[?'company.com/tenant'].orValue('')
  validations:
    - expression: >-
        variables.certManagedBy != '' && variables.clusterIssuerManagedBy != '' &&
        variables.certManagedBy == variables.clusterIssuerManagedBy
      messageExpression: >-
        'ClusterIssuer is only allowed when the Certificate label capsule.clastix.io/managed-by (' + variables.certManagedBy +
        ') matches the referenced ClusterIssuer label company.com/tenant (' + variables.clusterIssuerManagedBy + ').'{{< /tab >}}
{{% /tabpane %}}
