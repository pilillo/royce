# https://github.com/bharatmicrosystems/argo-cd-example/blob/main/terraform/main.tf

provider "kubectl" {
  host                   = var.eks_endpoint
  cluster_ca_certificate = var.eks_certificate
  token                  = var.eks_token
  load_config_file       = false
}

# 1. create namespace for argocd
data "kubectl_file_documents" "namespace" {
    content = file("manifests/namespace.yaml")
} 

resource "kubectl_manifest" "namespace" {
    count     = length(data.kubectl_file_documents.namespace.documents)
    yaml_body = element(data.kubectl_file_documents.namespace.documents, count.index)
    override_namespace = "argocd"
}

# 2. install argocd
data "kubectl_file_documents" "argocd" {
    content = file("manifests/install.yaml")
}

resource "kubectl_manifest" "argocd" {
    depends_on = [
      kubectl_manifest.namespace,
    ]
    count     = length(data.kubectl_file_documents.argocd.documents)
    yaml_body = element(data.kubectl_file_documents.argocd.documents, count.index)
    override_namespace = "argocd"
}

# 3. install root app
data "kubectl_file_documents" "root-app" {
    content = file("manifests/root-app.yaml")
}

resource "kubectl_manifest" "root-app" {
    depends_on = [
      kubectl_manifest.argocd,
    ]
    count     = length(data.kubectl_file_documents.root-app.documents)
    yaml_body = element(data.kubectl_file_documents.root-app.documents, count.index)
    override_namespace = "argocd"
}