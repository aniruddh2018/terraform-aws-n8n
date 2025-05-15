terraform {
  required_version = "~> 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30" # Specify a recent, appropriate version
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5" # Specify a recent, appropriate version
    }
  }
} 