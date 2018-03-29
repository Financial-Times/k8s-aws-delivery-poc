#!/bin/bash

# Create Ansible Vault credentials
echo ${VAULT_PASS} > /ansible/vault.pass
cd /ansible

ansible-playbook --vault-password-file=vault.pass decom.yaml --extra-vars "\
aws_region=${AWS_REGION} \
aws_access_key=${AWS_ACCESS_KEY} \
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY} \
cluster_name=${CLUSTER_NAME} \
cluster_environment=${CLUSTER_ENVIRONMENT} \
environment_type=${ENVIRONMENT_TYPE} \
konstructor_api_key=${KONSTRUCTOR_API_KEY} \
platform=${PLATFORM} "
