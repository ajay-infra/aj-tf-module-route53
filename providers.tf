terraform {
  required_version = "= 1.10.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.100.0"
    }
  }

  # Backend configured by the pipeline via -backend-config. One state per
  # zone, in the account that owns the zone — never cross-account
  # (aj-infra-context/arch/account-model.md §6).
  # backend "s3" {}
}

# Route 53 is a global service; the region matters only for the query-log
# group, which Route 53 will only write to in us-east-1.
provider "aws" {
  region = var.aws_region

  # Plan offline. No live reads — a plan with dummy credentials is a real
  # diff. The only data sources are aws_iam_policy_document, which renders
  # JSON locally and calls nothing. This is a property the estate depends
  # on (aj-infra-context/arch/capability-map.md); do not add a data source
  # without also adding a way to skip it.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  default_tags {
    tags = local.full_tags
  }
}
