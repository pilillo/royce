# Royce

```
     __
(___()'`;
/,    /`
\\"--\\
```

Example setup for a K8s cluster (EKS) with ArgoCD as a GitOps controller.  
Royce can be used to quickly get started with a Kappa architecture and event-based serving on K8s.

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

If you are running locally without using terragrunt/terraform you can install argo-cd manually with:

```
kubectl apply -f namespace.yaml
kubectl apply -n argocd -f install.yaml
kubectl apply -n argocd -f root-app.yaml
```

## Ingress controller

Knative-serving is used to manage serverless services and ramps up an ingress controller (e.g., istio).  
To expose the routes you need to firstly retrieve the load balancer external ip, e.g. for istio:

```bash
kubectl get svc -n istio-system istio-ingressgateway
NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                                      AGE
istio-ingressgateway   LoadBalancer   10.104.238.19   10.104.238.19   15021:32001/TCP,80:31789/TCP,443:32644/TCP   21d
```

or for kourier:
```bash
kubectl get svc -n kourier-system kourier -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Mind that, on local development clusters, a component such as metallb (or alternatively `minikube tunnel` on minikube) can be used to assign local IP addresses to load balancer services. The external IP needs to be retrieved and can be added as a magic DNS name to the knative-serving config map (either with an apply or a patch):
```bash
INGRESS_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
KNATIVE_DOMAIN="${INGRESS_IP}.sslip.io"

cat <<EOF | kubectl apply -f -
apiVersion: v1
data:
  ${KNATIVE_DOMAIN}: ""
kind: ConfigMap
metadata:
  name: config-domain
  namespace: knative-serving
EOF
```

The kn route can now be called with:
```bash
$ kn route list
NAME    URL                                                   READY
hello   http://hello.knative-serving.10.104.238.19.sslip.io   True
$ curl http://hello.knative-serving.10.104.238.19.sslip.io
Hello World!
```

When managed by argocd, you should avoid manual patching and apply the configuration directly in the `serving-core.yaml`.

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
