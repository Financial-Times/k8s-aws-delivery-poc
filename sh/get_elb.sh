#!/bin/bash
# Retrieves the API Server DNS name

# Set AWS credentials
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
export CLUSTER_NAME="${CLUSTER_NAME}"

if [[ -z ${AWS_REGION} ]]; then
   AWS_REGION="eu-west-1"
fi

# Get the API server elb and name
for elbs in $(aws elb describe-load-balancers --query LoadBalancerDescriptions[*].LoadBalancerName --region=${AWS_REGION} --output text); do
    for tags in $(aws elb describe-tags --load-balancer-names ${elbs} --region=${AWS_REGION} --query TagDescriptions[*].Tags[].Value --output text); do
        if [ "$tags" == "$CLUSTER_NAME" ]; then
            ELB_NAME=$(aws elb describe-load-balancers --load-balancer-names ${elbs} --query LoadBalancerDescriptions[*].DNSName --region=${AWS_REGION} --output text)
            break
        fi
    done
done

# if ELB not found yet search also for network load balancers
if [ -z "$ELB_NAME" ]; then
  for nlbArn in $(aws elbv2 describe-load-balancers --query LoadBalancers[*].LoadBalancerArn --region=${AWS_REGION} --output text); do
      for tag in $(aws elbv2 describe-tags --resource-arns ${nlbArn} --region=${AWS_REGION} --query TagDescriptions[*].Tags[].Value --output text); do
          if [ "$tag" == "$CLUSTER_NAME" ]; then
              ELB_NAME=$(aws elbv2 describe-load-balancers --load-balancer-arns ${nlbArn} --query LoadBalancers[*].DNSName --region=${AWS_REGION} --output text)
              break
          fi
      done
  done
fi

echo -n $ELB_NAME
