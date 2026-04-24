#!/bin/zsh

versioning_root_dir() {
  cd "$(dirname "$0")/.." && pwd
}

versioning_config_path() {
  local root_dir="${1:-$(versioning_root_dir)}"
  echo "$root_dir/Config/Version.xcconfig"
}

read_version_setting() {
  local key="$1"
  local config_path="${2:-$(versioning_config_path)}"

  sed -n "s/^${key}[[:space:]]*=[[:space:]]*//p" "$config_path" | tail -n 1
}

numeric_build_version() {
  local input="$1"
  local digits="${input//[^0-9]/}"
  if [[ -z "$digits" ]]; then
    digits="1"
  fi
  echo "$digits"
}
