---
title: ArgoCD
description: Capsule Integration with ArgoCD
logo: https://github.com/cncf/artwork/raw/main/projects/argo/icon/color/argo-icon-color.svg
type: single
display: true
integration: true
---

## Integration

## Resource Actions

You may provide [Custom Resource Actions](https://argo-cd.readthedocs.io/en/stable/operator-manual/resource_actions/) for Capsule specific resources and interactions.


### Namespace Resource Actions

![Namespace Resource Actions](/images/ecosystem/argo-ns-action.png)

With the following configuration, ArgoCD will show `Cordon` and `Resume` actions for the Namespace resource. The `Cordon` action will set the `projectcapsule.dev/cordoned` label to `true`, while the `Resume` action will set it to `false`. This is only for Namespaces part of a Capsule Tenant.

```yaml
resource.customizations.actions.Namespace: |
  mergeBuiltinActions: true
  discovery.lua: |
    actions = {
      cordon = {
        iconClass = "fa fa-solid fa-pause",
        disabled = true,
      },
      uncordon = {
        iconClass = "fa fa-solid fa-play",
        disabled = true,
      },
    }

    local function has_managed_ownerref()
      if obj.metadata == nil or obj.metadata.ownerReferences == nil then
        return false
      end

      for _, ref in ipairs(obj.metadata.ownerReferences) do
        if ref.kind == "Tenant" and ref.apiVersion == "capsule.clastix.io/v1beta2" then
          return true
        end
      end

      return false
    end
    if not has_managed_ownerref() then
      return {}
    end
    local labels = {}
    if obj.metadata ~= nil and obj.metadata.labels ~= nil then
      labels = obj.metadata.labels
    end

    local cordoned = labels["projectcapsule.dev/cordoned"] == "true"

    if cordoned then
      actions["uncordon"].disabled = false
    else
      actions["cordon"].disabled = false
    end

    return actions

  definitions:
    - name: cordon
      action.lua: |
        if obj.metadata == nil then
          obj.metadata = {}
        end
        if obj.metadata.labels == nil then
          obj.metadata.labels = {}
        end

        obj.metadata.labels["projectcapsule.dev/cordoned"] = "true"
        return obj

    - name: uncordon
      action.lua: |
        if obj.metadata ~= nil and obj.metadata.labels ~= nil then
          obj.metadata.labels["projectcapsule.dev/cordoned"] = "false"
        end
        return obj
```

### Tenant Resource Actions

![Tenant Resource Actions](/images/ecosystem/argo-tenant-action.png)

With the following configuration, ArgoCD will show `Cordon` and `Resume` actions for the Tenant resource. The `Cordon` action will set the `spec.cordon` field to `true`, while the `Resume` action will set it to `false`.

```yaml
resource.customizations.actions.capsule.clastix.io_Tenant: |
  mergeBuiltinActions: true
  discovery.lua: |
    actions = {}
    actions["cordon"] = {
      ["iconClass"] = "fa fa-solid fa-pause",
      ["disabled"] = true,
    }
    actions["uncordon"] = {
      ["iconClass"] = "fa fa-solid fa-play",
      ["disabled"] = true,
    }

    local suspend = false
    if obj.spec ~= nil and obj.spec.cordoned ~= nil then
      suspend = obj.spec.cordoned
    end

    if suspend then
      actions["uncordon"]["disabled"] = false
    else
      actions["cordon"]["disabled"] = false
    end

    return actions

  definitions:
    - name: cordon
      action.lua: |
        if obj.spec == nil then
          obj.spec = {}
        end
        obj.spec.cordoned = true
        return obj

    - name: uncordon
      action.lua: |
        if obj.spec ~= nil and obj.spec.cordoned ~= nil and obj.spec.cordoned then
          obj.spec.cordoned = false
        end
        return obj
```

## Resource Health

You may provide [Custom Resource Health](https://argo-cd.readthedocs.io/en/stable/operator-manual/health/) for Capsule specific resources and interactions.

### Tenant Resource Health

![Tenant Resource Actions](/images/ecosystem/argo-tenant-health.png)

Shows `Suspended` when the `Tenant` is cordoned, reflecting that no new workloads can be scheduled in its Namespaces. Reports `Degraded` when the `Ready` condition is `False`, `Healthy` when `Ready` is `True`, and `Progressing` otherwise.

```yaml
resource.customizations.health.capsule.clastix.io_Tenant: |
  local hs = {}
  if obj.status == nil or obj.status.conditions == nil then
    hs.status = "Progressing"
    hs.message = "Waiting for status"
    return hs
  end

  if obj.metadata ~= nil and obj.metadata.generation ~= nil and obj.status.observedGeneration ~= nil
      and obj.status.observedGeneration ~= obj.metadata.generation then
    hs.status = "Progressing"
    hs.message = "Waiting for reconciliation (generation mismatch)"
    return hs
  end

  for _, condition in ipairs(obj.status.conditions) do
    if condition.type == "Cordoned" and condition.status == "True" then
      hs.status = "Suspended"
      hs.message = condition.message
      return hs
    end
  end

  for _, condition in ipairs(obj.status.conditions) do
    if condition.type == "Ready" and condition.status == "False" then
      hs.status = "Degraded"
      hs.message = condition.message
      return hs
    end
    if condition.type == "Ready" and condition.status == "True" then
      hs.status = "Healthy"
      hs.message = condition.message
      return hs
    end
  end

  hs.status = "Progressing"
  hs.message = "Waiting for Ready condition"
  return hs
```

### Namespace Resource Health

![Namespace Resource Actions](/images/ecosystem/argo-ns-health.png)

`Suspends` a `Namespace` when it's `Cordoned`. This is only for Namespaces part of a Capsule Tenant.

```yaml
resource.customizations.health.Namespace: |
  local hs = {}
  local function has_managed_ownerref()
    if obj.metadata == nil or obj.metadata.ownerReferences == nil then
      return false
    end

    for _, ref in ipairs(obj.metadata.ownerReferences) do
      if ref.kind == "Tenant" and ref.apiVersion == "capsule.clastix.io/v1beta2" then
        return true
      end
    end

    return false
  end

  local labels = {}
  if obj.metadata ~= nil and obj.metadata.labels ~= nil then
    labels = obj.metadata.labels
  end

  local cordoned = labels["projectcapsule.dev/cordoned"] == "true"

  if cordoned and has_managed_ownerref() then
    hs.status = "Suspended"
    hs.message = "Namespace is cordoned (tenant-managed)"
    return hs
  end

  if obj.status ~= nil and obj.status.phase ~= nil then
    if obj.status.phase == "Active" then
      hs.status = "Healthy"
      hs.message = "Namespace is Active"
      return hs
    else
      hs.status = "Progressing"
      hs.message = "Namespace phase is " .. obj.status.phase
      return hs
    end
  end

  hs.status = "Progressing"
  hs.message = "Waiting for Namespace status"
  return hs
```

### CapsuleConfiguration Resource Health

Reports health based on the `Ready` condition.

```yaml
resource.customizations.health.capsule.clastix.io_CapsuleConfiguration: |
  local hs = {}
  if obj.status == nil or obj.status.conditions == nil then
    hs.status = "Progressing"
    hs.message = "Waiting for status"
    return hs
  end

  if obj.metadata ~= nil and obj.metadata.generation ~= nil and obj.status.observedGeneration ~= nil
      and obj.status.observedGeneration ~= obj.metadata.generation then
    hs.status = "Progressing"
    hs.message = "Waiting for reconciliation (generation mismatch)"
    return hs
  end

  for _, condition in ipairs(obj.status.conditions) do
    if condition.type == "Ready" and condition.status == "False" then
      hs.status = "Degraded"
      hs.message = condition.message
      return hs
    end
    if condition.type == "Ready" and condition.status == "True" then
      hs.status = "Healthy"
      hs.message = condition.message
      return hs
    end
  end

  hs.status = "Progressing"
  hs.message = "Waiting for Ready condition"
  return hs
```

### TenantOwner Resource Health

Reports `Degraded` when the `TenantOwner` failed to reconcile, and `Healthy` when the owner has been successfully bound to its tenant.

```yaml
resource.customizations.health.capsule.clastix.io_TenantOwner: |
  local hs = {}
  if obj.status == nil or obj.status.conditions == nil then
    hs.status = "Progressing"
    hs.message = "Waiting for status"
    return hs
  end

  if obj.metadata ~= nil and obj.metadata.generation ~= nil and obj.status.observedGeneration ~= nil
      and obj.status.observedGeneration ~= obj.metadata.generation then
    hs.status = "Progressing"
    hs.message = "Waiting for reconciliation (generation mismatch)"
    return hs
  end

  for _, condition in ipairs(obj.status.conditions) do
    if condition.type == "Ready" and condition.status == "False" then
      hs.status = "Degraded"
      hs.message = condition.message
      return hs
    end
    if condition.type == "Ready" and condition.status == "True" then
      hs.status = "Healthy"
      hs.message = condition.message
      return hs
    end
  end

  hs.status = "Progressing"
  hs.message = "Waiting for Ready condition"
  return hs
```

### ResourcePool Resource Health

Reports `Degraded` when any resource is exhausted or not ready, and `Healthy` when the pool is active and within limits.

```yaml
resource.customizations.health.capsule.clastix.io_ResourcePool: |
  local hs = {}
  if obj.status == nil or obj.status.conditions == nil then
    hs.status = "Progressing"
    hs.message = "Waiting for status"
    return hs
  end

  if obj.metadata ~= nil and obj.metadata.generation ~= nil and obj.status.observedGeneration ~= nil
      and obj.status.observedGeneration ~= obj.metadata.generation then
    hs.status = "Progressing"
    hs.message = "Waiting for reconciliation (generation mismatch)"
    return hs
  end

  if obj.status.exhaustions ~= nil then
    local exhausted = {}
    for resource, _ in pairs(obj.status.exhaustions) do
      table.insert(exhausted, resource)
    end
    table.sort(exhausted)
    if #exhausted > 0 then
      hs.status = "Degraded"
      hs.message = "Pool exhausted for: " .. table.concat(exhausted, ", ")
      return hs
    end
  end

  for _, condition in ipairs(obj.status.conditions) do
    if condition.type == "Ready" and condition.status == "False" then
      hs.status = "Degraded"
      hs.message = condition.message
      return hs
    end
    if condition.type == "Ready" and condition.status == "True" then
      hs.status = "Healthy"
      hs.message = condition.message
      return hs
    end
  end

  hs.status = "Progressing"
  hs.message = "Waiting for Ready condition"
  return hs
```

### ResourcePoolClaim Resource Health

Reports `Suspended` when unbound (waiting for a pool), `Degraded` when not ready, and `Healthy` when bound and ready.

```yaml
resource.customizations.health.capsule.clastix.io_ResourcePoolClaim: |
  local hs = {}
  if obj.status == nil or obj.status.conditions == nil then
    hs.status = "Progressing"
    hs.message = "Waiting for status"
    return hs
  end

  if obj.metadata ~= nil and obj.metadata.generation ~= nil and obj.status.observedGeneration ~= nil
      and obj.status.observedGeneration ~= obj.metadata.generation then
    hs.status = "Progressing"
    hs.message = "Waiting for reconciliation (generation mismatch)"
    return hs
  end

  for _, condition in ipairs(obj.status.conditions) do
    if condition.type == "Bound" and condition.status == "False" then
      hs.status = "Suspended"
      hs.message = condition.message
      return hs
    end
  end

  for _, condition in ipairs(obj.status.conditions) do
    if condition.type == "Ready" and condition.status == "False" then
      hs.status = "Degraded"
      hs.message = condition.message
      return hs
    end
    if condition.type == "Ready" and condition.status == "True" then
      hs.status = "Healthy"
      hs.message = condition.message
      return hs
    end
  end

  hs.status = "Progressing"
  hs.message = "Waiting for Ready condition"
  return hs
```

### CustomQuota Resource Health

Reports `Degraded` when the quota reconcile failed (e.g. a matched resource has a missing field), and `Healthy` when usage has been successfully calculated for the namespace.

```yaml
resource.customizations.health.capsule.clastix.io_CustomQuota: |
  local hs = {}
  if obj.status == nil or obj.status.conditions == nil then
    hs.status = "Progressing"
    hs.message = "Waiting for status"
    return hs
  end

  if obj.metadata ~= nil and obj.metadata.generation ~= nil and obj.status.observedGeneration ~= nil
      and obj.status.observedGeneration ~= obj.metadata.generation then
    hs.status = "Progressing"
    hs.message = "Waiting for reconciliation (generation mismatch)"
    return hs
  end

  for _, condition in ipairs(obj.status.conditions) do
    if condition.type == "Ready" and condition.status == "False" then
      hs.status = "Degraded"
      hs.message = condition.message
      return hs
    end
    if condition.type == "Ready" and condition.status == "True" then
      hs.status = "Healthy"
      hs.message = condition.message
      return hs
    end
  end

  hs.status = "Progressing"
  hs.message = "Waiting for Ready condition"
  return hs
```

### GlobalCustomQuota Resource Health

Reports `Degraded` when the quota reconcile failed, and `Healthy` when usage has been successfully calculated across all selected namespaces.

```yaml
resource.customizations.health.capsule.clastix.io_GlobalCustomQuota: |
  local hs = {}
  if obj.status == nil or obj.status.conditions == nil then
    hs.status = "Progressing"
    hs.message = "Waiting for status"
    return hs
  end

  if obj.metadata ~= nil and obj.metadata.generation ~= nil and obj.status.observedGeneration ~= nil
      and obj.status.observedGeneration ~= obj.metadata.generation then
    hs.status = "Progressing"
    hs.message = "Waiting for reconciliation (generation mismatch)"
    return hs
  end

  for _, condition in ipairs(obj.status.conditions) do
    if condition.type == "Ready" and condition.status == "False" then
      hs.status = "Degraded"
      hs.message = condition.message
      return hs
    end
    if condition.type == "Ready" and condition.status == "True" then
      hs.status = "Healthy"
      hs.message = condition.message
      return hs
    end
  end

  hs.status = "Progressing"
  hs.message = "Waiting for Ready condition"
  return hs
```

### TenantResource Resource Health

Reports `Degraded` when the replication of tenant-scoped resources failed, and `Healthy` when all resources have been successfully replicated into the target namespaces.

```yaml
resource.customizations.health.capsule.clastix.io_TenantResource: |
  local hs = {}
  if obj.status == nil or obj.status.conditions == nil then
    hs.status = "Progressing"
    hs.message = "Waiting for status"
    return hs
  end

  if obj.metadata ~= nil and obj.metadata.generation ~= nil and obj.status.observedGeneration ~= nil
      and obj.status.observedGeneration ~= obj.metadata.generation then
    hs.status = "Progressing"
    hs.message = "Waiting for reconciliation (generation mismatch)"
    return hs
  end

  for _, condition in ipairs(obj.status.conditions) do
    if condition.type == "Ready" and condition.status == "False" then
      hs.status = "Degraded"
      hs.message = condition.message
      return hs
    end
    if condition.type == "Ready" and condition.status == "True" then
      hs.status = "Healthy"
      hs.message = condition.message
      return hs
    end
  end

  hs.status = "Progressing"
  hs.message = "Waiting for Ready condition"
  return hs
```

### GlobalTenantResource Resource Health

Reports `Degraded` when the cluster-wide resource replication failed, and `Healthy` when all resources have been successfully replicated across all tenant namespaces.

```yaml
resource.customizations.health.capsule.clastix.io_GlobalTenantResource: |
  local hs = {}
  if obj.status == nil or obj.status.conditions == nil then
    hs.status = "Progressing"
    hs.message = "Waiting for status"
    return hs
  end

  if obj.metadata ~= nil and obj.metadata.generation ~= nil and obj.status.observedGeneration ~= nil
      and obj.status.observedGeneration ~= obj.metadata.generation then
    hs.status = "Progressing"
    hs.message = "Waiting for reconciliation (generation mismatch)"
    return hs
  end

  for _, condition in ipairs(obj.status.conditions) do
    if condition.type == "Ready" and condition.status == "False" then
      hs.status = "Degraded"
      hs.message = condition.message
      return hs
    end
    if condition.type == "Ready" and condition.status == "True" then
      hs.status = "Healthy"
      hs.message = condition.message
      return hs
    end
  end

  hs.status = "Progressing"
  hs.message = "Waiting for Ready condition"
  return hs
```

## Capsule Proxy

The following health checks apply to [Capsule Proxy](https://github.com/projectcapsule/capsule-proxy) CRDs.

### ProxySetting Resource Health

Reports `Degraded` when a per-user or per-group `ProxySetting` failed to reconcile, and `Healthy` when the proxy rules have been successfully applied.

```yaml
resource.customizations.health.capsule.clastix.io_ProxySetting: |
  local hs = {}
  if obj.status == nil or obj.status.conditions == nil then
    hs.status = "Progressing"
    hs.message = "Waiting for status"
    return hs
  end

  if obj.metadata ~= nil and obj.metadata.generation ~= nil and obj.status.observedGeneration ~= nil
      and obj.status.observedGeneration ~= obj.metadata.generation then
    hs.status = "Progressing"
    hs.message = "Waiting for reconciliation (generation mismatch)"
    return hs
  end

  for _, condition in ipairs(obj.status.conditions) do
    if condition.type == "Ready" and condition.status == "False" then
      hs.status = "Degraded"
      hs.message = condition.message
      return hs
    end
    if condition.type == "Ready" and condition.status == "True" then
      hs.status = "Healthy"
      hs.message = condition.message
      return hs
    end
  end

  hs.status = "Progressing"
  hs.message = "Waiting for Ready condition"
  return hs
```

### GlobalProxySettings Resource Health

Reports `Degraded` when the cluster-wide proxy settings failed to reconcile, and `Healthy` when the global proxy rules have been successfully applied.

```yaml
resource.customizations.health.capsule.clastix.io_GlobalProxySettings: |
  local hs = {}
  if obj.status == nil or obj.status.conditions == nil then
    hs.status = "Progressing"
    hs.message = "Waiting for status"
    return hs
  end

  if obj.metadata ~= nil and obj.metadata.generation ~= nil and obj.status.observedGeneration ~= nil
      and obj.status.observedGeneration ~= obj.metadata.generation then
    hs.status = "Progressing"
    hs.message = "Waiting for reconciliation (generation mismatch)"
    return hs
  end

  for _, condition in ipairs(obj.status.conditions) do
    if condition.type == "Ready" and condition.status == "False" then
      hs.status = "Degraded"
      hs.message = condition.message
      return hs
    end
    if condition.type == "Ready" and condition.status == "True" then
      hs.status = "Healthy"
      hs.message = condition.message
      return hs
    end
  end

  hs.status = "Progressing"
  hs.message = "Waiting for Ready condition"
  return hs
```
