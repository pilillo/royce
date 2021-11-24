# Royce

```
     __
(___()'`;
/,    /`
\\"--\\
```

Example setup for a K8s cluster (EKS) with ArgoCD as a GitOps controller.  
Royce can be used to quickly get started with a Kappa architecture on K8s.

## Disclaimer
This is a PoC and not production ready. 
Much of the application yaml is refined iteratively and may be polished at some point.

## Setup

Setup does start a K8s/EKS cluster using terragrunt and terraform, as well as ArgoCD and a root-app (see [app of apps pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)).
```
terragrunt run-all apply
```

From then on, ArgoCD takes care of syncing the app folder with standard k8s yaml files.

Wanna skip the EKS cloud setup? You can:  
* use a local k8s cluster (e.g. `minikube start --memory 16000 --cpus 14`)
* use EKS with [localstack](https://github.com/localstack/localstack) to simulate EKS and K8s

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