output "api_gateway_url" {
  description = "API Gateway base URL"
  value       = "https://${google_api_gateway_gateway.whales_gateway.default_hostname}"
}

output "backend_cloud_run_url" {
  description = "Backend Cloud Run service URL"
  value       = google_cloud_run_service.backend_api.status[0].url
}

output "frontend_cloud_run_url" {
  description = "Frontend Cloud Run service URL"
  value       = google_cloud_run_service.frontend.status[0].url
}

output "firestore_database" {
  description = "Firestore database name"
  value       = google_firestore_database.main.name
}

output "uploads_bucket_name" {
  description = "Cloud Storage bucket for application uploads"
  value       = google_storage_bucket.application_uploads.name
}

output "static_bucket_name" {
  description = "Cloud Storage bucket for static assets"
  value       = google_storage_bucket.static_assets.name
}

output "backend_service_account_email" {
  description = "Service Account email for backend"
  value       = google_service_account.backend_sa.email
}

output "gcp_region" {
  description = "GCP region where resources are deployed"
  value       = var.gcp_region
}

output "gcp_project_id" {
  description = "GCP project ID"
  value       = var.gcp_project_id
}
