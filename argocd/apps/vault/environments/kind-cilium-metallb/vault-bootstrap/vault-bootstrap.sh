#!/usr/bin/env bash

# +------------------------------------------------------------------------------------------+
# + FILE: vault-bootstrap.sh                                                                 +
# +                                                                                          +
# + AUTHOR: Saad Ali (https://github.com/NIXKnight)                                          +
# +------------------------------------------------------------------------------------------+

VAULT_INIT_OUTPUT_FILE=/tmp/vault_init
VAULT_INIT_K8S_SECRET_FILE=/tmp/vault-init-secret.yaml

# Get total number of pods in Vault StatefulSet
VAULT_PODS_IN_STATEFULSET=$(expr $(kubectl get statefulsets -o json | jq '.items[0].spec.replicas') - 1)

# Setup all Vault pods in an array
VAULT_PODS=($(seq --format='vault-%0g' --separator=" " 0 $VAULT_PODS_IN_STATEFULSET))

# Raft leaders and followers
VAULT_LEADER=${VAULT_PODS[0]}
VAULT_FOLLOWERS=("${VAULT_PODS[@]:1}")

# Wait for pod to be ready
function waitForPod {
  while [[ $(kubectl get pods $1 -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]] ; do
    echo "Waiting for pod $1 to be ready..."
    sleep 1
  done
}

# Initialize Vault
function vaultOperatorInit {
  waitForPod $1
  kubectl exec $1 -c vault -- vault operator init -format "json" > $VAULT_INIT_OUTPUT_FILE
}

# Create Kubernetes secret for Vault Unseal Keys and Root Token
function createVaultK8SInitSecret {
  cat <<EOF > $1
---
apiVersion: v1
kind: Secret
metadata:
  name: vault-init
type: Opaque
data:
$(
  local VAULT_INIT_JSON_BASE64=$(cat $2 | base64 -w0)
  echo -e "  VAULT_INIT_JSON: $VAULT_INIT_JSON_BASE64"
)
EOF
  kubectl apply -f $1
}

function unsealVault {
  local VAULT_INIT_JSON_BASE64_DECODED=$(kubectl get secrets/vault-init --template={{.data.VAULT_INIT_JSON}} | base64 -d)
  for VAULT_UNSEAL_KEY in $(jq -r '.unseal_keys_b64[]' <<< ${VAULT_INIT_JSON_BASE64_DECODED}) ; do
    waitForPod $1
    echo -e "Unsealing Vault on pod $1"
    sleep 5
    kubectl exec -it $1 -- vault operator unseal $VAULT_UNSEAL_KEY
  done
}

function joinRaftLeader() {
  waitForPod $1
  kubectl exec $1 -- vault operator raft join http://$VAULT_LEADER.vault-internal:8200

}

# Get Vault initialization status
waitForPod $VAULT_LEADER
VAULT_INIT_STATUS=$(kubectl exec $VAULT_LEADER -c vault -- vault status -format "json" | jq --raw-output '.initialized')

# If vault initialized, check if it sealed. If vault is sealed, unseal it.
# If vault is uninitialized, initialize it, create vault secret in Kubernetes
# and unseal it. Do it all on the raft leader pod (this will be vault-0).
if $VAULT_INIT_STATUS ; then
  VAULT_SEAL_STATUS=$(kubectl exec $VAULT_LEADER -c vault -- vault status -format "json" | jq --raw-output '.sealed')
  echo -e "Vault is already initialized on $VAULT_LEADER"
  if $VAULT_SEAL_STATUS ; then
    echo -e "Vault sealed on $VAULT_LEADER"
    unsealVault $VAULT_LEADER
  fi
else
  echo -e "Initializing Vault on $VAULT_LEADER"
  vaultOperatorInit $VAULT_LEADER
  echo -e "Creating Vault Kubernetes Secret vault-init"
  createVaultK8SInitSecret $VAULT_INIT_K8S_SECRET_FILE $VAULT_INIT_OUTPUT_FILE
  unsealVault $VAULT_LEADER
fi

# For all other pods, check unseal status and check if the pod is part
# of the raft cluster. If either condition is false, then do the needful.
for POD in "${VAULT_FOLLOWERS[@]}" ; do
  VAULT_TOKEN=$(kubectl get secrets/vault-init --template={{.data.VAULT_INIT_JSON}} | base64 -d | jq -r '.root_token')
  RAFT_NODES_JSON=$(kubectl exec $VAULT_LEADER -c vault -- /bin/sh -c "VAULT_TOKEN=$VAULT_TOKEN vault operator raft list-peers -format \"json\"")
  RAFT_NODES=$(echo $RAFT_NODES_JSON | jq '.data.config.servers[].address' -r)
  waitForPod $POD
  VAULT_SEAL_STATUS=$(kubectl exec $POD -c vault -- vault status -format "json" | jq --raw-output '.sealed')
  if [[ ${RAFT_NODES[@]} =~ $POD ]] ; then
    echo -e "Pod $POD is already part of raft cluster"
  else
    joinRaftLeader $POD
  fi
  if $VAULT_SEAL_STATUS ; then
    echo -e "Vault sealed on $POD"
    unsealVault $POD
  fi
done
