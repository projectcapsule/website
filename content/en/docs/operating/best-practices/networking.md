---
title: Networking
weight: 4
description: Multi-Tenant Networking considerations
---

## Network-Policies

It's a best practice to not allow any traffic outside of a tenant (or a tenant's namespace). For this we can use [Tenant Replications](/docs/replications/) to ensure we have for every namespace Networkpolicies in place.

The following NetworkPolicy is distributed to all namespaces which belong to a Capsule tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: default-networkpolicies
  namespace: solar-system
spec:
  resyncPeriod: 60s
  resources:
    - rawItems:
        - apiVersion: networking.k8s.io/v1
          kind: NetworkPolicy
          metadata:
            name: default-policy
          spec:
            # Apply to all pods in this namespace
            podSelector: {}
            policyTypes:
              - Ingress
              - Egress
            ingress:
              # Allow traffic from the same namespace (intra-namespace communication)
              - from:
                  - podSelector: {}

              # Allow traffic from all namespaces within the tenant
              - from:
                  - namespaceSelector:
                      matchLabels:
                        capsule.clastix.io/tenant: "{{tenant.name}}"

              # Allow ingress from other namespaces labeled (System Namespaces, eg. Monitoring, Ingress)
              - from:
                  - namespaceSelector:
                      matchLabels:
                        company.com/system: "true"

            egress:
              # Allow DNS to kube-dns service IP (might be different in your setup)
              - to:
                  - ipBlock:
                      cidr: 10.96.0.10/32
                ports:
                  - protocol: UDP
                    port: 53
                  - protocol: TCP
                    port: 53

              # Allow traffic to all namespaces within the tenant
              - to:
                  - namespaceSelector:
                      matchLabels:
                        capsule.clastix.io/tenant: "{{tenant.name}}"
```


### Deny Namespace Metadata

In the above example we allow traffic from namespaces with the label `company.com/system: "true"`. This is meant for Kubernetes Operators to eg. scrape the workloads within a tenant. However without further enforcement any namespace can set this label and therefor gain access to any tenant namespace. To prevent this, we must restrict, who can declare this label on namespaces.

We can deny such labels on tenant basis. So in this scenario every tenant should disallow the use of these labels on namespaces:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  namespaceOptions:
    forbiddenLabels:
      denied:
          - company.com/system
```

[Or you can implement a Kyverno-Policy, which solves this](/ecosystem/integrations/kyverno/).


### Non-Native Network-Policies

The same principle can be applied with alternative CNI solutions. In this example we are using Cilium:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: GlobalTenantResource
metadata:
  name: default-networkpolicies
  namespace: solar-system
spec:
  resyncPeriod: 60s
  resources:
    - rawItems:
        - apiVersion: cilium.io/v2
          kind: CiliumNetworkPolicy
          metadata:
            name: default-policy
          spec:
            endpointSelector: {}  # Apply to all pods in the namespace
            ingress:
              - fromEndpoints:
                  - matchLabels: {}  # Same namespace pods (intra-namespace)
              - fromEntities:
                  - cluster  # For completeness; can be used to allow internal cluster traffic if needed
              - fromEndpoints:
                  - matchLabels:
                      capsule.clastix.io/tenant: "{{tenant.name}}"  # Pods in other namespaces with same tenant
              - fromNamespaces:
                  - matchLabels:
                      company.com/system: "true"  # System namespaces (monitoring, ingress, etc.)
          
            egress:
              - toCIDR:
                  - 10.96.0.10/32  # kube-dns IP
                toPorts:
                  - ports:
                      - port: "53"
                        protocol: UDP
                      - port: "53"
                        protocol: TCP
          
              - toNamespaces:
                  - matchLabels:
                      capsule.clastix.io/tenant: "{{tenant.name}}"  # Egress to all tenant namespaces
```



