---
title: Enforcement
weight: 5
description: >
  Configure policies and restrictions on tenant-basis
---


## Metadata

### Namespaces

#### AdditionalMetadataList

The cluster admin can "taint" the namespaces created by tenant owners with additional metadata as labels and annotations. There is no specific semantic assigned to these labels and annotations: they will be assigned to the namespaces in the tenant as they are created. However you have the option to be more specific by selecting to which namespaces you want to assign what kind of metadata:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: oil
spec:
  owners:
  - name: alice
    kind: User
  namespaceOptions:
    additionalMetadataList:
    # An item without any further selectors is applied to all namspaces
    - annotations:
        storagelocationtype: s3
      labels:
        projectcapsule.dev/backup: "true"

    # Select a subset of namespaces to apply metadata on
    - namespaceSelector:
        matchExpressions:
          - key: projectcapsule.dev/low_security_profile
            operator: NotIn
            values: ["true"]
      labels:
        pod-security.kubernetes.io/enforce: baseline

    - namespaceSelector:
        matchExpressions:
          - key: projectcapsule.dev/low_security_profile
            operator: In
            values: ["true"]
      labels:
        pod-security.kubernetes.io/enforce: privileged
```


#### AdditionalMetadata

{{% alert title="Deprecated" color="info" %}}
This feature is deprecated and  will be removed in a future release of Capsule. Migrate to using [AdditionalMetadataList](#additionalmetadatalist)
{{% /alert %}}

The cluster admin can "taint" the namespaces created by tenant owners with additional metadata as labels and annotations. There is no specific semantic assigned to these labels and annotations: they will be assigned to the namespaces in the tenant as they are created. This can help the cluster admin to implement specific use cases as, for example, leave only a given tenant to be backed up by a backup service.

Assigns additional labels and annotations to all namespaces created in the `solar` tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: oil
spec:
  owners:
  - name: alice
    kind: User
  namespaceOptions:
    additionalMetadata:
      annotations:
        storagelocationtype: s3
      labels:
        projectcapsule.dev/backup: "true"
```

When the tenant owner creates a namespace, it inherits the given label and/or annotation:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    storagelocationtype: s3
  labels:
    capsule.clastix.io/tenant: solar
    kubernetes.io/metadata.name: solar-production
    name: solar-production
    projectcapsule.dev/backup: "true"
  name: solar-production
  ownerReferences:
  - apiVersion: capsule.clastix.io/v1beta2
    blockOwnerDeletion: true
    controller: true
    kind: Tenant
    name: solar
spec:
  finalizers:
  - kubernetes
status:
  phase: Active
```

#### Deny labels and annotations on Namespaces

By default, capsule allows tenant owners to add and modify any label or annotation on their namespaces.

But there are some scenarios, when tenant owners should not have an ability to add or modify specific labels or annotations (for example, this can be labels used in [Kubernetes network policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) which are added by cluster administrator).

Bill, the cluster admin, can deny Alice to add specific labels and annotations on namespaces:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  namespaceOptions:
    forbiddenAnnotations:
      denied:
          - foo.acme.net
          - bar.acme.net
      deniedRegex: .*.acme.net 
    forbiddenLabels:
      denied:
          - foo.acme.net
          - bar.acme.net
      deniedRegex: .*.acme.net
  owners:
  - name: alice
    kind: User
```

### Nodes

{{% alert title="Warning" color="warning" %}}
Due to [CVE-2021-25735](https://github.com/kubernetes/kubernetes/issues/100096) this feature is only supported for Kubernetes version older than: v1.18.18, v1.19.10, v1.20.6, v1.21.0
{{% /alert %}}

When using capsule together with [capsule-proxy](/docs/integrations/capsule-proxy), Bill can allow Tenant Owners to modify Nodes.

By default, it will allow tenant owners to add and modify any label or annotation on their nodes.

But there are some scenarios, when tenant owners should not have an ability to add or modify specific labels or annotations (there are some types of labels or annotations, which must be protected from modifications - for example, which are set by cloud-providers or autoscalers).

Bill, the cluster admin, can deny Tenant Owners to add or modify specific labels and annotations on Nodes:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: CapsuleConfiguration
metadata:
  name: default 
spec:
  nodeMetadata:
    forbiddenAnnotations:
      denied:
        - foo.acme.net
        - bar.acme.net
      deniedRegex: .*.acme.net
    forbiddenLabels:
      denied:
        - foo.acme.net
        - bar.acme.net
      deniedRegex: .*.acme.net
  userGroups:
    - projectcapsule.dev
    - system:serviceaccounts:default
```

### Services

The cluster admin can "taint" the services created by the tenant owners with additional metadata as labels and annotations.

Assigns additional labels and annotations to all services created in the `solar` tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  serviceOptions:
    additionalMetadata:
      annotations:
        storagelocationtype: s3
      labels:
        projectcapsule.dev/backup: "true"
```

When the tenant owner creates a service in a tenant namespace, it inherits the given label and/or annotation:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: solar-production
  labels:
    projectcapsule.dev/backup: "true"
  annotations:
    storagelocationtype: s3
spec:
  ports:
  - protocol: TCP
    port: 80 
    targetPort: 8080 
  selector:
    run: nginx
  type: ClusterIP
```

### Services

The cluster admin can "taint" the pods created by the tenant owners with additional metadata as labels and annotations.

Assigns additional labels and annotations to all services created in the `solar` tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  podOptions:
    additionalMetadata:
      annotations:
        storagelocationtype: s3
      labels:
        projectcapsule.dev/backup: "true"
```

When the tenant owner creates a service in a tenant namespace, it inherits the given label and/or annotation:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace: solar-production
  labels:
    projectcapsule.dev/backup: "true"
  annotations:
    storagelocationtype: s3
...
```

## Scheduling

### LimitRanges

> This feature will be deprecated in a future release of Capsule. Instead use [TenantReplications](#limitrange-distribution-with-tenantreplications)

Bill, the cluster admin, can also set Limit Ranges for each namespace in Alice's tenant by defining limits for pods and containers in the tenant spec:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
...
  limitRanges:
    items:
      - limits:
          - type: Pod
            min:
              cpu: "50m"
              memory: "5Mi"
            max:
              cpu: "1"
              memory: "1Gi"
      - limits:
          - type: Container
            defaultRequest:
              cpu: "100m"
              memory: "10Mi"
            default:
              cpu: "200m"
              memory: "100Mi"
            min:
              cpu: "50m"
              memory: "5Mi"
            max:
              cpu: "1"
              memory: "1Gi"
      - limits:
          - type: PersistentVolumeClaim
            min:
              storage: "1Gi"
            max:
              storage: "10Gi"
```

Limits will be inherited by all the namespaces created by Alice. In our case, when Alice creates the namespace `solar-production`, Capsule creates the following:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: capsule-solar-0
  namespace: solar-production
spec:
  limits:
    - max:
        cpu: "1"
        memory: 1Gi
      min:
        cpu: 50m
        memory: 5Mi
      type: Pod
---
apiVersion: v1
kind: LimitRange
metadata:
  name: capsule-solar-1
  namespace: solar-production
spec:
  limits:
    - default:
        cpu: 200m
        memory: 100Mi
      defaultRequest:
        cpu: 100m
        memory: 10Mi
      max:
        cpu: "1"
        memory: 1Gi
      min:
        cpu: 50m
        memory: 5Mi
      type: Container
---
apiVersion: v1
kind: LimitRange
metadata:
  name: capsule-solar-2
  namespace: solar-production
spec:
  limits:
    - max:
        storage: 10Gi
      min:
        storage: 1Gi
      type: PersistentVolumeClaim
```

> Note: being the limit range specific of single resources, there is no aggregate to count.

Alice doesn't have permission to change or delete the resources according to the assigned RBAC profile.

```bash
kubectl -n solar-production auth can-i patch resourcequota
no
kubectl -n solar-production auth can-i delete resourcequota
no
kubectl -n solar-production auth can-i patch limitranges
no
kubectl -n solar-production auth can-i delete limitranges
no
```


#### LimitRange Distribution with TenantReplications

In the future Cluster-Administrators must distribute LimitRanges via [TenantReplications](/docs/replications). This is a more flexible and powerful way to distribute LimitRanges, as it allows to distribute any kind of resource, not only LimitRanges. Here's an example of how to distribute a LimitRange to all the namespaces of a tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: solar-limitranges
  namespace: solar-system
spec:
  resyncPeriod: 60s
  resources:
    - namespaceSelector:
        matchLabels:
          capsule.clastix.io/tenant: solar
      rawItems:
        - apiVersion: v1
          kind: LimitRange
          metadata:
            name: cpu-resource-constraint
          spec:
            limits:
            - default: # this section defines default limits
                cpu: 500m
              defaultRequest: # this section defines default requests
                cpu: 500m
              max: # max and min define the limit range
                cpu: "1"
              min:
                cpu: 100m
              type: Container
```


### PriorityClasses

Pods can have priority. Priority indicates the importance of a Pod relative to other Pods. If a Pod cannot be scheduled, the scheduler tries to preempt (evict) lower priority Pods to make scheduling of the pending Pod possible. See [Kubernetes documentation](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/).

In a multi-tenant cluster, not all users can be trusted, as a tenant owner could create Pods at the highest possible priorities, causing other Pods to be evicted/not get scheduled.

To prevent misuses of Pod Priority Class, Bill, the cluster admin, can enforce the allowed Pod Priority Class at tenant level:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: oil
spec:
  owners:
  - name: alice
    kind: User
  priorityClasses:
    matchLabels:
      env: "production"
``` 

With the said Tenant specification, Alice can create a Pod resource if `spec.priorityClassName` equals to:

* Any PriorityClass which has the label `env` with the value `production`

If a Pod is going to use a non-allowed Priority Class, it will be rejected by the Validation Webhook enforcing it.

#### Assign Pod Priority Class as tenant default

> Note: This feature supports type PriorityClass only on API version scheduling.k8s.io/v1

This feature allows specifying a custom default value on a Tenant basis, bypassing the global cluster default (globalDefault=true) that acts only at the cluster level.

It's possible to assign each tenant a PriorityClass which will be used, if no PriorityClass is set on pod basis:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  priorityClasses:
    default: "tenant-default"
    matchLabels:
      env: "production"
```

Let's create a PriorityClass which is used as the default:

```bash
kubectl apply -f - << EOF
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: tenant-default
  labels:
    env: "production"
value: 1313
preemptionPolicy: Never
globalDefault: false
description: "This is the default PriorityClass for the solar-tenant"
EOF
```

Note the `globalDefault: false` which is important to avoid the PriorityClass to be used as the default for all the tenants. If a Pod has no value for `spec.priorityClassName`, the default value for PriorityClass (`tenant-default`) will be used.

### RuntimeClasses

Pods can be assigned different runtime classes. With the assigned runtime you can control Container Runtime Interface (CRI) is used for each pod. See [Kubernetes documentation](https://kubernetes.io/docs/concepts/containers/runtime-class/) for more information.

To prevent misuses of Pod Runtime Classes, Bill, the cluster admin, can enforce the allowed Pod Runtime Class at tenant level:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  runtimeClasses:
    matchLabels:
      env: "production"
```

With the said Tenant specification, Alice can create a Pod resource if `spec.runtimeClassName` equals to:

  * any RuntimeClass which has the label`env` with the value `production`

If a Pod is going to use a non-allowed Runtime Class, it will be rejected by the Validation Webhook enforcing it.

### NodeSelector

Bill, the cluster admin, can dedicate a pool of worker nodes to the oil tenant, to isolate the tenant applications from other noisy neighbors.

These nodes are labeled by Bill as `pool=renewable`

```bash
kubectl get nodes --show-labels

NAME                      STATUS   ROLES             AGE   VERSION   LABELS
...
worker06.acme.com         Ready    worker            8d    v1.25.2 pool=renewable
worker07.acme.com         Ready    worker            8d    v1.25.2   pool=renewable
worker08.acme.com         Ready    worker            8d    v1.25.2   pool=renewable
```

#### PodNodeSelector

> This approach requires `PodNodeSelector` Admission Controller plugin to be active. If the plugin is not active, the pods will be scheduled to any node. If your distribution does not support this feature, you can use [Expression Node Selectors](/docs/tenants/enforcement#node-selector-expressions).

The label `pool=renewable` is defined as `.spec.nodeSelector` in the tenant manifest:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  nodeSelector:
    pool: renewable
    kubernetes.io/os: linux
```

The Capsule controller makes sure that any namespace created in the tenant has the annotation: `scheduler.alpha.kubernetes.io/node-selector: pool=renewable`. This annotation tells the scheduler of Kubernetes to assign the node selector `pool=renewable` to all the pods deployed in the tenant. The effect is that all the pods deployed by Alice are placed only on the designated pool of nodes.

Multiple node selector labels can be defined as in the following snippet:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  nodeSelector:
    pool: renewable
    kubernetes.io/os: linux
    kubernetes.io/arch: amd64
    hardware: gpu
```

Any attempt of Alice to change the selector on the pods will result in an error from the PodNodeSelector Admission Controller plugin.
    
```bash
kubectl auth can-i edit ns -n solar-production
no
```

#### Node Selector Expressions

Feature TBD

## Connectivity

### Services

#### Deny Service Types

Bill, the cluster admin, can prevent the creation of services with specific service types.

##### NodePort

When dealing with a shared multi-tenant scenario, multiple [NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport) services can start becoming cumbersome to manage. The reason behind this could be related to the overlapping needs by the Tenant owners, since a NodePort is going to be open on all nodes and, when using `hostNetwork=true`, accessible to any Pod although any specific `NetworkPolicy`.

Bill, the cluster admin, can block the creation of services with NodePort service type for a given tenant

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  serviceOptions:
    allowedServices:
      nodePort: false
```

With the above configuration, any attempt of Alice to create a Service of type `NodePort` is denied by the Validation Webhook enforcing it. Default value is `true`.

#### ExternalName

Service with the type of [ExternalName](https://kubernetes.io/docs/concepts/services-networking/service/#externalname) has been found subject to many security issues. To prevent tenant owners to create services with the type of ExternalName, the cluster admin can prevent a tenant to create them:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  serviceOptions:
    allowedServices:
      externalName: false
```

With the above configuration, any attempt of Alice to create a Service of type `externalName` is denied by the Validation Webhook enforcing it. Default value is `true`.

#### LoadBalancer

Same as previously, the Service of type of [LoadBalancer](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer) could be blocked for various reasons. To prevent tenant owners to create these kinds of services, the cluster admin can prevent a tenant to create them:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  serviceOptions:
    allowedServices:
      loadBalancer: false
```

With the above configuration, any attempt of Alice to create a Service of type `LoadBalancer` is denied by the Validation Webhook enforcing it. Default value is `true`.


### GatewayClasses

> Note: This feature is offered only by API type `GatewayClass` in group `gateway.networking.k8s.io` version `v1`.


[GatewayClass](https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1.GatewayClass) is cluster-scoped resource defined by the infrastructure provider. This resource represents a class of Gateways that can be instantiated. [Read More](https://gateway-api.sigs.k8s.io/api-types/gatewayclass/)

Bill can assign a set of dedicated GatewayClasses to the `solar` tenant to force the applications in the `solar` tenant to be published only by the assigned Gateway Controller:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  gatewayOptions:
    allowedClasses:
      matchLabels:
        env: "production"
```

With the said Tenant specification, Alice can create a [Gateway](https://gateway-api.sigs.k8s.io/api-types/gateway/) resource if `spec.gatewayClassName` equals to:

* Any `GatewayClass` which has the label `env` with the value `production`

If an `Gateway` is going to use a non-allowed `GatewayClass`, it will be rejected by the Validation Webhook enforcing it.

Alice can create an `Gateway` using only an allowed `GatewayClass`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: example-gateway
  namespace: solar-production
spec:
  gatewayClassName: customer-class
  listeners:
  - name: http
    protocol: HTTP
    port: 80
```

Any attempt of Alice to use a non-valid `GatewayClass`, or missing it, is denied by the Validation Webhook enforcing it.

#### Assign GatewayClass as tenant default

> Note: The Default GatewayClass must have a label which is allowed within the tenant. This behavior is only implemented this way for the GatewayClass default.

This feature allows specifying a custom default value on a Tenant basis. Currently there is no global default feature for a GatewayClass. Each [Gateway](https://gateway-api.sigs.k8s.io/api-types/gateway/) must have a `spec.gatewayClassName` set.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  gatewayOptions:
    allowedClasses:
      default: "tenant-default"
      matchLabels:
        env: "production"
```

Here's how the Tenant default `GatewayClass` could look like:

```bash
kubectl apply -f - << EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: tenant-default
  labels:
    env: "production"
spec:
  controllerName: example.com/gateway-controller
EOF
```

If a `Gateway` has no value for `spec.gatewayClassName`, the `tenant-default` `GatewayClass` is automatically applied to the `Gateway` resource.


### Ingresses

#### Assign Ingress Hostnames

Bill can control ingress hostnames in the `solar` tenant to force the applications to be published only using the given hostname or set of hostnames:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  ingressOptions:
    allowedHostnames:
      allowed:
        - solar.acmecorp.com
      allowedRegex: ^.*acmecorp.com$
```
The Capsule controller assures that all Ingresses created in the tenant can use only one of the valid hostnames. Alice can create an Ingress using any allowed hostname:

```bash
kubectl apply -f - << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  namespace: solar-production
spec:
  ingressClassName: solar
  rules:
  - host: web.solar.acmecorp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF
```

Any attempt of Alice to use a non-valid hostname is denied by the Validation Webhook enforcing it.

#### Control Hostname collision in Ingresses

In a multi-tenant environment, as more and more ingresses are defined, there is a chance of collision on the hostname leading to unpredictable behavior of the Ingress Controller. Bill, the cluster admin, can enforce hostname collision detection at different scope levels:

* Cluster
* Tenant
* Namespace
* Disabled (default)

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  - name: joe
    kind: User
  ingressOptions:
    hostnameCollisionScope: Tenant
```

When a tenant owner creates an Ingress resource, Capsule will check the collision of hostname in the current ingress with all the hostnames already used, depending on the defined scope.

For example, Alice, one of the tenant owners, creates an Ingress:

```bash
kubectl apply -f - << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  namespace: solar-production
spec:
  rules:
  - host: web.solar.acmecorp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF
```

Another user, Joe creates an Ingress having the same hostname:

```bash
kubectl apply -f - << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  namespace: solar-development
spec:
  rules:
  - host: web.solar.acmecorp.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF
```

When a collision is detected at scope defined by `spec.ingressOptions.hostnameCollisionScope`, the creation of the Ingress resource will be rejected by the Validation Webhook enforcing it. When `spec.ingressOptions.hostnameCollisionScope=Disabled` (default), no collision detection is made at all.

#### Deny Wildcard Hostname in Ingresses

Bill, the cluster admin, can deny the use of wildcard hostname in Ingresses. Let's assume that Acme Corp. uses the domain acme.com.

As a tenant owner of `solar`, Alice creates an Ingress with the host like - `host: "*.acme.com"`. That can lead problems for the `water` tenant because Alice can deliberately create ingress with `host: water.acme.com`.

To avoid this kind of problems, Bill can deny the use of wildcard hostnames in the following way:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
    - name: alice
      kind: User
  ingressOptions:
    allowWildcardHostnames: false
```

Doing this, Alice will not be able to use `*.water.acme.com`, being the tenant owner of solar and green only.

### IngressClasses

An Ingress Controller is used in Kubernetes to publish services and applications outside of the cluster. An Ingress Controller can be provisioned to accept only Ingresses with a given Ingress Class.

Bill can assign a set of dedicated Ingress Classes to the `solar` tenant to force the applications in the `solar` tenant to be published only by the assigned Ingress Controller:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  ingressOptions:
    allowedClasses:
      matchLabels:
        env: "production"
```

With the said Tenant specification, Alice can create a Ingress resource if `spec.ingressClassName` or `metadata.annotations."kubernetes.io/ingress.class"` equals to:

* Any IngressClass which has the label `env` with the value `production`

If an Ingress is going to use a non-allowed IngressClass, it will be rejected by the Validation Webhook enforcing it.

Alice can create an Ingress using only an allowed Ingress Class:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  namespace: solar-production
spec:
  ingressClassName: legacy
  rules:
  - host: oil.acmecorp.com
    http:
      paths:
      - backend:
          service:
            name: nginx
            port:
              number: 80
        path: /
        pathType: ImplementationSpecific
```

Any attempt of Alice to use a non-valid Ingress Class, or missing it, is denied by the Validation Webhook enforcing it.

#### Assign Ingress Class as tenant default

> Note: This feature is offered only by API type IngressClass in group networking.k8s.io version v1. However, resource Ingress is supported in `networking.k8s.io/v1` and `networking.k8s.io/v1beta1`

This feature allows specifying a custom default value on a Tenant basis, bypassing the global cluster default (with the annotation metadata.`annotations.ingressclass.kubernetes.io/is-default-class=true`) that acts only at the cluster level. More information: [Default IngressClass](https://kubernetes.io/docs/concepts/services-networking/ingress/#default-ingress-class)

It's possible to assign each tenant an Ingress Class which will be used, if a class is not set on ingress basis:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  ingressOptions:
    allowedClasses:
      default: "tenant-default"
      matchLabels:
        env: "production"
```

Here's how the Tenant default IngressClass could look like:

```bash
kubectl apply -f - << EOF
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  labels:
    env: "production"
    app.kubernetes.io/component: controller
  name: tenant-default
  annotations:
    ingressclass.kubernetes.io/is-default-class: "false"
spec:
  controller: k8s.io/customer-nginx
EOF
```

If an Ingress has no value for `spec.ingressClassName` or `metadata.annotations."kubernetes.io/ingress.class"`, the `tenant-default` IngressClass is automatically applied to the Ingress resource.

### NetworkPolicies

{{% alert title="Deprecated" color="info" %}}
> This feature will be deprecated in a future release of Capsule. Instead use [TenantReplications](#networkpolicy-distribution-with-tenantreplications). This is also true if you would like other NetworkPolicy implementation like [Cilium](https://cilium.io/).
{{% /alert %}}

Kubernetes network policies control network traffic between namespaces and between pods in the same namespace. Bill, the cluster admin, can enforce network traffic isolation between different tenants while leaving to Alice, the tenant owner, the freedom to set isolation between namespaces in the same tenant or even between pods in the same namespace.

To meet this requirement, Bill needs to define network policies that deny pods belonging to Alice's namespaces to access pods in namespaces belonging to other tenants, e.g. Bob's tenant `water`, or in system namespaces, e.g. `kube-system`.

> Keep in mind, that because of how the NetworkPolicies API works, the users can still add a policy which contradicts what the Tenant has set, resulting in users being able to circumvent the initial limitation set by the tenant admin. Two options can be put in place to mitigate this potential privilege escalation: 1. providing a restricted role rather than the default admin one 2. using Calico's GlobalNetworkPolicy, or Cilium's CiliumClusterwideNetworkPolicy which are defined at the cluster-level, thus creating an order of packet filtering.
    
Also, Bill can make sure pods belonging to a tenant namespace cannot access other network infrastructures like cluster nodes, load balancers, and virtual machines running other services.

Bill can set network policies in the tenant manifest, according to the requirements:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  networkPolicies:
    items:
    - policyTypes:
      - Ingress
      - Egress
      egress:
      - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 192.168.0.0/16 
      ingress:
      - from:
        - namespaceSelector:
            matchLabels:
              capsule.clastix.io/tenant: oil
        - podSelector: {}
        - ipBlock:
            cidr: 192.168.0.0/16
      podSelector: {}
```

The Capsule controller, watching for namespace creation, creates the Network Policies for each namespace in the tenant.

Alice has access to network policies:

```bash
kubectl -n solar-production get networkpolicies
NAME              POD-SELECTOR   AGE
capsule-solar-0   <none>         42h
```

Alice can create, patch, and delete additional network policies within her namespaces:

```bash
kubectl -n solar-production auth can-i get networkpolicies
yes

kubectl -n solar-production auth can-i delete networkpolicies
yes

kubectl -n solar-production auth can-i patch networkpolicies
yes
```

For example, she can create:

```bash
kubectl apply -f - << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  labels:
  name: production-network-policy
  namespace: solar-production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
```

Check all the network policies

```bash
kubectl -n solar-production get networkpolicies
NAME                          POD-SELECTOR   AGE
capsule-solar-0               <none>         42h
production-network-policy     <none>         3m
```

And delete the namespace network policies:

```bash
kubectl -n solar-production delete networkpolicy production-network-policy
```

Any attempt of Alice to delete the tenant network policy defined in the tenant manifest is denied by the Validation Webhook enforcing it. Any deletion by a cluster-administrator will cause the network policy to be recreated by the Capsule controller.

#### NetworkPolicy Distribution with TenantReplications

In the future Cluster-Administrators must distribute NetworkPolicies via [TenantReplications](/docs/replications). This is a more flexible and powerful way to distribute NetworkPolicies, as it allows to distribute any kind of resource. Here's an example of how to distribute a `CiliumNetworkPolicy` to all the namespaces of a tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: TenantResource
metadata:
  name: solar-limitranges
  namespace: solar-system
spec:
  resyncPeriod: 60s
  resources:
    - namespaceSelector:
        matchLabels:
          capsule.clastix.io/tenant: solar
      rawItems:
        - apiVersion: "cilium.io/v2"
          kind: CiliumNetworkPolicy
          metadata:
            name: "l3-rule"
          spec:
            endpointSelector:
              matchLabels:
                role: backend
            ingress:
            - fromEndpoints:
              - matchLabels:
                  role: frontend
```

## Storage

### PersistentVolumes

Any Tenant owner is able to create a `PersistentVolumeClaim` that, backed by a given StorageClass, will provide volumes for their applications.

In most cases, once a `PersistentVolumeClaim` is deleted, the bounded `PersistentVolume` will be recycled due.

However, in some scenarios, the `StorageClass` or the provisioned `PersistentVolume` itself could change the retention policy of the volume, keeping it available for recycling and being consumable for another Pod.

In such a scenario, Capsule enforces the Volume mount only to the Namespaces belonging to the Tenant on which it's been consumed, by adding a label to the Volume as follows.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    pv.kubernetes.io/provisioned-by: rancher.io/local-path
  creationTimestamp: "2022-12-22T09:54:46Z"
  finalizers:
  - kubernetes.io/pv-protection
  labels:
    capsule.clastix.io/tenant: solar
  name: pvc-1b3aa814-3b0c-4912-9bd9-112820da38fe
  resourceVersion: "2743059"
  uid: 9836ae3e-4adb-41d2-a416-0c45c2da41ff
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 10Gi
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: melange
    namespace: caladan
    resourceVersion: "2743014"
    uid: 1b3aa814-3b0c-4912-9bd9-112820da38fe
```

Once the `PeristentVolume` become available again, it can be referenced by any `PersistentVolumeClaim` in the `solar` Tenant Namespace resources.

If another Tenant, like `green`, tries to use it, it will get an error:

```bash
$ kubectl describe pv pvc-9788f5e4-1114-419b-a830-74e7f9a33f5d
Name:              pvc-9788f5e4-1114-419b-a830-74e7f9a33f5d
Labels:            capsule.clastix.io/tenant=solar
Annotations:       pv.kubernetes.io/provisioned-by: rancher.io/local-path
Finalizers:        [kubernetes.io/pv-protection]
StorageClass:      standard
Status:            Available
...

$ cat /tmp/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: melange
  namespace:  green-energy
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
  volumeName: pvc-9788f5e4-1114-419b-a830-74e7f9a33f5d

$ kubectl apply -f /tmp/pvc.yaml
Error from server: error when creating "/tmp/pvc.yaml": admission webhook "pvc.capsule.clastix.io" denied the request: PeristentVolume pvc-9788f5e4-1114-419b-a830-74e7f9a33f5d cannot be used by the following Tenant, preventing a cross-tenant mount
```

### StorageClasses

Persistent storage infrastructure is provided to tenants. Different types of storage requirements, with different levels of QoS, eg. SSD versus HDD, are available for different tenants according to the tenant's profile. To meet these different requirements, Bill, the cluster admin can provision different Storage Classes and assign them to the tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  storageClasses:
    matchLabels:
      env: "production"
```

With the said Tenant specification, Alice can create a Persistent Volume Claims if spec.storageClassName equals to:

* Any `StorageClass` which has the label env with the value production

Capsule assures that all Persistent Volume Claims created by Alice will use only one of the valid storage classes. Assume the StorageClass `ceph-rbd` has the label `env: production`:

```bash 
kubectl apply -f - << EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: pvc
  namespace: solar-production
spec:
  storageClassName: ceph-rbd
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 12Gi
EOF
```

If a Persistent Volume Claim is going to use a non-allowed Storage Class, it will be rejected by the Validation Webhook enforcing it.

#### Assign Storage Class as tenant default

> Note: This feature supports type StorageClass only on API version `storage.k8s.io/v1`

This feature allows specifying a custom default value on a Tenant basis, bypassing the global cluster default (`.metadata.annotations.storageclass.kubernetes.io/is-default-class=true`) that acts only at the cluster level. See [the Default Storage Class](https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/) section on Kubernetes documentation.

It's possible to assign each tenant a StorageClass which will be used, if no value is set on Persistent Volume Claim basis:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: oil
spec:
  owners:
  - name: alice
    kind: User
  storageClasses:
    default: "tenant-default"
    matchLabels:
      env: "production"
```

Here's how the new Storage Class could look like:

```bash
kubectl apply -f - << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tenant-default
  labels:
    env: production
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF
```

If a Persistent Volume Claim has no value for `spec.storageClassName` the `tenant-default` value will be used on new Persistent Volume Claim resources.



## Images


### PullPolicy

Bill is a cluster admin providing a Container as a Service platform using shared nodes.

Alice, a Tenant Owner, can start container images using private images: according to the Kubernetes architecture, the kubelet will download the layers on its cache.

Bob, an attacker, could try to schedule a Pod on the same node where Alice is running her Pods backed by private images: they could start new Pods using `ImagePullPolicy=IfNotPresent` and be able to start them, even without required authentication since the image is cached on the node.

To avoid this kind of attack, Bill, the cluster admin, can force Alice, the tenant owner, to start her Pods using only the allowed values for ImagePullPolicy, enforcing the kubelet to check the authorization first.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  imagePullPolicies:
  - Always
```

Allowed values are: `Always`, `IfNotPresent`, `Never`. As defined by the [Kubernetes API](https://kubernetes.io/docs/concepts/containers/images/#image-pull-policy)

Any attempt of Alice to use a disallowed `imagePullPolicies` value is denied by the Validation Webhook enforcing it.

### Images Registries

Bill, the cluster admin, can set a strict policy on the applications running into Alice's tenant: he'd like to allow running just images hosted on a list of specific container registries.

The `spec.containerRegistries` addresses this task and can provide a combination with hard enforcement using a list of allowed values.

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  containerRegistries:
    allowed:
    - docker.io
    - quay.io
    allowedRegex: 'internal.registry.\\w.tld'
```

> In case of Pod running non-FQCI (non fully qualified container image) containers, the container registry enforcement will disallow the execution. If you would like to run a b`busybox:latest` container that is commonly hosted on Docker Hub, the Tenant Owner has to specify its name explicitly, like `docker.io/library/busybox:latest`.

A Pod running `internal.registry.foo.tld/capsule:latest` as registry will be allowed, as well `internal.registry.bar.tld` since these are matching the regular expression.

> A catch-all regex entry as `.*` allows every kind of registry, which would be the same result of unsetting `.spec.containerRegistries` at all.

Any attempt of Alice to use a not allowed `.spec.containerRegistries` value is denied by the Validation Webhook enforcing it.


## Administration


### Cordoning

Bill needs to cordon a Tenant and its Namespaces for several reasons:

  * Avoid accidental resource modification(s) including deletion during a Production Freeze Window
  * During the Kubernetes upgrade, to prevent any workload updates
  * During incidents or outages
  * During planned maintenance of a dedicated nodes pool in a BYOD scenario

With this said, the Tenant Owner and the related Service Account living into managed Namespaces, cannot proceed to any update, create or delete action.

This is possible by just toggling the specific Tenant specification:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  cordoned: true
  owners:
  - kind: User
    name: alice
```

Any operation performed by Alice, the Tenant Owner, will be rejected by the Admission controller.

Uncordoning can be done by removing the said specification key:

```bash
$ cat <<EOF | kubectl apply -f -
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  cordoned: false
  owners:
  - kind: User
    name: alice
EOF

$ kubectl --as alice --as-group projectcapsule.dev -n solar-dev create deployment nginx --image nginx
deployment.apps/nginx created
```

Status of cordoning is also reported in the state of the tenant:

```bash
kubectl get tenants
NAME     STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR    AGE
bronze   Active                     2                                  3d13h
gold     Active                     2                                  3d13h
solar    Cordoned                   4                                  2d11h
silver   Active                     2                                  3d13h
```

### Force Tenant-Prefix

Use this if you want to disable/enable the Tenant name prefix to specific Tenants, overriding global forceTenantPrefix in [CapsuleConfiguration](/docs/reference/#capsuleconfigurationspec). When set to 'true', it enforces Namespaces created for this Tenant to be named with the Tenant name prefix, separated by a dash (i.e. for Tenant 'foo', namespace names must be prefixed with 'foo-'), this is useful to avoid Namespace name collision. When set to 'false', it allows Namespaces created for this Tenant to be named anything. Overrides CapsuleConfiguration global forceTenantPrefix for the Tenant only. If unset, Tenant uses CapsuleConfiguration's forceTenantPrefix

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  forceTenantPrefix: true
```

### Deletion Protection

Sometimes it is important to protect business critical tenants from accidental deletion. This can be achieved by toggling preventDeletion specification key on the tenant:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: solar
spec:
  owners:
  - name: alice
    kind: User
  preventDeletion: true
```