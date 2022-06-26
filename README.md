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
* use a local k8s cluster 
  * `minikube start --memory 16000 --cpus 14`
  * using kind with the enclosed `start_local.sh` script
* use EKS with [localstack](https://github.com/localstack/localstack) to simulate EKS and K8s

## Usage

Place your argo-cd applications under the monitored `test/apps` folder.

If you are running locally without using terragrunt/terraform you can install argo-cd manually (from `test/argocd/manifests`) with:

```
kubectl apply -f namespace.yaml
kubectl apply -n argocd -f install.yaml
kubectl apply -n argocd -f root-app.yaml
```

This will install both argocd and the root application, point to the github repo for the application configuration files.
Note that for debugging purposes you can also bypass argo-cd, by directly installing application directories with something like:

```bash
apply_all(){
  abs_path=$(readlink --canonicalize --no-newline $1)
  if [ "$#" -ne 2 ]; then
    echo "usage: apply_all <path> <namespace>"
  else
    echo "applying all yaml files in ${abs_path} to namespace $2"
    kubectl get ns ${2} >/dev/null 2>&1 || kubectl create namespace ${2}
    ls -l ${abs_path}/*.yaml | awk '{print $9}' | xargs -n1 kubectl apply -n ${2} -f
  fi
}
```

which runs an apply for each yaml file in the folder. For instance:

```bash
cd kafka/templates
apply_all . kafka
apply_all connect kafka
```

Make sure from the log all the files where applied correctly, as there may be dependencies between the resources, such as the broker being created after the CRD are applied firstly.

## Ingress controller

Knative-serving is used to manage serverless services and ramps up an ingress controller (e.g., kourier, istio).  
To expose the routes you need to firstly retrieve the load balancer external ip, e.g. for istio:

```bash
kubectl get svc -n istio-system istio-ingressgateway
NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                                      AGE
istio-ingressgateway   LoadBalancer   10.104.238.19   10.104.238.19   15021:32001/TCP,80:31789/TCP,443:32644/TCP   21d
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

Now the kn route can now be called with, for instance:
```bash
$ kn route list
NAME    URL                                                   READY
hello   http://hello.knative-serving.10.104.238.19.sslip.io   True
$ curl http://hello.knative-serving.10.104.238.19.sslip.io
Hello World!
```

When managed by argocd, you should avoid manual setting and apply the configuration directly in the `serving-core.yaml`.

Alternatively, you can use node port to directly forward the ingress port on each node.
For instance for kourier you can replace the following:

```yaml
spec:
  ports:
    - name: http2
      port: 80
      protocol: TCP
      targetPort: 8081
    - name: https
      port: 443
      protocol: TCP
      targetPort: 8444
  selector:
    app: 3scale-kourier-gateway
  type: ClusterIP
```

with:

```bash
read -r -d '' KOURIER_PATCH <<EOF
spec:
  ports:
  - name: http2
    port: 80
    protocol: TCP
    targetPort: 8081
    nodePort: 31080
  - name: https
    port: 443
    protocol: TCP
    targetPort: 8444
    nodePort: 31443
  selector:
    app: 3scale-kourier-gateway
  type: NodePort
EOF

kubectl patch service kourier -n kourier-system --patch "$KOURIER_PATCH"
```

You can then set the config to the localhost ip:

```bash
KNATIVE_DOMAIN="127.0.0.1.sslip.io"

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

You can now start the hello world knative service:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: serving.knative.dev/v1 # Current version of Knative
kind: Service
metadata:
  name: helloworld-go # The name of the app
  namespace: default # The namespace the app will use
spec:
  template:
    spec:
      containers:
        - image: gcr.io/knative-samples/helloworld-go # The URL to the image of the app
          env:
            - name: TARGET # The environment variable printed out by the sample app
              value: "Hello Knative Serving is up and running with Kourier!!"
EOF
```

And call it with: `curl -v http://helloworld-go.default.127.0.0.1.sslip.io`
which shall return: `Hello Knative Serving is up and running with Kourier!!!`

To delete it just run a `kubectl delete kvsc helloworld-go -n default`.

## Kafka

Let's start with Kafka by creating a new topic on the cluster.
```bash
cat << EOF | kubectl create -n kafka -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: my-topic
  labels:
    strimzi.io/cluster: "royce"
spec:
  partitions: 3
  replicas: 1
EOF
```

You can use the following commands to respectively create a producer and a consumer:
```
kubectl -n kafka run kafka-producer -ti --image=quay.io/strimzi/kafka:0.29.0-kafka-3.2.0 --rm=true --restart=Never -- bin/kafka-console-producer.sh --bootstrap-server royce-kafka-bootstrap:9092 --topic my-topic --producer.config /tmp/client.properties

kubectl -n kafka run kafka-consumer -ti --image=quay.io/strimzi/kafka:0.29.0-kafka-3.2.0 --rm=true --restart=Never -- bin/kafka-console-consumer.sh --bootstrap-server royce-kafka-bootstrap:9092 --topic my-topic --from-beginning --consumer.config /tmp/client.properties
```

In case you use tls auth, do not forget to create a proper user (as in [here](https://smallstep.com/hello-mtls/doc/client/kafka-cli) and [here](https://www.systemcraftsman.com/2020/09/30/simple-acl-authorization-on-strimzi-using-strimzi-kafka-cli/)).
For instance, we add a kafka user `my-user` that can read (using the group `my-group`) and write to the topic:

```
cat << EOF | kubectl create -n kafka -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: my-user
  labels:
    strimzi.io/cluster: royce
spec:
  authentication:
    type: tls
  authorization:
    type: simple
    acls:
      # Example consumer Acls for topic my-topic using consumer group my-group
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Read
        host: "*"
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Describe
        host: "*"
      - resource:
          type: group
          name: my-group
          patternType: literal
        operation: Read
        host: "*"
      # Example Producer Acls for topic my-topic
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Write
        host: "*"
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Create
        host: "*"
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Describe
        host: "*"
EOF
```

This will generate a secret of the same name, from where 

And specify a proper client properties file, of kind:

```
bootstrap.servers=<kafka_cluster_name>-kafka-bootstrap:9093
security.protocol=SSL
ssl.truststore.location=/tmp/ca.p12
ssl.truststore.password=<truststore_password>
ssl.keystore.location=/tmp/user.p12
ssl.keystore.password=<keystore_password>
group.id=my-group
```

The certs and keys can be exported from kafka and imported into the truststore.

For the cluster side:

```
kubectl get secret royce-cluster-ca-cert -n kafka -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
kubectl get secret royce-cluster-ca-cert -n kafka -o jsonpath='{.data.ca\.p12}' | base64 -d > ca.p12
kubectl get secret royce-cluster-ca-cert -n kafka -o jsonpath='{.data.ca\.password}' | base64 -d > ca.password
```

For the newly created user:
```
kubectl get secret my-user -n kafka  -o jsonpath='{.data.user\.password}' | base64 -d > user.password
kubectl get secret my-user -n kafka  -o jsonpath='{.data.user\.p12}' | base64 -d > user.p12
```

This translates into:

```
bootstrap.servers=royce-kafka-bootstrap:9093
security.protocol=SSL
ssl.truststore.location=/tmp/ca.p12
ssl.truststore.password=<content-of-ca.password>
ssl.keystore.location=/tmp/user.p12
ssl.keystore.password=<content-of-user.password>
group.id=my-group
```

You can otherwise create a JKS keystore and a datastore.
```
keytool -keystore user-truststore.jks -alias CARoot -import -file ca.crt
keytool -importkeystore -srckeystore user.p12 -srcstoretype pkcs12 -destkeystore user-keystore.jks -deststoretype jks
```
For instance, we use *changeit* as password for the truststore, and *changeit* as password for the keystore.
For the latter, the destination password is *changeit* whereas the source keystore password is the one defined in `user.password`.
This translates into:

```
bootstrap.servers=royce-kafka-bootstrap:9093
security.protocol=SSL
ssl.truststore.location=/tmp/user-truststore.jks
ssl.truststore.password=changeit
ssl.keystore.location=/tmp/user.p12
ssl.keystore.password=<content-of-user.password>
group.id=my-group
```

The files can be finally uploaded to the producer and consumer pods with a `kubectl cp config.properties <interactive_pod_name>:/tmp/config.properties`.

```bash
kubectl -n kafka run kafka-producer -ti --image=quay.io/strimzi/kafka:0.29.0-kafka-3.2.0 --rm=true --restart=Never bash
kubectl cp -n kafka user.p12 kafka-producer:/tmp
kubectl cp -n kafka ca.p12 kafka-producer:/tmp
kubectl cp -n kafka client.properties kafka-producer:/tmp

bin/kafka-console-producer.sh --bootstrap-server royce-kafka-bootstrap:9093 --topic my-topic --producer.config /tmp/client.properties
>hello world!
>
>aaa
>
>bbb
>
```

```bash
kubectl -n kafka run kafka-consumer -ti --image=quay.io/strimzi/kafka:0.29.0-kafka-3.2.0 --rm=true --restart=Never bash
kubectl cp -n kafka user.p12 kafka-consumer:/tmp
kubectl cp -n kafka ca.p12 kafka-consumer:/tmp
kubectl cp -n kafka client.properties kafka-consumer:/tmp
bin/kafka-console-consumer.sh --bootstrap-server royce-kafka-bootstrap:9093 --topic my-topic --from-beginning --consumer.config /tmp/client.properties
hello world!

aaa

bbb
```

Or otherwise using the jks truststore:

```bash
bin/kafka-console-producer.sh --bootstrap-server royce-kafka-bootstrap:9093 --topic my-topic --producer.config /tmp/client-jks.properties 
[2022-06-12 01:47:20,532] WARN The configuration 'group.id' was supplied but isn't a known config. (org.apache.kafka.clients.producer.ProducerConfig)
>hello world!
>
```
```
bin/kafka-console-consumer.sh --bootstrap-server royce-kafka-bootstrap:9093 --topic my-topic --from-beginning --consumer.config /tmp/client-jks.properties 

hello world!
```

Also, the broker is exposed externally as a nodeport, so the same process can be actuated with either the producer or the consumer running outside the cluster.
To retrieve the actual port being binded on:

```
kubectl get service royce-kafka-external-bootstrap -n kafka -o=jsonpath='{.spec.ports[0].nodePort}{"\n"}'
```

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

## Woof
