---
title: Tekton
describtion: Capsule interation with Tekton
---

With Capsule extension for [Lens](https://github.com/lensapp/lens), a cluster administrator can easily manage from a single pane of glass all resources of a Kubernetes cluster, including all the Tenants created through the Capsule Operator.

## Prerequisites 

Tekton must be already installed on your cluster, if that's not the case consult the documentation here:

  - [Tekton](https://tekton.dev/docs/installation/)

## Cluster Scoped Permissions





## Tekton Dashboard

Now for the enduser experience we are going to deploy the tekton dashboard. When using oauth2-proxy we can deploy one single dashboard, which can be used for all tenants. Refer to the following guide to setup the dashboard with the oauth2-proxy:

  - [Tekton Dashboard](https://github.com/tektoncd/dashboard/blob/main/docs/walkthrough/walkthrough-oauth2-proxy.md)

Once that is done, we need to make small adjustments to the `tekton-dashboard` service account. 

**kustomization.yaml**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml
patches:
  # Adjust the service for the capsule-proxy according to your installation
  # The used values are compatbile with the default installation values
  - target:
      version: v1
      kind: Deployment
      name: tekton-dashboard
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/env/-
        value:
          name: KUBERNETES_SERVICE_HOST
          value: "capsule-proxy.capsule-system.svc"
      - op: add
        path: /spec/template/spec/containers/0/env/-
        value:
          name: KUBERNETES_SERVICE_PORT
          value: "9001"

  # Adjust the CA certificate for the capsule-proxy according to your installation
  - target:
      version: v1
      kind: Deployment
      name: tekton-dashboard
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/volumeMounts
        value: []
      - op: add
        path: /spec/template/spec/containers/0/volumeMounts/-
        value:
          mountPath: "/var/run/secrets/kubernetes.io/serviceaccount"
          name: token-ca
      - op: add
        path: /spec/template/spec/volumes
        value: []
      - op: add
        path: /spec/template/spec/volumes/-
        value:
          name: token-ca
          projected:
            sources:
              - serviceAccountToken:
                  expirationSeconds: 86400
                  path: token
              - secret:
                  name: capsule-proxy
                  items:
                    - key: ca
                      path: ca.crt

```

This patch assumes there's a secret called `capsule-proxy` with the CA certificate for the Capsule Proxy URL. 


Apply the given kustomization:


  

extraEnv:
  - name: KUBERNETES_SERVICE_HOST
    value: '${CAPSULE_PROXY_URL}'
  - name: KUBERNETES_SERVICE_PORT
    value: '${CAPSULE_PROXY_PORT}'



### Tekton Operator 

When using the [Tekton Operator](https://tekton.dev/docs/operator/), you need to add the following to the `TektonConfig`:

```yaml
apiVersion: operator.tekton.dev/v1alpha1
kind: TektonConfig
metadata:
  name: config
spec:
  dashboard:
    readonly: false
    options:
      disabled: false
      deployments:
        tekton-dashboard:
          spec:
            template:
              spec:
                volumes:
                  - name: token-ca
                    projected:
                      sources:
                        - serviceAccountToken:
                            expirationSeconds: 86400
                            path: token
                        - secret:
                            name: capsule-proxy
                            items:
                              - key: ca
                                path: ca.crt
                containers:
                  - name: tekton-dashboard
                    volumeMounts:
                      - mountPath: "/var/run/secrets/kubernetes.io/serviceaccount"
                        name: token-ca
                    env:
                      - name: KUBERNETES_SERVICE_HOST
                        value: "capsule-proxy.capsule-system.svc"
                      - name: KUBERNETES_SERVICE_PORT
                        value: "9001"
```  
  
See for reference the [options spec](https://tekton.dev/docs/operator/tektonconfig/#additional-fields-as-options)