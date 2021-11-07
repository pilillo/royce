remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    profile="royce"
    bucket = "royce-tf-state"
    #key="global/terraform.tfstate"
    key = "${path_relative_to_include()}/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "royce-tf-lock"
  }
}