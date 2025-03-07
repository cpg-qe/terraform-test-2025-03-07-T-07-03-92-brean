# Generate a random string suffix for the subnetwork
resource "random_string" "subnet_suffix" {
  length  = 4
  upper   = false
  lower   = true
  numeric  = true
  special = false
}

# Create a subnetwork with a unique name
resource "google_compute_subnetwork" "subnetdata" {
  project       = var.project
  region        = var.region
  name          = "${var.subnet_id}-${random_string.subnet_suffix.result}"  # Dynamic name
  ip_cidr_range = var.subnet_cidr  # Ensure you have a variable for CIDR range
  network       = var.network        # Ensure you have a variable for the VPC network
}

# Generate a random string suffix for the VM
resource "random_string" "vm_suffix" {
  length  = 4
  upper   = false
  lower   = true
  numeric  = true
  special = false
}

# Create a VM instance referencing the dynamically created subnet
resource "google_compute_instance" "csc_basic_vm" {
  name           = "${var.vm_name}-${random_string.vm_suffix.result}"  # Dynamic VM name
  machine_type   = var.machine_type
  zone           = var.zone
  desired_status = var.vm_desired_status

  boot_disk {
    device_name = "${var.vm_name}-disk"
    auto_delete = var.auto_delete
    mode        = "READ_WRITE"

    initialize_params {
      image = var.image
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnetdata.self_link  # Reference to the created subnet

    access_config {
      // Ephemeral public IP
    }
  }

  metadata = var.authentication_type == "ssh_key" ? {
    ssh-keys       = "${var.ssh_user}:${var.ssh_pub_key}"
    enable-oslogin = "FALSE"
  } : {}

  metadata_startup_script = var.authentication_type == "ssh_key" ? "" : <<EOT
    #!/bin/bash
    # Set up a new user with a password
    useradd -m -s /bin/bash "${var.vm_username}"
    echo "${var.vm_username}:${var.vm_password}" | chpasswd
    usermod -aG sudo "${var.vm_username}"
    sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    systemctl restart ssh
  EOT
}

# Output the subnetwork and VM details
output "subnetwork_id" {
  value = google_compute_subnetwork.subnetdata.id
}

output "subnetwork_cidr" {
  value = google_compute_subnetwork.subnetdata.ip_cidr_range
}

output "vm_id" {
  value = google_compute_instance.csc_basic_vm.id
}