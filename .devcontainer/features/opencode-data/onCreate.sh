#!/usr/bin/env bash
set -euo pipefail

# Runs as the remote user once the named volumes declared by this feature are
# mounted. The volumes are mounted at /mnt; we own them and point OpenCode's
# expected XDG locations at them via symlinks so sessions/state/config persist
# across container rebuilds.
data_mount=/mnt/opencode-data
config_mount=/mnt/opencode-config

user_home="${HOME:-$_REMOTE_USER_HOME}"
user_data_dir="${XDG_DATA_HOME:-$user_home/.local/share}/opencode"
user_config_dir="${XDG_CONFIG_HOME:-$user_home/.config}/opencode"

sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        command sudo "$@"
    fi
}

# The mount points belong to the container user; make sure they are writable.
sudo chown "$(id -u)":"$(id -g)" "$data_mount" "$config_mount"

# Redirect OpenCode's XDG data/config directories into the mounted volumes.
# Move any pre-existing data out of the way first so the symlink lands cleanly.
if [ -e "$user_data_dir" ] && [ ! -L "$user_data_dir" ]; then
    mv "$user_data_dir" "$user_data_dir-old"
fi
mkdir -p "$(dirname "$user_data_dir")"
ln -sfn "$data_mount" "$user_data_dir"

if [ -e "$user_config_dir" ] && [ ! -L "$user_config_dir" ]; then
    mv "$user_config_dir" "$user_config_dir-old"
fi
mkdir -p "$(dirname "$user_config_dir")"
ln -sfn "$config_mount" "$user_config_dir"
