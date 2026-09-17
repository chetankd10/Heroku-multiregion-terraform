# Heroku Multi-Region Deployment (Terraform)

Terraform module that deploys a single Heroku app instance — web + worker
dynos, a Postgres database, and a build from local source — into either
Heroku Common Runtime, a Private Space, or a Shield Private Space. Ships
with an interactive wizard (`deploy.sh`) that walks you through app name,
space type, and the dyno/Postgres options valid for that space type.

Designed so the same app code/module can later be fanned out across
multiple regions/spaces at once — see [Multi-region expansion](#multi-region-expansion-future).

## Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Deploying with the wizard (`deploy.sh`)](#deploying-with-the-wizard-deploysh)
- [Deploying manually with Terraform](#deploying-manually-with-terraform)
- [Destroying an app](#destroying-an-app)
- [Space types](#space-types)
- [Variables reference](#variables-reference)
- [Outputs](#outputs)
- [Project structure](#project-structure)
- [The sample app](#the-sample-app)
- [Multi-region expansion (future)](#multi-region-expansion-future)
- [Troubleshooting](#troubleshooting)

## Architecture

For a single `terraform apply`, this module creates:

| Resource | Purpose |
|---|---|
| `heroku_app.instance` | The Heroku app itself. Deployed to a region (Common Runtime) or a named Private/Shield Space, never both. |
| `heroku_addon.postgres` | A Heroku Postgres database attached to the app, plan chosen per space type. |
| `heroku_build.deploy` | Builds and deploys the contents of [`app/`](#the-sample-app) using the `heroku/nodejs` buildpack. |
| `heroku_formation.web` | The `web` process, sized by `dyno_size`. |
| `heroku_formation.worker` | The `worker` process, sized by `worker_dyno_size` (defaults to `dyno_size` if left blank). |

The app receives its physical region as the `APP_REGION` config var
(resolved from `var.region` for Common Runtime, or looked up from the
space via `data.heroku_space.selected` for Private/Shield), plus
`APP_SPACE_NAME` when deployed into a space. Both are returned in its
JSON response — useful for confirming which instance/region/space you're
hitting once you have more than one deployed.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- A [Heroku account](https://signup.heroku.com/) and the `heroku/heroku`
  Terraform provider (declared in `providers.tf`, installed automatically
  by `terraform init`)
- A Heroku API key, exported as an environment variable:

  ```bash
  export HEROKU_API_KEY="$(heroku auth:token)"
  # or: export HEROKU_API_KEY=<your API key>
  ```
- If deploying to a Private or Shield Space: an existing space of that type
  and a Heroku Enterprise team/organization that owns it.

## Quick start

```bash
terraform init
./deploy.sh
```

`deploy.sh` prompts for everything and calls `terraform apply` for you. See
below for what each prompt means, or skip straight to
[deploying manually](#deploying-manually-with-terraform) if you'd rather
pass `-var` flags yourself.

## Deploying with the wizard (`deploy.sh`)

`deploy.sh` is an interactive Bash wizard, in this order:

1. **App name** — free text, must be globally unique on Heroku.
2. **Space type** — numbered list: `Common Runtime`, `Private Space`, or
   `Shield Private Space`.
3. Depending on space type:
   - **Common Runtime** → numbered list of regions (`us`, `eu`), plus an
     optional organization/team.
   - **Private/Shield Space** → the existing space's name, plus the
     organization/team that owns it (required).
4. **Web dyno size** — numbered list, filtered to the sizes valid for the
   space type you picked (see [Space types](#space-types)).
5. **Worker dyno size** — same numbered list, plus a "Same as web" option
   first (the default choice) so worker only needs its own size when you
   want it to differ.
6. **Postgres plan** — numbered list, filtered the same way.
7. Prints a summary of your choices, then runs:

   ```bash
   terraform apply -var "app_name=..." -var "space_type=..." -var "region=..." \
     -var "space_name=..." -var "organization=..." -var "dyno_size=..." \
     -var "worker_dyno_size=..." -var "db_plan=..."
   ```

   Terraform's own plan output and `yes` confirmation still apply — the
   wizard only fills in the variables, it does not auto-approve.

Run it with `./deploy.sh` (it's executable) or `bash deploy.sh`.

## Deploying manually with Terraform

If you'd rather skip the wizard, `terraform plan`/`apply` will prompt for
any variable you don't supply. You can also pass them directly:

```bash
terraform apply \
  -var "app_name=myapp-us" \
  -var "space_type=common" \
  -var "region=us" \
  -var "space_name=" \
  -var "organization=" \
  -var "dyno_size=standard-1x" \
  -var "worker_dyno_size=" \
  -var "db_plan=essential-0"
```

Or create a `terraform.tfvars` (git-ignored by default — see
`.gitignore`) with the same key/value pairs and just run `terraform apply`.

Whichever way you set variables, `main.tf` enforces via `precondition`
blocks that:

- `region` is set (and `space_name` blank) when `space_type = "common"`,
  and `space_name` is set (and `region` blank) otherwise.
- `dyno_size` is one of the values valid for the chosen `space_type`.
- `worker_dyno_size` — if set, must also be one of the values valid for
  the chosen `space_type`; if left blank it falls back to `dyno_size`.
- `db_plan` is one of the Postgres plan slugs valid for the chosen
  `space_type`.

Terraform will refuse to apply with a clear error message if any of these
don't line up — so even outside the wizard, invalid combinations get
caught at `plan`/`apply` time rather than surfacing as a Heroku API error.

## Destroying an app

To tear down everything this module created for an instance (the app,
its Postgres database, the build, and both dynos), run `terraform
destroy` from the same directory you applied from:

```bash
terraform destroy
```

- If you deployed with a `terraform.tfvars` file, `terraform destroy`
  alone is enough — it reuses those same variable values.
- If you deployed by passing `-var` flags (or via `deploy.sh`), pass at
  least `app_name` again so Terraform can identify the app — the other
  variables (`space_type`, `region`, `space_name`, `dyno_size`,
  `worker_dyno_size`, `db_plan`) default to blank and aren't required for
  destroy:

  ```bash
  terraform destroy -var "app_name=myapp-us"
  ```

  If you're unsure which values were used, check `terraform.tfstate` or
  run `terraform show` first.
- As with `apply`, `terraform destroy` shows a plan of what will be
  removed and asks you to confirm with `yes` before deleting anything.
- This only destroys the single instance managed by your current
  Terraform state. If you've deployed multiple regions/spaces as
  separate `terraform apply` runs (e.g. separate working directories or
  workspaces), destroy each one independently.

## Space types

| Space type | `space_type` value | Uses | Belongs to a team? |
|---|---|---|---|
| Common Runtime | `common` | Shared multi-tenant infrastructure, set by `region` (`us`/`eu`) | Optional |
| Private Space | `private` | Isolated network, set by `space_name` (must already exist) | Required |
| Shield Private Space | `shield` | Private Space + compliance controls (e.g. HIPAA), set by `space_name` (must already exist) | Required |

### Dyno sizes by space type

Source: [Heroku Dyno Types](https://devcenter.heroku.com/articles/dyno-types).
Eco/Basic/Standard/Performance dynos only run in Common Runtime; Private
and Shield Spaces have their own dedicated-compute tiers.

| space_type | Valid `dyno_size` values |
|---|---|
| `common` | `eco`, `basic`, `standard-1x`, `standard-2x`, `performance-m`, `performance-l` |
| `private` | `private-s`, `private-m`, `private-l`, `private-l-ram`, `private-xl`, `private-2xl` |
| `shield` | `shield-s`, `shield-m`, `shield-l`, `shield-l-ram`, `shield-xl`, `shield-2xl` |

### Postgres plans by space type

Source: [Heroku Postgres add-on plans](https://elements.heroku.com/addons/heroku-postgresql).

| space_type | Valid `db_plan` values |
|---|---|
| `common` | `essential-0`, `essential-1`, `essential-2`, `standard-0`, `standard-2`–`standard-10`, `premium-0`, `premium-2`–`premium-9`, `premium-l-6`, `premium-xl-6`, `premium-l-9`, `premium-xl-9`, `premium-10` |
| `private` | `private-0`, `private-2`–`private-9`, `private-l-6`, `private-xl-6`, `private-l-9`, `private-xl-9`, `private-10` |
| `shield` | `shield-0`, `shield-2`–`shield-9`, `shield-l-6`, `shield-xl-6`, `shield-l-9`, `shield-xl-9`, `shield-10` |

Note the tier numbering skips `-1` (e.g. `standard-2` follows `standard-0`)
— that's Heroku's own plan naming, not a typo.

`dyno_size` sizes `heroku_formation.web`. `heroku_formation.worker` has
its own `worker_dyno_size` variable — leave it blank to match `dyno_size`,
or set it to any value from the table above (for the same `space_type`)
to size the worker differently from web.

The authoritative lists live in `local.dyno_sizes_by_space_type` and
`local.db_plans_by_space_type` in `main.tf`; the arrays in `deploy.sh` are
kept in sync with them by hand, so if you change one, change the other.

## Variables reference

| Variable | Type | Default | Description |
|---|---|---|---|
| `app_name` | string | — | Heroku app name, must be globally unique. |
| `space_type` | string | — | `common`, `private`, or `shield`. |
| `region` | string | `""` | Common Runtime region (`us`/`eu`). Required iff `space_type = "common"`. |
| `space_name` | string | `""` | Existing Private/Shield Space name. Required iff `space_type != "common"`. |
| `organization` | string | `""` | Heroku team owning the app. Required if `space_name` is set. |
| `db_plan` | string | — | Heroku Postgres plan slug, must be valid for `space_type` (see table above). |
| `dyno_size` | string | — | Dyno size for `web`, must be valid for `space_type` (see table above). |
| `worker_dyno_size` | string | `""` | Dyno size for `worker`, must be valid for `space_type` if set. Defaults to `dyno_size` when left blank. |

## Outputs

| Output | Description |
|---|---|
| `app_url` | Web URL for the deployed instance. |
| `app_id` | Heroku app ID, useful for `heroku` CLI commands against this app. |

## Project structure

```
.
├── main.tf                          # heroku_app, heroku_addon, heroku_build, heroku_formation
├── variables.tf                     # Input variables
├── outputs.tf                       # app_url, app_id
├── providers.tf                     # heroku provider + required_version
├── deploy.sh                        # Interactive deployment wizard
├── app/                             # Source deployed by heroku_build.deploy
│   ├── index.js                     # Express web process
│   ├── worker.js                    # Background worker process
│   ├── package.json
│   └── Procfile
└── future/
    └── multi-region-expansion.tf    # Sketch for fanning this module out across regions
```

## The sample app

`app/` is a minimal Node.js/Express app deployed by `heroku_build.deploy`:

- **`index.js`** (web) — serves `GET /`, returning JSON with the app's
  region (`APP_REGION`) and, when deployed into a Private/Shield Space,
  its space name (`APP_SPACE_NAME`) — both config vars set in `main.tf`
  — plus dyno name and current time. Useful for confirming which
  region/space/instance answered a request.
- **`worker.js`** (worker) — logs a heartbeat with its space name/region
  every 30 seconds; a stand-in for background job processing.
- **`Procfile`** — declares the `web` and `worker` process types that
  `heroku_formation.web`/`heroku_formation.worker` size and scale.

## Multi-region expansion (future)

`future/multi-region-expansion.tf` is a sketch (not part of the root
module — Terraform never auto-loads `future/`) for deploying this same app
to several regions/spaces from one `terraform apply`, via a `deployments`
map and `for_each`. See the comment block at the top of that file for the
steps to activate it (extracting `main.tf` into a reusable module under
`modules/app/`, then promoting the sketch into the root module).

## Troubleshooting

- **`Error: no matching Heroku app found` / auth errors** — make sure
  `HEROKU_API_KEY` is exported in your shell before running `terraform`
  or `deploy.sh`.
- **Precondition failed: dyno_size / worker_dyno_size / db_plan not valid
  for space_type** — you passed a value from the wrong table in
  [Space types](#space-types); re-run `deploy.sh` and let it filter the
  list for you, or double-check `local.dyno_sizes_by_space_type` /
  `local.db_plans_by_space_type` in `main.tf`.
- **Precondition failed on region/space_name** — for `space_type =
  "common"` set `region` and leave `space_name` blank; for `"private"`/
  `"shield"` set `space_name` (an existing space) and leave `region`
  blank.
- **App name already taken** — Heroku app names are global; pick a more
  unique `app_name`.
