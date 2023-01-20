###################################
##      Terraform providers       ##
###################################

provider "vsphere" {
  vsphere_server       = var.vsphere_server
  user                 = var.vsphere_user
  password             = var.vsphere_password
  allow_unverified_ssl = true
}

# Configure the Rancher2 provider to bootstrap and admin
# Provider config for bootstrap
provider "rancher2" {
  alias     = "bootstrap"
  api_url   = var.rancher_api_url
  bootstrap = true  
  insecure  = true
}

# Create a new rancher2_bootstrap using bootstrap provider config
resource "rancher2_bootstrap" "admin" {
  provider   = rancher2.bootstrap
  initial_password = var.rancher_admin_pass_initial
  password   = var.rancher_admin_pass
  telemetry  = true
  depends_on = [vsphere_virtual_machine.rancher01, vsphere_virtual_machine.rancher02, vsphere_virtual_machine.rancher03]
}

# Provider config for admin
provider "rancher2" {

  api_url   = rancher2_bootstrap.admin.url
  token_key = rancher2_bootstrap.admin.token
  insecure  = true
}

###################################
##      Terraform resources      ##
###################################

#===============================================================================
# Collect essential vSphere Data Sources
#===============================================================================

data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.vsphere_drs_cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = var.vsphere_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_network" "network" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.vsphere_template
  datacenter_id = data.vsphere_datacenter.dc.id
}

#===============================================================================
# Generate Templates to obfuscate secrets in them
#===============================================================================

data "template_file" "rke2_token" {
  template = file("templates/config.tpl")
  vars = {
    my-shared-secret = "${var.rke2_token}"
    san-1            = "${var.vsphere_network_ips["domain"]}"
    san-2            = "${var.rancher_fqdn}"
    san-3            = "${var.vm_01["ip"]}"
    san-4            = "${var.vm_01["name"]}"
    san-5            = "${var.vm_01["fqdn"]}"
    san-6            = "${var.vm_02["ip"]}"
    san-7            = "${var.vm_02["name"]}"
    san-8            = "${var.vm_02["fqdn"]}"
    san-9            = "${var.vm_03["ip"]}"
    san-10           = "${var.vm_03["name"]}"
    san-11           = "${var.vm_03["fqdn"]}"
  }
}

data "template_file" "rke2_token_server" {
  template = file("templates/config_server.tpl")
  vars = {
    server           = "${var.rancher_api}"
    my-shared-secret = "${var.rke2_token}"
    san-1            = "${var.vsphere_network_ips["domain"]}"
    san-2            = "${var.rancher_fqdn}"
    san-3            = "${var.vm_01["ip"]}"
    san-4            = "${var.vm_01["name"]}"
    san-5            = "${var.vm_01["fqdn"]}"
    san-6            = "${var.vm_02["ip"]}"
    san-7            = "${var.vm_02["name"]}"
    san-8            = "${var.vm_02["fqdn"]}"
    san-9            = "${var.vm_03["ip"]}"
    san-10           = "${var.vm_03["name"]}"
    san-11           = "${var.vm_03["fqdn"]}"
  }
}

#===============================================================================
# Local Resources to create from Terraform data Templates 
#===============================================================================

resource "local_file" "rke2_token" {
  content  = data.template_file.rke2_token.rendered
  filename = "files/config.yaml"
}

resource "local_file" "rke2_token_server" {
  content  = data.template_file.rke2_token_server.rendered
  filename = "files/config_server.yaml"
}

#===============================================================================
# Create rke2 engine 
#===============================================================================
resource "vsphere_virtual_machine" "rancher01" {
  name             = var.vm_01["name"]
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = var.vsphere_folder

  num_cpus = var.cpucount
  memory   = var.memory
  guest_id = data.vsphere_virtual_machine.template.guest_id

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "${var.vm_01["name"]}.vmdk"
    size             = data.vsphere_virtual_machine.template.disks.0.size
    eagerly_scrub    = data.vsphere_virtual_machine.template.disks.0.eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    linked_clone  = false

    customize {
      linux_options {
        host_name = var.vm_01["name"]
        domain    = var.vsphere_network_ips["domain"]
      }

      network_interface {
        ipv4_address = var.vm_01["ip"]
        ipv4_netmask = var.vsphere_network_ips["netmask"]
      }

      ipv4_gateway    = var.vsphere_network_ips["gateway"]
      dns_server_list = [var.vsphere_network_ips["dns-server"]]
    }
  }


  provisioner "file" {
    source      = "files/script.sh"
    destination = "/tmp/script.sh"

    connection {
      type     = "ssh"
      host     = self.default_ip_address
      user     = var.vm_ssh_user
      password = var.vm_ssh_password
    }
  }

  provisioner "file" {
    source      = "files/config.yaml"
    destination = "/tmp/config.yaml"

    connection {
      type     = "ssh"
      host     = self.default_ip_address
      user     = var.vm_ssh_user
      password = var.vm_ssh_password
    }
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      host     = self.default_ip_address
      user     = var.vm_ssh_user
      password = var.vm_ssh_password
    }

    inline = [
      "sudo chmod +x /tmp/script.sh",
      "sudo mkdir -p /etc/rancher/rke2",
      "sudo cp /tmp/config.yaml /etc/rancher/rke2",
      "echo '${var.vm_02["ip"]} ${var.vm_02["fqdn"]} ${var.vm_02["name"]}' | sudo tee -a /etc/hosts",
      "echo '${var.vm_03["ip"]} ${var.vm_03["fqdn"]} ${var.vm_03["name"]}' | sudo tee -a /etc/hosts",
      "sudo /tmp/script.sh"
    ]
  }
  lifecycle {
    ignore_changes = [disk]
  }
}

resource "vsphere_virtual_machine" "rancher02" {
  name             = var.vm_02["name"]
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = var.vsphere_folder

  num_cpus = var.cpucount
  memory   = var.memory
  guest_id = data.vsphere_virtual_machine.template.guest_id

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "${var.vm_02["name"]}.vmdk"
    size             = data.vsphere_virtual_machine.template.disks.0.size
    eagerly_scrub    = data.vsphere_virtual_machine.template.disks.0.eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    linked_clone  = false

    customize {
      linux_options {
        host_name = var.vm_02["name"]
        domain    = var.vsphere_network_ips["domain"]
      }

      network_interface {
        ipv4_address = var.vm_02["ip"]
        ipv4_netmask = var.vsphere_network_ips["netmask"]
      }

      ipv4_gateway    = var.vsphere_network_ips["gateway"]
      dns_server_list = [var.vsphere_network_ips["dns-server"]]
    }
  }


  provisioner "file" {
    source      = "files/script.sh"
    destination = "/tmp/script.sh"

    connection {
      type = "ssh"
      host = self.default_ip_address
      user = var.vm_ssh_user
      password = var.vm_ssh_password
    }
  }

  provisioner "file" {
    source      = "files/config_server.yaml"
    destination = "/tmp/config.yaml"

    connection {
      type     = "ssh"
      host     = self.default_ip_address
      user     = var.vm_ssh_user
      password = var.vm_ssh_password
    }
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      host     = self.default_ip_address
      user     = var.vm_ssh_user
      password = var.vm_ssh_password
    }

    inline = [
      "sudo chmod +x /tmp/script.sh",
      "sudo mkdir -p /etc/rancher/rke2",
      "sudo cp /tmp/config.yaml /etc/rancher/rke2",
      "echo '${var.vm_01["ip"]} ${var.vm_01["fqdn"]} ${var.vm_01["name"]}' | sudo tee -a /etc/hosts",
      "echo '${var.vm_03["ip"]} ${var.vm_03["fqdn"]} ${var.vm_03["name"]}' | sudo tee -a /etc/hosts",
      "sudo /tmp/script.sh"
    ]
  }
  lifecycle {
    ignore_changes = [disk]
  }
  depends_on = [vsphere_virtual_machine.rancher01]
}

resource "vsphere_virtual_machine" "rancher03" {
  name             = var.vm_03["name"]
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = var.vsphere_folder

  num_cpus = var.cpucount
  memory   = var.memory
  guest_id = data.vsphere_virtual_machine.template.guest_id

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "${var.vm_03["name"]}.vmdk"
    size             = data.vsphere_virtual_machine.template.disks.0.size
    eagerly_scrub    = data.vsphere_virtual_machine.template.disks.0.eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    linked_clone  = false

    customize {
      linux_options {
        host_name = var.vm_03["name"]
        domain    = var.vsphere_network_ips["domain"]
      }

      network_interface {
        ipv4_address = var.vm_03["ip"]
        ipv4_netmask = var.vsphere_network_ips["netmask"]
      }

      ipv4_gateway    = var.vsphere_network_ips["gateway"]
      dns_server_list = [var.vsphere_network_ips["dns-server"]]
    }
  }



  provisioner "file" {
    source      = "files/script.sh"
    destination = "/tmp/script.sh"

    connection {
      type     = "ssh"
      host     = self.default_ip_address
      user     = var.vm_ssh_user
      password = var.vm_ssh_password
    }
  }

  provisioner "file" {
    source      = "files/config_server.yaml"
    destination = "/tmp/config.yaml"

    connection {
      type     = "ssh"
      host     = self.default_ip_address
      user     = var.vm_ssh_user
      password = var.vm_ssh_password
    }
  }

  provisioner "file" {
    source      = "files/rancher_install.sh"
    destination = "/tmp/rancher_install.sh"

    connection {
      type     = "ssh"
      host     = self.default_ip_address
      user     = var.vm_ssh_user
      password = var.vm_ssh_password
    }
  }


  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      host     = self.default_ip_address
      user     = var.vm_ssh_user
      password = var.vm_ssh_password
    }

    inline = [
      "sudo chmod +x /tmp/script.sh",
      "sudo chmod +x /tmp/rancher_install.sh",
      "sudo mkdir -p /etc/rancher/rke2",
      "sudo cp /tmp/config.yaml /etc/rancher/rke2",
      "echo '${var.vm_01["ip"]} ${var.vm_01["fqdn"]} ${var.vm_01["name"]}' | sudo tee -a /etc/hosts",
      "echo '${var.vm_02["ip"]} ${var.vm_02["fqdn"]} ${var.vm_02["name"]}' | sudo tee -a /etc/hosts",
      "sudo /tmp/script.sh",
      "sudo chown root:root /tmp/rancher_install.sh",
      "sudo chmod u+s /tmp/rancher_install.sh",
      "sudo /tmp/rancher_install.sh"
    ]
  }
  lifecycle {
    ignore_changes = [disk]
  }
  depends_on = [vsphere_virtual_machine.rancher01, vsphere_virtual_machine.rancher02]
}