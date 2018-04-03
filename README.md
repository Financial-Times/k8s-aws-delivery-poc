# USE https://github.com/Financial-Times/upp-global-configs FOR GLOBAL CONFIGS

## Description
This repository contains the files required to provision clusters using Kubernetes on AWS for UPP (delivery, publishing, neo4j) and PAC platforms.

It uses [kube-aws](https://coreos.com/kubernetes/docs/latest/kubernetes-on-aws.html) for provisioning the cluster on AWS.

## Prerequisites
1. [Install docker](https://docs.docker.com/engine/installation/) locally
2. [Install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-binary-via-curl), the latest version (preferably >1.8). OSX users can install using brew.
```
brew install kubernetes-cli
```
You can check the client version by running 
```
kubectl version
```
3. [Install helm](https://github.com/kubernetes/helm#install), the latest version (preferably >2.7).

## Building the Docker image
The k8s provisioner can be built locally as a Docker image:

```
docker build -t k8s-provisioner:local .
```

##  Provisioning a new cluster

Here are the steps for provisioning a new cluster:

1. [Build your docker image locally](#building-the-docker-image)
1. Set the environment variables to provision a cluster. The variables are stored in LastPass:
    - For PAC Cluster: LP note "PAC - k8s Cluster Provisioning env variables"
    - For UPP Cluster: LP note "UPP - k8s Cluster Provisioning env variables"
1. Create an empty folder named `credentials` in the current folder    
1. Determine the credentials TLS assets to be used by the cluster and for logging into the cluster
    1. For sharing the authentication credentials with another cluster, meaning that you will be able to access 
    using `kubectl` both clusters with the same TLS certificates:
        1. place the certificates `ca.pem` and `ca-key.pem` in the `credentials` folder. These can be found zipped in the LassPass note from step 2. 
        1. set the env var ```export SHARE_CLUSTER_CREDENTIALS=y```
    1. For creating a new set of authentication credentials for a brand new cluster
        1. leave the `credentials` folder empty
        1. set the env var ```export SHARE_CLUSTER_CREDENTIALS=n```  
1. Run the docker container that will provision the stack in AWS 
    ```
    docker run \
        -v $(pwd)/credentials:/ansible/credentials \
        -e "AWS_REGION=$AWS_REGION" \
        -e "AWS_ACCESS_KEY=$AWS_ACCESS_KEY" \
        -e "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" \
        -e "CLUSTER_NAME=$CLUSTER_NAME" \
        -e "CLUSTER_ENVIRONMENT=$CLUSTER_ENVIRONMENT" \
        -e "ENVIRONMENT_TYPE=$ENVIRONMENT_TYPE" \
        -e "KONSTRUCTOR_API_KEY=$KONSTRUCTOR_API_KEY" \
        -e "OIDC_ISSUER_URL=$OIDC_ISSUER_URL" \
        -e "SHARE_CLUSTER_CREDENTIALS=$SHARE_CLUSTER_CREDENTIALS" \
        -e "PLATFORM=$PLATFORM" \
        -e "VAULT_PASS=$VAULT_PASS" \
        k8s-provisioner:local /bin/bash provision.sh
    ```    
1. Once the stack is created, update the kubeconfig file with the API servers DNS name and test if you can connect to the cluster by doing
    ```
    kubectl cluster-info
    ```
1. `VERY IMPORTANT`: Zip the credentials folder and upload it in the LastPass node from step 2.
    ```
    export CLUSTER_NAME=_the_name_of_the_cluster_as_outputted_by_the_stack_creation_
    mv credentials credentials.${CLUSTER_NAME}
    zip -r ${CLUSTER_NAME}.zip credentials.${CLUSTER_NAME}
    ```
    These initial credentials are vital for subsequent updates in the cluster.

The following steps have to be manually done:

1. Connect to the cluster and grant admin to the default user
```
kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=default:default
```
1. Add the new environment to the jenkins pipeline. Instructions can be found [here](https://github.com/Financial-Times/k8s-pipeline-library#what-to-do-when-adding-a-new-environment). 
1. Make sure you have defined the credentials for the new cluster in Jenkins.
1. [Just for UPP Clusters] Create/ amend the app-configs for the [upp-global-configs](https://github.com/Financial-Times/upp-global-configs/tree/master/helm/upp-global-configs/app-configs) repository. Release and deploy a new version of this app to the new environment using this [Jenkins Job](https://upp-k8s-jenkins.in.ft.com/job/k8s-deployment/job/apps-deployment/job/upp-global-configs-auto-deploy/)
1. Deploy all the apps necessary in the current cluster. This can be done in 2 ways:
    1. One slower way, but which is fire & forget: synchronize the cluster with an already existing cluster using this [Jenkins Job](https://upp-k8s-jenkins.in.ft.com/job/k8s-deployment/job/utils/job/diff-between-envs/).
    1. One quick way, but this would require some more manual steps: [Restore](#restore-k8s-config) the config from a S3 backup of another cluster 
1. Connect through SSH to one of the etcd servers and use the command “etcdctl mk <key> <value>” to introduce the following etcd keys needed for forwarding the logs to splunk
    ```
    /ft/config/public_address {clusters_dns_name_without_region - ex: upp-dev-cj-publish.ft.com}
    /ft/config/splunk-forwarder/bucket_name {s3_bucket_name_for_logs, pattern: splunklogs-upp-[env] - ex: splunklogs-upp-dev-cj}
    /ft/config/splunk-forwarder/aws_region {s3_aws_region}
    /ft/config/splunk-forwarder/aws_access_key_id {s3_aws_access_key_id}
    /ft/config/splunk-forwarder/aws_secret_access_key {s3_aws_secret_access_key_id}
    /ft/config/splunk-forwarder/batchsize {log_msgs_batch_size, default value: 100}
    /ft/config/environment_tag {environment_name, ex: upp-dev-cj-publish-eu}
    ```
    The Splunk hec token and the url can be found in lastpass.

    ```
    ## For UPP Dev clusters
    ## LastPass: content-test: Splunk HEC token
    ## For UPP Prod & Staging clusters
    ## LastPass: content-prod: Splunk HEC token
    ## For PAC Prod Clusters
    ## LastPas: PAC - Splunk HEC Token
    ```
1. If this is a test/team cluster that needs to be shutdown over night please put the `ec2Powercycle` tag on the autoscaling groups in the cluster.
You can do this from the AWS console:
    1. [Login](https://awslogin.in.ft.com) to the cluster's account
    1. Go to Ec2 -> Auto Scaling Groups 
    1. Select ASG, go to Tags, and add the `ec2Powercycle` tag. Example value:
    ```
    { "start":"30 6 * * 1-5", "stop": "30 18 * * 1-5", "desired": 2, "min": 2}
    ```
    Make sure you get the `desired` and `min` values in sync with the current ASG's values
     
##  Updating a cluster

**Before updating the cluster make sure you put the initial credentials(certificates & keys) that were used when 
the cluster was initially provisioned in the /credentials folder. Failure in doing this will damage the cluster**
 
```
## Login credentials and the environments variables are stored in LastPass
## For PAC Cluster
## LastPass: PAC - k8s Cluster Provisioning env variables
## For UPP Cluster
## LastPass: UPP - k8s Cluster Provisioning env variables

docker run \
    -v $(pwd)/credentials:/ansible/credentials \
    -e "AWS_REGION=$AWS_REGION" \
    -e "AWS_ACCESS_KEY=$AWS_ACCESS_KEY" \
    -e "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" \
    -e "CLUSTER_NAME=$CLUSTER_NAME" \
    -e "CLUSTER_ENVIRONMENT=$CLUSTER_ENVIRONMENT" \
    -e "ENVIRONMENT_TYPE=$ENVIRONMENT_TYPE" \
    -e "OIDC_ISSUER_URL=$OIDC_ISSUER_URL" \
    -e "PLATFORM=$PLATFORM" \
    -e "VAULT_PASS=$VAULT_PASS" \
    k8s-provisioner:local /bin/bash update.sh
```

##  Restore k8s Config

`kube-resources-autosave` on kubernetes is a pod which takes and uploads snapshots of all the kubernetes resources to an S3 bucket in 24 hours interval. The backups are stored in a timestamped folder in the S3 bucket in the following format.
```
s3://<s3-bucket-name>/kube-aws/clusters/<cluster-name>/backup/<backup_timestamped_folder>
```
To restore the k8s cluster state, do the following:
1. Before restoring make sure you have deployed the following apps, using [this Jenkins job](https://upp-k8s-jenkins.in.ft.com/job/k8s-deployment/job/utils/job/deploy-upp-helm-chart/), 
so that they don't get overwritten by the restore:
    - upp-global-configs
    - kafka-bridges
     
1. Clone this repository
1. Determine the S3 bucket name where the backup of the source cluster resides.
   Choose one of the exports bellow:
    ```
    # When the source cluster is a test (team) cluster in the EU region. The AWS account is Content Test
    # export RESTORE_BUCKET=k8s-provisioner-test-eu
    # 
    # When the source cluster is a test (team) cluster in the US region. The AWS account is Content Test
    # export RESTORE_BUCKET=k8s-provisioner-test-us
    #
    # When the source cluster is staging or prod in the EU region. The AWS account is Content Prod
    # export RESTORE_BUCKET=k8s-provisioner-prod-eu
    # 
    # When the source cluster is staging or prod in the US region. The AWS account is Content Prod
    # export RESTORE_BUCKET=k8s-provisioner-prod-us
    #     

1. Set the AWS credentials for the AWS account where the source cluster resides, based on the previous choice. They are stored in lastpass.
    - For PAC Cluster "PAC - k8s Cluster Provisioning env variables"
    - For UPP Cluster "UPP - k8s Cluster Provisioning env variables"
    ```
    export AWS_ACCESS_KEY_ID=
    export AWS_SECRET_ACCESS_KEY=
    # This should be either eu-west-1 or us-east-1, depending on the cluster's region.
    export AWS_DEFAULT_REGION=
    ```
1. Determine the backup folder that should be used for restore. Use awscli for this
    ```
    # Check that the source cluster is in the chosen bucket
    aws s3 --human-readable ls s3://$RESTORE_BUCKET/kube-aws/clusters/
    
    # Determine the backup S3 folder that should be used for restore. This should be a recent folder. 
    aws s3 ls --page-size 100 --human-readable s3://$RESTORE_BUCKET/kube-aws/clusters/<source_cluster>/backup/ | sort | tail -n 7
    ```
1. **Make sure you are connected to the right cluster that you are restoring the config to** 
Test if you are connected to the correct cluster by doing a
    ```
    kubectl cluster-info
    ```

1. Run the following command from the root of this repository to restore the `default` and the `kube-system` namespace
    ```
    ./sh/restore.sh s3://$RESTORE_BUCKET/kube-aws/clusters/<source_cluster>/backup/<source_backup_folder> kube-system
    ./sh/restore.sh s3://$RESTORE_BUCKET/kube-aws/clusters/<source_cluster>/backup/<source_backup_folder> default
    ```

1. In order to get the cluster green after an S3 restoration, some manual steps are further required for mongo, kafka and varnish. Steps are detailed [here](README-app_troubleshooting.md)

##  Decommissioning a cluster

```
## Set the environments variables to provision a cluster. The variables are stored in LastPass
## For PAC Cluster
## LastPass: PAC - k8s Cluster Provisioning env variables
## For UPP Cluster
## LastPass: UPP - k8s Cluster Provisioning env variables

docker run \
    -e "AWS_REGION=$AWS_REGION" \
    -e "CLUSTER_NAME=$CLUSTER_NAME" \
    -e "CLUSTER_ENVIRONMENT=$CLUSTER_ENVIRONMENT" \
    -e "ENVIRONMENT_TYPE=$ENVIRONMENT_TYPE" \
    -e "KONSTRUCTOR_API_KEY=$KONSTRUCTOR_API_KEY" \
    -e "PLATFORM=$PLATFORM" \
    -e "VAULT_PASS=$VAULT_PASS" \
    k8s-provisioner:local /bin/bash decom.sh
```

## Accessing the cluster

See [here](https://github.com/Financial-Times/upp-kubeconfig).
