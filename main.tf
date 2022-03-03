#### Provider ####

provider "aws" {
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  region = var.global_region
}

provider "aviatrix" {
  username                = "admin"
  password                = var.ctrl_password
  controller_ip           = var.ctrl_ip
}

terraform {
  required_providers {
    aviatrix = {
      source  = "aviatrixsystems/aviatrix"
      version = "2.20.3"
    }
  }
}

##### Data resources
# AWS Account ID
data "aws_caller_identity" "current" {}

#### available azs ####
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aviatrix_account" "avx_acc_aws" {  # Should this be Module ?
  account_name       = "test"
  cloud_type         = 1
  aws_iam            = false
  aws_account_number = data.aws_caller_identity.current.account_id
  aws_access_key     = var.aws_access_key_id
  aws_secret_key     = var.aws_secret_access_key
}


#### Admin VPC ###

#### ------- VPC ------- ####
module "admin_vpc" {
  source = "git::https://github.com/karolnedza/terraform-aws-vpc.git?ref=v1.0.0"
  vpc_cidr = var.cidr
  vpc_name = "${var.name}-vpc"
  vpc_security_zone = "security-zone-1"
}


#### ------- IGW ------- ####

module "admin_igw" {
  source = "git::https://github.com/karolnedza/terraform-aws-igw.git?ref=v1.0.0"
  igw_vpc = module.admin_vpc.vpc_id
  name = var.name
 #
}

# #
# #
# # #### ------- Subnet Workloads------- ####
module "admin_vpc_sample_subnet" {
  source = "git::https://github.com/karolnedza/terraform-aws-subnet.git?ref=v1.0.0"
  subnet_vpc = module.admin_vpc.vpc_id
  subnet_cidr_block = local.vm_subnet
  subnet_name = "${var.name}-subnet"
  subnet_az = data.aws_availability_zones.available.names[0]
}

# #### ------- Subnet GW ------- ####
module "admin_vpc_gw_subnet" {
  source = "git::https://github.com/karolnedza/terraform-aws-subnet.git?ref=v1.0.0"
  count = var.insane_mode ? 0 : 1
  subnet_vpc = module.admin_vpc.vpc_id
  subnet_cidr_block = local.gw_subnet
  subnet_name = "${var.name}-subnet-gw"
  subnet_az = data.aws_availability_zones.available.names[0]
}

# #### ------- Subnet GW-HAGW ------- ####
module "admin_vpc_gwha_subnet" {
  source = "git::https://github.com/karolnedza/terraform-aws-subnet.git?ref=v1.0.0"
  count = var.insane_mode ? 0 : 1
  subnet_vpc = module.admin_vpc.vpc_id
  subnet_cidr_block = local.gwha_subnet
  subnet_name = "${var.name}-subnet-hagw"
  subnet_az = data.aws_availability_zones.available.names[1]
}


# #### ------- Private Route table workloads------- ####
module "admin_vpc_subnet1_rt"{
  source = "git::https://github.com/karolnedza/terraform-aws-route-table-private.git?ref=v1.0.0"
  name = "test-private"
  route_table_vpc = module.admin_vpc.vpc_id
  route_table_name = "${var.name}-rt-private"
}

# # #### ------- Public Route table workloads------- ####
module "admin_vpc_subnet_gw_rt"{
  source = "git::https://github.com/karolnedza/terraform-aws-route-table-public.git?ref=v1.0.1"
  route_table_vpc = module.admin_vpc.vpc_id
  name = "${var.name}-rt-public"
  igw_vpc_id = module.admin_igw.igw.id
}

# #
# #
# #
# # #### ------- Route table workloads association ------- ####
module "admin_vpc_subnet1_rt_assoc" {
  source = "git::https://github.com/karolnedza/terraform-aws-rt-association.git?ref=v1.0.0"
  subnet_id = module.admin_vpc_sample_subnet.subnet_id
  route_table_id = module.admin_vpc_subnet1_rt.route_table_id
}

module "admin_vpc_gw_subnet_rt_assoc" {
  source = "git::https://github.com/karolnedza/terraform-aws-rt-association.git?ref=v1.0.0"
  count = var.insane_mode ? 0 : 1
  subnet_id = module.admin_vpc_gw_subnet[0].subnet_id
  route_table_id = module.admin_vpc_subnet_gw_rt.route_table_id
}


module "admin_vpc_gwha_subnet_rt_assoc" {
  source = "git::https://github.com/karolnedza/terraform-aws-rt-association.git?ref=v1.0.0"
  count = var.insane_mode ? 0 : 1
  subnet_id = module.admin_vpc_gwha_subnet[0].subnet_id
  route_table_id = module.admin_vpc_subnet_gw_rt.route_table_id
}

# #
# #### ------- NACL ------- ####
# module "admin_vpc_subnet1_nacl" {
#   source = "./terraform-aws-nacl "
#   nacl_vpc_id = module.admin_vpc.vpc_id
#   nacl_name = "admin-vpc-sample-subnet-nacl"
#   nacl_subnet_ids = [module.admin_vpc_sample_subnet.subnet_id]
# }

# #
### ------- NACL rule : allow ssh inbound from SAP range ------- ####
# module "admin_vpc_subnet1_nacl_allow_https_in" {
#   source = "../modules/nacl-add-rule"
#   nacl_id = module.admin_vpc_subnet1_nacl.nacl_id
#   rule_number = 200
#   is_egress = false
#   rule_protocol = "tcp"
#   action = "allow"
#   rule_cidr = "10.125.14.0/24"
#   port_from = 22
#   port_to = 22
# }

# #### ------- NACL rule : allow ssh outbound to ephemeral ------- ####
# module "admin_vpc_subnet1_nacl_allow_https_out" {
#   source = "../modules/nacl-add-rule"
#   nacl_id = module.admin_vpc_subnet1_nacl.nacl_id
#   rule_number = 200
#   is_egress = true
#   rule_protocol = "tcp"
#   action = "allow"
#   rule_cidr = "10.125.14.0/24"
#   port_from = 1024
#   port_to = 65535
# }
# #
# #### ------- Security group ------- ####
# module "admin_vpc_sample_sg" {
#   source = "git::https://github.com/karolnedza/terraform-aws-security-group.git?ref=v1.0.0"
#   sg_name = "${var.name}-rt-public"
#   sg_description = "${var.name}-rt-public"
#   sg_vpc_id = module.admin_vpc.vpc_id
# }


# # #### ------- Security group sample rule : allow ssh from SAP range ------- ####
# module "admin_vpc_sample_sg_allow_https" {
#   source = "./terraform-security-group-rule"
#   rule_description = "allow-https"
#   rule_type = "ingress"
#   rule_port_from = 22
#   rule_port_to = 22
#   rule_protocol = "tcp"
#   rule_cidr_block = ["10.125.14.0/24"]
#   sg_id = module.admin_vpc_sample_sg.sg_id
# }

##### ------- Aviatrix Spoke GW ------- ####

module "admin_avx_spoke_sample_sg" {
  source = "git::https://github.com/karolnedza/terraform-aws-aviatrix-spoke.git?ref=v1.0.1"
  vpc_id = module.admin_vpc.vpc_id
  subnet_gw = var.insane_mode ? local.gw_subnet : module.admin_vpc_gw_subnet[0].subnet_cidr_block
  subnet_gwha = var.ha_enabled ? (var.insane_mode ? local.gwha_subnet : module.admin_vpc_gwha_subnet[0].subnet_cidr_block) : null
  name = var.name
  account = aviatrix_account.avx_acc_aws.account_name
  region = var.global_region
  ha_gw = var.ha_enabled
  insane_mode = var.insane_mode
#  transit_gw = "av-transit-eu-central-1"
#  security_domain = "red"
}
