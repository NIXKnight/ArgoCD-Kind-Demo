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
