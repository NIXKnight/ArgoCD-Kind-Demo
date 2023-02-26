# **ArgoCD Demo with Kind Cluster**

## **Kind Cluster**

Provision the cluster:
```bash
kind create cluster --config argocd/environments/kind/scripts/kind-cluster-config.yaml
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
kubectl create namespace argoproj && kubectl -n argoproj create secret generic argocd-repo-creds-ssh-creds --from-literal=url=git@github.com:NIXKnight/ArgoCD-Demo.git --from-file=sshPrivateKey=$HOME/.ssh/id_rsa -o json --dry-run=client | jq '.metadata.labels |= {"argocd.argoproj.io/secret-type": "repo-creds"}' | kubectl apply -f -
```
Install ArgoCD:
```bash
helm install argocd argocd/apps/argo-cd/ --namespace argoproj -f argocd/apps/argo-cd/environments/kind/values.yaml
```
Deploy apps with ArgoCD:
```bash
kustomize build argocd/environments/kind/ | kubectl apply -f -
```
