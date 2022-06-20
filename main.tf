terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

variable "bridge_name" {
  default  = "virbr2"
  nullable = false
}

variable "ubuntu_cloud_image_location" {
  type        = string
  default     = "/v-machines/cloud-images/focal-server-cloudimg-amd64.img"
  nullable    = false
  description = "location of ubuntu cloud img file. Only tested with fossa (20.04). One can also use the HTTP directly if you don't want to download it first."
}

variable "kafka_vm_pool_location" {
  type     = string
  default  = "/v-machines/kafka-pool"
  nullable = false
}

variable "nodes" {
  type = object({
    disk_size_in_bytes = number
    count              = number
    memory_in_mbytes   = number
    vcpus              = number
  })
  default = {
    disk_size_in_bytes = 15 * 1024 * 1024 * 1024
    memory_in_mbytes   = 4 * 1024
    vcpus              = 2
    count              = 3
  }
  nullable = false
}

variable "base_ip_address" {
  type        = string
  default     = "192.168.100"
  nullable    = false
  description = "Initial 3 octets of a class C IP address of a KVM network configured. Addresses will start with 2 (kafka-vm-0=$base_ip_address.2)"
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_pool" "kafka" {
  name = "kafka-pool"
  type = "dir"
  path = var.kafka_vm_pool_location
}

resource "libvirt_volume" "os_image_ubuntu" {
  name   = "os_image_ubuntu"
  pool   = "kafka-pool"
  source = var.ubuntu_cloud_image_location
}

resource "libvirt_volume" "volume_resized" {
  name           = "kafka-vm-${count.index}.qcow2"
  pool           = libvirt_pool.kafka.name
  base_volume_id = libvirt_volume.os_image_ubuntu.id
  size           = var.nodes.disk_size_in_bytes
  count          = var.nodes.count
}

resource "libvirt_cloudinit_disk" "kafkainit" {
  count          = var.nodes.count
  name           = "kafkainit-${count.index}.iso"
  pool           = libvirt_pool.kafka.name
  user_data      = <<EOF
#cloud-config
users:
  - name: ubuntu
    groups: [sudo]
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    ssh-authorized-keys:
      - ${file("~/.ssh/id_rsa.pub")}
growpart:
  mode: auto
  devices: ['/']
runcmd:
  - sudo hostnamectl set-hostname kafka-vm-${count.index}
package_update: false 
package_upgrade: false
EOF
  network_config = <<EOF
    version: 2
    ethernets:
      ens3:
        addresses: [${var.base_ip_address}.${count.index + 2}/24]
        gateway4: ${var.base_ip_address}.1
        nameservers:
          addresses: [${var.base_ip_address}.1]
EOF
}


resource "libvirt_domain" "kafka-domain" {
  name      = "kafka-vm-${count.index}"
  memory    = var.nodes.memory_in_mbytes
  vcpu      = var.nodes.vcpus
  cloudinit = element(libvirt_cloudinit_disk.kafkainit.*.id, count.index)

  network_interface {
    #network_name = "default"
    bridge    = var.bridge_name
    hostname  = "kafka-vm-${count.index}"
    addresses = ["${var.base_ip_address}.${count.index + 2}"]
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  disk {
    volume_id = element(libvirt_volume.volume_resized.*.id, count.index)
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
  count = 3

  provisioner "file" {
    source      = "install_confluent.sh"
    destination = "/home/ubuntu/install_confluent.sh"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = "${var.base_ip_address}.${count.index + 2}"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "file" {
    source      = "zookeeper.properties"
    destination = "/home/ubuntu/zookeeper.properties"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = "${var.base_ip_address}.${count.index + 2}"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "remote-exec" {
    # inline = ["sudo apt-add-repository ppa:fish-shell/release-3 -y; sudo apt-get update && sudo apt-get upgrade -y; sudo apt-get install fish -y"]
    inline = [
      "chmod +x /home/ubuntu/install_confluent.sh",
      "/home/ubuntu/install_confluent.sh ${var.base_ip_address}.${count.index + 2}  ${count.index}"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = "${var.base_ip_address}.${count.index + 2}"
      private_key = file("~/.ssh/id_rsa")
    }
  }
}

