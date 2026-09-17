variable "app_name" {
  type        = string
  description = "Heroku app name (must be globally unique across all of Heroku)"
}

variable "space_type" {
  type        = string
  default     = ""
  description = "Where to deploy: \"common\" (Common Runtime), \"private\" (Private Space), or \"shield\" (Shield Private Space). Determines which region/space, dyno sizes, and Postgres plans are valid. Required for apply; leave blank for destroy."

  validation {
    condition     = var.space_type == "" || contains(["common", "private", "shield"], var.space_type)
    error_message = "space_type must be one of: common, private, shield."
  }
}

variable "region" {
  type        = string
  default     = ""
  description = "Common Runtime region, e.g. \"us\" or \"eu\". Required when space_type = \"common\"; leave blank otherwise."
}

variable "space_name" {
  type        = string
  default     = ""
  description = "Existing Heroku Private/Shield Space name, e.g. \"test-space-vi\". Required when space_type = \"private\" or \"shield\"; leave blank otherwise."
}

variable "organization" {
  type        = string
  default     = ""
  description = "Heroku team that owns this app. Required if space_name is set, since Private/Shield Spaces belong to a team. Not prompted for; pass with -var or TF_VAR_organization."
}

variable "db_plan" {
  type        = string
  default     = ""
  description = "Heroku Postgres plan for this instance's database. Valid values depend on space_type - see local.db_plans_by_space_type in main.tf. Required for apply; leave blank for destroy."
}

variable "dyno_size" {
  type        = string
  default     = ""
  description = "Dyno size for the web process. Valid values depend on space_type - see local.dyno_sizes_by_space_type in main.tf. Required for apply; leave blank for destroy."
}

variable "worker_dyno_size" {
  type        = string
  default     = ""
  description = "Dyno size for the worker process. Valid values depend on space_type - see local.dyno_sizes_by_space_type in main.tf. Defaults to the same value as dyno_size when left blank. Leave blank for destroy."
}
