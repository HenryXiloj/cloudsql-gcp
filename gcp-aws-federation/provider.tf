# Terraform + provider configuration.
# Both the google and google-beta providers are required: the Workload Identity
# Pool / Provider resources below use the google-beta provider.
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }
}

# Credentials come from Application Default Credentials (gcloud auth
# application-default login) or a CI service account — no keys in this repo.
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
