---
title: Monitoring
weight: 5
description: "Monitoring Capsule Items and Tenants"
---

The Capsule dashboard allows you to track the health and performance of Capsule manager and tenants, with particular attention to resources saturation, server responses, and latencies. Prometheus and Grafana are requirements for monitoring Capsule.

## ResourcePools

Instrumentation for [ResourcePools](../resourcepools/).

### Dashboards

Dashboards can be deployed via helm-chart, enable the following values:

```yaml
monitoring:
  dashboards:
    enabled: true
```

#### Capsule / ResourcePools

Dashboard which grants a detailed overview over the ResourcePools

![Resourcepool Dashboard](/images/content/monitoring/dashboard-resourcepools-1.png)

---

### Rules

Example rules to give you some idea, what's possible.

1. Alert on [ResourcePools](../resourcepools/) usage
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: resourcepool-usage-alert
spec:
groups:
  - name: capsule-pool-usage.rules
    rules:
      - alert: CapsulePoolHighUsageWarning
        expr: |
          capsule_pool_usage_percentage > 90
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: High resource usage in Resourcepool
          description: |
            Resource {{ $labels.resource }} in pool {{ $labels.pool }} is at {{ $value }}% usage for the last 10 minutes.

      - alert: CapsulePoolHighUsageCritical
        expr: |
          capsule_pool_usage_percentage > 95
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: Critical resource usage in Resourcepool
          description: |
            Resource {{ $labels.resource }} in pool {{ $labels.pool }} has exceeded 95% usage for the last 10 minutes.
```

---

### Metrics

The following Metrics are exposed and can be used for monitoring:

```shell
# HELP capsule_claim_condition The current condition status of a claim.
# TYPE capsule_claim_condition gauge
capsule_claim_condition{condition="Bound",name="compute",pool="solar-compute",reason="Succeeded",target_namespace="solar-prod"} 1
capsule_claim_condition{condition="Bound",name="compute-10",pool="solar-compute",reason="PoolExhausted",target_namespace="solar-prod"} 0
capsule_claim_condition{condition="Bound",name="compute-2",pool="solar-compute",reason="Succeeded",target_namespace="solar-prod"} 1
capsule_claim_condition{condition="Bound",name="compute-3",pool="solar-compute",reason="Succeeded",target_namespace="solar-prod"} 1
capsule_claim_condition{condition="Bound",name="compute-4",pool="solar-compute",reason="Succeeded",target_namespace="solar-test"} 1
capsule_claim_condition{condition="Bound",name="compute-5",pool="solar-compute",reason="PoolExhausted",target_namespace="solar-test"} 0
capsule_claim_condition{condition="Bound",name="compute-6",pool="solar-compute",reason="PoolExhausted",target_namespace="solar-test"} 0
capsule_claim_condition{condition="Bound",name="pods",pool="solar-size",reason="Succeeded",target_namespace="solar-test"} 1

# HELP capsule_claim_resource The given amount of resources from the claim
# TYPE capsule_claim_resource gauge
capsule_claim_resource{name="compute",resource="limits.cpu",target_namespace="solar-prod"} 0.375
capsule_claim_resource{name="compute",resource="limits.memory",target_namespace="solar-prod"} 4.02653184e+08
capsule_claim_resource{name="compute",resource="requests.cpu",target_namespace="solar-prod"} 0.375
capsule_claim_resource{name="compute",resource="requests.memory",target_namespace="solar-prod"} 4.02653184e+08
capsule_claim_resource{name="compute-10",resource="limits.memory",target_namespace="solar-prod"} 1.073741824e+10
capsule_claim_resource{name="compute-2",resource="limits.cpu",target_namespace="solar-prod"} 0.5
capsule_claim_resource{name="compute-2",resource="limits.memory",target_namespace="solar-prod"} 5.36870912e+08
capsule_claim_resource{name="compute-2",resource="requests.cpu",target_namespace="solar-prod"} 0.5
capsule_claim_resource{name="compute-2",resource="requests.memory",target_namespace="solar-prod"} 5.36870912e+08
capsule_claim_resource{name="compute-3",resource="requests.cpu",target_namespace="solar-prod"} 0.5
capsule_claim_resource{name="compute-4",resource="requests.cpu",target_namespace="solar-test"} 0.5
capsule_claim_resource{name="compute-5",resource="requests.cpu",target_namespace="solar-test"} 0.5
capsule_claim_resource{name="compute-6",resource="requests.cpu",target_namespace="solar-test"} 5
capsule_claim_resource{name="pods",resource="pods",target_namespace="solar-test"} 3

# HELP capsule_pool_available Current resource availability for a given resource in a resource pool
# TYPE capsule_pool_available gauge
capsule_pool_available{pool="solar-compute",resource="limits.cpu"} 1.125
capsule_pool_available{pool="solar-compute",resource="limits.memory"} 1.207959552e+09
capsule_pool_available{pool="solar-compute",resource="requests.cpu"} 0.125
capsule_pool_available{pool="solar-compute",resource="requests.memory"} 1.207959552e+09
capsule_pool_available{pool="solar-size",resource="pods"} 4

# HELP capsule_pool_exhaustion Resources become exhausted, when there's not enough available for all claims and the claims get queued
# TYPE capsule_pool_exhaustion gauge
capsule_pool_exhaustion{pool="solar-compute",resource="limits.memory"} 1.073741824e+10
capsule_pool_exhaustion{pool="solar-compute",resource="requests.cpu"} 5.5

# HELP capsule_pool_exhaustion_percentage Resources become exhausted, when there's not enough available for all claims and the claims get queued (Percentage)
# TYPE capsule_pool_exhaustion_percentage gauge
capsule_pool_exhaustion_percentage{pool="solar-compute",resource="limits.memory"} 788.8888888888889
capsule_pool_exhaustion_percentage{pool="solar-compute",resource="requests.cpu"} 4300

# HELP capsule_pool_limit Current resource limit for a given resource in a resource pool
# TYPE capsule_pool_limit gauge
capsule_pool_limit{pool="solar-compute",resource="limits.cpu"} 2
capsule_pool_limit{pool="solar-compute",resource="limits.memory"} 2.147483648e+09
capsule_pool_limit{pool="solar-compute",resource="requests.cpu"} 2
capsule_pool_limit{pool="solar-compute",resource="requests.memory"} 2.147483648e+09
capsule_pool_limit{pool="solar-size",resource="pods"} 7

# HELP capsule_pool_namespace_usage Current resources claimed on namespace basis for a given resource in a resource pool for a specific namespace
# TYPE capsule_pool_namespace_usage gauge
capsule_pool_namespace_usage{pool="solar-compute",resource="limits.cpu",target_namespace="solar-prod"} 0.875
capsule_pool_namespace_usage{pool="solar-compute",resource="limits.memory",target_namespace="solar-prod"} 9.39524096e+08
capsule_pool_namespace_usage{pool="solar-compute",resource="requests.cpu",target_namespace="solar-prod"} 1.375
capsule_pool_namespace_usage{pool="solar-compute",resource="requests.cpu",target_namespace="solar-test"} 0.5
capsule_pool_namespace_usage{pool="solar-compute",resource="requests.memory",target_namespace="solar-prod"} 9.39524096e+08
capsule_pool_namespace_usage{pool="solar-size",resource="pods",target_namespace="solar-test"} 3

# HELP capsule_pool_namespace_usage_percentage Current resources claimed on namespace basis for a given resource in a resource pool for a specific namespace (percentage)
# TYPE capsule_pool_namespace_usage_percentage gauge
capsule_pool_namespace_usage_percentage{pool="solar-compute",resource="limits.cpu",target_namespace="solar-prod"} 43.75
capsule_pool_namespace_usage_percentage{pool="solar-compute",resource="limits.memory",target_namespace="solar-prod"} 43.75
capsule_pool_namespace_usage_percentage{pool="solar-compute",resource="requests.cpu",target_namespace="solar-prod"} 68.75
capsule_pool_namespace_usage_percentage{pool="solar-compute",resource="requests.cpu",target_namespace="solar-test"} 25
capsule_pool_namespace_usage_percentage{pool="solar-compute",resource="requests.memory",target_namespace="solar-prod"} 43.75
capsule_pool_namespace_usage_percentage{pool="solar-size",resource="pods",target_namespace="solar-test"} 42.857142857142854

# HELP capsule_pool_resource Type of resource being used in a resource pool
# TYPE capsule_pool_resource gauge
capsule_pool_resource{pool="solar-compute",resource="limits.cpu"} 1
capsule_pool_resource{pool="solar-compute",resource="limits.memory"} 1
capsule_pool_resource{pool="solar-compute",resource="requests.cpu"} 1
capsule_pool_resource{pool="solar-compute",resource="requests.memory"} 1
capsule_pool_resource{pool="solar-size",resource="pods"} 1

# HELP capsule_pool_usage Current resource usage for a given resource in a resource pool
# TYPE capsule_pool_usage gauge
capsule_pool_usage{pool="solar-compute",resource="limits.cpu"} 0.875
capsule_pool_usage{pool="solar-compute",resource="limits.memory"} 9.39524096e+08
capsule_pool_usage{pool="solar-compute",resource="requests.cpu"} 1.875
capsule_pool_usage{pool="solar-compute",resource="requests.memory"} 9.39524096e+08
capsule_pool_usage{pool="solar-size",resource="pods"} 3

# HELP capsule_pool_usage_percentage Current resource usage for a given resource in a resource pool (percentage)
# TYPE capsule_pool_usage_percentage gauge
capsule_pool_usage_percentage{pool="solar-compute",resource="limits.cpu"} 43.75
capsule_pool_usage_percentage{pool="solar-compute",resource="limits.memory"} 43.75
capsule_pool_usage_percentage{pool="solar-compute",resource="requests.cpu"} 93.75
capsule_pool_usage_percentage{pool="solar-compute",resource="requests.memory"} 43.75
capsule_pool_usage_percentage{pool="solar-size",resource="pods"} 42.857142857142854
```

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
