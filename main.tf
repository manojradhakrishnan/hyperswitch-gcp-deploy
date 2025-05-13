terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

data "google_compute_network" "default" {
  name = "default"
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.instance_name}-allow-ssh"
  network = data.google_compute_network.default.self_link
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"] # Consider restricting this to specific IPs if possible
  target_tags   = [var.instance_name]
}

resource "google_compute_firewall" "allow_hyperswitch" {
  name    = "${var.instance_name}-allow-hyperswitch"
  network = data.google_compute_network.default.self_link
  allow {
    protocol = "tcp"
    ports    = ["8080"] # Assuming Hyperswitch runs on port 8080 (via network_mode: host)
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.instance_name]
}

resource "google_compute_instance" "hyperswitch_server" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.gcp_zone
  tags         = [var.instance_name] # For firewall rules

  boot_disk {
    initialize_params {
      image = "${var.image_project}/${var.image_family}"
      size  = 10 # GB, f1-micro free tier includes 30GB standard persistent disk
    }
  }

  network_interface {
    network = data.google_compute_network.default.self_link
    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = file("${path.module}/startup.sh")

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform", # Broad scopes, consider narrowing if possible
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }

  allow_stopping_for_update = true
}

output "instance_ip" {
  value = google_compute_instance.hyperswitch_server.network_interface[0].access_config[0].nat_ip
}

output "ssh_command" {
  value = "gcloud compute ssh --project ${var.project_id} --zone ${var.gcp_zone} ${var.instance_name}"
} 