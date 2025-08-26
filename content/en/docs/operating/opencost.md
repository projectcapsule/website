---
title: OpenCost Integration
weight: 5
description: "OpenCost Integration for Tenants"
---
This guide explains how to integrate OpenCost with Capsule to provide cost visibility and chargeback/showback per Tenant. 
We can group workloads into Tenants by annotating Namespaces (e.g., `opencost.projectcapsule.dev/tenant: {{ tenant.name }}`). 
OpenCost can use this annotation to aggregate costs, enabling accurate cost allocation across clusters, nodes, namespaces, controllerKinds, controllers, services, pods, containers for each Tenant.
# Requirements
- [Capsule](/docs/operating/setup/installation/) v0.10.8 or later
- [Prometheus Operator](https://prometheus-operator.dev/docs/getting-started/installation/)
- [Prometheus](https://opencost.io/docs/installation/prometheus)
- [OpenCost](https://opencost.io/docs/installation/helm)
# Installation
## Capsule
1. Create tenant with `spec.namespaceOptions.additionalMetadataList`
    ```bash
    kubectl create -f - << EOF
    apiVersion: capsule.clastix.io/v1beta2
    kind: Tenant
    metadata:
      name: solar
    spec:
      namespaceOptions:
        additionalMetadataList:
        - annotations:
            opencost.projectcapsule.dev/tenant: "{{ tenant.name }}"
      applyOpenCostMetadata: false
      owners:
      - name: alice
        kind: User
    EOF
    ```
## OpenCost
1. Create basic OpenCost values file. `emitNamespaceAnnotations: true` is mandatory as we are going to aggregate costs based on Capsule annotation.
    ```yaml
        opencost:
        prometheus:
        internal:
        namespaceName: prometheus-system
        serviceName: prometheus-server
        port: 80
        
        dataRetention:
        dailyResolutionDays: 30  # default: 15
        
        exporter:
        defaultClusterId: kind-opencost-capsule
        replicas: 1
        resources:
        requests:
        cpu: "10m"
        memory: "55Mi"
        limits:
        memory: "1Gi"
        persistence:
        enabled: false
        
        metrics:
        kubeStateMetrics:
        emitNamespaceAnnotations: true
        emitPodAnnotations: true
        emitKsmV1Metrics: false
        emitKsmV1MetricsOnly: false
        serviceMonitor:
        enabled: true
        relabelings:
        - sourceLabels: [__meta_kubernetes_namespace]
        targetLabel: kubernetes_namespace
          - sourceLabels: [__meta_kubernetes_pod_name]
          targetLabel: pod
          additionalLabels:
          release: prometheus
    ```
2. Install OpenCost with the values above
    ```bash
    helm install opencost opencost-charts/opencost --namespace opencost --create-namespace -f values.yaml
    ```
## Fetch data from OpenCost
{{% alert title="Note!" color=warning %}}
Aggregation is only possible via the API. There is no option to aggregate using the UI.
{{% /alert %}}
1. Port-forward 
    ```bash
    kubectl -n opencost port-forward deployment/opencost 9003 9090
    ```
2. Query the API
    - Aggregate on namespace
        ```bash
        curl -G http://localhost:9003/allocation \
          -d window=1h \
          -d aggregate=namespace,annotation:opencost_projectcapsule_dev_tenant \
          -d resolution=1h
        ```
    - Aggregate on pod
        ```bash
        curl -G http://localhost:9003/allocation \
          -d window=1h \
          -d aggregate=pod,annotation:opencost_projectcapsule_dev_tenant \
          -d resolution=1h
        ```
   - Aggregate on deployment
       ```bash
       curl -G http://localhost:9003/allocation \
         -d window=1h \
         -d aggregate=deployment,annotation:opencost_projectcapsule_dev_tenant \
         -d resolution=1h
       ```