# Royce

Example setup for a K8s cluster (EKS) with ArgoCD as GitOps controller.  
Royce can be used to quickly get started with a Kappa architecture on K8s.

## Setup

Setup K8s with argo and a root-app.
```
terragrunt run-all apply
```

## Usage

Place your argo-cd applications under the monitored `test/apps` folder.

## Cleanup

Go to the base module and run `terragrunt destroy` to delete the K8s cluster.

## References
* [Real-time Data Infrastructure at Uber](https://arxiv.org/pdf/2104.00087.pdf)
* [Kappa+ at Uber](https://www.youtube.com/watch?v=4qSlsYogALo)
* [ArgoCD](https://argo-cd.readthedocs.io/en/stable/)
* [Ververica playground](https://github.com/ververica/ververica-platform-playground)
* [Ververica installation](https://docs.ververica.com/installation/helm/index.html)
* [Strimzi examples](https://github.com/strimzi/strimzi-kafka-operator/tree/0.26.0/examples)
* [Prometheus community](https://github.com/prometheus-community/helm-charts)