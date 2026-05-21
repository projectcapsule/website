---
title: Monitoring
weight: 5
description: "Monitoring Capsule Items and Tenants"
---

The Capsule dashboard allows you to track the health and performance of Capsule manager and tenants, with particular attention to resources saturation, server responses, and latencies. Prometheus and Grafana are requirements for monitoring Capsule.

## Tenants

Instrumentation for [Tenants](../tenants/).

### Metrics

The following Metrics are exposed and can be used for monitoring:

```shell
# HELP capsule_tenant_condition Provides per tenant condition status for each condition
# TYPE capsule_tenant_condition gauge
capsule_tenant_condition{condition="Cordoned",tenant="solar"} 0
capsule_tenant_condition{condition="Ready",tenant="solar"} 1


# HELP capsule_tenant_namespace_condition Provides per namespace within a tenant condition status for each condition
# TYPE capsule_tenant_namespace_condition gauge
capsule_tenant_namespace_condition{condition="Cordoned",target_namespace="earth",tenant="solar"} 0
capsule_tenant_namespace_condition{condition="Cordoned",target_namespace="fire",tenant="solar"} 0
capsule_tenant_namespace_condition{condition="Cordoned",target_namespace="foild",tenant="solar"} 0
capsule_tenant_namespace_condition{condition="Cordoned",target_namespace="green",tenant="solar"} 0
capsule_tenant_namespace_condition{condition="Cordoned",target_namespace="solar",tenant="solar"} 0
capsule_tenant_namespace_condition{condition="Cordoned",target_namespace="wind",tenant="solar"} 0
capsule_tenant_namespace_condition{condition="Ready",target_namespace="earth",tenant="solar"} 1
capsule_tenant_namespace_condition{condition="Ready",target_namespace="fire",tenant="solar"} 1
capsule_tenant_namespace_condition{condition="Ready",target_namespace="foild",tenant="solar"} 1
capsule_tenant_namespace_condition{condition="Ready",target_namespace="green",tenant="solar"} 1
capsule_tenant_namespace_condition{condition="Ready",target_namespace="solar",tenant="solar"} 1
capsule_tenant_namespace_condition{condition="Ready",target_namespace="wind",tenant="solar"} 1

# HELP capsule_tenant_namespace_count Total number of namespaces currently owned by the tenant
# TYPE capsule_tenant_namespace_count gauge
capsule_tenant_namespace_count{tenant="solar"} 6

# HELP capsule_tenant_namespace_relationship Mapping metric showing namespace to tenant relationships
# TYPE capsule_tenant_namespace_relationship gauge
capsule_tenant_namespace_relationship{target_namespace="earth",tenant="solar"} 1
capsule_tenant_namespace_relationship{target_namespace="fire",tenant="solar"} 1
capsule_tenant_namespace_relationship{target_namespace="soil",tenant="solar"} 1
capsule_tenant_namespace_relationship{target_namespace="green",tenant="solar"} 1
capsule_tenant_namespace_relationship{target_namespace="solar",tenant="solar"} 1
capsule_tenant_namespace_relationship{target_namespace="wind",tenant="solar"} 1

# HELP capsule_tenant_resource_limit Current resource limit for a given resource in a tenant
# TYPE capsule_tenant_resource_limit gauge
capsule_tenant_resource_limit{resource="limits.cpu",resourcequotaindex="0",tenant="solar"} 2
capsule_tenant_resource_limit{resource="limits.memory",resourcequotaindex="0",tenant="solar"} 2.147483648e+09
capsule_tenant_resource_limit{resource="pods",resourcequotaindex="1",tenant="solar"} 7
capsule_tenant_resource_limit{resource="requests.cpu",resourcequotaindex="0",tenant="solar"} 2
capsule_tenant_resource_limit{resource="requests.memory",resourcequotaindex="0",tenant="solar"} 2.147483648e+09

# HELP capsule_tenant_resource_usage Current resource usage for a given resource in a tenant
# TYPE capsule_tenant_resource_usage gauge
capsule_tenant_resource_usage{resource="limits.cpu",resourcequotaindex="0",tenant="solar"} 0
capsule_tenant_resource_usage{resource="limits.memory",resourcequotaindex="0",tenant="solar"} 0
capsule_tenant_resource_usage{resource="namespaces",resourcequotaindex="",tenant="solar"} 2
capsule_tenant_resource_usage{resource="pods",resourcequotaindex="1",tenant="solar"} 0
capsule_tenant_resource_usage{resource="requests.cpu",resourcequotaindex="0",tenant="solar"} 0
capsule_tenant_resource_usage{resource="requests.memory",resourcequotaindex="0",tenant="solar"} 0
```

## Custom Metrics

You can gather more information based on the status of the tenants. These can be scrapped via [Kube-State-Metrics CustomResourcesState Metrics](https://github.com/kubernetes/kube-state-metrics/blob/main/docs/metrics/extend/customresourcestate-metrics.md). With these you have the possibility to create custom metrics based on the status of the tenants.

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
