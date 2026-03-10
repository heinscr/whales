terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "google-beta" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# Terraform State Bucket
resource "google_storage_bucket" "terraform_state" {
  name     = "whales-terraform-state-${var.gcp_project_id}"
  location = "US"

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 3
    }
    action {
      type = "Delete"
    }
  }
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",
    "apigateway.googleapis.com",
    "servicemanagement.googleapis.com",
    "servicecontrol.googleapis.com",
    "firestore.googleapis.com",
    "storage.googleapis.com",
    "artifactregistry.googleapis.com"
  ])

  service            = each.value
  disable_on_destroy = false
}

# Firestore Database
resource "google_firestore_database" "main" {
  name             = "${var.environment}-database"
  location_id      = var.gcp_region
  type             = "FIRESTORE_NATIVE"
  concurrency_mode = "OPTIMISTIC"

  depends_on = [google_project_service.required_apis]
}

# Cloud Storage Buckets
resource "google_storage_bucket" "application_uploads" {
  name          = "${var.gcp_project_id}-${var.environment}-uploads"
  location      = var.gcp_region
  force_destroy = var.environment != "production"

  uniform_bucket_level_access = true

  versioning {
    enabled = false
  }
}

resource "google_storage_bucket" "static_assets" {
  name          = "${var.gcp_project_id}-${var.environment}-static"
  location      = var.gcp_region
  force_destroy = var.environment != "production"

  uniform_bucket_level_access = true

  versioning {
    enabled = var.environment == "production"
  }
}

# Service Account for Cloud Run
resource "google_service_account" "backend_sa" {
  account_id   = "${var.environment}-backend-sa"
  display_name = "Backend Cloud Run Service Account"
}

# IAM Bindings for Service Account
resource "google_project_iam_member" "backend_firestore" {
  project = var.gcp_project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.backend_sa.email}"
}

resource "google_project_iam_member" "backend_storage" {
  project = var.gcp_project_id
  role    = "roles/storage.objectUser"
  member  = "serviceAccount:${google_service_account.backend_sa.email}"
}

resource "google_project_iam_member" "backend_artifactregistry" {
  project = var.gcp_project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.backend_sa.email}"
}

