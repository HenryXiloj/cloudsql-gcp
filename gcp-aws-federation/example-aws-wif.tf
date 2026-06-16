# EKS path example (Kubernetes OIDC) — see doc/eks.md.
# A GCP service account that EKS ServiceAccounts impersonate to upload to GCS.

resource "google_service_account" "example_aws_wif" {
  project      = var.project_id
  account_id   = "example-aws-wif-sa"
  display_name = "Example AWS WIF Service Account for test upload"

  depends_on = [google_project_service.wif_api]
}

# Full resource path of the pool, reused by both example files to build the
# principal / principalSet members. Note WIF members use the project NUMBER.
locals {
  example_wif_pool = "projects/${var.project_number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.aws-wif.workload_identity_pool_id}"
}

# Let each Kubernetes ServiceAccount subject impersonate the SA above.
# `principal://.../subject/<sub>` targets a single federated identity (the OIDC
# token's sub), as opposed to the principalSet used for the AWS-role path.
resource "google_service_account_iam_binding" "example-aws-wif-sa-binding" {
  service_account_id = google_service_account.example_aws_wif.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    for subject in var.example_eks_subjects :
    "principal://iam.googleapis.com/${local.example_wif_pool}/subject/${subject}"
  ]
}

# Example destination bucket. Shared by both the EKS and EC2 examples.
resource "google_storage_bucket" "test_bucket" {
  name                        = "example-test-bucket"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  depends_on = [google_project_service.wif_api]
}

# Write-only access: objectCreator allows uploading objects but not listing,
# reading, or deleting them.
resource "google_storage_bucket_iam_member" "example-aws-wif-bucket-creator" {
  bucket = google_storage_bucket.test_bucket.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.example_aws_wif.email}"
}
