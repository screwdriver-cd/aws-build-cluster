#!/bin/bash -eo pipefail

CWD=$(dirname ${BASH_SOURCE})
template_dir=${GENERATED_DIR:-$CWD/../generated}
mkdir -p $template_dir

# install build cluster worker

declare -rx SD_K8S_NAMESPACE=${SD_K8S_NAMESPACE:-sd}
declare -rx SD_K8S_LAUNCHER_VERSION=${SD_K8S_LAUNCHER_VERSION:-latest}
declare -rx SD_RABBITMQ_VHOST=${SD_RABBITMQ_VHOST:-/screwdriver}
declare -rx SD_RABBITMQ_EXCHANGE=${SD_RABBITMQ_EXCHANGE:-build}

envsubst < $CWD/../templates/_build_cluster_worker_namespace.yaml | kubectl apply -f -
envsubst < $CWD/../templates/_build_cluster_worker.yaml > $template_dir/build_cluster_worker.yaml
kubectl apply -f $template_dir/build_cluster_worker.yaml
