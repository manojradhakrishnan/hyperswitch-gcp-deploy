variable "project_id" {
  description = "The GCP project ID to deploy Hyperswitch into."
  type        = string
}

variable "gcp_region" {
  description = "The GCP region to deploy resources into."
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "The GCP zone to deploy resources into."
  type        = string
  default     = "us-central1-a"
}

variable "instance_name" {
  description = "Name for the Compute Engine instance."
  type        = string
  default     = "hyperswitch-vm"
}

variable "machine_type" {
  description = "Machine type for the Compute Engine instance (f1-micro for free tier)."
  type        = string
  default     = "f1-micro"
}

variable "image_project" {
  description = "Project for the boot image."
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "image_family" {
  description = "Family for the boot image."
  type        = string
  default     = "ubuntu-2204-lts"
} 