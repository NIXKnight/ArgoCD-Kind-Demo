# **ArgoCD Demo with Kind Cluster**

This repository demonstrates how to set up ArgoCD on Kubernetes clusters provisioned with Kind (Kubernetes in Docker). It provides two configurations:
* Simple Kind Cluster.
* Kind Cluster with Cilium for networking and MetalLB for load balancing.

# **Prerequisites**
Before starting, ensure the following:
* Docker is installed and running.
* Helm is installed.
* Kind is installed.

# **Provisioning a Kind Cluster**
Before setting up ArgoCD, you need to provision a Kind cluster. Use the appropriate configuration based on your desired cluster setup.

## **Simple Kind Cluster**

```bash
kind create cluster --config argocd/environments/kind-simple/cluster-config/config.yaml
```

## **Kind Cluster with Cilium and MetalLB**
```bash
kind create cluster --config argocd/environments/kind-cilium-metallb/cluster-config/config.yaml
```
Download the Cilium image and load it into all kind nodes:
```bash
docker pull cilium/cilium:v1.15.0
kind load docker-image cilium/cilium:v1.15.0 --name cilium-metallb
```
Install Cilium with the following command:
```bash
pushd argocd/apps/cilium/ && helm dependency build && popd
helm template cilium argocd/apps/cilium/ --namespace kube-system \
  -f argocd/apps/cilium/environments/kind-cilium-metallb/values.yaml | \
  kubectl -n kube-system apply -f -
```
# **Add ArgoCD Repository Credentials**
Add your Git repository’s private SSH key to ArgoCD for accessing the repository:
```bash
kubectl create namespace argoproj
kubectl create secret generic argocd-repo-creds-ssh-creds \
  --from-literal=url=git@github.com:NIXKnight/ArgoCD-Demo.git \
  --from-file=sshPrivateKey=$HOME/.ssh/id_rsa -o json --dry-run=client | \
   jq '.metadata.labels |= {"argocd.argoproj.io/secret-type": "repo-creds"}' | \
   kubectl -n argoproj apply -f -
```

# **Install ArgoCD**
Install ArgoCD using the appropriate `values.yaml` file for your cluster environment.

## **For Simple Kind Cluster**
```bash
pushd argocd/apps/argoproj/ && helm dependency build && popd
helm template argoproj argocd/apps/argoproj/ --namespace argoproj \
  -f argocd/apps/argoproj/environments/kind-simple/values.yaml | \
  kubectl -n argoproj apply -f -
```
## **For Kind Cluster with Cilium and MetalLB**
```bash
pushd argocd/apps/argoproj/ && helm dependency build && popd
helm template argoproj argocd/apps/argoproj/ --namespace argoproj \
  -f argocd/apps/argoproj/environments/kind-cilium-metallb/values.yaml | \
  kubectl -n argoproj apply -f -
```
# **Apply App of Apps Manifest**
Once ArgoCD is installed you need to install **App of Apps** using `kustomize` which is defined under `argocd/environments/<environment>/` and installs the apps defined under `argocd/environments/<environment>/base`:
## **For Simple Kind Cluster**
```bash
kubectl wait --namespace argoproj --for=condition=ready pod --selector=app.kubernetes.io/component=repo-server --timeout=300s
kustomize build argocd/environments/kind-simple/ | kubectl apply -f -

```
## **For Kind Cluster with Cilium and MetalLB**
```bash
kubectl wait --namespace argoproj --for=condition=ready pod --selector=app.kubernetes.io/component=repo-server --timeout=300s && \
  kustomize build argocd/environments/kind-cilium-metallb/ | kubectl apply -f -

```
