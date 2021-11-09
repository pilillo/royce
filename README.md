# Royce

Example setup for a K8s cluster (EKS) with ArgoCD as GitOps controller.

## Setup

Setup K8s with argo and a root-app.
```
terragrunt run-all apply
```

## Usage

Place your argo-cd applications under the monitored `test/apps` folder.

## Cleanup

Go to the base module and run `terragrunt destroy` to delete the K8s cluster.
