provider "google" {
  project = var.project_id
  region  = "europe-west1"
}

resource "google_compute_instance" "sonarqube" {
  name         = "sonarqube-server"
  machine_type = "e2-standard-4"
  zone         = "europe-west1-d"

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-11" # Debian 11
      size  = 30 # Disk size in GB
      type  = "pd-ssd" # SSD disk
    }
  }

  network_interface {
    network       = "default"
    access_config {} # Assign a public IP
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y openjdk-11-jdk
    echo "Java installed for SonarQube."
  EOT

  tags = ["sonarqube"]

  labels = {
    environment = "dev"
  }
}

resource "google_compute_firewall" "sonarqube_firewall" {
  name    = "allow-sonarqube-http-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "9000"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["sonarqube"]
}

output "sonarqube_instance_ip" {
  value = google_compute_instance.sonarqube.network_interface[0].access_config[0].nat_ip
  description = "Public IP of the SonarQube server"
}

