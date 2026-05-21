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

`Suspends` a `Tenant` when it's `Cordoned`. Cordoning a Tenant will Cordon/Uncordon all it's Namespaces.

```yaml
resource.customizations.health.capsule.clastix.io_Tenant: |
  hs = {}
  if obj.status ~= nil then
    if obj.status.conditions ~= nil then
      for i, condition in ipairs(obj.status.conditions) do
        if condition.type == "Cordoned" and condition.status == "True" then
          hs.status = "Suspended"
          hs.message = condition.message
          return hs
        end
      end
      for i, condition in ipairs(obj.status.conditions) do
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
    end
  end
  
  hs.status = "Progressing"
  hs.message = "Waiting for Status"
  return hs
```

### Namespace Resource Health

![Namespace Resource Actions](/images/ecosystem/argo-ns-health.png)

`Suspends` a `Namespace` when it's `Cordoned`. This is only for Namespaces part of a Capsule Tenant.

```yaml
resource.customizations.health.Namespace: |
  hs = {}
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
