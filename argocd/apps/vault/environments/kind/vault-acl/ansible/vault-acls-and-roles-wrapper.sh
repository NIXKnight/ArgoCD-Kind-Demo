#!/usr/bin/env bash

# +------------------------------------------------------------------------------------------+
# + FILE: vault-acls-and-roles-wrapper.sh                                                    +
# +                                                                                          +
# + AUTHOR: Saad Ali (https://github.com/NIXKnight)                                          +
# +------------------------------------------------------------------------------------------+

export K8S_API_SERVER="https://$KUBERNETES_SERVICE_HOST"
export K8S_SERVICEACCOUNT_DIR="/var/run/secrets/kubernetes.io/serviceaccount"
export K8S_NAMESPACE="$(cat $K8S_SERVICEACCOUNT_DIR/namespace)"
export K8S_AUTH_TOKEN="$(cat $K8S_SERVICEACCOUNT_DIR/token)"
export K8S_AUTH_SSL_CA_CERT="$K8S_SERVICEACCOUNT_DIR/ca.crt"

export VAULT_ADDR="http://$VAULT_SERVICE_HOST:$VAULT_SERVICE_PORT"
export VAULT_TOKEN=$(curl --cacert $K8S_AUTH_SSL_CA_CERT --header "Authorization: Bearer $K8S_AUTH_TOKEN" -X GET $K8S_API_SERVER/api/v1/namespaces/vault/secrets/vault-init | jq -r ".data.VAULT_INIT_JSON" |base64 -d | jq -r '.root_token')

export ANSIBLE_STDOUT_CALLBACK="debug"
export ANSIBLE_CALLBACKS_ENABLED="profile_tasks"

cd /vault-acl/
ansible-playbook vault-acls-and-roles-playbook.yaml -vv
