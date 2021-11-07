terraform {
    required_providers {
        kubectl = {
            source  = "gavinbunney/kubectl"
            version = ">= 1.7.0"
        }

    }
    required_version = ">= 0.14.9"
}