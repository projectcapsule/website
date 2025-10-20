---
title: Installation
weight: 1
description: "Installing the Capsule Controller"
---

## Requirements

 * [Helm 3](https://github.com/helm/helm/releases) is required when installing the Capsule Operator chart. Follow Helm’s official  for installing helm on your particular operating system.
 * A Kubernetes cluster 1.16+ with following [Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/) enabled:
    * PodNodeSelector
    * LimitRanger
    * ResourceQuota
    * MutatingAdmissionWebhook
    * ValidatingAdmissionWebhook
 * A [Kubeconfig](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/) file accessing the Kubernetes cluster with cluster admin permissions.
 * [Cert-Manager](https://cert-manager.io/) is recommended but not required

## Installation

We officially only support the installation of Capsule using the Helm chart. The chart itself handles the Installation/Upgrade of needed [CustomResourceDefinitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/). The following Artifacthub repository are official:

* [Artifacthub Page (OCI)](https://artifacthub.io/packages/helm/capsule/capsule)
* [Artifacthub Page (Legacy - Best Effort)](https://artifacthub.io/packages/helm/projectcapsule/capsule)

Perform the following steps to install the capsule Operator:

1. Add repository:

        helm repo add projectcapsule https://projectcapsule.github.io/charts

2. Install Capsule:

        helm install capsule projectcapsule/capsule --version 0.10.6 -n capsule-system --create-namespace

    or (**OCI**)

        helm install capsule oci://ghcr.io/projectcapsule/charts/capsule --version 0.10.6 -n capsule-system --create-namespace

3. Show the status:

        helm status capsule -n capsule-system

4. Upgrade the Chart

        helm upgrade capsule projectcapsule/capsule -n capsule-system

    or (**OCI**)

        helm upgrade capsule oci://ghcr.io/projectcapsule/charts/capsule --version 0.10.7

5. Uninstall the Chart

        helm uninstall capsule -n capsule-system


## Considerations

Here are some key considerations to keep in mind when installing Capsule. Also check out the **[Best Practices](/docs/operating/best-practices)** for more information.

### Admission Policies

While Capsule provides a robust framework for managing multi-tenancy in Kubernetes, it does not include built-in admission policies for enforcing specific security or operational standards for all possible aspects of a Kubernetes cluster. Therefore, it is recommended to use additional tools like [Kyverno](https://kyverno.io/) to enforce admission policies that align with your organization's requirements.

[We provide policy recommendations for Kyverno here](/ecosystem/integrations/kyverno/#recommended-policies).

### Certificate Management

We recommend using [cert-manager](https://cert-manager.io/) to manage the TLS certificates for Capsule. This will ensure that your Capsule installation is secure and that the certificates are automatically renewed. Capsule requires a valid TLS certificate for it's Admission Webserver. By default Capsule reconciles it's own TLS certificate. To use cert-manager, you can set the following values:

```yaml
certManager:
  generateCertificates: true
tls:
  enableController: false
  create: false
```

### Webhooks

Capsule makes use of [webhooks for admission control](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers). Ensure that your cluster supports webhooks and that they are properly configured. The webhooks are automatically created by Capsule during installation. However some of these webhooks will cause problems when capsule is not running  (this is especially problematic in single-node clusters). Here are the webhooks you need to watch out for.

Generally we recommend to use [matchconditions](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#matching-requests-matchconditions) for all the webhooks to avoid problems when Capsule is not running. You should exclude your system critical components from the Capsule webhooks. For namespaced resources (`pods`, `services`, etc.) the webhooks all select only namespaces which are part of a Capsule Tenant. If your system critical components are not part of a Capsule Tenant, they will not be affected by the webhooks. However, if you have system critical components which are part of a Capsule Tenant, you should exclude them from the Capsule webhooks by using [matchconditions](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#matching-requests-matchconditions) as well or add more specific [namespaceselectors](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#matching-requests-namespaceselector)/[objectselectors](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#matching-requests-objectselector) to exclude them. This can also be considered to improve performance.

[Refer to the webhook values](https://artifacthub.io/packages/helm/projectcapsule/capsule#webhooks-parameters).

**The Webhooks below are the most important ones to consider.**

#### Nodes

There is a webhook which catches interactions with the Node resource. This Webhook is mainly interesting, when you make use of [Node Metadata](/docs/tenants/enforcement/#nodes). In any other case it will just case you problems. By default the webhook is enabled, but you can disable it by setting the following value:

```yaml
webhooks:
  hooks:
    nodes:
      enabled: false
```

Or you could at least consider to set the failure policy to `Ignore`:

```yaml
webhooks:
  hooks:
    nodes:
      failurePolicy: Ignore
```

If you still want to use the feature, you could execlude the kube-system namespace (or any other namespace you want to exclude) from the webhook by setting the following value:

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

Namespaces are the most important resource in Capsule. The Namespace Webhook is responsible for enforcing the Capsule Tenant boundaries. It is enabled by default and should not be disabled. However, you may change the matchConditions to execlude certain namespaces from the Capsule Tenant boundaries. For example, you can exclude the kube-system namespace by setting the following value:

```yaml
webhooks:
  hooks:
    namespaces:
      matchConditions:
      - name: 'exclude-kube-system'
        expression: '!("system:serviceaccounts:kube-system" in request.userInfo.groups)'
```

## Compatibility

The Kubernetes compatibility is announced for each [Release](https://github.com/projectcapsule/capsule/releases). Generally we are up to date with the latest upstream Kubernetes Version. Note that the Capsule project offers support only for the latest minor version of Kubernetes. Backwards compatibility with older versions of Kubernetes and OpenShift is offered by [vendors](/support/).

## GitOps

There are no specific requirements for using Capsule with GitOps tools like ArgoCD or FluxCD. You can manage Capsule resources as you would with any other Kubernetes resource.

### ArgoCD

Manifests to get you started with ArgoCD. For ArgoCD you might need to skip the validation of the `CapsuleConfiguration` resources, otherwise there might be errors on the first install:

```yaml
manager:
  options:
    annotations:
      argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
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
    targetRevision: 0.11.0
    chart: capsule
    helm:
      skipCrds: true
      valuesObject:
        crds:
          install: true
        certManager:
          generateCertificates: true
        tls:
          enableController: false
          create: false
        manager:
          options:
            annotations:
              argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
            capsuleConfiguration: default
            ignoreUserGroups:
              - oidc:administators
            capsuleUserGroups:
              - oidc:kubernetes-users
              - system:serviceaccounts:capsule-argo-addon
        webhooks:
          hooks:
            nodes:
              failurePolicy: Ignore
        serviceMonitor:
          enabled: true
          annotations:
            argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
        proxy:
          enabled: true
          webhooks:
            enabled: true
          certManager:
            generateCertificates: true
          options:
            generateCertificates: false
            oidcUsernameClaim: "email"
            extraArgs:
            - "--feature-gates=ProxyClusterScoped=true"
            - "--feature-gates=ProxyAllNamespaced=true"
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
      version: "0.10.6"
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
    certManager:
      generateCertificates: true
    tls:
      enableController: false
      create: false
    manager:
      options:
        capsuleConfiguration: default
        ignoreUserGroups:
          - oidc:administators
        capsuleUserGroups:
          - oidc:kubernetes-users
          - system:serviceaccounts:capsule-argo-addon
    webhooks:
      hooks:
        nodes:
          failurePolicy: Ignore
    serviceMonitor:
      enabled: true
    proxy:
      enabled: true
      webhooks:
        enabled: true
      certManager:
        generateCertificates: true
      options:
        generateCertificates: false
        oidcUsernameClaim: "email"
        extraArgs:
        - "--feature-gates=ProxyClusterScoped=true"
        - "--feature-gates=ProxyAllNamespaced=true"
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

To verify artifacts you need to have [cosign installed](https://github.com/sigstore/cosign#installation). This guide assumes you are using v2.x of cosign. All of the signatures are created using [keyless signing](https://docs.sigstore.dev/verifying/verify/#keyless-verification-using-openid-connect). You can set the environment variable `COSIGN_REPOSITORY` to point to this repository. For example:

    # Docker Image
    export COSIGN_REPOSITORY=ghcr.io/projectcapsule/capsule

    # Helm Chart
    export COSIGN_REPOSITORY=ghcr.io/projectcapsule/charts/capsule

To verify the signature of the docker image, run the following command. Replace `<release_tag>` with an [available release tag](https://github.com/projectcapsule/capsule/pkgs/container/capsule):

    COSIGN_REPOSITORY=ghcr.io/projectcapsule/charts/capsule cosign verify ghcr.io/projectcapsule/capsule:<release_tag> \
      --certificate-identity-regexp="https://github.com/projectcapsule/capsule/.github/workflows/docker-publish.yml@refs/tags/*" \
      --certificate-oidc-issuer="https://token.actions.githubusercontent.com" | jq

To verify the signature of the helm image, run the following command. Replace `<release_tag>` with an [available release tag](https://github.com/projectcapsule/capsule/pkgs/container/charts%2Fcapsule):

    COSIGN_REPOSITORY=ghcr.io/projectcapsule/charts/capsule cosign verify ghcr.io/projectcapsule/charts/capsule:<release_tag> \
      --certificate-identity-regexp="https://github.com/projectcapsule/capsule/.github/workflows/helm-publish.yml@refs/tags/*" \
      --certificate-oidc-issuer="https://token.actions.githubusercontent.com" | jq

### Provenance

Capsule creates and attests to the provenance of its builds using the [SLSA standard](https://slsa.dev/spec/v0.2/provenance) and meets the [SLSA Level 3](https://slsa.dev/spec/v0.1/levels) specification. The attested provenance may be verified using the cosign tool.

Verify the provenance of the docker image. Replace `<release_tag>` with an [available release tag](https://github.com/projectcapsule/capsule/pkgs/container/capsule)

```bash
cosign verify-attestation --type slsaprovenance \
  --certificate-identity-regexp="https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@refs/tags/*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/projectcapsule/capsule:<release_tag> | jq .payload -r | base64 --decode | jq
```

Verify the provenance of the helm image. Replace `<release_tag>` with an [available release tag](https://github.com/projectcapsule/capsule/pkgs/container/charts%2Fcapsule)

```bash
cosign verify-attestation --type slsaprovenance \
  --certificate-identity-regexp="https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@refs/tags/*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/projectcapsule/charts/capsule:<release_tag> | jq .payload -r | base64 --decode | jq
```

### Software Bill of Materials (SBOM)

An SBOM (Software Bill of Materials) in CycloneDX JSON format is published for each release, including pre-releases. You can set the environment variable `COSIGN_REPOSITORY` to point to this repository. For example:

    # Docker Image
    export COSIGN_REPOSITORY=ghcr.io/projectcapsule/capsule

    # Helm Chart
    export COSIGN_REPOSITORY=ghcr.io/projectcapsule/charts/capsule


To inspect the SBOM of the docker image, run the following command. Replace `<release_tag>` with an [available release tag](https://github.com/projectcapsule/capsule/pkgs/container/capsule):

    COSIGN_REPOSITORY=ghcr.io/projectcapsule/capsule cosign download sbom ghcr.io/projectcapsule/capsule:<release_tag>

To inspect the SBOM of the helm image, run the following command. Replace `<release_tag>` with an [available release tag](https://github.com/projectcapsule/capsule/pkgs/container/charts%2Fcapsule):

    COSIGN_REPOSITORY=ghcr.io/projectcapsule/charts/capsule cosign download sbom ghcr.io/projectcapsule/charts/capsule:<release_tag>
