---
title: Admission Policies
weight: 10
description: Recommended Admission Policies to enforce best practices in multi-tenant environments.
---

As Capsule we try to provide a secure multi-tenant environment out of the box, there are however some additional Admission Policies you should consider to enforce best practices in your cluster. Since Capsule only covers the core multi-tenancy features, such as Namespaces, Resource Quotas, Network Policies, and Container Registries, Classes, you should consider using an additional Admission Controller to enforce best practices on workloads and other resources.

## CNPG Cluster

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

## Certificates

### Deny ClusterIssuer in Certificates

Often when working in multi-tenant environments, you want to ensure that tenants are not using `ClusterIssuers` to issue certificates, but rather use namespaced `Issuers` within their own namespace. This policy enforces that `cert-manager.io/v1/Certificate` resources do not reference `ClusterIssuers` and that the `Issuer` referenced is in the same namespace as the `Certificate`.

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: certificates-only-local-issuer
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: deny-clusterissuer-in-certificates
      match:
        any:
          - resources:
              kinds:
                - cert-manager.io/v1/Certificate
              namespaceSelector:
                matchExpressions:
                - key: capsule.clastix.io/tenant
                  operator: Exists
      validate:
        message: "Certificates must not reference ClusterIssuers; use a namespaced Issuer in the same namespace."
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.issuerRef.kind || 'Issuer' }}"
                operator: Equals
                value: "ClusterIssuer"

    - name: deny-cross-namespace-issuerref-in-certificates
      match:
        any:
          - resources:
              kinds:
                - cert-manager.io/v1/Certificate
      validate:
        message: "Certificates must reference an Issuer in the same namespace (spec.issuerRef.namespace must be empty or equal to the Certificate namespace)."
        deny:
          conditions:
            any:
              # If issuerRef.namespace is set and differs from the Certificate namespace -> deny
              - key: "{{request.object.spec.issuerRef.namespace || '' }}"
                operator: NotEquals
                value: ""
                # AND also not equal to request namespace
              - key: "{{ request.object.spec.issuerRef.namespace || request.namespace  }}"
                operator: NotEquals
                value: "{{ request.namespace }}"{{< /tab >}}
{{% /tabpane %}}

### Deny ClusterIssuer in Gateways

Deny to usage of ClusterIssuers in Gateways by checking for the `cert-manager.io/cluster-issuer` annotation. This ensures that tenants use namespaced issuer mechanisms instead.

This requires extra permissions to allow Kyverno to read Gateway resources:

```yaml
admissionController:
  rbac:
    clusterRole:
      extraResources:
       - apiGroups: ["gateway.networking.k8s.io"]
         resources: ["*"]
         verbs: ["get", "list", "watch"]
```

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: gateways-deny-cluster-issuer-annotation
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: deny-cert-manager-cluster-issuer-annotation
      match:
        any:
          - resources:
              kinds:
                - gateway.networking.k8s.io/v1/Gateway
              namespaceSelector:
                matchExpressions:
                - key: capsule.clastix.io/tenant
                  operator: Exists
      validate:
        message: "Gateways must not use cert-manager.io/cluster-issuer; use namespaced issuer mechanisms instead."
        deny:
          conditions:
            any:
              - key: "{{ request.object.metadata.annotations.\"cert-manager.io/cluster-issuer\" || '' }}"
                operator: NotEquals
                value: ""{{< /tab >}}
{{% /tabpane %}}

### Selective ClusterIssuers

Allow certain ClusterIssuers within Tenants:

{{% tabpane lang="yaml" %}}
  {{% tab header="**Engines**:" disabled=true /%}}
  {{< tab header="Kyverno" >}}
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: certificates-restrict-clusterissuer-by-tenant-label
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: allow-clusterissuer-only-when-managed-by-matches
      match:
        any:
          - resources:
              kinds:
                - cert-manager.io/v1/Certificate
              namespaceSelector:
                matchExpressions:
                  - key: capsule.clastix.io/tenant
                    operator: Exists
      context:
        - name: certManagedBy
          variable:
            jmesPath: request.object.metadata.labels."capsule.clastix.io/managed-by" || ''
        - name: clusterIssuerManagedBy
          apiCall:
            urlPath: /apis/cert-manager.io/v1/clusterissuers/{{ request.object.spec.issuerRef.name }}
            jmesPath: metadata.labels."company.com/tenant" || ''
            default: ""
      preconditions:
        all:
          - key: "{{ request.object.spec.issuerRef.kind || 'Issuer' }}"
            operator: Equals
            value: ClusterIssuer
          - key: "{{request.operation || 'BACKGROUND'}}"
            operator: AnyIn
            value:
            - CREATE
            - UPDATE
      validate:
        message: >-
          ClusterIssuer is only allowed when the Certificate label
          capsule.clastix.io/managed-by ({{certManagedBy}}) matches the referenced ClusterIssuer label
          company.com/tenant ({{clusterIssuerManagedBy}}).
        deny:
          conditions:
            any:
              - key: "{{certManagedBy}}"
                operator: Equals
                value: ""
              - key: "{{clusterIssuerManagedBy}}"
                operator: Equals
                value: ""
              - key: "{{certManagedBy}}"
                operator: NotEquals
                value: "{{clusterIssuerManagedBy}}"{{< /tab >}}
{{% /tabpane %}}
