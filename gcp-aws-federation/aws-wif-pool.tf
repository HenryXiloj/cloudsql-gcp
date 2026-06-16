# The Workload Identity Pool — the single federation boundary for this project.
# Both the AWS provider (below) and the EKS providers (eks-identity-provider.tf)
# attach to this one pool.
resource "google_iam_workload_identity_pool" "aws-wif" {
  provider                  = google-beta
  project                   = var.project_id
  workload_identity_pool_id = "aws-wif-pool"
  display_name              = "Example AWS WIF"
  description               = "Workload Identity Pool for AWS / EKS federation"

  depends_on = [google_project_service.wif_api]
}

# AWS IAM provider — for workloads that present AWS STS/IAM credentials
# (EC2 instances, or EKS pods using a node role / IRSA). See doc/ec2.md.
# Use the OIDC providers in eks-identity-provider.tf instead if the pod
# presents a Kubernetes ServiceAccount token.
resource "google_iam_workload_identity_pool_provider" "aws" {
  provider                           = google-beta
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.aws-wif.workload_identity_pool_id
  workload_identity_pool_provider_id = "aws-provider"
  display_name                       = "AWS Provider"
  description                        = "AWS IAM federation provider"

  # Maps claims from the AWS credential into GCP attributes. attribute.aws_role
  # is what the EC2 binding gates on (principalSet .../attribute.aws_role/<role>).
  attribute_mapping = {
    "google.subject"        = "assertion.arn"
    "attribute.aws_account" = "assertion.account"
    "attribute.aws_role"    = "assertion.arn.extract('assumed-role/{role}/')"
  }

  # account_id scopes the provider to a single AWS account.
  aws {
    account_id = var.aws_account_id
  }
}
