# USE https://github.com/Financial-Times/upp-global-configs FOR GLOBAL CONFIGS

# Delivery cluster on Kubernetes POC


## Description
This repository contains the files needed to run the delivery cluster
using Kubernetes on AWS.

It uses [kube-aws](https://coreos.com/kubernetes/docs/latest/kubernetes-on-aws.html) for provisioning the cluster on AWS.

## Building the Docker image
The k8s provisioner can be built locally as a Docker image:

```
docker build -t k8s-provisioner:local .
```

##  Provisioning a new cluster

```
## Set the environments variables to provision a cluster. The variables are stored in LastPass
## For PAC Cluster
## LastPass: pac-content-provisioner env variables
## For UPP Cluster
## LastPass: infraprod-coco-aws-provisioning-keys

docker run \
    -v $(pwd)/credentials:/provisioner-configs/credentials \
    -e "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" \
    -e "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" \
    -e "CLUSTER=$CLUSTER" \
    -e "KONSTRUCTOR_API_KEY=$KONSTRUCTOR_API_KEY" \
    k8s-provisioner:local /bin/sh provision.sh
```

Follow the steps in [here](https://docs.google.com/document/d/1TTih1gcj-Vsqjp1aCAzsP4lpt6ivR8jDIXaZtBxNaUU/edit?pli=1#heading=h.idonu4gksr10) 

## Prerequisites for development
1. [Install kubectl version](https://kubernetes.io/docs/user-guide/prereqs/) > 1.5.1 (latest should do), since we're using Kubernetes 1.5.1. 
You can check the client version by running 
```
kubectl version
```

## Accessing the cluster
We'll share the same Kubernetes cluster that was provisioned on aws. Please do the following setup:

1. Clone this repository
1. Go to lastpass and search for the secure note "upp-k8s-stack infraprod credentials". 
1. Download the attachment from this secure note (either one is fine) and unzip it in the credentials folder. You should have now the key files needed to communicate with the Kubernetes cluster into this folder.
    1. To download attachments, you need to install [LP binary plugin](https://lastpass.com/support.php?cmd=showfaq&id=3206) and access the vault through the add-on/extension.
1. Set the environment variable `KUBECONFIG` to point to the absolute path of the file:
    1. For the delivery cluster: the kubeconfig file in the cloned folder. 
    1. For the publishing cluster: the kubeconfig-pub file in the cloned folder.

You should be all set now. Test your setup by running
```
kubectl cluster-info
```
You should get something like:
```
Kubernetes master is running at https://sorin-kube-aws-test.ft.com
Heapster is running at https://sorin-kube-aws-test.ft.com/api/v1/proxy/namespaces/kube-system/services/heapster
KubeDNS is running at https://sorin-kube-aws-test.ft.com/api/v1/proxy/namespaces/kube-system/services/kube-dns
kubernetes-dashboard is running at https://sorin-kube-aws-test.ft.com/api/v1/proxy/namespaces/kube-system/services/kubernetes-dashboard
```
