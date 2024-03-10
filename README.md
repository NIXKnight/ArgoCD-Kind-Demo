# **ArgoCD Demo with Kind Cluster**

## **Simple Kind Cluster**

Provision a simple cluster with default CNI:
```bash
kind create cluster --config argocd/environments/kind-simple/cluster-config/config.yaml
```

## **ArgoCD Initial Setup on Kind**
Add private key for ArgoCD repo:
```bash
kubectl create namespace argoproj && kubectl create secret generic argocd-repo-creds-ssh-creds --from-literal=url=git@github.com:NIXKnight/ArgoCD-Demo.git --from-file=sshPrivateKey=$HOME/.ssh/id_rsa -o json --dry-run=client | jq '.metadata.labels |= {"argocd.argoproj.io/secret-type": "repo-creds"}' | kubectl -n argoproj apply -f -
```
Install ArgoCD and deploy apps:
```bash
pushd argocd/apps/argoproj/ && helm dependency build && popd
helm template argoproj argocd/apps/argoproj/ --namespace argoproj -f argocd/apps/argoproj/environments/kind-simple/values.yaml | kubectl -n argoproj apply -f - && kubectl wait --namespace argoproj --for=condition=ready pod --selector=app.kubernetes.io/component=repo-server --timeout=300s && kustomize build argocd/environments/kind-simple/ | kubectl apply -f -
```
