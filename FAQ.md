# Table of Contents:
<!--- TOC BEGIN -->
* [VPC Setup](#vpc-setup)
    * [How do I decide which prefix to choose for VPC?](#how-do-i-decide-which-prefix-to-choose-for-vpc)
    * [Do I really need a NAT gateway?](#do-i-really-need-a-nat-gateway)
    * [Should EKS cluster endpoint be private only?](#should-eks-cluster-endpoint-be-private-only)
* [Node Group](#node-group)
    * [Managed node group or self-managed node group?](#managed-node-group-or-self-managed-node-group)
    * [How many instances should I start with?](#how-many-instances-should-i-start-with)
    * [How do I use other volume type for the worker node group?](#how-do-i-use-other-volume-type-for-the-worker-node-group)
    * [How do I enable EC2 level configurations for the worker node group, such as bootstrap command and SSH access?](#how-do-i-enable-ec2-level-configurations-for-the-worker-node-group-such-as-bootstrap-command-and-ssh-access)
    * [How do I make the worker node launched with custom AMI?](#how-do-i-make-the-worker-node-launched-with-custom-ami)
    * [How do I run GPU worker instances?](#how-do-i-run-gpu-worker-instances)
    * [Cluster Autoscaler is having issue scaling](#cluster-autoscaler-is-having-issue-scaling)
    * [How do I build docker container image in a build?](#how-do-i-build-docker-container-image-in-a-build)
<!--- TOC END -->

## VPC Setup

### How do I decide which prefix to choose for VPC?

VPC CIDR determines the total number of IP addresses available in your VPC, commonly shared by its subnets. AWS CNI plugin assigns each pod in the EKS cluster with a free IP address from the available secondary IP address warm pool on the node. The more pods you have in your cluster the quicker you run out of available IP addresses. Also, different instance types have different number of ENIs attached to them, and each ENI can hold different number of IP addresses. See https://github.com/aws/amazon-vpc-cni-k8s/blob/master/docs/cni-proposal.md#how-many-addresses-are-available for the best way to calculate the maximum number of IP addresses available to pods on each EC2 instance. Be wise with the size of the VPC and subnets, and you should estimate the number of resources based on your CI/CD usage pattern.

---

### Do I really need a NAT gateway?

It depends. We do not recommend running worker nodes on public subnets. NAT gateway is a more secure way to let instances on private subnets to have egress only traffic to public internet, for example, fetching container images from external container registry.

---

### Should EKS cluster endpoint be private only?

Yes. In order to protect your control plane on EKS, you should allow internal access only from your VPC or via connected networks. The most common examples of connected networks are bastion and VPN. However, most of the sample configurations enable both public and private endpoint access because not everyone can run tunnel via bastion host due to whatever reason. Please refer to https://aws.amazon.com/blogs/containers/de-mystifying-cluster-networking-for-amazon-eks-worker-nodes/ for illustrations.

---

## Node Group

### Managed node group or self-managed node group?

There are some major differences between the two. Managed node group is basically the data plane managed by AWS where you do not have the option to employ custom AMI but you save yourself the trouble to go through the upgrade process of the node group. Currently, a worker node in a managed node group in a private subnet will still get public IP but soon it's going to change as per https://aws.amazon.com/blogs/containers/upcoming-changes-to-ip-assignment-for-eks-managed-node-groups/. Also, for managed node group you do not have the option to enable EBS volume encryption. For some business compliance, it is often required to have encryption at rest as much as possible.

---

### How many instances should I start with?

The minimum number of instance should be 1 because it's actually needed for *cluster-autoscaler* to operate. Then you should look at the amount of CPU & memory resources consumed by a typical Screwdriver build. Based on that info, one can estimate the maximum number of build containers could be running on a node at the same time, thus inducing the right number of instances to start with.

---

### How do I use other volume type for the worker node group?

You have to create your own `cluster.yaml` according to the [eksctl schema](https://eksctl.io/usage/schema/) provided by eksctl. Volume type information is available in https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html

---

### How do I enable EC2 level configurations for the worker node group, such as bootstrap command and SSH access?

We do not wish to expose you to node level EC2 cloud init or user data configuration unless you need to perform optimization at that level. To enable such option, you have to create your own `cluster.yaml` according to the [eksctl schema](https://eksctl.io/usage/schema/). Again, you do not need anything else other than a functional EKS cluster to run build cluster worker.

---

### How do I make the worker node launched with custom AMI?

In order to launch worker node with a custom AMI, you must use self-managed node group instead of managed node group. You can configure the type of AMI (e.g. EKS-optimized AMI, Ubuntu, Windows, Bottlerocket). Please refer to https://eksctl.io/usage/custom-ami-support/ for more details.

---

### How do I run GPU worker instances?

First, you need to choose the EC2 instance type with GPU support, then you will have to look up the EKS-optimized AMIs with GPU support, and at last you have to install NVIDIA device plugin on the EKS cluster. Please refer to https://docs.aws.amazon.com/eks/latest/userguide/gpu-ami.html and https://eksctl.io/usage/gpu-support/ for more details on GPU instance.

---

### Cluster Autoscaler is having issue scaling

You should always try to look for hints from the logs or K8s events related to Cluster Autoscaler (CA). The most trivial case is that either the min/max number of instances has been reached. However, if there is something about the underlying Auto Scaling Group (ASG) failed to create new instance and if you have enabled KMS volume encryption, you need to make sure the KMS key has already granted access for AWS service-linked role for ASG, `AWSServiceRoleForAutoScaling`. And if CA isn't scaling down where it's supposed to, check the node instance utilization level to see if it's below the threshold set by `CLUSTER_WORKER_UTILIZATION_THRESHOLD` in the config. By default, CA would terminate a node if it's well below that threshold for 10 minutes. You can confirm that by checking CA's logs.

---

### How do I build docker container image in a build?

Assuming the Screwdriver cluster your build cluster connects to does have `DOCKER_FEATURE_ENABLED` on its API, you have to specify the annotation `screwdriver.cd/dockerEnabled: true` on the Screwdriver job to enable this feature on the executor side. Because `k8s` is the executor plugin chosen for the AWS build cluster worker, the only way to build container images is using a `dind` sidecar container alongside the build container in the same pod. Please refer to https://docs.screwdriver.cd/user-guide/configuration/annotations.html for other annotations related to docker.

---
