project_id     = "your-project-id"
project_number = "000000000000"
region         = "us-central1"
zone           = "us-central1-a"

# --- EKS path only (see doc/eks.md) ---
# eks_clusters = {
#   "example-dev" = {
#     issuer_uri   = "https://oidc.eks.<my-region>.amazonaws.com/id/EXAMPLE0OIDCID"
#     display_name = "Example EKS Dev Cluster"
#     description  = "EKS OIDC Identity Provider"
#     allowed_service_accounts = [
#       "system:serviceaccount:example-ns:example-sa",
#     ]
#   }
# }
# example_eks_subjects = [
#   "system:serviceaccount:example-ns:example-sa",
# ]

# --- EC2 / AWS IAM path only (see doc/ec2.md) ---
# aws_account_id        = "<aws-account-id>"
# example_aws_role_name = "example-gcp-upload-role"
