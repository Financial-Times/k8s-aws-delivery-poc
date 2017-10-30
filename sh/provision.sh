#!/bin/bash

CONFIGS_FOLDER=cluster-configs

# Set AWS credentials
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"

# Generate the cluster config file from the template
if [ ! -f ${CONFIGS_FOLDER}/${CLUSTER}.properties ]; then
    echo "Cluster config file not found"
else
    /bin/sh generate_cluster_config.sh ${CLUSTER}
fi

# Create the TLS assets for the cluster
kube-aws render credentials --generate-ca

# Get the parameters for the provisioner
API_DNS=$(grep API_DNS_NAME ${CONFIGS_FOLDER}/${CLUSTER}.properties | cut -d '=' -f 2- | cut -d '.' -f -1 )
ENVIRONMENT_TYPE=$(grep TAGS.environment ${CONFIGS_FOLDER}/${CLUSTER}.properties | cut -d '=' -f 2- )
REGION=$(grep REGION ${CONFIGS_FOLDER}/${CLUSTER}.properties | cut -d '=' -f 2- )
VPC=$(grep VPC_ID ${CONFIGS_FOLDER}/${CLUSTER}.properties | cut -d '=' -f 2- )
CLUSTER_NAME=$(grep CLUSTER_NAME ${CONFIGS_FOLDER}/${CLUSTER}.properties | cut -d '=' -f 2- )

# Set the provisioner bucket
case ${ENVIRONMENT_TYPE} in
    d)
        case "${REGION}" in
            eu-west-1)
                PROVISIONER_BUCKET="k8s-provisioner-test-eu" ;;
            us-east-1)
                PROVISIONER_BUCKET="k8s-provisioner-test-us" ;;
            *)
                echo "AWS region is not set."
        esac ;;
    p|t)
        case "${REGION}" in
            eu-west-1)
                PROVISIONER_BUCKET="k8s-provisioner-prod-eu" ;;
            us-east-1)
                PROVISIONER_BUCKET="k8s-provisioner-prod-us" ;;
            *)
                echo "AWS region is not set."
        esac ;;
    *)
        echo "Environment type is not set."
esac

# Validate the config
kube-aws validate --s3-uri s3://${PROVISIONER_BUCKET}

# Create the stack
kube-aws up --s3-uri s3://${PROVISIONER_BUCKET}

# Tag the subnets with the cluster value
for subnet in $(aws ec2 describe-subnets --filters Name=vpc-id,Values=${VPC} --query Subnets[*].SubnetId --region=${REGION} --output text); do
    aws ec2 create-tags --resources ${subnet} --tags Key=kubernetes.io/cluster/${CLUSTER_NAME},Value=true --region=${REGION}
done
echo "All public and private subnets are tagged with the kubernetes tag kubernetes.io/cluster/${CLUSTER_NAME}"

# Get the API server elb and name
for elbs in $(aws elb describe-load-balancers --query LoadBalancerDescriptions[*].LoadBalancerName --region=${REGION} --output text); do
    for tags in $(aws elb describe-tags --load-balancer-names ${elbs} --region=${REGION} --query TagDescriptions[*].Tags[].Value --output text); do
        if [ "$tags" == "$CLUSTER_NAME" ]; then
            ELB_NAME=$(aws elb describe-load-balancers --load-balancer-names ${elbs} --query LoadBalancerDescriptions[*].DNSName --region=${REGION} --output text)
            break
        fi
    done
done

# Replace api dns name and elb in the json file
sed -i "s#API_DNS#$API_DNS#g" stack-templates/api-server-dns.json
sed -i "s#ELB_NAME#$ELB_NAME#g" stack-templates/api-server-dns.json

# Create a cname using konstructor api
curl -X POST "https://dns-api.in.ft.com/v2" --header "Content-Type: application/json" --header "Accept: application/json" --header "x-api-key: ${KONSTRUCTOR_API_KEY}" -d @stack-templates/api-server-dns.json
