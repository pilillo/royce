# Base setup
Using terragrunt we can more easily manage the remote backend, for instance as opposed to using partial configuration.

Specifically, you can get into one specific module folder and run apply as follows:
```
terragrunt apply
```

To simplify the process, you can operate on all modules with `terragrunt run-all apply` and `terragrunt run-all destroy`, respectively.

## Pre-requisites
* an aws account with the IAM permissions necessary to create/edit the managed resources (S3 and DynamoDB for the backend, and [EKS](https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/iam-permissions.md));
* the aws cli to retrieve the kubeconfig;
* the [kubectl CLI](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) to interact with the k8s cluster;

## Creating base resources
The base creates an S3 bucket and a DynamoDB table, respectively for storing the terraform state and a lock.

Along with those, this will setup a VPC with specific security groups and an EKS cluster.
You can finally use kubectl to interact with the cluster, after retrieving the kubeconfig with:
```
aws eks --region $(terragrunt output -raw region) update-kubeconfig --name $(terragrunt output -raw cluster_name) --profile royce
```
which does return something like:
```
Added new context arn:aws:eks:eu-west-1:196393882643:cluster/royce-test-cluster-VqZsu8Os to /Users/pilillo/.kube/config
```

## Setting up Argo-cd

The argocd folder contains terraform HCL code to setup argocd in a new namespace.

To access the service you can port-forward it with:
```
kubectl port-forward -n argocd svc/argocd-server 8443:443
```

The initial admin secret can be retrieved with:
```
kubectl get secrets -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

As visible, this step also sets up a root-app application.