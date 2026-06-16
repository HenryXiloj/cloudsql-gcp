# ---------------------------------------------------------------------------
# Core project settings (always required) — set in terraform.tfvars.
# ---------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID (e.g. my-project)."
  default     = ""
}

variable "project_number" {
  description = "GCP project NUMBER. WIF principal/principalSet members use the number, not the ID."
  default     = ""
}

variable "region" {
  description = "Default region; also the location of the example bucket."
  default     = ""
}

variable "zone" {
  default = ""
}

# Secondary region/zone — not used by the resources here; kept for convenience.
variable "sec_region" {
  default = ""
}

variable "sec_zone" {
  default = ""
}

# ---------------------------------------------------------------------------
# EKS path (Kubernetes OIDC) — see doc/eks.md.
# ---------------------------------------------------------------------------

# One entry per EKS cluster; each creates an OIDC provider on the pool.
# allowed_service_accounts gates the provider (which K8s ServiceAccounts may federate).
variable "eks_clusters" {
  type = map(object({
    issuer_uri               = string
    display_name             = string
    description              = string
    allowed_service_accounts = list(string)
  }))
  description = "EKS clusters to federate, keyed by a short cluster alias."
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.eks_clusters : length(v.allowed_service_accounts) > 0 && alltrue([
        for sa in v.allowed_service_accounts : startswith(sa, "system:serviceaccount:")
      ])
    ])
    error_message = "Each EKS cluster must list at least one allowed_service_accounts entry, each formatted as system:serviceaccount:<namespace>:<name>."
  }
}

# K8s ServiceAccount subjects bound for impersonation. Must match the
# allowed_service_accounts above (one gates the provider, the other binds the SA).
variable "example_eks_subjects" {
  type    = list(string)
  default = []
}

# Attribute mapping for the EKS OIDC providers (maps OIDC claims → GCP attributes).
variable "eks_idp_attribute_mapping" {
  type        = map(any)
  description = "EKS (Kubernetes OIDC) Workload Identity Pool Provider attribute mapping."

  default = {
    "google.subject"                 = "assertion.sub"
    "attribute.namespace"            = "assertion['kubernetes.io']['namespace']"
    "attribute.service_account_name" = "assertion['kubernetes.io']['serviceaccount']['name']"
  }
}

# ---------------------------------------------------------------------------
# EC2 / AWS IAM path — see doc/ec2.md.
# ---------------------------------------------------------------------------

# AWS account that the AWS IAM provider trusts (scopes the aws {} provider).
variable "aws_account_id" {
  type    = string
  default = ""
}

# AWS IAM role NAME (not the ARN) used to build the principalSet binding.
variable "example_aws_role_name" {
  type    = string
  default = "example-gcp-upload-role"
}
