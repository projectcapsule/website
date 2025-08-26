---
title: OpenCost Integration
weight: 5
description: "OpenCost Integration for Tenants"
---
This guide explains how to integrate OpenCost with Capsule to provide cost visibility and chargeback/showback per tenant.
You can group workloads into tenants by annotating namespaces (for example, `opencost.projectcapsule.dev/tenant: {{ tenant.name }}`).
OpenCost can use this annotation to aggregate costs, enabling accurate cost allocation across clusters, nodes, namespaces, controller kinds, controllers, services, pods, and containers for each tenant.

# Prerequisites
- [Capsule](/docs/operating/setup/installation/) v0.10.8 or later
- [Prometheus Operator](https://prometheus-operator.dev/docs/getting-started/installation/)
- [Prometheus](https://opencost.io/docs/installation/prometheus)
- [OpenCost](https://opencost.io/docs/installation/helm)

# Installation

## Capsule
1. Create a tenant with spec.namespaceOptions.additionalMetadataList:
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
      owners:
      - name: alice
        kind: User
    EOF
    ```

## OpenCost
1. Create a basic OpenCost values file. Set emitNamespaceAnnotations: true because aggregation is based on the Capsule annotation.
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
          additionalLabels:
            release: prometheus
    ```
2. Install OpenCost with the values above:
    ```bash
    helm install opencost opencost-charts/opencost --namespace opencost --create-namespace -f values.yaml
    ```

# Fetch data from OpenCost
{{% alert title="Note!" color=warning %}}
Aggregation is only possible via the API. There is no option to aggregate using the UI.
{{% /alert %}}

1. Port-forward:
    ```bash
    kubectl -n opencost port-forward deployment/opencost 9003:9003 9090:9090
    ```
2. Query the API:
    - Aggregate by namespace:
        ```bash
        curl -G http://localhost:9003/allocation \
          -d window=1h \
          -d aggregate=namespace,annotation:opencost_projectcapsule_dev_tenant \
          -d resolution=1h
        ```
    - Aggregate by pod:
        ```bash
        curl -G http://localhost:9003/allocation \
          -d window=1h \
          -d aggregate=pod,annotation:opencost_projectcapsule_dev_tenant \
          -d resolution=1h
        ```
    - Aggregate by deployment:
        ```bash
        curl -G http://localhost:9003/allocation \
          -d window=1h \
          -d aggregate=deployment,annotation:opencost_projectcapsule_dev_tenant \
          -d resolution=1h
        ```