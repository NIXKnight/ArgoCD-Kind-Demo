# **ArgoCD Demo with Kind Cluster**

## **Kind Cluster**

Provision the cluster:
```bash
kind create cluster --config argocd/environments/kind/scripts/kind-cluster-config.yaml
```

Use any one of the CNI modules listed below.

### **Setup Cilium in Kind**
Download Cilium container image and load it to all Kind nodes:
```bash
docker pull cilium/cilium:v1.15.0 && kind load docker-image cilium/cilium:v1.15.0 --name kind
```
Install Cilium:
```bash
pushd argocd/apps/cilium/ && helm dependency build && popd
helm template cilium argocd/apps/cilium/ --namespace kube-system -f argocd/apps/cilium/environments/kind/values.yaml | kubectl -n kube-system apply -f -
```

### **Setup Calico in Kind**

**NOTE:** These instructions for Calico are outdated at the moment, will be updated later on. Don't use Calico with this repo for now.

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
kubectl create namespace argoproj && kubectl -n argoproj create secret generic argocd-repo-creds-ssh-creds --from-literal=url=git@github.com:NIXKnight/ArgoCD-Demo.git --from-file=sshPrivateKey=$HOME/.ssh/id_rsa -o json --dry-run=client | jq '.metadata.labels |= {"argocd.argoproj.io/secret-type": "repo-creds"}' | kubectl apply -f -
```
Install ArgoCD:
```bash
pushd argocd/apps/argoproj/ && helm dependency build && popd
helm template argoproj argocd/apps/argoproj/ --namespace argoproj -f argocd/apps/argoproj/environments/kind/values.yaml | kubectl -n argoproj apply -f -
```
Deploy apps with ArgoCD:
```bash
kustomize build argocd/environments/kind/ | kubectl apply -f -
```
