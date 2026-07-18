terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "billing_alerts" {
  source = "../.."

  billing_account    = var.billing_account
  display_name       = "example-budget"
  amount             = 500
  threshold_percents = [0.5, 0.9, 1.0]
  projects           = ["projects/${var.project_id}"]
}

variable "project_id" {
  description = "Project ID used to configure the google provider and scope the budget."
  type        = string
}

variable "billing_account" {
  description = "Billing account id the budget is created under."
  type        = string
}

variable "region" {
  description = "Region for the google provider."
  type        = string
  default     = "us-central1"
}

output "budget_name" {
  value = module.billing_alerts.name
}
