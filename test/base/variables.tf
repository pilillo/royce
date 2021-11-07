variable "region" {
  default     = "eu-west-1"
  description = "AWS region"
}

variable "profile" {
    default     = "royce"
    description = "AWS profile"
}

variable "cluster_name" {
  default     = "royce-test-cluster"
  description = "Name of EKS cluster"
}

variable "k8s_cluster_version" {
    default     = "1.21"
    description = "Version of K8s"
}

variable "vpc_name" {
    default     = "royce-test-vpc"
    description = "Name of VPC"
}