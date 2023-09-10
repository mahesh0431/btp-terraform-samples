###############################################################################################
# Setup of names in accordance to naming convention
###############################################################################################
locals {
  random_uuid               = uuid()
  project_subaccount_domain = "teched23-tf-e2b-actions-${local.random_uuid}"
  project_subaccount_cf_org = substr(replace("${local.project_subaccount_domain}", "-", ""), 0, 32)
}

###############################################################################################
# Creation of subaccount
###############################################################################################
resource "btp_subaccount" "project" {
  name      = var.subaccount_name
  subdomain = local.project_subaccount_domain
  region    = lower(var.region)
}

###############################################################################################
# Assignment of users as sub account administrators
###############################################################################################
resource "btp_subaccount_role_collection_assignment" "subaccount-admins" {
  for_each             = toset("${var.subaccount_admins}")
  subaccount_id        = btp_subaccount.project.id
  role_collection_name = "Subaccount Administrator"
  user_name            = each.value
}

###############################################################################################
# Assignment of users as sub account service administrators
###############################################################################################
resource "btp_subaccount_role_collection_assignment" "subaccount-service-admins" {
  for_each             = toset("${var.subaccount_service_admins}")
  subaccount_id        = btp_subaccount.project.id
  role_collection_name = "Subaccount Service Administrator"
  user_name            = each.value
}

######################################################################
# Creation of Cloud Foundry environment
######################################################################
module "cloudfoundry_environment" {
  source                = "../modules/envinstance-cloudfoundry/"
  subaccount_id         = btp_subaccount.project.id
  instance_name         = local.project_subaccount_cf_org
  plan_name             = "standard"
  cloudfoundry_org_name = local.project_subaccount_cf_org
}

######################################################################
# Creation of Cloud Foundry space
######################################################################
module "cloudfoundry_space" {
  source              = "../modules/cloudfoundry-space/"
  cf_org_id           = module.cloudfoundry_environment.org_id
  name                = var.cf_space_name
  cf_space_managers   = var.cf_space_managers
  cf_space_developers = var.cf_space_developers
  cf_space_auditors   = var.cf_space_auditors
}

######################################################################
# Add "sleep" resource for generic purposes
######################################################################
resource "time_sleep" "wait_a_few_seconds" {
  create_duration = "30s"
}

######################################################################
# Entitlement of all services and apps
######################################################################
resource "btp_subaccount_entitlement" "name" {
  depends_on = [time_sleep.wait_a_few_seconds]
  for_each = {
    for index, entitlement in var.entitlements :
    index => entitlement
  }
  subaccount_id = btp_subaccount.project.id
  service_name  = each.value.service_name
  plan_name     = each.value.plan_name
}

######################################################################
# Create service instances (and service keys when needed)
######################################################################
# hana-cloud
module "create_cf_service_instance_hana_cloud" {
  depends_on   = [module.cloudfoundry_space, btp_subaccount_entitlement.name, time_sleep.wait_a_few_seconds]
  source       = "../modules/cloudfoundry-service-instance/"
  cf_space_id  = module.cloudfoundry_space.id
  service_name = "hana-cloud"
  plan_name    = "hana"
  parameters   = jsonencode({ "data" : { "memory" : 30, "edition" : "cloud", "systempassword" : "Abcd1234", "whitelistIPs" : ["0.0.0.0/0"] } })
}

# privatelink -> Azure details are needed
# module "create_cf_service_instance_01" {
#   depends_on   = [module.cloudfoundry_space, btp_subaccount_entitlement.name, time_sleep.wait_a_few_seconds]
#   source       = "../modules/cloudfoundry-service-instance/"
#   cf_space_id  = module.cloudfoundry_space.id
#   service_name = "privatelink"
#   plan_name    = "standard"
#   parameters   = null
# }

######################################################################
# Create app subscriptions
######################################################################
resource "btp_subaccount_subscription" "app" {
  subaccount_id = btp_subaccount.project.id
  for_each = {
    for index, entitlement in var.entitlements :
    index => entitlement if contains(["app"], entitlement.type)
  }

  app_name   = each.value.service_name
  plan_name  = each.value.plan_name
  depends_on = [btp_subaccount_entitlement.name]
}

