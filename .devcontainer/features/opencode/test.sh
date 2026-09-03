VERSION="latest"

if [ "${VERSION:-latest}" = "latest" ] || [ -z "${VERSION:-}" ]; then
  echo "Installing latest version..."
else
  echo "Installing version ${VERSION}..."
fi