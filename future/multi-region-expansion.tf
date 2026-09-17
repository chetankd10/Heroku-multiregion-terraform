# FUTURE USE — NOT ACTIVE
#
# This file is not part of the root module (it lives under future/, which
# Terraform never auto-loads), so it has zero effect on the current
# single-app deployment in ../main.tf. It's a sketch of how to fan the same
# app code out to multiple Heroku apps/regions from one `terraform apply`,
# using a reusable module + for_each, for whenever multi-region is needed.
#
# To activate later:
#   1. Move the resources in ../main.tf into a reusable module, e.g.
#      modules/app/main.tf (app_name, region, space_name, db_plan, dyno_size
#      become module input variables instead of root variables).
#   2. Move this file's contents up into the root module (e.g. rename/copy
#      to ../multi-region.tf) and delete the single heroku_app.instance
#      version in ../main.tf so both don't try to manage the same app.
#   3. Set var.deployments (below) to one entry per region/space you want.

variable "app_prefix" {
  type        = string
  default     = ""
  description = "Prefix used to build each app_name, e.g. \"myapp\" -> \"myapp-us\", \"myapp-eu\"."
}

variable "deployments" {
  type = map(object({
    region     = optional(string, "")
    space_name = optional(string, "")
    db_plan    = optional(string, "essential-0")
    dyno_size  = optional(string, "eco")
  }))
  default     = {}
  description = "One entry per Heroku app to deploy, keyed by a short name (e.g. \"us\", \"eu\"). Each entry runs the same app code as its own app/region."
}

module "app" {
  for_each = var.deployments

  source = "../modules/app"

  app_name     = "${var.app_prefix}-${each.key}"
  region       = each.value.region
  space_name   = each.value.space_name
  organization = var.organization
  db_plan      = each.value.db_plan
  dyno_size    = each.value.dyno_size
}

output "app_urls" {
  description = "Web URL for every deployed instance, keyed by deployment name"
  value       = { for k, m in module.app : k => m.app_url }
}
