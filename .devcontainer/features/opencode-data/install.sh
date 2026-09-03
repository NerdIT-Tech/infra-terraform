#!/usr/bin/env bash
set -euo pipefail

# _REMOTE_USER / _REMOTE_USER_HOME are injected by the devcontainer CLI
# during feature installation (run as root).
remote_home="${_REMOTE_USER_HOME:-/home/vscode}"

# OpenCode keeps sessions/state under the XDG data dir and config under the
# XDG config dir. Persist both so credentials, sessions, and configuration
# survive container rebuilds via named-volume mounts in devcontainer.json.
data_dir="${XDG_DATA_HOME:-$remote_home/.local/share}/opencode"
config_dir="${XDG_CONFIG_HOME:-$remote_home/.config}/opencode"

mkdir -p "$data_dir"
mkdir -p "$config_dir"

if [ -n "${_REMOTE_USER:-}" ]; then
  chown -R "${_REMOTE_USER}:${_REMOTE_USER}" "$data_dir" "$config_dir"
fi
