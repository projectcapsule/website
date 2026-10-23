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

```shell
E0707 08:38:18.319041       1 leaderelection.go:452] "Error retrieving lease lock"
  err="Get \"https://10.96.0.1:443/apis/coordination.k8s.io/v1/namespaces/capsule-
  system/leases/42c733ea.clastix.capsule.io?timeout=5s\": net/http: request canceled
  (Client.Timeout exceeded while awaiting headers)" lock="capsule-
  system/42c733ea.clastix.capsule.io"
  I0707 08:38:18.442700       1 leaderelection.go:299] "Failed to renew lease"
```

Tune leader election with `manager.options.leaderElection.leaseDuration`, `manager.options.leaderElection.renewDeadline`, and `manager.options.leaderElection.retryPeriod`. Increasing these values makes Capsule more tolerant of slow or overloaded Kubernetes API servers; for example, raising `renewDeadline` also raises the leader-election client request timeout because controller-runtime uses roughly half of that value. The tradeoff is slower failover: if the active controller really dies, standby replicas will wait longer before taking leadership. Keep the ordering valid: `leaseDuration` should be greater than `renewDeadline`, and `renewDeadline` should be greater than `retryPeriod`.

```yaml
manager:
  options:
    leaderElection:
      leaseDuration: "60s"
      renewDeadline: "40s"
      retryPeriod: "5s"
```

Worst-case leader failover is slower, around 60s, if the active pod really dies. Keep `manager.options.leaderElection.leaseDuration` > `manager.options.leaderElection.renewDeadline` > `manager.options.leaderElection.retryPeriod`.

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


By default, the Capsule controller runs with the ClusterRole `cluster-admin`, which provides full access to the cluster. This is because the controller must be able to grant RoleBindings on a per-namespace basis: Kubernetes [prevents privilege escalation through RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#privilege-escalation-prevention-and-bootstrapping), so a RoleBinding referencing a ClusterRole can only be created by a subject that either already holds all permissions of that ClusterRole or holds the `bind` verb on it. For production environments we recommend configuring stricter RBAC permissions for the Capsule controller by setting the following value in the Helm chart:

```yaml
manager:
  rbac:
    strict: true
```

This replaces the `cluster-admin` binding with a ClusterRole that grants the controller only the permissions required for its own operation (`manager.rbac.minimal` is a deprecated alias for this option; both flags enable the same behavior). To satisfy the escalation prevention described above, this ClusterRole contains the narrow `bind` verb on the ClusterRoles listed in `manager.rbac.bindableClusterRoles` (default: `admin`) plus the ClusterRoles managed by Capsule itself (the `manager.options.rbac` provisioner, deleter, `administrationClusterRoles` and `promotionClusterRoles`), which are always bindable. With default values this renders as:

```yaml
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["clusterroles"]
  resourceNames: ["admin", "capsule-namespace-deleter", "capsule-namespace-provisioner"]
  verbs: ["bind"]
```

Tenant owner RoleBindings for the default ClusterRoles therefore work out of the box, without the controller inheriting all of `admin`'s permissions.

{{% alert title="Chart versions v0.13.11 and earlier" color="warning" %}}
On older chart versions strict mode is only enabled via `manager.rbac.minimal: true` (`manager.rbac.strict` had no effect there), and the controller ClusterRole includes neither the `bind` rule above nor `create` on NetworkPolicies, which [GlobalTenantResource](/docs/replications/global/) propagation requires. Add both via Helm values:

    manager:
      rbac:
        minimal: true
        clusterRole:
          extraResources:
            - apiGroups: ["rbac.authorization.k8s.io"]
              resources: ["clusterroles"]
              resourceNames: ["admin", "capsule-namespace-provisioner", "capsule-namespace-deleter"]
              verbs: ["bind"]
            - apiGroups: ["networking.k8s.io"]
              resources: ["networkpolicies"]
              verbs: ["get", "list", "watch", "create", "update", "patch", "delete", "deletecollection"]

Or aggregate the full `admin` ClusterRole to the controller — note that the controller then holds all of `admin`'s permissions:

    kubectl label clusterrole admin projectcapsule.dev/aggregate-to-controller=true
{{% /alert %}}

Any further ClusterRole that is assigned to [Tenant owners](/docs/tenants/permissions/#owner-roles) or used for [additional RoleBindings](/docs/tenants/permissions/#strict) needs the same treatment. This applies only to ClusterRoles that are not managed by Capsule (see [Configuration](/docs/operating/setup/configuration/#rbac)). The narrowest option is adding it to `manager.rbac.bindableClusterRoles` — note that the list replaces the default, so keep `admin` in it:

```yaml
manager:
  rbac:
    strict: true
    bindableClusterRoles:
      - admin
      - prometheus-servicemonitors-viewer
```

Alternatively, you can aggregate the permissions of further ClusterRoles into the controller. The ClusterRole for the controller aggregates all ClusterRoles carrying one of the following labels:

* `projectcapsule.dev/aggregate-to-controller: "true"`
* `projectcapsule.dev/aggregate-to-controller-instance: {{ .Release.Name }}`

```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: prometheus-servicemonitors-viewer
  labels:
    projectcapsule.dev/aggregate-to-controller: "true"
rules:
...
```

This is broader than `bind` — the controller then actually holds these permissions. It is required whenever the controller must exercise the permissions itself, for example when replicating resources via [GlobalTenantResources](/docs/replications/global/) without impersonation.

You can also directly grant arbitrary additional permissions via Helm values:

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

Before you enable strict mode, you must implement the required permissions for your use case. Depending on which features you are using, you may need to take manual action, for example:

* [Migrate additional RoleBindings](/docs/tenants/permissions/#strict)
* [Grant RBAC to the `TenantResources` impersonation ServiceAccount](/docs/replications/tenant/#impersonation)
* [Migrate `GlobalTenantResources` to use impersonation](/docs/replications/global/#impersonation)

### Admission Policies

While Capsule provides a robust framework for managing multi-tenancy in Kubernetes, it does not include built-in admission policies for enforcing specific security or operational standards for all possible aspects of a Kubernetes cluster.  [We provide additional policy recommendations here](/docs/operating/best-practices/admission-policies.md).

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

Capsule uses [admission webhooks](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/) to enforce tenant boundaries and apply namespace rules. If a matching webhook has `failurePolicy: Fail`, requests can be rejected while Capsule is unavailable. Excluding the operations needed to recover your cluster is especially important in single-node clusters and when admission controllers depend on each other.

Many of Capsule's namespaced resource webhooks already select tenant namespaces. Review the [webhook values](https://artifacthub.io/packages/helm/projectcapsule/capsule#webhooks-parameters) for the enabled hooks, including hooks for cluster-scoped resources. The following conditions provide explicit exemptions for selected system workloads and trusted controllers.

#### System-critical Components

Two different kinds of requests need consideration: **operations on resources inside system namespaces**, and **operations performed by trusted system service accounts**. Use both conditions below when you want to keep system workloads running and allow those controllers to manage resources elsewhere in the cluster while Capsule is unavailable. They address different requests; a service-account exemption alone does not cover every operation involved in creating and scheduling a Pod.

```yaml
webhooks:
  matchConditions:
    # Skip namespaced resources in these namespaces, regardless of the caller.
    # Keep the Namespace objects themselves subject to ownership checks.
    - name: exclude-system-namespaced-resources
      expression: >-
        !has(request.namespace) ||
        !(request.namespace in ["kube-system", "kube-public", "kyverno-system"]) ||
        (request.resource.group == "" &&
         request.resource.resource == "namespaces")

    # Skip requests from service accounts in these trusted namespaces,
    # including requests for cluster-scoped resources or other namespaces.
    - name: exclude-trusted-system-serviceaccounts
      expression: >-
        !has(request.userInfo.username) ||
        !["kube-system", "kube-public", "kyverno-system"].exists(ns,
          request.userInfo.username.startsWith("system:serviceaccount:" + ns + ":")
        )
```

These values apply to all enabled Capsule mutating and validating webhooks. Choose the namespaces for your installation and update both lists. Adding another namespace only requires another list entry, rather than a separate expression for every namespace.

Kubernetes evaluates [match conditions](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#matching-requests-matchconditions) before calling the webhook. All conditions must be `true` for a request to match; **any condition returning `false` skips that webhook**. The two exemptions therefore work independently: a request can be skipped because of its target namespace **or** its authenticated caller. A skipped request does not depend on the webhook server being available.

##### Why the target namespace condition is needed

The first condition excludes namespaced resources such as Pods, Services, ConfigMaps, and requests to namespaced subresources such as `pods/binding`. It applies regardless of who submits the request. This covers a human creating a system Pod, a controller creating a replacement Pod, the scheduler binding it to a node, and a kubelet updating its status, wherever the resource and operation rules for that webhook would otherwise match.

Those requests do not necessarily come from a service account in the Pod's namespace. For example, the scheduler commonly authenticates as `system:kube-scheduler`, and a human creating a Pod authenticates as that human. The Pod's `spec.serviceAccountName` describes the identity its containers will use; it does not change the caller submitting the Pod or scheduling request. An exemption for service accounts in `kube-system` therefore cannot, by itself, keep all Pod operations in `kube-system` independent of Capsule.

This condition prevents the configured Capsule webhooks from blocking those namespaced operations. Kubernetes RBAC, other admission controllers, node capacity, taints, and scheduling constraints still apply. It also means Capsule's validation and mutation are skipped for **every caller** acting on those namespaced resources, so reserve these exclusions for namespaces where that policy exemption is intended.

##### Why the service-account condition is needed

The second condition checks the authenticated API caller. Kubernetes [service-account usernames](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#service-account-tokens) have the form `system:serviceaccount:<namespace>:<name>`. The prefix includes the colon after the namespace, so `kube-system-other` does not accidentally match `kube-system`.

A trusted controller may create or update a Namespace, ClusterRole, or another cluster-scoped resource. Such a resource has no target namespace, even when the controller runs in `kube-system`. A controller can also manage resources in application namespaces. The target namespace condition keeps those requests in scope; the caller condition provides the additional exemption needed for that controller's work to continue without Capsule.

This is a broad trust decision: **every service account in a listed namespace bypasses the configured webhooks for all otherwise matching requests, including requests outside its own namespace**. Only include namespaces whose service accounts and credentials are controlled by trusted administrators. Anyone able to run a Pod as one of those service accounts may obtain its identity. For tighter control, replace the prefix test with a list of exact service-account usernames. This condition does not exempt certificate identities such as `system:kube-scheduler` or `system:kube-controller-manager`; the target namespace condition already covers their namespaced operations in the selected namespaces.

If your only goal is to exclude Pods and other namespaced resources in these namespaces, the first condition is sufficient. Add the caller condition when trusted controllers also need the wider exemption for cluster-scoped resources or resources in other namespaces.

##### Preserve Namespace ownership checks

A Namespace object such as `Namespace/kube-system` is cluster-scoped. Updating it is different from updating a Pod **inside** `kube-system`. The final clause in the first condition deliberately returns `true` for core Namespace resources, keeping them eligible for admission. The `has(...)` guards handle admission requests where optional namespace or username fields are absent.

Do not add an exemption based on a Namespace object's name. A blanket [namespaceSelector](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#matching-requests-namespaceselector) exclusion is also unsuitable for the Namespace ownership webhook: Kubernetes evaluates that selector against a Namespace object's own labels. Excluding the system Namespace objects would let callers with Kubernetes RBAC permission to update them bypass Capsule's ownership checks. Capsule installations can rely on those checks to constrain tenant owners who have broad Namespace RBAC permissions.

No additional `namespaceSelector` exclusion is needed for the CEL conditions above. The intended behavior is:

| Request | Effect of these conditions |
| --- | --- |
| An ordinary user creates a Pod in `kube-system` | The target namespace condition skips the webhook; Kubernetes RBAC must still permit the operation. |
| The scheduler binds a Pod in `kyverno-system` | The target namespace condition skips the webhook, even though the caller is not a service account from that namespace. |
| An ordinary tenant owner updates `Namespace/kube-system` | Neither exemption applies; Capsule's Namespace ownership checks remain in scope. |
| A trusted service account from `kube-system` creates a Namespace or updates a resource in an application namespace | The caller condition skips the webhook. |
| An ordinary tenant owner updates a resource in a tenant application namespace | Neither exemption applies; the normal webhook selection and admission checks apply. |

Global, mutating/validating, and per-hook match conditions are combined. Existing selectors and resource rules also continue to determine which requests can reach a webhook. If you use the per-hook `opts.capsuleUsers` or `opts.administrators` settings, review their interaction with explicit conditions: Capsule uses explicitly configured `matchConditions` instead of generating the identity condition from those options.

##### Kyverno Helm values

When Kyverno also needs these exemptions, configure its chart separately under `config.matchConditions`. Capsule's `webhooks.matchConditions` values do not configure Kyverno. The example below uses the same three namespaces and the same two conditions.

Kyverno's chart also has default namespace exclusions. To keep Namespace objects subject to policy for ordinary callers, remove the overlapping blanket exclusions and express the intended exemptions through CEL. In the [Kyverno chart values](https://github.com/kyverno/kyverno/blob/kyverno-chart-3.9.2/charts/kyverno/values.yaml), `excludeKyvernoNamespace: false` disables the automatic exclusion of Kyverno's installation namespace. Setting `matchExpressions: []` replaces the default namespace selector expressions; an empty map can leave defaults in place when Helm merges values. Despite its name, `resourceFiltersExcludeNamespaces` removes those namespaces from the chart's default resource filters; it does not add a new namespace exclusion.

```yaml
config:
  # Remove blanket exclusions that would also skip Namespace objects.
  excludeKyvernoNamespace: false
  webhooks:
    namespaceSelector:
      matchExpressions: []
  resourceFiltersExcludeNamespaces:
    - kube-system
    - kube-public
    - kyverno-system

  matchConditions:
    # Exempt system workloads without excluding their Namespace objects.
    - name: exclude-system-namespaced-resources
      expression: >-
        !has(request.namespace) ||
        !(request.namespace in ["kube-system", "kube-public", "kyverno-system"]) ||
        (request.resource.group == "" &&
         request.resource.resource == "namespaces")

    # Exempt trusted controllers, including their cluster-scoped operations.
    - name: exclude-trusted-system-serviceaccounts
      expression: >-
        !has(request.userInfo.username) ||
        !["kube-system", "kube-public", "kyverno-system"].exists(ns,
          request.userInfo.username.startsWith("system:serviceaccount:" + ns + ":")
        )
```

The CEL conditions prevent matching requests from being sent to Kyverno. Resource filters alone are insufficient for this availability goal because they are evaluated inside Kyverno after a webhook request reaches it. Other default resource filters remain in place. Review any additional selectors, filters, and caller exclusions in your installed Kyverno version; these values do not remove unrelated exclusions or configure background policy scans.

If Capsule runs in `capsule-system` and Kyverno must also exempt its workloads and service accounts, add `capsule-system` to both CEL namespace lists and to `resourceFiltersExcludeNamespaces` in the Kyverno values. Apply the same trust assessment before exempting that namespace.

#### Nodes

The Node webhook is relevant when you use [Node metadata](/docs/tenants/metadata/#nodes). It is **disabled** by default. Enable it only when you need that enforcement:

```yaml
webhooks:
  hooks:
    nodes:
      enabled: true
```

To allow matching Node operations to continue when the webhook cannot be reached, you can set its failure policy to `Ignore`. This also means those operations proceed without Capsule's Node validation during an outage:

```yaml
webhooks:
  hooks:
    nodes:
      failurePolicy: Ignore
```

Nodes are cluster-scoped, so the target namespace condition above does not exempt them. The global service-account condition does exempt requests made by trusted service accounts, but kubelets commonly authenticate in the `system:nodes` group. If you intentionally want to bypass Capsule's Node checks for kubelets, use a caller condition on this hook:

```yaml
webhooks:
  hooks:
    nodes:
      matchConditions:
        - name: exclude-kubelet-requests
          expression: >-
            !has(request.userInfo.groups) ||
            !("system:nodes" in request.userInfo.groups)
```

This exempts kubelet callers from this Node webhook, regardless of which Node they target. It does not exclude a namespace, and it bypasses the Node metadata enforcement that would otherwise apply to those callers. Prefer this scoped configuration over a global exemption for all node identities.

#### Namespaces

The Namespace webhook enforces Capsule Tenant boundaries. It is enabled by default and should remain enabled. The global conditions above keep Namespace objects in scope for ordinary callers while exempting trusted service accounts. Exempting resources **inside** a system namespace must not become an exemption for an ordinary tenant owner's updates to the Namespace object itself.

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
