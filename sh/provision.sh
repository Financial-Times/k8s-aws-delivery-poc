#!/bin/bash

cd /ansible

ansible-playbook provision.yaml --extra-vars "\
aws_region=${AWS_REGION} \
aws_access_key=${AWS_ACCESS_KEY_ID} \
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY} \
cluster_name=${CLUSTER_NAME} \
platform=${PLATFORM} \
environment_type=${ENVIRONMENT_TYPE} \
cluster_environment=${CLUSTER_ENVIRONMENT} \
konstructor_api_key=${KONSTRUCTOR_API_KEY} \
oidc_issuer_url=${OIDC_ISSUER_URL}"
