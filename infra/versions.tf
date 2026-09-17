# Provider and version constraints for the Tasklane infrastructure module.
#
# No state backend is configured and no credentials are referenced. The module
# describes the infrastructure the application requires; it is validated,
# formatted and scanned as source, and never applied.

terraform {
  required_version = "~> 1.16"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}
