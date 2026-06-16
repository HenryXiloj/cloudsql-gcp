# EC2 / AWS IAM path example — see doc/ec2.md.
# A separate GCP service account that the AWS IAM role impersonates. It has its
# own SA (not the EKS one) so its authoritative workloadIdentityUser binding
# does not conflict with the EKS binding in example-aws-wif.tf.

resource "google_service_account" "example_aws_ec2" {
  project      = var.project_id
  account_id   = "example-aws-ec2-sa"
  display_name = "Example AWS EC2 (IAM role) Service Account for test upload"

  depends_on = [google_project_service.wif_api]
}

# Let any identity assuming the AWS IAM role impersonate the SA above.
# `principalSet://.../attribute.aws_role/<role>` matches a GROUP of identities
# (everyone with that aws_role attribute), unlike the single-subject principal
# used for the EKS path. local.example_wif_pool is defined in example-aws-wif.tf.
resource "google_service_account_iam_binding" "example-aws-ec2-sa-binding" {
  service_account_id = google_service_account.example_aws_ec2.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "principalSet://iam.googleapis.com/${local.example_wif_pool}/attribute.aws_role/${var.example_aws_role_name}"
  ]
}

# Write-only access to the shared bucket (defined in example-aws-wif.tf).
resource "google_storage_bucket_iam_member" "example-aws-ec2-bucket-creator" {
  bucket = google_storage_bucket.test_bucket.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.example_aws_ec2.email}"
}
