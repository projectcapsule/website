---
title: Installation
weight: 1
description: "Installing the Capsule Controller"
---

## Requirements

 * [Helm 3](https://github.com/helm/helm/releases) is required when installing the Capsule Operator chart. Follow Helm’s official documentation for installing Helm on your operating system.
 * A Kubernetes cluster (v1.16+) with the following [Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/) enabled:
    * PodNodeSelector
    * LimitRanger
    * ResourceQuota
    * MutatingAdmissionWebhook
    * ValidatingAdmissionWebhook
 * A [Kubeconfig](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/) file accessing the Kubernetes cluster with cluster admin permissions.
 * [Cert-Manager](https://cert-manager.io/) is required by default but can be disabled. It is used to manage the TLS certificates for the Capsule Admission Webhooks.

## Installation

We officially only support the installation of Capsule using the Helm chart. The chart itself handles the installation/upgrade of the required [CustomResourceDefinitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/). The following Artifact Hub repositories are official:

* [Artifact Hub Page (OCI)](https://artifacthub.io/packages/helm/capsule/capsule)
* [Artifact Hub Page (Legacy - Best Effort)](https://artifacthub.io/packages/helm/projectcapsule/capsule)

Perform the following steps to install the Capsule operator:

1. Add repository:

        helm repo add projectcapsule https://projectcapsule.github.io/charts

2. Install Capsule:

        helm install capsule projectcapsule/capsule --version {{< capsule_chart_version >}} -n capsule-system --create-namespace

    or (**OCI**)

        helm install capsule oci://ghcr.io/projectcapsule/charts/capsule --version {{< capsule_chart_version >}} -n capsule-system --create-namespace

3. Show the status:

        helm status capsule -n capsule-system

4. Upgrade the Chart

        helm upgrade capsule projectcapsule/capsule -n capsule-system

    or (**OCI**)

        helm upgrade capsule oci://ghcr.io/projectcapsule/charts/capsule --version {{< capsule_chart_version >}}

5. Uninstall the Chart

        helm uninstall capsule -n capsule-system


## Production

Here are some key considerations to keep in mind when installing Capsule. Also check out the **[Best Practices](/docs/operating/best-practices)** for more information.

### Scalability

For large clusters you might need to consider adjusting values for the Capsule controller.

#### QPS/Burst

In order to handle a large number of tenants and resources, you may need to increase the QPS and Burst values for the Capsule controller. This avoids the controller being throttled by the Kubernetes API server (Client Rate limited). You can set the following values in the Helm chart:

```yaml
manager:
  options:
    clientConnectionQPS: 400
    clientConnectionBurst: 200
```

#### Workers

Define the number of workers for the Capsule controller, which translates into the number of concurrent reconciles:

```yaml
manager:
  options:
    workers: 4
```

#### Cache Synchronisation

The more resources you have in your cluster, the longer it will take for the Capsule controller to sync its cache. You can adjust the cache sync period to a higher value to reduce the load on the API server:

```yaml
manager:
  options:
    cacheSyncTimeout: "10m"
```

#### Leader Election Timeout

In high pressure environments leader election may fail due to the default timeout values. You can adjust the leader election timeout values to avoid this issue:

```yaml
```shell
E0707 08:38:18.319041       1 leaderelection.go:452] "Error retrieving lease lock"
  err="Get \"https://10.96.0.1:443/apis/coordination.k8s.io/v1/namespaces/capsule-
  system/leases/42c733ea.clastix.capsule.io?timeout=5s\": net/http: request canceled
  (Client.Timeout exceeded while awaiting headers)" lock="capsule-
  system/42c733ea.clastix.capsule.io"
  I0707 08:38:18.442700       1 leaderelection.go:299] "Failed to renew lease"
```

Tune leader election with `manager.options.leaderElectionLeaseDuration`, `manager.options.leaderElectionRenewDeadline`, and `manager.options.leaderElectionRetryPeriod`. Increasing these values makes Capsule more tolerant of slow or overloaded Kubernetes API servers; for example, raising `leaderElectionRenewDeadline` also raises the leader-election client request timeout because controller-runtime uses roughly half of that value. The tradeoff is slower failover: if the active controller really dies, standby replicas will wait longer before taking leadership. Keep the ordering valid: `leaseDuration` should be greater than `renewDeadline`, and `renewDeadline` should be greater than `retryPeriod`.

```yaml
manager:
  options:
    leaderElectionLeaseDuration: "60s"
    leaderElectionRenewDeadline: "40s"
    leaderElectionRetryPeriod: "5s"
```

Worst-case leader failover is slower, around 60s, if the active pod really dies. Keep `manager.options.leaderElectionLeaseDuration` > `manager.options.leaderElectionRenewDeadline` > `manager.options.leaderElectionRetryPeriod`.

#### API Priority and Fairness (APF)

With APF enabled, the Capsule controller will be subject to the APF configuration of the cluster. If you are running a large cluster with many tenants, you may need to adjust the APF configuration to ensure that the Capsule controller has sufficient resources to operate effectively. For more information on APF, see [Kubernetes API Priority and Fairness](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/apiserver-aggregation/#api-priority-and-fairness).

We provide a built-in APF configuration for the Capsule controller, which provides API priority for all resources managed by Capsule. This configuration is applied automatically when you install Capsule. To enable the built-in APF configuration, set the following value in the Helm chart:

```yaml
# Manager Options
manager:
  apiPriorityAndFairness:
    # -- Change to `true` if you want to insulate the API calls made by Capsule admission controller activities.
    # This will help ensure Capsule stability in busy clusters.
    # Ref: https://kubernetes.io/docs/concepts/cluster-administration/flow-control/
    enabled: true

    # -- Only the first matching FlowSchema for a given request matters. If multiple FlowSchemas match a single inbound request, it will be assigned based on the one with the highest matchingPrecedence.
    # Ref: https://kubernetes.io/docs/concepts/cluster-administration/flow-control/#flowschema
    matchingPrecedence: 900

    # -- Priority level configuration.
    # The block is directly forwarded into the priorityLevelConfiguration, so you can use whatever specification you want.
    # ref: https://kubernetes.io/docs/concepts/cluster-administration/flow-control/#prioritylevelconfiguration
    priorityLevelConfigurationSpec:
      type: Limited
      limited:
          nominalConcurrencyShares: 100
          limitResponse:
            type: Queue
            queuing:
              queues: 64
              handSize: 6
              queueLengthLimit: 100
```


### Strict RBAC

{{% alert title="Attention" color="warning" %}}
Ensure to first upgrade to version `0.13.0` of capsule before enabling strict mode. As it requires fields which are newly added with version `0.13.0`.
{{% /alert %}}


By default, the Capsule controller runs with the ClusterRole `cluster-admin`, which provides full access to the cluster. This is because the controller itself must grant RoleBindings on a per-namespace basis that by default reference the ClusterRole `admin`, which needs to at least match the permissions of the controller itself. However, for production environments we recommend configuring stricter RBAC permissions for the Capsule controller. You can enable the minimal required permissions by setting the following value in the Helm chart:

```yaml
manager:
  rbac:
    strict: true
```

This grants the controller the minimal permissions required for its own operation. However, that alone is not sufficient for it to function properly. The ClusterRole for the controller allows aggregating further permissions to it via the following labels:

* `projectcapsule.dev/aggregate-to-controller: "true"`
* `projectcapsule.dev/aggregate-to-controller-instance: {{ .Release.Name }}`

In other words, you must aggregate all ClusterRoles that are assigned to [Tenant owners](/docs/tenants/permissions/#owner-roles) or used for [additional RoleBindings](/docs/tenants/permissions/#strict). This applies only to ClusterRoles that are not managed by Capsule (see [Configuration](/docs/operating/setup/configuration/#rbac)). By default, the only such ClusterRole granted to owners is `admin` (not managed by Capsule).

```bash
kubectl label clusterrole admin projectcapsule.dev/aggregate-to-controller=true
```

Verify that the label has been applied:

```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: admin
  labels:
    projectcapsule.dev/aggregate-to-controller: "true"
rules:
...
```

Alternatively you can directly grant more permissions via Helm values:

```yaml
manager:
  rbac:
    strict: true
    clusterRole:
      extraResources: 
        - apiGroups: ["storage.k8s.io"]
          resources: ["storageclasses"]
          verbs: ["get", "list", "watch", "update", "patch"]
```

If you are missing permissions you will see an error status for the respective tenants reflecting

```bash
kubectl get tnt
NAME    STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR   READY   STATUS                                                                                                                                                                                                                                                                                                                                          AGE
green   Active                     2                                 False   cannot sync rolebindings items: rolebindings.rbac.authorization.k8s.io "capsule:managed:658936e7f2a30e35" is forbidden: user "system:serviceaccount:capsule-system:capsule" (groups=["system:serviceaccounts" "system:serviceaccounts:capsule-system" "system:authenticated"]) is attempting to grant RBAC permissions not currently held:...   5s

```

Alternatively, you can enable only the minimal required permissions by setting the following value in the Helm chart:

```yaml
manager:
  rbac:
    minimal: true
```

Before you enable this option, you must implement the required permissions for your use case. Depending on which features you are using, you may need to take manual action, for example:

* [Migrate additional RoleBindings](/docs/tenants/permissions/#strict)
* [Migrate `TenantResources` to use impersonation](/docs/replications/tenant/#impersonation)
* [Migrate `GlobalTenantResources` to use impersonation](/docs/replications/global/#impersonation)

### Admission Policies

While Capsule provides a robust framework for managing multi-tenancy in Kubernetes, it does not include built-in admission policies for enforcing specific security or operational standards for all possible aspects of a Kubernetes cluster.  [We provide additional policy recommendations here](/docs/operating/admission-policies/).

### Certificate Management

By default, Capsule delegates its certificate management to [cert-manager](https://cert-manager.io/). This is the recommended way to manage the TLS certificates for Capsule. However, you can also use Capsule's built-in TLS reconciler to manage the certificates. This is not recommended for production environments. To enable the TLS reconciler, use the following values:

```yaml
certManager:
  generateCertificates: false
tls:
  enableController: true
  create: true
```

### Webhooks

Capsule makes use of [webhooks for admission control](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers). Ensure that your cluster supports webhooks and that they are properly configured. The webhooks are automatically created by Capsule during installation. However, some of these webhooks will cause problems when Capsule is not running (this is especially problematic in single-node clusters). Here are the webhooks you need to watch out for.

Generally, we recommend using [matchConditions](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#matching-requests-matchconditions) for all webhooks to avoid problems when Capsule is not running. You should exclude your system-critical components from the Capsule webhooks. For namespaced resources (`pods`, `services`, etc.) the webhooks select only namespaces that are part of a Capsule Tenant. If your system-critical components are not part of a Capsule Tenant, they will not be affected by the webhooks. However, if you have system-critical components that are part of a Capsule Tenant, you should exclude them from the Capsule webhooks by using [matchConditions](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#matching-requests-matchconditions) as well, or add more specific [namespaceSelectors](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#matching-requests-namespaceselector)/[objectSelectors](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#matching-requests-objectselector) to exclude them. This can also improve performance.

[Refer to the webhook values](https://artifacthub.io/packages/helm/projectcapsule/capsule#webhooks-parameters).

**The Webhooks below are the most important ones to consider.**

#### Nodes

There is a webhook which catches interactions with the Node resource. This webhook is mainly relevant when you make use of [Node metadata](/docs/tenants/enforcement/#nodes). In most other cases, it will only cause problems. By default, the webhook is **disabled**, but you can enable it by setting the following value:

```yaml
webhooks:
  hooks:
    nodes:
      enabled: true
```

Or you could at least consider to set the failure policy to `Ignore`, if you don't want to disrupt critical nodes:

```yaml
webhooks:
  hooks:
    nodes:
      failurePolicy: Ignore
```

If you still want to use the feature, you could exclude the kube-system namespace (or any other namespace you want to exclude) from the webhook by setting the following value:

```yaml
webhooks:
  hooks:
    nodes:
      matchConditions:
      - name: 'exclude-kubelet-requests'
        expression: '!("system:nodes" in request.userInfo.groups)'
      - name: 'exclude-kube-system'
        expression: '!("system:serviceaccounts:kube-system" in request.userInfo.groups)'
```

#### Namespaces

Namespaces are the most important resource in Capsule. The Namespace webhook is responsible for enforcing the Capsule Tenant boundaries. It is enabled by default and should not be disabled. However, you may change the matchConditions to exclude certain namespaces from the Capsule Tenant boundaries. For example, you can exclude the kube-system namespace by setting the following value:

```yaml
webhooks:
  hooks:
    namespaces:
      matchConditions:
      - name: 'exclude-kube-system'
        expression: '!("system:serviceaccounts:kube-system" in request.userInfo.groups)'
```

#### Protected

By default resources with the following values are protected by a webhook to be changed by [Capsule Users]:

```yaml
webhooks:
  hooks:
    managed:
      objectSelector:
        matchExpressions:
          - key: "projectcapsule.dev/created-by"
            operator: In
            values:
            - "controller"
            - "resources"
          - key: "projectcapsule.dev/managed-by"
            operator: In
            values:
            - "controller"
```


## GitOps

There are no specific requirements for using Capsule with GitOps tools like ArgoCD or FluxCD. You can manage Capsule resources as you would with any other Kubernetes resource.

### ArgoCD

Visit the [ArgoCD Integration](/ecosystem/integrations/argocd/) for more options to integrate Capsule with ArgoCD.

Manifests to get you started with ArgoCD. For ArgoCD you might need to skip the validation of the `CapsuleConfiguration` resources, otherwise there might be errors on the first install:

{{% alert title="Information" color="warning" %}}
The `Validate=false` option is required for the CapsuleConfiguration resource, because ArgoCD tries to validate the resource before the Capsule CRDs are installed via our CRD Lifecycle hook. [Upstream Issue](https://github.com/argoproj/argo-cd/issues/16144). This has mainly been observed in ArgoCD Applications using Service-Side Diff/Apply.
{{% /alert %}}

```yaml
manager:
  options:
    annotations:
      argocd.argoproj.io/sync-options: "Validate=false,SkipDryRunOnMissingResource=true"
```


```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: capsule
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: system
  source:
    repoURL: ghcr.io/projectcapsule/charts
    targetRevision: {{< capsule_chart_version >}}
    chart: capsule
    helm:
      valuesObject:
        crds:
          install: true
        manager:
          options:
            annotations:
              argocd.argoproj.io/sync-options: "Validate=false,SkipDryRunOnMissingResource=true"
            capsuleConfiguration: default
            ignoreUserGroups:
              - oidc:administators
            users:
              - kind: Group
                name: oidc:kubernetes-users
              - kind: Group
                name: system:serviceaccounts:tenants-system
        monitoring:
          dashboards:
            enabled: true
          serviceMonitor:
            enabled: true
            annotations:
              argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true

  destination:
    server: https://kubernetes.default.svc
    namespace: capsule-system

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - ServerSideApply=true
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    - RespectIgnoreDifferences=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
---
apiVersion: v1
kind: Secret
metadata:
  name: capsule-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  url: ghcr.io/projectcapsule/charts
  name: capsule
  project: system
  type: helm
  enableOCI: "true"
```

### FluxCD

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: capsule
  namespace: flux-system
spec:
  serviceAccountName: kustomize-controller
  targetNamespace: "capsule-system"
  interval: 10m
  releaseName: "capsule"
  chart:
    spec:
      chart: capsule
      version: "{{< capsule_chart_version >}}"
      sourceRef:
        kind: HelmRepository
        name: capsule
      interval: 24h
  install:
    createNamespace: true
  upgrade:
    remediation:
      remediateLastFailure: true
  driftDetection:
    mode: enabled
  values:
    crds:
      install: true
    manager:
      options:
        capsuleConfiguration: default
        ignoreUserGroups:
          - oidc:administators
        users:
          - kind: Group
            name: oidc:kubernetes-users
          - kind: Group
            name: system:serviceaccounts:tenants-system
    monitoring:
      dashboards:
        enabled: true
      serviceMonitor:
        enabled: true
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: capsule
  namespace: flux-system
spec:
  type: "oci"
  interval: 12h0m0s
  url: oci://ghcr.io/projectcapsule/charts
```

## Security

[See all available Artifacts](https://github.com/orgs/projectcapsule/packages?repo_name=capsule)

### Signature

To verify artifacts you need to have [cosign installed](https://github.com/sigstore/cosign#installation). This guide assumes you are using v2.x of cosign. All of the signatures are created using [keyless signing](https://docs.sigstore.dev/cosign/verifying/verify/#keyless-verification-using-openid-connect). You can set the environment variable `COSIGN_REPOSITORY` to point to this repository. For example:

    # Docker Image
    export COSIGN_REPOSITORY=ghcr.io/projectcapsule/capsule

    # Helm Chart
    export COSIGN_REPOSITORY=ghcr.io/projectcapsule/charts/capsule

To verify the signature of the docker image, run the following command.

    COSIGN_REPOSITORY=ghcr.io/projectcapsule/charts/capsule cosign verify ghcr.io/projectcapsule/capsule:<release_tag> \
      --certificate-identity-regexp="https://github.com/projectcapsule/capsule/.github/workflows/docker-publish.yml@refs/tags/*" \
      --certificate-oidc-issuer="https://token.actions.githubusercontent.com" | jq

To verify the signature of the helm image, run the following command.

    COSIGN_REPOSITORY=ghcr.io/projectcapsule/charts/capsule cosign verify ghcr.io/projectcapsule/charts/capsule:<release_tag> \
      --certificate-identity-regexp="https://github.com/projectcapsule/capsule/.github/workflows/helm-publish.yml@refs/tags/*" \
      --certificate-oidc-issuer="https://token.actions.githubusercontent.com" | jq

### Provenance

Capsule creates and attests to the provenance of its builds using the [SLSA standard](https://slsa.dev/spec/v0.2/provenance) and meets the [SLSA Level 3](https://slsa.dev/spec/v0.1/levels) specification. The attested provenance may be verified using the cosign tool.

Verify the provenance of the docker image.

```
cosign verify-attestation --type slsaprovenance \
  --certificate-identity-regexp="https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@refs/tags/*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/projectcapsule/capsule:{{< capsule_chart_version >}} | jq .payload -r | base64 --decode | jq
```

```bash
cosign verify-attestation --type slsaprovenance \
  --certificate-identity-regexp="https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@refs/tags/*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/projectcapsule/charts/capsule:{{< capsule_chart_version >}} | jq .payload -r | base64 --decode | jq
```

### Software Bill of Materials (SBOM)

An SBOM (Software Bill of Materials) in CycloneDX JSON format is published for each release, including pre-releases. You can set the environment variable `COSIGN_REPOSITORY` to point to this repository. For example:

    # Docker Image
    export COSIGN_REPOSITORY=ghcr.io/projectcapsule/capsule

    # Helm Chart
    export COSIGN_REPOSITORY=ghcr.io/projectcapsule/charts/capsule


To inspect the SBOM of the docker image, run the following command.

    COSIGN_REPOSITORY=ghcr.io/projectcapsule/capsule cosign download sbom ghcr.io/projectcapsule/capsule:{{< capsule_chart_version >}}

To inspect the SBOM of the helm image, run the following command.

    COSIGN_REPOSITORY=ghcr.io/projectcapsule/charts/capsule cosign download sbom ghcr.io/projectcapsule/charts/capsule:{{< capsule_chart_version >}}

## Compatibility

The Kubernetes compatibility is announced for each [Release](https://github.com/projectcapsule/capsule/releases). Generally we are up to date with the latest upstream Kubernetes Version. Note that the Capsule project offers support only for the latest minor version of Kubernetes. Backwards compatibility with older versions of Kubernetes and OpenShift is offered by [vendors](/support/).
