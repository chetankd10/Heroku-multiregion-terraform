#!/usr/bin/env bash
# Interactive wizard for `terraform apply` on this module.
#
# Asks app name, then space type, then shows the dyno sizes and Postgres
# plans valid for that space type as numbered lists. The valid-value lists
# below must stay in sync with local.dyno_sizes_by_space_type and
# local.db_plans_by_space_type in main.tf.
set -euo pipefail

prompt_text() {
  local __resultvar=$1 __label=$2 __value=""
  while [[ -z "$__value" ]]; do
    read -r -p "$__label: " __value
  done
  printf -v "$__resultvar" '%s' "$__value"
}

prompt_choice() {
  # prompt_choice <result var> <prompt label> <choice>...
  local __resultvar=$1 __label=$2
  shift 2
  local __choices=("$@")
  echo "$__label"
  select __choice in "${__choices[@]}"; do
    if [[ -n "${__choice:-}" ]]; then
      printf -v "$__resultvar" '%s' "$__choice"
      break
    fi
    echo "Invalid selection, try again."
  done
}

echo "== Heroku multi-region Terraform deploy =="
echo

prompt_text APP_NAME "App name (must be globally unique on Heroku)"

prompt_choice SPACE_TYPE_LABEL "Space type:" \
  "Common Runtime" \
  "Private Space" \
  "Shield Private Space"

case "$SPACE_TYPE_LABEL" in
  "Common Runtime")     SPACE_TYPE="common" ;;
  "Private Space")      SPACE_TYPE="private" ;;
  "Shield Private Space") SPACE_TYPE="shield" ;;
esac

REGION=""
SPACE_NAME=""
ORGANIZATION=""

if [[ "$SPACE_TYPE" == "common" ]]; then
  prompt_choice REGION "Common Runtime region:" "us" "eu"
  read -r -p "Heroku team/organization (leave blank if none): " ORGANIZATION
else
  prompt_text SPACE_NAME "Existing ${SPACE_TYPE_LABEL} name"
  prompt_text ORGANIZATION "Heroku team/organization (required for spaces)"
fi

case "$SPACE_TYPE" in
  common)
    DYNO_SIZES=(eco basic standard-1x standard-2x performance-m performance-l)
    DB_PLANS=(
      essential-0 essential-1 essential-2
      standard-0 standard-2 standard-3 standard-4 standard-5
      standard-6 standard-7 standard-8 standard-9 standard-10
      premium-0 premium-2 premium-3 premium-4 premium-5 premium-6
      premium-l-6 premium-xl-6 premium-7 premium-8 premium-9
      premium-l-9 premium-xl-9 premium-10
    )
    ;;
  private)
    DYNO_SIZES=(private-s private-m private-l private-l-ram private-xl private-2xl)
    DB_PLANS=(
      private-0 private-2 private-3 private-4 private-5 private-6
      private-l-6 private-xl-6 private-7 private-8 private-9
      private-l-9 private-xl-9 private-10
    )
    ;;
  shield)
    DYNO_SIZES=(shield-s shield-m shield-l shield-l-ram shield-xl shield-2xl)
    DB_PLANS=(
      shield-0 shield-2 shield-3 shield-4 shield-5 shield-6
      shield-l-6 shield-xl-6 shield-7 shield-8 shield-9
      shield-l-9 shield-xl-9 shield-10
    )
    ;;
esac

prompt_choice DYNO_SIZE "Dyno size (${SPACE_TYPE_LABEL}):" "${DYNO_SIZES[@]}"
prompt_choice DB_PLAN "Postgres plan (${SPACE_TYPE_LABEL}):" "${DB_PLANS[@]}"

echo
echo "== Summary =="
echo "  app_name:     $APP_NAME"
echo "  space_type:   $SPACE_TYPE"
[[ -n "$REGION" ]] && echo "  region:       $REGION"
[[ -n "$SPACE_NAME" ]] && echo "  space_name:   $SPACE_NAME"
[[ -n "$ORGANIZATION" ]] && echo "  organization: $ORGANIZATION"
echo "  dyno_size:    $DYNO_SIZE"
echo "  db_plan:      $DB_PLAN"
echo

TF_ARGS=(
  -var "app_name=$APP_NAME"
  -var "space_type=$SPACE_TYPE"
  -var "region=$REGION"
  -var "space_name=$SPACE_NAME"
  -var "organization=$ORGANIZATION"
  -var "dyno_size=$DYNO_SIZE"
  -var "db_plan=$DB_PLAN"
)

echo "Running: terraform apply ${TF_ARGS[*]}"
echo
exec terraform apply "${TF_ARGS[@]}"
