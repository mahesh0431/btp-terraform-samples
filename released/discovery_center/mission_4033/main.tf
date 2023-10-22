###############################################################################################
# Setup of names in accordance to naming convention
###############################################################################################
resource "random_uuid" "uuid" {}

locals {
  random_uuid               = random_uuid.uuid.result
  project_subaccount_domain = lower(replace("mission-4033-${local.random_uuid}", "_", "-"))
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
# Assign custom IDP to sub account
######################################################################
resource "btp_subaccount_trust_configuration" "fully_customized" {
  subaccount_id     = btp_subaccount.project.id
  identity_provider = var.custom_idp
  depends_on        = [btp_subaccount.project]
}


######################################################################
# Setup Kyma
######################################################################
data "btp_regions" "all" {}

data "btp_subaccount" "this" {
  id = btp_subaccount.project.id
}

locals {
  subaccount_iaas_provider = [for region in data.btp_regions.all.values : region if region.region == data.btp_subaccount.this.region][0].iaas_provider
}

resource "btp_subaccount_entitlement" "kymaruntime" {
  subaccount_id = btp_subaccount.project.id
  service_name  = "kymaruntime"
  plan_name     = lower(local.subaccount_iaas_provider)
  amount        = 1
}


resource "btp_subaccount_environment_instance" "kyma" {
  subaccount_id    = btp_subaccount.project.id
  name             = var.kyma_instance.name
  environment_type = "kyma"
  service_name     = "kymaruntime"
  plan_name        = "aws"
  parameters = jsonencode({
    name            = var.kyma_instance.name
    region          = var.kyma_instance.region
    machine_type    = var.kyma_instance.machine_type
    auto_scaler_min = var.kyma_instance.auto_scaler_min
    auto_scaler_max = var.kyma_instance.auto_scaler_max
  })
  timeouts = {
    create = var.kyma_instance.createtimeout
    update = var.kyma_instance.updatetimeout
    delete = var.kyma_instance.deletetimeout
  }
  depends_on = [btp_subaccount_entitlement.kymaruntime]
}

######################################################################
# Entitlement of all services
######################################################################
resource "btp_subaccount_entitlement" "name" {
  depends_on = [btp_subaccount.project]
  for_each = {
    for index, entitlement in var.entitlements :
    index => entitlement
  }
  subaccount_id = btp_subaccount.project.id
  service_name  = each.value.service_name
  plan_name     = each.value.plan_name
}

######################################################################
# Create app subscriptions
######################################################################
data "btp_subaccount_subscriptions" "all" {
  subaccount_id = btp_subaccount.project.id
  depends_on = [ btp_subaccount_entitlement.name ]
}

resource "btp_subaccount_subscription" "app" {
  subaccount_id = btp_subaccount.project.id
  for_each = {
    for index, entitlement in var.entitlements :
    index => entitlement if contains(["app"], entitlement.type)
  }
  app_name = [
    for subscription in data.btp_subaccount_subscriptions.all.values :
    subscription
    if subscription.commercial_app_name == each.value.service_name
  ][0].app_name
  plan_name  = each.value.plan_name
  depends_on = [data.btp_subaccount_subscriptions.all]
}

######################################################################
# Assign Role Collection
######################################################################

resource "btp_subaccount_role_collection_assignment" "conn_dest_admn" {
  depends_on           = [btp_subaccount_subscription.app]
  for_each             = toset(var.conn_dest_admin)
  subaccount_id        = btp_subaccount.project.id
  role_collection_name = "Connectivity and Destination Administrator"
  user_name            = each.value
}

resource "btp_subaccount_role_collection_assignment" "int_prov" {
  depends_on           = [btp_subaccount_subscription.app]
  for_each             = toset(var.int_provisioner)
  subaccount_id        = btp_subaccount.project.id
  role_collection_name = "Integration_Provisioner"
  user_name            = each.value
  origin               = btp_subaccount_trust_configuration.fully_customized.origin
}

resource "btp_subaccount_role_collection_assignment" "sbpa_admin" {
  depends_on           = [btp_subaccount_subscription.app]
  for_each             = toset(var.ProcessAutomationAdmin)
  subaccount_id        = btp_subaccount.project.id
  role_collection_name = "ProcessAutomationAdmin"
  user_name            = each.value
  origin               = btp_subaccount_trust_configuration.fully_customized.origin
}

resource "btp_subaccount_role_collection_assignment" "sbpa_dev" {
  depends_on           = [btp_subaccount_subscription.app]
  for_each             = toset(var.ProcessAutomationDeveloper)
  subaccount_id        = btp_subaccount.project.id
  role_collection_name = "ProcessAutomationDeveloper"
  user_name            = each.value
  origin               = btp_subaccount_trust_configuration.fully_customized.origin
}

resource "btp_subaccount_role_collection_assignment" "sbpa_part" {
  depends_on           = [btp_subaccount_subscription.app]
  for_each             = toset(var.ProcessAutomationParticipant)
  subaccount_id        = btp_subaccount.project.id
  role_collection_name = "ProcessAutomationParticipant"
  user_name            = each.value
  origin               = btp_subaccount_trust_configuration.fully_customized.origin
}


# ------------------------------------------------------------------------------------------------------
# Get all roles in the subaccount
# ------------------------------------------------------------------------------------------------------
data "btp_subaccount_roles" "all" {
  subaccount_id = btp_subaccount.project.id
  depends_on    = [btp_subaccount_subscription.app]
}

# ------------------------------------------------------------------------------------------------------
# Setup for role collection BuildAppsAdmin
# ------------------------------------------------------------------------------------------------------
# Create the role collection
resource "btp_subaccount_role_collection" "build_apps_BuildAppsAdmin" {
  subaccount_id = btp_subaccount.project.id
  name          = "BuildAppsAdmin"

  roles = [
    for role in data.btp_subaccount_roles.all.values : {
      name                 = role.name
      role_template_app_id = role.app_id
      role_template_name   = role.role_template_name
    } if contains(["BuildAppsAdmin"], role.name)
  ]
}

# ------------------------------------------------------------------------------------------------------
# Assign users to the role collection
# ------------------------------------------------------------------------------------------------------
resource "btp_subaccount_role_collection_assignment" "build_apps_BuildAppsAdmin" {
  depends_on           = [btp_subaccount_role_collection.build_apps_BuildAppsAdmin]
  for_each             = toset(var.users_BuildAppsAdmin)
  subaccount_id        = btp_subaccount.project.id
  role_collection_name = "BuildAppsAdmin"
  user_name            = each.value
  origin               = btp_subaccount_trust_configuration.fully_customized.origin
}

# ------------------------------------------------------------------------------------------------------
# Setup for role collection BuildAppsDeveloper
# ------------------------------------------------------------------------------------------------------
# Create the role collection
resource "btp_subaccount_role_collection" "build_apps_BuildAppsDeveloper" {
  subaccount_id = btp_subaccount.project.id
  name          = "BuildAppsDeveloper"

  roles = [
    for role in data.btp_subaccount_roles.all.values : {
      name                 = role.name
      role_template_app_id = role.app_id
      role_template_name   = role.role_template_name
    } if contains(["BuildAppsDeveloper"], role.name)
  ]
}

# ------------------------------------------------------------------------------------------------------
# Assign users to the role collection
# ------------------------------------------------------------------------------------------------------
resource "btp_subaccount_role_collection_assignment" "build_apps_BuildAppsDeveloper" {
  depends_on           = [btp_subaccount_role_collection.build_apps_BuildAppsDeveloper]
  for_each             = toset(var.users_BuildAppsDeveloper)
  subaccount_id        = btp_subaccount.project.id
  role_collection_name = "BuildAppsDeveloper"
  user_name            = each.value
  origin               = btp_subaccount_trust_configuration.fully_customized.origin
}

# ------------------------------------------------------------------------------------------------------
# Setup for role collection RegistryAdmin
# ------------------------------------------------------------------------------------------------------
# Create the role collection
resource "btp_subaccount_role_collection" "build_apps_RegistryAdmin" {
  subaccount_id = btp_subaccount.project.id
  name          = "RegistryAdmin"

  roles = [
    for role in data.btp_subaccount_roles.all.values : {
      name                 = role.name
      role_template_app_id = role.app_id
      role_template_name   = role.role_template_name
    } if contains(["RegistryAdmin"], role.name)
  ]
}
# Assign users to the role collection
resource "btp_subaccount_role_collection_assignment" "build_apps_RegistryAdmin" {
  depends_on           = [btp_subaccount_role_collection.build_apps_RegistryAdmin]
  for_each             = toset(var.users_RegistryAdmin)
  subaccount_id        = btp_subaccount.project.id
  role_collection_name = "RegistryAdmin"
  user_name            = each.value
  origin               = btp_subaccount_trust_configuration.fully_customized.origin
}

# ------------------------------------------------------------------------------------------------------
# Setup for role collection RegistryDeveloper
# ------------------------------------------------------------------------------------------------------
# Create the role collection
resource "btp_subaccount_role_collection" "build_apps_RegistryDeveloper" {
  subaccount_id = btp_subaccount.project.id
  name          = "RegistryDeveloper"

  roles = [
    for role in data.btp_subaccount_roles.all.values : {
      name                 = role.name
      role_template_app_id = role.app_id
      role_template_name   = role.role_template_name
    } if contains(["RegistryDeveloper"], role.name)
  ]
}
# Assign users to the role collection
resource "btp_subaccount_role_collection_assignment" "build_apps_RegistryDeveloper" {
  depends_on           = [btp_subaccount_role_collection.build_apps_RegistryDeveloper]
  for_each             = toset(var.users_RegistryDeveloper)
  subaccount_id        = btp_subaccount.project.id
  role_collection_name = "RegistryDeveloper"
  user_name            = each.value
  origin               = btp_subaccount_trust_configuration.fully_customized.origin
}
# ------------------------------------------------------------------------------------------------------
# Create destination for Visual Cloud Functions
# ------------------------------------------------------------------------------------------------------
# Get plan for destination service
data "btp_subaccount_service_plan" "by_name" {
  subaccount_id = btp_subaccount.project.id
  name          = "lite"
  offering_name = "destination"
}

# ------------------------------------------------------------------------------------------------------
# Create the destination
# ------------------------------------------------------------------------------------------------------
resource "btp_subaccount_service_instance" "vcf_destination" {
  subaccount_id  = btp_subaccount.project.id
  serviceplan_id = data.btp_subaccount_service_plan.by_name.id
  name           = "SAP-Build-Apps-Runtime"
  parameters = jsonencode({
    HTML5Runtime_enabled = true
    init_data = {
      subaccount = {
        existing_destinations_policy = "update"
        destinations = [
          {
            Name                     = "SAP-Build-Apps-Runtime"
            Type                     = "HTTP"
            Description              = "Endpoint to SAP Build Apps runtime"
            URL                      = "https://${btp_subaccount.project.subdomain}.cr1.${btp_subaccount.project.region}.apps.build.cloud.sap/"
            ProxyType                = "Internet"
            Authentication           = "NoAuthentication"
            "HTML5.ForwardAuthToken" = true
          }
        ]
      }
    }
  })
}
