#!/bin/bash -eo pipefail

CWD=$(dirname ${BASH_SOURCE})
template_dir=${GENERATED_DIR:-$CWD/../generated}
mkdir -p $template_dir

# install cluster-autoscaler
declare -rx CLUSTER_WORKER_UTILIZATION_THRESHOLD=${CLUSTER_WORKER_UTILIZATION_THRESHOLD:-0.5}
envsubst < $CWD/../templates/_cluster_autoscaler.yaml > $template_dir/cluster_autoscaler.yaml
kubectl apply -f $template_dir/cluster_autoscaler.yaml

# install container insights daemonsets for CloudWatch and FluentD agent
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed "s/{{cluster_name}}/${CLUSTER_NAME}/;s/{{region_name}}/${CLUSTER_REGION}/" | kubectl apply -f -


# install / upgrade VPC CNI Plugin
kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/release-1.6/config/v1.6/aws-k8s-cni.yaml

# turn on external SNAT because our private subnets are communicating to external via NAT gateway
kubectl set env daemonset -n kube-system aws-node AWS_VPC_K8S_CNI_EXTERNALSNAT=true

# deploy VPC CNI Metrics Helper to collect metrics for ENI and IP addresses in your cluster to CloudWatch
kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/release-1.6/config/v1.6/cni-metrics-helper.yaml

# install Metrics server for the cluster
helm install metrics-server stable/metrics-server -n kube-system

# optional installations
if [[ "$SD_INSTALL_OPTIONAL" == "true" ]]; then
    # install Kubernetes dashboard
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta8/aio/deploy/recommended.yaml

    # install Prometheus
    kubectl create namespace prometheus && helm install prometheus stable/prometheus -n prometheus \
        --set alertmanager.persistentVolume.storageClass="${CLUSTER_PV_SC:-gp2}",server.persistentVolume.storageClass="${CLUSTER_PV_SC:-gp2}"
fi
