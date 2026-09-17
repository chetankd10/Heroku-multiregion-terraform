locals {
  actual_region = var.space_name != "" ? data.heroku_space.selected[0].region : var.region

  # Dyno sizes Heroku allows per space type (Eco/Basic/Standard/Performance
  # only run in Common Runtime; Private/Shield Spaces have their own tiers).
  dyno_sizes_by_space_type = {
    common  = ["eco", "basic", "standard-1x", "standard-2x", "performance-m", "performance-l"]
    private = ["private-s", "private-m", "private-l", "private-l-ram", "private-xl", "private-2xl"]
    shield  = ["shield-s", "shield-m", "shield-l", "shield-l-ram", "shield-xl", "shield-2xl"]
  }

  # Heroku Postgres plan slugs per space type (Essential/Standard/Premium
  # are Common Runtime tiers; Private/Shield Spaces use their own tiers).
  db_plans_by_space_type = {
    common = [
      "essential-0", "essential-1", "essential-2",
      "standard-0", "standard-2", "standard-3", "standard-4", "standard-5",
      "standard-6", "standard-7", "standard-8", "standard-9", "standard-10",
      "premium-0", "premium-2", "premium-3", "premium-4", "premium-5", "premium-6",
      "premium-l-6", "premium-xl-6", "premium-7", "premium-8", "premium-9",
      "premium-l-9", "premium-xl-9", "premium-10",
    ]
    private = [
      "private-0", "private-2", "private-3", "private-4", "private-5", "private-6",
      "private-l-6", "private-xl-6", "private-7", "private-8", "private-9",
      "private-l-9", "private-xl-9", "private-10",
    ]
    shield = [
      "shield-0", "shield-2", "shield-3", "shield-4", "shield-5", "shield-6",
      "shield-l-6", "shield-xl-6", "shield-7", "shield-8", "shield-9",
      "shield-l-9", "shield-xl-9", "shield-10",
    ]
  }
}

data "heroku_space" "selected" {
  count = var.space_name != "" ? 1 : 0
  name  = var.space_name
}

resource "heroku_app" "instance" {
  name = var.app_name
  # The provider schema marks "region" as required even when "space" is set,
  # but Heroku's API still validates that it matches the space's actual
  # region, so it must be looked up rather than hardcoded.
  region = var.space_name != "" ? data.heroku_space.selected[0].region : var.region
  space  = var.space_name != "" ? var.space_name : null

  dynamic "organization" {
    for_each = var.organization == "" ? [] : [var.organization]
    content {
      name = organization.value
    }
  }

  config_vars = merge(
    { APP_REGION = local.actual_region },
    var.space_name != "" ? { APP_SPACE_NAME = var.space_name } : {}
  )

  lifecycle {
    precondition {
      condition = var.space_type == "common" ? (
        var.region != "" && var.space_name == ""
        ) : (
        var.space_name != "" && var.region == ""
      )
      error_message = "For space_type = \"common\", set region and leave space_name blank. For space_type = \"private\" or \"shield\", set space_name and leave region blank."
    }

    precondition {
      condition     = contains(lookup(local.dyno_sizes_by_space_type, var.space_type, []), var.dyno_size)
      error_message = "dyno_size \"${var.dyno_size}\" is not valid for space_type \"${var.space_type}\". Valid: ${join(", ", lookup(local.dyno_sizes_by_space_type, var.space_type, []))}."
    }

    precondition {
      condition     = contains(lookup(local.db_plans_by_space_type, var.space_type, []), var.db_plan)
      error_message = "db_plan \"${var.db_plan}\" is not valid for space_type \"${var.space_type}\". Valid: ${join(", ", lookup(local.db_plans_by_space_type, var.space_type, []))}."
    }
  }
}

resource "heroku_addon" "postgres" {
  app_id = heroku_app.instance.id
  plan   = "heroku-postgresql:${var.db_plan}"
}

# Deploys the app/ directory (web + worker) to this instance.
resource "heroku_build" "deploy" {
  app_id = heroku_app.instance.id

  source {
    path = "${path.module}/app"
  }
}

resource "heroku_formation" "web" {
  depends_on = [heroku_build.deploy]

  app_id   = heroku_app.instance.id
  type     = "web"
  quantity = 1
  size     = var.dyno_size
}

resource "heroku_formation" "worker" {
  depends_on = [heroku_build.deploy]

  app_id   = heroku_app.instance.id
  type     = "worker"
  quantity = 1
  size     = var.dyno_size
}
