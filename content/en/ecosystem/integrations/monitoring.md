---
title: Monitoring
describtion: Capsule interation with Monitoring Solutions
display: false
---

While we can not provide a full list of all the monitoring solutions available, we can provide some guidance on how to integrate Capsule with some of the most popular ones. Also this is dependent on how you have set up your monitoring solution. We will just explore the options available to you.



## Logging




### Loki


### Promtail 




```yaml
config:
  clients:
    - url: "https://loki.company.com/loki/api/v1/push"
      # Maximum wait period before sending batch
      batchwait: 1s
      # Maximum batch size to accrue before sending, unit is byte
      batchsize: 102400
      # Maximum time to wait for server to respond to a request
      timeout: 10s
      backoff_config:
        # Initial backoff time between retries
        min_period: 100ms
        # Maximum backoff time between retries
        max_period: 5s
        # Maximum number of retries when sending batches, 0 means infinite retries
        max_retries: 20
      tenant_id: "tenant"
      external_labels:
        cluster: "${cluster_name}"
  serverPort: 3101
  positions:
    filename: /run/promtail/positions.yaml
  target_config:
    # Period to resync directories being watched and files being tailed
    sync_period: 10s
  snippets:
    pipelineStages:
      - docker: {}
      # Drop health logs
      - drop:
          expression: "(.*/health-check.*)|(.*/health.*)|(.*kube-probe.*)"
      - static_labels:
          cluster: ${cluster}
      - tenant:
          source: tenant
    # This wont work if pods on the cluster are not labeled with tenant
    extraRelabelConfigs:
      - action: replace
        source_labels:
          - __meta_kubernetes_pod_label_capsule_clastix_io_tenant
        target_label: tenant
...
```



As mentioned, the above configuration will not work if the pods on the cluster are not labeled with tenant. You can use the following [Kyverno policy](/docs/integrations/tools/kyverno/) to ensure that all pods are labeled with tenant. If the pod does not belong to any tenant, it will be labeled with management (assuming you have a central management tenant)

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: capsule-pod-labels
spec:
  background: false
  rules:
  - name: add-pod-label
    context:
      - name: tenant
        apiCall:
          method: GET
          urlPath: "/api/v1/namespaces/{{request.namespace}}"
          jmesPath: "not_null(metadata.labels.\"capsule.clastix.io/tenant\" || 'management')"
    match:
      all:
      - resources:
          kinds:
            - Pod
          operations:
            - CREATE
            - UPDATE
    mutate:
      patchStrategicMerge:
        metadata:
          labels:
            +(capsule.clastix.io/tenant): "{{ tenant_name }}"
```



## Grafana
