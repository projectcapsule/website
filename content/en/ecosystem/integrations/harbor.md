---
title: Envoy-Gateway
description: Capsule Integration with Harbor
logo: https://github.com/cncf/artwork/raw/main/projects/envoy/envoy-gateway/icon/color/envoy-gateway-icon-color.svg
type: single
display: true
integration: true
---

There's different ways to use [Gateway API](https://gateway-api.sigs.k8s.io/) in a multi-tenant setup. This guide suggested a strong isolated implementation using the [Envoy Gateway Project](https://gateway.envoyproxy.io/). The Architecture suggested looks something like this:

![Namespace Resource Actions](/images/ecosystem/envoy-gateway.drawio.png)

Each tenant will get it's own `-system` `Namespace`. However that namespace is not managed by the `Tenant` nor part of it. It's the namespace where the platform deploys managed services for each `Tenant`, which are out of bound for `TenantOwners`.

## Registry Overwrite

## Management (Crossplane)

The following example shows how you could automate the management of Harbor based Tenants. This assumes you provide a single harbor instance where all Tenants host their Harbor Projects. However this approach requires [Crossplane](https://www.crossplane.io/) in combindation with the [community provider for Harbor](https://github.com/globallogicuki/provider-harbor).

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: tenant-harbor-project
spec:
  scope: Tenant
  resources:
    - generators:
      - template: |
          ---
          apiVersion: project.harbor.crossplane.io/v1alpha1
          kind: Project
          metadata:
            name: {{$.tenant.metadata.name}}
            labels:
              projectcapsule.dev/tenant: {{$.tenant.metadata.name}}
          spec:
            forProvider:
              autoSbomGeneration: true
              enableContentTrust: true
              enableContentTrustCosign: false
              name: {{$.tenant.metadata.name}}
              public: false
              vulnerabilityScanning: true
              {{- with $.tenant.data.registryStorageQuota }}
              storageQuota: 10
              {{- end }}
          ---
          apiVersion: project.harbor.crossplane.io/v1alpha1
          kind: RetentionPolicy
          metadata:
            name: {{$.tenant.metadata.name}}
          spec:
            forProvider:
              rule:
              - nDaysSinceLastPull: 5
                repoMatching: '**'
                tagMatching: latest
              - nDaysSinceLastPush: 10
                repoMatching: '**'
                tagMatching: '{latest,snapshot}'
              schedule: Daily
              scopeSelector:
                matchLabels:
                  projectcapsule.dev/tenant: {{$.tenant.metadata.name}}
    - generators:
      - template: |
          {{- range $.tenant.status.owners }}
            {{- if eq .kind "User" }}
          ---
          apiVersion: project.harbor.crossplane.io/v1alpha1
          kind: MemberGroup
          metadata:
            name: {{$.tenant.metadata.name}}-owner-group-{{.name}}
          spec:
            forProvider:
              groupName: {{.name}}
              projectIdSelector:
                matchLabels:
                  projectcapsule.dev/tenant: {{$.tenant.metadata.name}}
              role: projectadmin
              type: oidc
            {{- elseif eq .kind "User"  }}
            ---
            apiVersion: project.harbor.crossplane.io/v1alpha1
            kind: MemberUser
            metadata:
              name: {{$.tenant.metadata.name}}-owner-user-{{.name}}
            spec:
              forProvider:
                projectIdSelector:
                  matchLabels:
                    projectcapsule.dev/tenant: {{$.tenant.metadata.name}}
                role: projectadmin
                userName: {{.name}}
            {{- end }}