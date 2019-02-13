# USE https://github.com/Financial-Times/upp-global-configs FOR GLOBAL CONFIGS

## Description
This repository contains the files required to provision clusters using Kubernetes on AWS for UPP (delivery, publishing) and PAC platforms.

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
        -e "OIDC_ISSUER_URL=$OIDC_ISSUER_URL" \
        -e "PLATFORM=$PLATFORM" \
        -e "VAULT_PASS=$VAULT_PASS" \
        k8s-provisioner:local /bin/bash provision.sh
    ```    
1. `VERY IMPORTANT`: Upload the zip with the TLS assets in the LastPass note from step 2.
    The zip is found at `credentials/${CLUSTER_NAME}.zip`
    These initial credentials are vital for subsequent updates in the cluster.

The following steps have to be manually done:

1. Add the new environment to the [auth setup](https://github.com/Financial-Times/content-k8s-auth-setup/) following the instructions [here](https://github.com/Financial-Times/content-k8s-auth-setup/blob/master/README.md#how-to-add-a-new-cluster)
1. Add the new environment to the jenkins pipeline. Instructions can be found [here](https://github.com/Financial-Times/k8s-pipeline-library#what-to-do-when-adding-a-new-environment).
1. Make sure you have defined the credentials for the new cluster in Jenkins. See previous step.
1. [Just for UPP Clusters] Create/ amend the app-configs for the [upp-global-configs](https://github.com/Financial-Times/upp-global-configs/tree/master/helm/upp-global-configs/app-configs) repository. Release and deploy a new version of this app to the new environment using this [Jenkins Job](https://upp-k8s-jenkins.in.ft.com/job/k8s-deployment/job/apps-deployment/job/upp-global-configs-auto-deploy/)
1. Deploy all the apps necessary in the current cluster. This can be done in 2 ways:
    1. One slower way, but which is fire & forget: synchronize the cluster with an already existing cluster using this [Jenkins Job](https://upp-k8s-jenkins.in.ft.com/job/k8s-deployment/job/utils/job/diff-between-envs/).
    1. One quick way, but this would require some more manual steps: [Restore](#restore-k8s-config) the config from a S3 backup of another cluster 
1. If this is a test/team cluster that needs to be shutdown over night please put the `ec2Powercycle` tag on the autoscaling groups in the cluster.
You can do this from the AWS console:
    1. [Login](https://awslogin.in.ft.com) to the cluster's account
    1. Go to Ec2 -> Auto Scaling Groups 
    1. Select ASG, go to Tags, and add the `ec2Powercycle` tag. Example value:
    ```
    { "start":"30 6 * * 1-5", "stop": "30 18 * * 1-5", "desired": 2, "min": 2}
    ```
    Make sure you get the `desired` and `min` values in sync with the current ASG's values
1. For the ASG controlling the dedicated node for `Thanos` put the `ec2Powercycle` to be in sync with the thanos compactor job.
    See [Thanos Compactor](https://github.com/Financial-Times/content-k8s-prometheus#thanos-compactor) for details.
    Follow the same steps as above and look for the workers with the `Wt` in the name.
    If this is prod, you should also change the `environment` tag to `t`, so that the `ec2Powercycle` will be considered

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

##  Rotating the TLS assets for a cluster


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
    k8s-provisioner:local /bin/bash rotate-tls.sh
```

After rotating the TLS assets, there are some **important** manual steps that should be done:

1. Validate that the login using the backup token works. Using the **new token** from the output, check the `kubectl-login config` on how to check this. If this validation doesn't work, there must be something wrong. Check the Troubleshooting section.
1. Update the backup token access in the LP note `kubectl-login config`. You can find the new token value in the provisioner output:
        ```
        backup-access token value is: .....
        ```
1. Update the token used by jenkins to access the K8s cluster.
   The credential has the id `ft.k8s-auth.${full-cluster-name}.token`. Look it up [here](https://upp-k8s-jenkins.in.ft.com/job/k8s-deployment/credentials/store/folder/domain/_/) and update it with the token from the provisioner output:
       ```
       "jenkins token value is: .......
       ```
1. Validate that jenkins still has access to the cluster by deploying an existing helm chart version onto the cluster through the [Jenkins job](https://upp-k8s-jenkins.in.ft.com/job/k8s-deployment/job/utils/job/deploy-upp-helm-chart/).
1. Update the TLS assets used by Jenkins for cluster updates.
   The credential has the id `ft.k8s-provision.${full-cluster-name}.credentials`. Look it up [here](https://upp-k8s-jenkins.in.ft.com/job/k8s-deployment/credentials/store/folder/domain/_/) and update the zip with the one created in the `credentials` folder with the name `${full-cluster-name}.zip`
1. Validate that this update worked by triggering a cluster update using the [Jenkins job](https://upp-k8s-jenkins.in.ft.com/job/k8s-deployment/job/utils/job/update-cluster/) on the cluster. It should finish quickly as it doesn't have anything to do.
   If it takes a long time and really goes through updating please check that you did the previous step and try again.
1. Validate that the normal flow of login through DEX works.
1. Merge the PR you created for [content-k8s-auth-setup](https://github.com/Financial-Times/content-k8s-auth-setup) repository. This is needed so that everybody can access the cluster.
1. Notify everybody to update their local setup so that they can still login on the cluster.
1. Update the TLS assets in the LP note `UPP - k8s Cluster Provisioning env variables` or `PAC - k8s Cluster Provisioning env variables`

### Extra validation
To validate everything works after the rotation do the following:

1. Check that logs are getting into Splunk after the rotation from this environment.

### Troubleshooting
Here are the situations encountered so far when the rotation did not complete successfully:

#### After rotation one could not login using the normal flow
Possible problems:

1. Dex may not be started yet. Wait for 5 mins then give it another go. As an alternative try using the backup token that was newly generated and you updated in the LP note `kubectl-login config`
2. The state of the etcd cluster is not consistent between the nodes.
   Here's how to check that this is the situation and overcome this:
    1. First you need to connect to the cluster. Create a `kubeconfig` file that uses the newly created certificates to login into the cluster. It may look like:
        ```
        apiVersion: v1
        clusters:
        - cluster:
            server: https://{{full-cluster-name}}-api.ft.com
            insecure-skip-tls-verify: true
          name: prov-test
        contexts:
        - context:
            cluster: prov-test
            namespace: kube-system
            user: cert
          name: prov-test-cert-ctx

        current-context: prov-test-cert-ctx

        kind: Config
        preferences: {}
        users:
        - name: cert
          user:
            client-certificate: credentials/admin.pem
            client-key: credentials/admin-key.pem
        ```
    1. set KUBECONFIG in the shell to point to the newly created cluster.
    1. issue some `kubectl get secret` multiple times. If this returns different values each time or there are duplicates in the secrets, it means the state of the etcds is out of sync.
    1. Check which etcd is the leader & terminate the other instances that are not
        1. Connect to SSH to one of the etcd node ssh core@<ip_address>
        1. do an ```etcdctl member list```
        1. The leader would be printed in the above command.
        1. From the AWS console to and terminate the 2 instances from the cluster that are not the leader.

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
    -e "AWS_ACCESS_KEY=$AWS_ACCESS_KEY" \
    -e "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" \
    -e "CLUSTER_NAME=$CLUSTER_NAME" \
    -e "CLUSTER_ENVIRONMENT=$CLUSTER_ENVIRONMENT" \
    -e "ENVIRONMENT_TYPE=$ENVIRONMENT_TYPE" \
    -e "PLATFORM=$PLATFORM" \
    -e "VAULT_PASS=$VAULT_PASS" \
    k8s-provisioner:local /bin/bash decom.sh
```

Additional manual steps  to do:

1. Delete all AWS resources associated with the cluster. Go to AWS console -> Resource groups -> Tag editor -> find all resources by the k8s cluster tag & delete them
## Accessing the cluster

See [here](https://github.com/Financial-Times/upp-kubeconfig).

## How to upgrade kube-aws
When upgrading the Kubernetes version, it is wise to do it on the latest kube-aws version, since they might upgraded already to a closer version that you need.
Here are some guidelines on how to do it:

1. Read all the changelogs involved (kube-aws, kubernetes) to spot any show-stoppers.
1. Generate the plain kube-aws artifacts with the new version of kube-aws

        1. Open a terminal
        1. Create a new folder and go into it ```mkdir kube-aws-upgrade; cd kube-aws-upgrade```
        1. [Download the kube-aws](https://github.com/kubernetes-incubator/kube-aws/releases) version that you want to upgrade to and put it in this new folder
        1. Init the cluster.yaml of kube-aws using some dummy values:
            ```
            ./kube-aws init --cluster-name=kube-aws-up --external-dns-name=kube-aws-up --region=eu-west-1 --key-name="dum" --kms-key-arn="dum" --no-record-set --s3-uri s3://k8s-provisioner-test-eu --availability-zone=eu-west-1a
            ```
        1. Render the stack:
            ```
            ./kube-aws render
            ```
1. At this point kube-aws should have created 2 folders: `stack-templates` & `userdata`
1. Carefully update the file `ansible/templates/cluster-template.yaml.j2` adapting it to the changes from `kube-aws-upgrade/cluster.yaml`.
One way to do this is to do a merge with a tool like Intellij Idea between the two files.
1. Carefully update the contents of the files from `ansible/stack-templates/` adapting them to the changes from `kube-aws-upgrade/stack-templates`.
Before doing this, it is advisable to look at the Git history of the folder and see if there have been executed some manual changes on the files, as those need to be kept.
Use the same technique of merging the files.
1. Carefully update the contents of the files from `ansible/userdata/` adapting them to the changes from `kube-aws-upgrade/userdata`.
Before doing this, it is advisable to look at the Git history of the folder and see if there have been executed some manual changes on the files, as those need to be kept.
Use the same technique of merging the files.

The update part should be done. Now we need to validate it is really working.
### Validate that the update works
It is advisable to go through the following steps for doing a full validation:

1. Create a new branch in the [k8s-cli-utils](https://github.com/Financial-Times/k8s-cli-utils/) repo  & update the `kube-aws` version.
1. Update the Dockefile of the provisioner to extend from the new version of [k8s-cli-utils Docker image](https://hub.docker.com/r/coco/k8s-cli-utils/tags/) & build the new docker image of the provisioner
1. Test provisioning of a new simple cluster. Use `CLUSTER_ENVIRONMENT=prov` when provisioning. Validate that everything worked well (nodes, kube-system namespace pods)
1. Test that decommisioning still work. Decommision this new cluster and check that AWS resources were deleted.
1. Test upgrading a simple cluster to the new version
    1. Provision a new cluster using the `master` version of the provisioner. Use the same `CLUSTER_ENVIRONMENT=prov`
    1. Update the cluster with the new version of the provisioner
    1. Validate that after the upgrade everything works (nodes, kube-system namespace pods)
1. Test upgrading a replica of a delivery cluster
    1. Provision a new cluster using the `master` version of the provisioner. Use `CLUSTER_ENVIRONMENT=delivery`
    1. Go through the [restore procedure](##restore-k8s-config). Use as source cluster the `upp-uptst-delivery-eu` cluster
    1. Get the cluster as green as possible
    1. Update the cluster with the new version of the provisioner
    1. Validate that everything is ok & the cluster is still green after the update
    1. [Add the environment to the Jenkins pipeline](https://github.com/Financial-Times/k8s-pipeline-library#what-to-do-when-adding-a-new-environment).
    1. Validate that Jenkins can deploy to the updated cluster. You can trigger a [Diff & Sync](https://upp-k8s-jenkins.in.ft.com/job/k8s-deployment/job/utils/job/diff-between-envs/) job to update from prod.
1. Don't forget to [decommision the cluster](https://github.com/Financial-Times/content-k8s-provisioner#decommissioning-a-cluster) after all these validations.

After all these validations succeed, you are ready to update the dev clusters.
