variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "backend_image_url" {
  description = "Cloud Run backend container image URL (gcr.io/project/image:tag)"
  type        = string
  default     = ""
}

variable "frontend_image_url" {
  description = "Cloud Run frontend container image URL (gcr.io/project/image:tag)"
  type        = string
  default     = ""
}
