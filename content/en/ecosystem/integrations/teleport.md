---
title: Teleport
describtion: Capsule Proxy interation with Teleport
logo: https://avatars.githubusercontent.com/u/10781132?s=200&v=4
type: single
display: true
integration: true
---

[Teleport](https://goteleport.com/) is an open-source tool that provides zero trust access to servers and cloud applications using SSH, Kubernetes, Database, Remote Desktop Protocol and HTTPS. It can eliminate the need for VPNs by providing a single gateway to access computing infrastructure via SSH, Kubernetes clusters, and cloud applications via a built-in proxy.[^1]

If you want to pass requests from teleport users through the capsule-proxy for users to be able to do things like listing namespaces scoped to their own tenants, this integration is for you.

[^1]: [Teleport - Wikipedia](https://en.wikipedia.org/wiki/Teleport_(software))

## Prerequisites

1. [Capsule](/docs/operating/setup/installation/)
2. [Capsule Proxy](/docs/proxy/)
3. [Teleport Cluster](https://goteleport.com/)
4. [teleport-kube-agent](https://goteleport.com/docs/enroll-resources/kubernetes-access/getting-started/)

## Integration

It's recommended to install `teleport-kube-agent` in the `capsule-system` namespace. Otherwise you need to somehow replicate the internal ca secret to the namespace, where `teleport-kube-agent` is deployed to. For this case [Cert-Manager Trust-Bundles](https://cert-manager.io/docs/trust/trust-manager/) might be useful.

Add the following values to the `teleport-kube-agent` helm chart and you're already done:

```yaml
extraEnv:
  - name: KUBERNETES_SERVICE_HOST
    value: capsule-proxy.capsule-system.svc
  - name: KUBERNETES_SERVICE_PORT
    value: "9001"
extraVolumes:
  - name: kube-api-access-capsule
    projected:
      sources:
        - serviceAccountToken:
            path: token
        - secret:
            items:
              - key: ca
                path: ca.crt
            name: capsule-proxy
        - downwardAPI:
            items:
              - fieldRef:
                  apiVersion: v1
                  fieldPath: metadata.namespace
                path: namespace
extraVolumeMounts:
  - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
    name: kube-api-access-capsule
    readOnly: true
```

**Note**: The secret `capsule-proxy` refers to the secret which is being used by the capsule-proxy instance directly, not the self-signed-ca secret.

## Local Demo

If you want to test this integration locally, follow these steps.

### References

- <https://goteleport.com/docs/linux-demo/>
- <https://projectcapsule.dev/docs/operating/setup/installation/>
- <https://projectcapsule.dev/docs/proxy/installation/>

### Tools

The following tools have to be installed on your machine:

- docker
- kind
- kubectl
- helm
- mkcert

### Docker Network

Create docker network `teleport`:

  ```bash
  docker network create teleport
  ```

### Self-signed certificates

Create certificates for `teleport.demo`:

  ```bash
  mkdir teleport-tls
  cd teleport-tls
  mkcert teleport.demo "*.teleport.demo"
  cp "$(mkcert -CAROOT)/rootCA.pem" .
  ```

## Teleport installation

- Run Ubuntu docker image in the `teleport` network using `teleport.demo` alias on port `443`:

    ```bash
    docker run -it -v .:/etc/teleport-tls --name teleport --network teleport --network-alias teleport.demo -p 443:443 ubuntu:22.04
    ```

- Run the following commands inside docker container:

  - `apt-get update && apt-get install -y curl`
  - `cp /etc/teleport-tls/rootCA.pem /etc/ssl/certs/mkcertCA.pem`
  - `curl https://cdn.teleport.dev/install.sh | bash -s 18.2.1`

  - ```bash
    teleport configure -o file \
      --cluster-name=teleport.demo \
      --public-addr=teleport.demo:443 \
      --cert-file=/etc/teleport-tls/teleport.demo+1.pem \
      --key-file=/etc/teleport-tls/teleport.demo+1-key.pem
    ```

  - `teleport start --config="/etc/teleport.yaml"`

- Open new shell
- Note down IP of docker container:

  ```bash
  docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' teleport
  ```

## Kubernetes Cluster setup

- Create kind cluster: `kind create cluster --name capsule`

### CoreDNS

To allow pods to easily connect to the teleport service running in the other Docker container:

- Connect to docker network: `docker network connect teleport capsule-control-plane`
- Edit ConfigMap of coredns to set up dns resolution of teleport.demo: `kubectl edit cm -n kube-system coredns`

  - ```bash
    hosts {
        <Paste IP from docker inspect command here> teleport.demo
        fallthrough
    }
    ```

- Restart coredns Deployment: `kubectl rollout restart deployment -n kube-system coredns`

### Capsule

capsule-values.yaml:

```yaml
manager:
  options:
    capsuleUserGroups: ["tenant-oil"]
    forceTenantPrefix: true
```

tenant.yaml:

```yaml
apiVersion: capsule.clastix.io/v1beta2
kind: Tenant
metadata:
  name: oil
spec:
  owners:
  - name: alice
    kind: User
```

Install `capsule` with `tenant-oil` as a capsule user group via helm chart:

- `helm repo add projectcapsule https://projectcapsule.github.io/charts`
- `helm upgrade --install capsule -n capsule-system --create-namespace projectcapsule/capsule --version 0.10.9 -f capsule-values.yaml`
- Create tenant named `oil`: `kubectl apply -f tenant.yaml`

### Capsule Proxy

Install default `capsule-proxy` via helm chart:

- `helm repo add projectcapsule https://projectcapsule.github.io/charts`
- `helm upgrade --install capsule-proxy -n capsule-system projectcapsule/capsule-proxy --version 0.9.12`

### Teleport

Create teleport role for kubernetes cluster access which adds `tenant-oil` group to user auth token.

- `docker exec -it teleport bash`

- ```bash
  cat <<EOF > role.yaml
  kind: role
  metadata:
    labels:
      capsule: "true"
    name: kube-access
  version: v8
  spec:
    allow:
      kubernetes_groups:
      - tenant-oil
      kubernetes_labels:
        capsule: "true"
      kubernetes_resources:
      - api_group: '*'
        kind: '*'
        name: '*'
        namespace: '*'
        verbs:
        - '*'
      kubernetes_users:
      - alice
  EOF
  ```

- `tctl create role.yaml`

Create and set up user `alice` with `kube-access` teleport role:

- `tctl users add alice --roles=access,kube-access`
- Add `127.0.0.1      teleport.demo` to `etc/hosts` of your computer
- Set password and second factor for user `alice` in browser

Create join token for `teleport-kube-agent`:

- Note down `authToken` from command: `tctl tokens add --type=kube --ttl=24h`

### Teleport Agent

teleport-agent-values.yaml:

```yaml
proxyAddr: "teleport.demo:443"
kubeClusterName: "teleport.demo"
insecureSkipProxyTLSVerify: true
authToken: "<Paste authToken from tctl tokens add command here>"
labels:
  capsule: "true"
extraEnv:
  - name: KUBERNETES_SERVICE_HOST
    value: capsule-proxy.capsule-system.svc
  - name: KUBERNETES_SERVICE_PORT
    value: "9001"
extraVolumes:
  - name: kube-api-access-capsule
    projected:
      sources:
        - serviceAccountToken:
            path: token
        - secret:
            items:
              - key: ca
                path: ca.crt
            name: capsule-proxy
        - downwardAPI:
            items:
              - fieldRef:
                  apiVersion: v1
                  fieldPath: metadata.namespace
                path: namespace
extraVolumeMounts:
  - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
    name: kube-api-access-capsule
    readOnly: true
```

- Update `authToken` in `teleport-agent-values.yaml` from output of `tctl tokens add` command
- `helm repo add teleport https://charts.releases.teleport.dev`
- `helm upgrade --install teleport-agent -n capsule-system teleport/teleport-kube-agent --version 18.2.0 -f teleport-agent-values.yaml`

## Test it out

- `tsh login --proxy=teleport.demo:443 --auth=local --user=alice teleport.demo`
- `tsh kube login teleport.demo`
- `kubectl get tenant`
- `kubectl get namespace` (only works because teleport is connected to capsule-proxy instead of kubernetes api)
- `kubectl create ns foo-bar` (should fail, since not owner)
- `kubectl create ns oil-bar` (should succeed)

From here you could enable `ProxyClusterScoped` [feature gate](https://projectcapsule.dev/docs/proxy/options/) to allow listing of cluster scoped resources via [ProxySettings](https://projectcapsule.dev/docs/proxy/proxysettings/).

## Cleanup

- `kind delete clusters capsule`
- `rm -rf teleport-tls`
- `tsh logout --proxy=teleport.demo --user alice`
- `docker rm teleport`
