# **ArgoCD Demo with Kind Cluster**

## **Kind Cluster**

```yaml
# four node (3 workers) cluster config
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: caldera # any name
networking:
  ipFamily: ipv4
  disableDefaultCNI: true # Use Cilium
  podSubnet: "10.10.0.0/16"
  serviceSubnet: "10.11.0.0/16"
nodes:
  - role: control-plane
    image: kindest/node:v1.22.0
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        name: "control-plane"
# Use the following snippet in Kind for the control-plane if you plan on using the default Kind CNI and not use Cilium.
#     kubeletExtraArgs:
    #       node-labels: "ingress-ready=true"
    # extraPortMappings:
    # - { containerPort: 80, hostPort: 80, protocol: TCP }
    # - { containerPort: 443, hostPort: 443, protocol: TCP }
  - role: worker
    image: kindest/node:v1.22.0
    kubeadmConfigPatches:
    - |
      kind: JoinConfiguration
      nodeRegistration:
        name: "worker-01"
        kubeletExtraArgs:
          node-labels: "NodeGroup=Tools-NodeGroup"
    # extraMounts:
    #   - { hostPath: "/home/saadali/Projects/Kubernetes/Kind/worker-01", containerPath: "/var/local-path-provisioner" }
  - role: worker
    image: kindest/node:v1.22.0
    kubeadmConfigPatches:
    - |
      kind: JoinConfiguration
      nodeRegistration:
        name: "worker-02"
        kubeletExtraArgs:
          node-labels: "NodeGroup=Other-NodeGroup"
    # extraMounts:
    #   - { hostPath: "/home/saadali/Projects/Kubernetes/Kind/worker-02", containerPath: "/var/local-path-provisioner" }
  - role: worker
    image: kindest/node:v1.22.0
    kubeadmConfigPatches:
    - |
      kind: JoinConfiguration
      nodeRegistration:
        name: "worker-03"
        kubeletExtraArgs:
          node-labels: "NodeGroup=Other-NodeGroup"
    # extraMounts:
    #   - { hostPath: "/home/saadali/Projects/Kubernetes/Kind/worker-03", containerPath: "/var/local-path-provisioner" }
```
Provision the cluster:
```bash
kind create cluster --config kind-caldera-cluster.yaml
```

Use any one of the CNI modules listed below.

## **Setup Cilium in Kind**
Download Cilium container image and load it to all Kind nodes:
```bash
docker pull cilium/cilium:v1.13.0
kind load docker-image cilium/cilium:v1.13.0 --name caldera
```
Install Cilium:
```bash
helm install cilium argocd/apps/cilium/ --namespace kube-system -f argocd/apps/cilium/environments/kind/values.yaml
```

## **Setup Calico in Kind**
Download Calico container images and load them to all Kind nodes:
```bash
docker pull docker.io/calico/cni:v3.23.0
docker pull docker.io/calico/node:v3.23.0
docker pull docker.io/calico/kube-controllers:v3.23.0
kind load docker-image docker.io/calico/cni:v3.23.0 --name caldera
kind load docker-image docker.io/calico/node:v3.23.0 --name caldera
kind load docker-image docker.io/calico/kube-controllers:v3.23.0 --name caldera

```
Install Calico using Calico's manifest:
```bash
kubectl apply -f https://docs.projectcalico.org/v3.23/manifests/calico.yaml
```

## **ArgoCD Initial Setup on Kind**
Add private key for ArgoCD repo:
```bash
kubectl create namespace argoproj
kubectl -n argoproj create secret generic argocd-repo-creds-ssh-creds --from-literal=url=git@github.com:NIXKnight/ArgoCD-Demo.git --from-file=sshPrivateKey=$HOME/.ssh/id_rsa -o json --dry-run=client | jq '.metadata.labels |= {"argocd.argoproj.io/secret-type": "repo-creds"}' | kubectl apply -f -
```
Install ArgoCD:
```bash
helm install argocd argocd/apps/argo-cd/ --namespace argoproj -f argocd/apps/argo-cd/environments/kind/values.yaml
```
Deploy apps with ArgoCD:
```bash
kustomize build argocd/environments/kind/ | kubectl apply -f -
```
