# K8s infrastructure for Screwdriver build cluster on AWS

## Introduction

This repository is meant to serve as a quickstart tool to provision necessary EKS cluster and cloud infrastructure resources required by Screwdriver build cluster on AWS. The most trivial platform to deploy Screwdriver build cluster is Kubernetes as the build cluster itself employs a set of executor plugins which speak fluently with K8s under the cover. Also having K8s be the backbone of the container orchestration will abstract away the complexity of running multiple build clusters on AWS.

For the sake of simplicity and ease of use, we recommend administering a K8s cluster with managed Kubernetes offering from the cloud provider, in this case with AWS, instead of self managed K8s cluster.

The second component of this tool is to help deploy a standard Screwdriver build cluster worker on the K8s cluster to communicate to the job queue from the main Screwdriver application, whether it is hosted by you or Screwdriver team.

This tool relies heavily on other open source tools, especially [eksctl](https://eksctl.io/) as IaC for setting up EKS cluster, as well as [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl) for native K8s deployment.

## Prerequisite

### Tool Dependencies

The followings are the external dependencies required to run this tool:

- [jq](https://github.com/stedolan/jq/releases/latest)
- [yq](https://github.com/mikefarah/yq/releases/latest)
- [envsubst](https://formulae.brew.sh/formula/gettext), part of the [`gettext` package](https://www.gnu.org/software/gettext/)
- [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- [eksctl](https://github.com/weaveworks/eksctl/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl)
- [helm](https://helm.sh/docs/intro/install/)

All of these tools can be installed via Homebrew on Mac OS X.

### Getting RabbitMQ credentials for build cluster worker

You should have already reached out to the target Screwdriver cluster admins to obtain the credential for the RabbitMQ running in the cluster. Also to make sure Screwdriver API recognize the new build cluster, one should:

* update the database build cluster table to register the new build cluster
* declare and bind corresponding queue on RabbitMQ for the new build cluster

It will be much more straightforward if you actually own the Screwdriver cluster.

## Instructions

To get started, first we recommend composing your own configuration file for the EKS cluster. Please refer to [`examples/config.yaml`](./examples/config.yaml) for structure and definitions.

Second, configure the AWS CLI by running `aws configure` with your AWS credentials.

Next, to begin the infrastructure provisioning process:

```sh
# by default, run.sh will try to find "config.yaml" at CWD if no argument is passed
./run.sh path-to-config.yaml
```

`./run.sh` will first prepare the shell environment setup based on given configs, then sequentially execute scripts in `scripts/` directory in alphanumerical order. You can freely insert your own scripts in the order you want by manipulating the naming convention for the scripts.

And if you already have a `cluster.yaml` at the root dir, which is compatible with eksctl, it will be used instead of. Otherwise, a generated `cluster.yaml` will be created in the directory specified by the config `GENERATED_DIR` in your config file. *(see [below](#config-definitions))*

### Considerations for VPC setup

The complexity of the instructions scales along with the number of resources in the infrastructure. There are basically 3 scenarios:

- [New VPC with new K8s cluster](#new-vpc-with-new-k8s-cluster)
- [Existing VPC with new K8s cluster](#existing-vpc-with-new-k8s-cluster)
- [Existing VPC with existing K8s cluster](#existing-vpc-with-existing-k8s-cluster)

#### New VPC with new K8s cluster

This is the clean slate scenario. The only required configuration needed for a new VPC setup is VPC CIDR. The VPC CIDR prefix must be between `/16` and `/24` and not overlap with `172.17.0.0/16` CIDR range because Docker runs in that range. The range should be determined based on the number of IPv4 addresses and workers in the node group.

Example configuration is located in [`examples/new_vpc.yaml`](./examples/new_vpc.yaml)

#### Existing VPC with new K8s cluster

For existing VPC and subnets, all we need are the resource IDs of the VPC and its subnets. It's required by eksctl to have at least two private subnets in your VPC for the workers. The only need for a public subnet is to host a NAT gateway for the workers in the private subnets to communicate to public internet. Therefore, we highly recommend reviewing your existing VPC to see if it fits or a new one should be created instead.

Example configuration is located in [`examples/existing_vpc.yaml`](./examples/existing_vpc.yaml)

#### Existing VPC with existing K8s cluster

This scenario assumes that you already have an operating K8s cluster with dedicated ndoe group in your cloud infrastructure. Then all you need to do is to run `scripts/30_build_cluster_worker.sh`

## Configurations

The way configuration works is that cluster admins will define configs in `config.yaml` at the root dir, which serves as a footprint of the environment variables consumed throughout the EKS cluster setup as well as the K8s deployment. `run.sh` dynamically injects environment variables from these configs with names composed from the keys along the path that are only in uppercase. For example,

```yaml
CLUSTER:
    NAME: my-cluster
    VPC:
        ID: vpc-xxx
        SUBNETS:
            # this becomes a JSON string
            PRIVATE:
                us-east-1a: { id: "subnet-xxx" }
                us-east-1b: { id: "subnet-yyy" }
```

Three environment variables will be created:

```sh
CLUSTER_NAME=my-cluster
CLUSTER_VPC_ID=vpc-xxx
CLUSTER_VPC_SUBNETS_PRIVATE={"us-east-1a":{"id":"subnet-xxx"},"us-east-1b":{"id":"subnet-yyy"}}
```

### Config Definitions

The following table describes all the configurable options one can put in the `config.yaml`. There is a fully documented sample `config.yaml` in the `/examples` directory.


| Name | Type | Description |
| - | - | - |
| CLUSTER_NAME <sup>*</sup> | String | Name of the EKS cluster |
| CLUSTER_REGION <sup>*</sup> | String | Name of the AWS region of the EKS cluster |
| CLUSTER_ENV | String | Annotated environment, e.g. dev, stage, prod |
| CLUSTER_OWNER | String | Email of the owner of the EKS cluster |
| CLUSTER_EKS_VERSION | Number | K8s version available in EKS, default version is dictated by whatever default in eksctl |
| CLUSTER_LOGGING_TYPES | String[] | CloudWatch Logs settings. Options: ["api", "audit", "authenticator", "controllerManager", "scheduler"] or ["*"] for everything |
| CLUSTER_ENVELOPE_ENCRYPTION_KEY_ARN | String | KMS key arn for EKS cluster secrets envelope encryption |
| CLUSTER_WORKER_INSTANCE_TYPE | String | EC2 instance type for the worker node group |
| CLUSTER_WORKER_DESIRED_CAPACITY | Integer | Starting number of worker in node group |
| CLUSTER_WORKER_MIN_SIZE | Integer | Minimum number of worker in node group |
| CLUSTER_WORKER_MAX_SIZE | Integer | Maximum number of worker in node group |
| CLUSTER_WORKER_VOLUME_SIZE | Integer | EBS gp2 volume size in GiB |
| CLUSTER_WORKER_VOLUME_ENCRYPTED | Boolean | Flag to enable EBS volume encryption. If false, EKS managed node group will be used instead of self-managed node group |
| CLUSTER_WORKER_EBS_VOLUME_ENCRYPTION_KEY_ARN | String | KMS key arn for EC2 EBS volume encryption |
| CLUSTER_WORKER_UTILIZATION_THRESHOLD | Number | Worker utilization level below which downscaling will be performed. Default: 0.5 |
| CLUSTER_PV_SC | String | K8s storage class to use for PV. Default: gp2 |
| CLUSTER_FARGATE_PROFILE_SELECTORS | Object[] | Array of selectors (namespace & label) for pod to be run in Fargate node. *Avoid including "kube-system" as cluster-autoscaler will run in that namespace and require file system* |
| CLUSTER_VPC_ID | String | VPC resource ID, for existing VPC setup |
| CLUSTER_VPC_CIDR | String | VPC CIDR, for both new and existing VPC setup. Must be between `/16` and `/24`. |
| CLUSTER_VPC_SUBNETS_PRIVATE | Object | Private subnets, requires at least 2 for existing VPC setup. `{ [AZ name]: { id: "subnet_id", cidr: "subnet_cidr" } }` |
| CLUSTER_VPC_SUBNETS_PUBLIC | Object | Public subnets for existing VPC setup. `{ [AZ name]: { id: "subnet_id", cidr: "subnet_cidr" } }` |
| TAG_REPFIX | String | Prefix for tag preset name |
| GENERATED_DIR | String | Path to store generated manifest files. Default: {root_dir}/generated |
| SD_K8S_NAMESPACE | String | K8s namespace for build cluster worker and build workers. Default: sd |
| SD_INSTALL_OPTIONAL | Boolean | Whether or not to install kubernetes dashboard and prometheus |
| SD_API_HOST <sup>*</sup> | String | Hostname for Screwdriver API service |
| SD_STORE_HOST <sup>*</sup> | String | Hostname for Screwdriver Store service |
| SD_RABBITMQ_USERNAME <sup>*</sup> | String | RabbitMQ username |
| SD_RABBITMQ_PASSWORD <sup>*</sup> | String | RabbitMQ password |

<i><sup>*</sup> required config</i>
