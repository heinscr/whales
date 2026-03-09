terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket  = "whales-terraform-state"
    prefix  = "whales"
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
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
  name            = "${var.environment}-database"
  location_id     = var.gcp_region
  type            = "FIRESTORE_NATIVE"
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

# Cloud Run Service for Backend API
resource "google_cloud_run_service" "backend_api" {
  name     = "${var.environment}-api"
  location = var.gcp_region

  template {
    spec {
      service_account_name = google_service_account.backend_sa.email
      
      containers {
        image = var.backend_image_url != "" ? var.backend_image_url : "gcr.io/google.com/cloudrun/hello"
        
        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }
        
        env {
          name  = "GCP_PROJECT_ID"
          value = var.gcp_project_id
        }
        
        env {
          name  = "FIRESTORE_DATABASE"
          value = google_firestore_database.main.name
        }
        
        env {
          name  = "STORAGE_BUCKET"
          value = google_storage_bucket.application_uploads.name
        }

        ports {
          container_port = 8080
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.required_apis,
    google_firestore_database.main
  ]
}

# Allow public access to Cloud Run service
resource "google_cloud_run_service_iam_member" "public_invoker" {
  service       = google_cloud_run_service.backend_api.name
  location      = google_cloud_run_service.backend_api.location
  role          = "roles/run.invoker"
  member        = "allUsers"
}

# API Gateway - API Config
resource "google_api_gateway_api" "whales_api" {
  provider = google
  api_id   = "${var.environment}-api"

  depends_on = [google_project_service.required_apis]
}

resource "google_api_gateway_api_config" "whales_api_config" {
  api            = google_api_gateway_api.whales_api.api_id
  api_config_id  = "${var.environment}-config-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  display_name   = "Whales API Config"

  openapi_documents {
    document {
      path     = "openapi.yaml"
      contents = base64encode(templatefile("${path.module}/openapi.yaml", {
        cloud_run_url = google_cloud_run_service.backend_api.status[0].url
      }))
    }
  }

  depends_on = [google_project_service.required_apis]
}

# API Gateway - Gateway
resource "google_api_gateway_gateway" "whales_gateway" {
  api_config      = google_api_gateway_api_config.whales_api_config.id
  gateway_id      = "${var.environment}-gateway"
  display_name    = "Whales API Gateway"
  region          = var.gcp_region

  depends_on = [google_project_service.required_apis]
}

# Cloud Run Service for Frontend (static assets)
resource "google_cloud_run_service" "frontend" {
  name     = "${var.environment}-frontend"
  location = var.gcp_region

  template {
    spec {
      containers {
        # Use a simple Node.js image to serve static files
        image = var.frontend_image_url != "" ? var.frontend_image_url : "gcr.io/google.com/cloudrun/hello"
        
        env {
          name  = "API_GATEWAY_URL"
          value = google_api_gateway_gateway.whales_gateway.default_hostname
        }

        ports {
          container_port = 3000
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [google_project_service.required_apis]
}

# Allow public access to frontend
resource "google_cloud_run_service_iam_member" "frontend_public" {
  service       = google_cloud_run_service.frontend.name
  location      = google_cloud_run_service.frontend.location
  role          = "roles/run.invoker"
  member        = "allUsers"
}
