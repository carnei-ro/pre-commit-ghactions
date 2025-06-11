#!/usr/bin/env bash
set -eo pipefail

# globals variables
# shellcheck disable=SC2155 # No way to assign to readonly variable in separate lines
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

function main {
  common::initialize "$SCRIPT_DIR"
  common::parse_cmdline "$@"
  common::export_provided_env_vars "${ENV_VARS[@]}"
  common::parse_and_export_env_vars
  # Support for setting relative PATH to .action-docs.yml config.
  for i in "${!ARGS[@]}"; do
    ARGS[i]=${ARGS[i]/--config=/--config=$(pwd)\/}
  done
  # shellcheck disable=SC2153 # False positive
  tofu_check_ "${HOOK_CONFIG[*]}" "${ARGS[*]}" "${FILES[@]}"
}

#######################################################################
# TODO Function which checks `action-docs` exists
# Arguments:
#   hook_config (string with array) arguments that configure hook behavior
#   args (string with array) arguments that configure wrapped tool behavior
#   files (array) filenames to check
#######################################################################
function tofu_check_ {
  local -r hook_config="$1"
  local -r args="$2"
  shift 2
  local -a -r files=("$@")

  # Get hook settings
  IFS=";" read -r -a configs <<< "$hook_config"

  if [[ ! $(command -v action-docs) ]]; then
    echo "ERROR: action-docs is required by action_docs pre-commit hook but is not installed or in the system's PATH."
    exit 1
  fi

  action_docs "${configs[*]}" "${args[*]}" "${files[@]}"
}

#######################################################################
# Wrapper around `action-docs` tool that check and change/create
# (depends on provided hook_config) OpenTofu documentation in
# markdown format
# Arguments:
#   hook_config (string with array) arguments that configure hook behavior
#   args (string with array) arguments that configure wrapped tool behavior
#   files (array) filenames to check
#######################################################################
function action_docs {
  local -r hook_config="$1"
  local -r args="$2"
  shift 2
  local -a -r files=("$@")

  local -a paths

  local index=0
  local file_with_path
  for file_with_path in "${files[@]}"; do
    file_with_path="${file_with_path// /__REPLACED__SPACE__}"

    paths[index]=$(dirname "$file_with_path")

    ((index += 1))
  done

  #
  # Get hook settings
  #
  local text_file="README.md"
  local add_to_existing=false
  local create_if_not_exist=false
  local use_standard_markers=false

  read -r -a configs <<< "$hook_config"

  for c in "${configs[@]}"; do

    IFS="=" read -r -a config <<< "$c"
    key=${config[0]}
    value=${config[1]}
  done

  local dir_path
  for dir_path in $(echo "${paths[*]}" | tr ' ' '\n' | sort -u); do
    dir_path="${dir_path//__REPLACED__SPACE__/ }"

    pushd "$dir_path" > /dev/null || continue

    # If file still not exist - skip dir
    [[ ! -f "$text_file" ]] && popd > /dev/null && continue

    action-docs $args

    popd > /dev/null
  done
}

[ "${BASH_SOURCE[0]}" != "$0" ] || main "$@"
