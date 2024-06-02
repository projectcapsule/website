---
title: Monitoring
weight: 5
description: "Monitoring Capsule Controller and Tenants"
---

The Capsule dashboard allows you to track the health and performance of Capsule manager and tenants, with particular attention to resources saturation, server responses, and latencies. Prometheus and Grafana are requirements for monitoring Capsule.

## Quickstart


##  Metrics

### Controller



### Proxy 



### Custom

You can gather more information based on the status of the tenants. These can be scrapped via [Kube-State-Metrics CustomResourcesState Metrics](https://github.com/kubernetes/kube-state-metrics/blob/main/docs/customresourcestate-metrics.md). With these you have the possibility to create custom metrics based on the status of the tenants.

Here as an example with the [kube-prometheus-stack chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack), set the following values:

```yaml
kube-state-metrics:
  rbac:
    extraRules:
      - apiGroups: [ "capsule.clastix.io" ]
        resources: ["tenants"]
        verbs: [ "list", "watch" ]
  customResourceState:
    enabled: true
    config:
      spec:
        resources:
          - groupVersionKind:
              group: capsule.clastix.io
              kind: "Tenant"
              version: "v1beta2"
            labelsFromPath:
              name: [metadata, name]
            metrics:
              - name: "tenant_size"
                help: "Count of namespaces in the tenant"
                each:
                  type: Gauge
                  gauge:
                    path: [status, size]
                commonLabels:
                  custom_metric: "yes"
                labelsFromPath:
                  capsule_tenant: [metadata, name]
                  kind: [ kind ]
              - name: "tenant_state"
                help: "The operational state of the Tenant"
                each:
                  type: StateSet
                  stateSet:
                    labelName: state
                    path: [status, state]
                    list: [Active, Cordoned]
                commonLabels:
                  custom_metric: "yes"
                labelsFromPath:
                  capsule_tenant: [metadata, name]
                  kind: [ kind ]
              - name: "tenant_namespaces_info"
                help: "Namespaces of a Tenant"
                each:
                  type: Info
                  info:
                    path: [status, namespaces]
                    labelsFromPath:
                      tenant_namespace: []
                commonLabels:
                  custom_metric: "yes"
                labelsFromPath:
                  capsule_tenant: [metadata, name]
                  kind: [ kind ]
```

This example creates three custom metrics:

- `tenant_size` is a gauge that counts the number of namespaces in the tenant.
- `tenant_state` is a state set that shows the operational state of the tenant.
- `tenant_namespaces_info` is an info metric that shows the namespaces of the tenant.
