include "root" {
  path = find_in_parent_folders()
}

dependency "base" {
  config_path = "../base"
}

inputs = {
  eks_endpoint = dependency.base.outputs.eks_endpoint
  eks_certificate = dependency.base.outputs.eks_certificate
  eks_token = dependency.base.outputs.eks_token
}