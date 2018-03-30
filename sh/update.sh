#!/bin/bash

# Create Ansible Vault credentials
echo ${VAULT_PASS} > /ansible/vault.pass
cd /ansible

ansible-playbook --vault-password-file=vault.pass update.yaml --extra-vars "\
aws_region=${AWS_REGION} \
aws_access_key=${AWS_ACCESS_KEY} \
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY} \
cluster_name=${CLUSTER_NAME} \
platform=${PLATFORM} \
cluster_environment=${CLUSTER_ENVIRONMENT} \
oidc_issuerurl=${OIDC_ISSUER_URL} \
environment_type=${ENVIRONMENT_TYPE} "
