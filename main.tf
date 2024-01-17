terraform {
  backend "kubernetes" {
    secret_suffix = "okteto"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.5.0"
    }
  }
  required_version = ">= 1.5.4"
}
provider "google" {
  project = var.gcpProject
}

provider "kubernetes" {
  config_path = var.kubeconfig
}


resource "google_pubsub_topic" "this" {
  name = format("topic-%s", var.name)
}

resource "google_service_account" "this" {
  project      = var.gcpProject
  account_id   = format("%spubsub", var.name)
  display_name = format("%spubsub", var.name)
}

resource "google_project_iam_binding" "this" {
  role    = "roles/pubsub.editor"
  project = var.gcpProject
  members = ["serviceAccount:${google_service_account.this.email}"]
}

resource "google_service_account_key" "this" {
  service_account_id = google_service_account.this.name
}

variable "name" {
  type        = string
  description = "pubsub topic name"
  default     = null
}
variable "gcpProject" {
  type        = string
  description = "GCP project"
  default     = null
}

variable "kubeconfig" {
  type        = string
  description = "kubernetes kubeconfig file path"
  default     = null
}

resource "local_file" "this" {
  content  = base64decode(google_service_account_key.this.private_key)
  filename = "k8s/credentials.json"
}

resource "kubernetes_secret" "this" {
  metadata {
    name      = "gcp-credentials"
    namespace = var.name
  }
  data = {
    "credentials.json" = base64decode(google_service_account_key.this.private_key)
  }
}
