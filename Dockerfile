FROM coco/k8s-cli-utils

# Get the files for the provisioner
RUN mkdir -p /provisioner-configs
RUN mkdir -p /provisioner-configs/credentials
COPY cluster-configs /provisioner-configs/cluster-configs
COPY stack-templates /provisioner-configs/stack-templates
COPY cluster-template.yaml /provisioner-configs
COPY sh/* /provisioner-configs/
COPY userdata /provisioner-configs/userdata

WORKDIR /provisioner-configs/
