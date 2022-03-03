variable "aws_access_key_id" {}

variable "aws_secret_access_key" {}

variable "name" {default = ""}

variable "global_region" {}

variable "cidr" {}

variable "ctrl_password" {}

variable "ctrl_ip" {}

variable "insane_mode" {default = false}
variable "ha_enabled" {default = true}

locals {
  cidrbits              = tonumber(split("/", var.cidr)[1])
  newbits_insane_mode   = 26 - local.cidrbits  # insane mode subnet will be always /26
  newbits_gw            = 28 - local.cidrbits  # gw/gwha subnet will be always /28
  newbits_vm            = 24 - local.cidrbits  # VM mode subnet will be always /24
  vm_subnet             = cidrsubnet(var.cidr, local.newbits_vm, 1) # second avaiable /24
  gw_subnet             = var.insane_mode ? cidrsubnet(var.cidr, local.newbits_insane_mode, 0) : cidrsubnet(var.cidr, local.newbits_gw, 0)
  gwha_subnet           = var.insane_mode ? cidrsubnet(var.cidr, local.newbits_insane_mode, 1) : cidrsubnet(var.cidr, local.newbits_gw, 1)
}