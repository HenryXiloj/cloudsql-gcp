# EKS (Kubernetes OIDC) Workload Identity Pool Providers.
#
# EKS pods authenticate with a projected Kubernetes ServiceAccount JWT signed by
# the cluster's own OIDC issuer (https://oidc.eks.<region>.amazonaws.com/id/...),
# NOT with an AWS IAM credential — so these use an oidc {} block, unlike the
# aws {} provider in aws-wif-pool.tf. One provider is created per entry in
# var.eks_clusters, all attached to the same pool. See doc/eks.md.
resource "google_iam_workload_identity_pool_provider" "eks" {
  for_each = var.eks_clusters

  provider                           = google-beta
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.aws-wif.workload_identity_pool_id
  workload_identity_pool_provider_id = "eks-provider-${each.key}"
  display_name                       = each.value.display_name
  description                        = each.value.description

  attribute_mapping = var.eks_idp_attribute_mapping

  # Provider-level gate: accept ONLY the ServiceAccounts listed for this cluster.
  # Builds e.g. assertion.sub == "system:serviceaccount:ns:sa" || assertion.sub == "...".
  attribute_condition = join(" || ", [
    for sa in each.value.allowed_service_accounts : "assertion.sub == \"${sa}\""
  ])

  # The cluster's OIDC issuer — Google validates the JWT signature against it.
  oidc {
    issuer_uri = each.value.issuer_uri
  }
}
