---
title: Quickstart
type: docs
weight: 1
description: "Create your first Capsule Tenant"
---

In Capsule, a Tenant is an abstraction to group multiple namespaces in a single entity within a set of boundaries defined by the Cluster Administrator. The tenant is then assigned to a user or group of users who is called [Tenant Owner](/docs/overview/architecture#ownership). Capsule defines a Tenant as Custom Resource with cluster scope. Create the tenant as cluster admin:

```bash
kubectl create -f - << EOF
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: oil
spec:
  owners:
  - name: alice
    kind: User
EOF
```

You can check the tenant just created

```bash
$ kubectl get tenants
NAME   STATE    NAMESPACE QUOTA   NAMESPACE COUNT   NODE SELECTOR   AGE
solar    Active                     0                                 10s
```

## Login as Tenant Owner

Each tenant comes with a delegated user or group of users acting as the tenant admin. In the Capsule jargon, this is called the [Tenant Owner](/docs/concepts/ownership/). Other users can operate inside a tenant with different levels of permissions and authorizations assigned directly by the Tenant Owner.

Capsule does not care about the authentication strategy used in the cluster and all the Kubernetes methods of authentication are supported. The only requirement to use Capsule is to assign tenant users to the group defined by --capsule-user-group option, which defaults to `capsule.clastix.io`.

Assignment to a group depends on the authentication strategy in your cluster.

For example, if you are using capsule.clastix.io, users authenticated through a X.509 certificate must have capsule.clastix.io as Organization: `-subj "/CN=${USER}/O=capsule.clastix.io"`

Users authenticated through an OIDC token must have in their token:

```
...
"users_groups": [
  "capsule.clastix.io",
  "other_group"
]
```

The [hack/create-user.sh](https://github.com/projectcapsule/capsule/blob/main/hack/create-user.sh) can help you set up a dummy kubeconfig for the alice user acting as owner of a tenant called solar.

```bash
./hack/create-user.sh alice solar
...
certificatesigningrequest.certificates.k8s.io/alice-solar created
certificatesigningrequest.certificates.k8s.io/alice-solar approved
kubeconfig file is: alice-solar.kubeconfig
to use it as alice export KUBECONFIG=alice-solar.kubeconfig
```

Login as tenant owner

```bash
$ export KUBECONFIG=alice-solar.kubeconfig
```

### Impersonation

You can simulate this behavior by using [impersonation](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#user-impersonation):

```bash
kubectl --as alice --as-group capsule.clastix.io ...
```

## Create namespaces

As tenant owner, you can create namespaces:

```bash
$ kubectl create namespace solar-production
$ kubectl create namespace solar-development
```

or 

```bash
$ kubectl --as alice --as-group capsule.clastix.io create namespace solar-production
$ kubectl --as alice --as-group capsule.clastix.io create namespace solar-development
```

And operate with fully admin permissions:

```bash
$ kubectl -n solar-development run nginx --image=docker.io/nginx 
$ kubectl -n solar-development get pods
```

## Limiting access

Tenant Owners have full administrative permissions limited to only the namespaces in the assigned tenant. They can create any namespaced resource in their namespaces but they do not have access to cluster resources or resources belonging to other tenants they do not own:

```bash
$ kubectl -n kube-system get pods
Error from server (Forbidden): pods is forbidden:
User "alice" cannot list resource "pods" in API group "" in the namespace "kube-system"
```

See the [concepts](/docs/concepts) for getting more cool things you can do with Capsule.