########################################
##             Variables              ##
########################################

variable "rancher_api_url" { 
  default = "https://rancher.your.domain"
}

variable "rancher_api" { 
  default = "https://rancher.your.domain:9345"
}

# If this is changed make sure to change it in the rancher_install.sh file as well
variable "rancher_admin_pass_initial" {
    default = "admin"
}

variable "rancher_admin_pass" {
    default = "rancheradminpassword"
}

variable "rke2_token" {
  default = "randomtoken"
}

variable "rancher_fqdn" {
  default = "rancher.your.domain"
}

## Node Template 

# disk size in MB
variable "disksize" {
  default = 90000
}

# number of CPUs
variable "haproxycpucount" {
  default = 4
}

# number of CPUs
variable "cpucount" {
  default = 8
}

# memory size in MB
variable "haproxymemory" {
  default = 4096
}

# memory size in MB
variable "memory" {
  default = 8192
}

# VMware vsphere
variable "vsphere_server" {
  default = "vserver.your.domain"
}

# vsphere User
variable "vsphere_user" { 
    default = "administrator@vsphere.local"
}
variable "vsphere_password" {
  default = "vpassword"
}

# VMware Datastore
variable "vsphere_datastore" {
  default = "VxRail-Virtual-SAN-Datastore"
}

# VMware Datacenter
variable "vsphere_datacenter" {
  default = "VxRail-Datacenter"
}

# VMware Resource Pool
variable "vsphere_pool" {
  default = "VxRail-Virtual-SAN-Cluster/Resources/rke-cluster-dev"
}

# VMware Folder
variable "vsphere_folder" {
  default = "rke-cluster-dev"
}

variable "vm_ssh_user" {
  default = "vmuser"
}
variable "vm_ssh_password" {
  default = "vmpassword"
}

variable "vsphere_drs_cluster" {
    default = "VxRail-Virtual-SAN-Cluster"
}

# VMware Network
variable "vsphere_network" {
  default =  "virtual-machine-network"
}

variable "vsphere_network_ips" {
  type = map
  default =  {
    "dns-server" = "100.xx.xx.xx"
    "domain" = "your.domain"
    "gateway" = "100.xx.xx.xx"
    "netmask" = "24"
  }
}

variable "vm_haproxy" {
  type = map
  default =  {
    "name" = "rke-dev-haproxy"
    "fqdn" = "rke-dev-haproxy.your.domain"
    "ip" = "100.xx.xx.xx"
  }
}

variable "vm_01" {
  type = map
  default =  {
    "name" = "rke-dev-01"
    "fqdn" = "rke-dev-01.your.domain"
    "ip" = "100.xx.xx.xx"
  }
}

variable "vm_02" {
  type = map
  default =  {
    "name" = "rke-dev-02"
    "fqdn" = "rke-dev-02.your.domain"
    "ip" = "100.xx.xx.xx"
  }
}

variable "vm_03" {
  type = map
  default =  {
    "name" = "rke-dev-03"
    "fqdn" = "rke-dev-03.your.domain"
    "ip" = "100.xx.xx.xx"
  }
}

variable "vsphere_template" {
    default = "Sles_15_SP4"
}
