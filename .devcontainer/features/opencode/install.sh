#!/usr/bin/env bash
set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to install OpenCode" >&2
  exit 1
fi

# Install the CLI onto the system PATH (/usr/local/bin) so it is available
# to every shell in the container without editing any user's rc files. The
# official installer hard-codes its install dir to $HOME/.opencode/bin, so we
# point HOME at a scratch dir and --no-modify-path to avoid touching rc files,
# then move the freshly-downloaded binary onto the PATH.
install_dir="$(mktemp -d)"

if [ "${VERSION:-latest}" = "latest" ] || [ -z "${VERSION:-}" ]; then
  VERSION="" # reset or else the installer will error out if VERSION is set to "latest"
  curl -fsSL https://opencode.ai/install | HOME="$install_dir" bash -s -- --no-modify-path
else
  curl -fsSL https://opencode.ai/install | HOME="$install_dir" VERSION="$VERSION" bash -s -- --no-modify-path
fi

install -m 0755 "$install_dir/.opencode/bin/opencode" /usr/local/bin/opencode

rm -rf "$install_dir"

opencode --version
