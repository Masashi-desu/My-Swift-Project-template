#!/usr/bin/env zsh
set -euo pipefail

INSTALL_DIR="${1:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/butler-bin}"
mkdir -p "${INSTALL_DIR}"

case "$(uname -s):$(uname -m)" in
  Darwin:arm64)
    BUTLER_PLATFORM="darwin-arm64"
    ;;
  Darwin:x86_64)
    BUTLER_PLATFORM="darwin-amd64"
    ;;
  Linux:x86_64)
    BUTLER_PLATFORM="linux-amd64"
    ;;
  Linux:aarch64|Linux:arm64)
    BUTLER_PLATFORM="linux-arm64"
    ;;
  *)
    echo "Unsupported platform for butler: $(uname -s) $(uname -m)" >&2
    exit 1
    ;;
esac

ARCHIVE_PATH="${INSTALL_DIR}/butler.zip"
DOWNLOAD_URL="https://broth.itch.zone/butler/${BUTLER_PLATFORM}/LATEST/archive/default"

curl -LfsS "${DOWNLOAD_URL}" -o "${ARCHIVE_PATH}"
unzip -q -o "${ARCHIVE_PATH}" -d "${INSTALL_DIR}"
chmod +x "${INSTALL_DIR}/butler"

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "${INSTALL_DIR}" >> "${GITHUB_PATH}"
fi

"${INSTALL_DIR}/butler" -V
