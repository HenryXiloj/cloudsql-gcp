# Enable the GCP APIs that WIF and the example bucket depend on.
# These must exist before the pool / service accounts / bucket are created,
# which is why those resources declare `depends_on = [google_project_service.wif_api]`.
resource "google_project_service" "wif_api" {
  for_each = toset([
    "iam.googleapis.com",                  # service accounts + WIF
    "cloudresourcemanager.googleapis.com", # project-level IAM
    "iamcredentials.googleapis.com",       # short-lived token generation
    "sts.googleapis.com",                  # token exchange (federation)
    "storage.googleapis.com",              # the example GCS bucket
  ])

  service = each.value
  # Keep the APIs enabled if this config is destroyed (they may be shared).
  disable_on_destroy = false
}
