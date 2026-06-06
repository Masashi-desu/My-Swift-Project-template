#!/usr/bin/env zsh
set -euo pipefail

source "${0:A:h}/../release_common.zsh"
cd "${RELEASE_REPO_ROOT}"

print_usage() {
  cat <<'EOF'
Usage: ./Scripts/release/itch/publish_itch_io.zsh [options]

Options:
  --dmg <path>           Publish a specific DMG. Defaults to newest dist/*.dmg matching MARKETING_VERSION.
  --dist-dir <dir>       Directory containing release DMGs. Default: RELEASE_OUTPUT_DIR or dist.
  --target <target>      itch.io butler target, e.g. user/project:osx-dmg.
  --user-version <text>  Version shown on itch.io. Default: MARKETING_VERSION (CURRENT_PROJECT_VERSION).
  --dry-run              Run butler dry-run only.
  -h, --help             Show this help.
EOF
}

release_project_metadata() {
  local project_file="${PROJECT_FILE:-project.yml}"

  [[ -f "${project_file}" ]] || return 0

  awk '
    function clean(value) {
      sub(/^[^:]+:[[:space:]]*/, "", value)
      sub(/[[:space:]]+#.*$/, "", value)
      gsub(/["'\''[:space:]]/, "", value)
      return value
    }
    /^[[:space:]]*MARKETING_VERSION:[[:space:]]*/ {
      marketing = clean($0)
    }
    /^[[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*/ {
      build = clean($0)
    }
    END {
      if (marketing != "") {
        printf "%s\t%s\n", marketing, build
      }
    }
  ' "${project_file}"
}

latest_dmg_in_dist() {
  local dist_dir="$1"
  local release_version="$2"

  release_require_command "ruby" "ruby が見つかりません。--dmg で対象 DMG を明示するか、ruby を利用できる環境で実行してください。"

  ruby -e '
    dir = ARGV.fetch(0)
    version = ARGV.fetch(1)
    files = Dir[File.join(dir, "*.dmg")]
    files = files.select { |path| File.basename(path).include?(version) } unless version.empty?
    abort("DMG が見つかりません: #{dir} version=#{version}") if files.empty?
    puts files.max_by { |path| File.mtime(path) }
  ' "${dist_dir}" "${release_version}"
}

DMG_PATH=""
DIST_DIR=""
ITCH_TARGET_OVERRIDE=""
USER_VERSION_OVERRIDE=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dmg)
      [[ $# -ge 2 ]] || release_fail "--dmg には値が必要です。"
      DMG_PATH="$2"
      shift 2
      ;;
    --dist-dir)
      [[ $# -ge 2 ]] || release_fail "--dist-dir には値が必要です。"
      DIST_DIR="$2"
      shift 2
      ;;
    --target)
      [[ $# -ge 2 ]] || release_fail "--target には値が必要です。"
      ITCH_TARGET_OVERRIDE="$2"
      shift 2
      ;;
    --user-version)
      [[ $# -ge 2 ]] || release_fail "--user-version には値が必要です。"
      USER_VERSION_OVERRIDE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      release_fail "Unknown option: $1"
      ;;
  esac
done

release_load_env
release_require_command "butler" $'butler が見つかりません。以下でインストールしてください:\n  ./Scripts/release/itch/install_butler.zsh /tmp/butler-bin\n  export PATH="/tmp/butler-bin:$PATH"'

metadata="$(release_project_metadata || true)"
release_version="${RELEASE_VERSION:-}"
release_build="${RELEASE_BUILD:-}"

if [[ -n "${metadata}" ]]; then
  release_version="${release_version:-${metadata%%$'\t'*}}"
  release_build="${release_build:-${metadata##*$'\t'}}"
fi

DIST_DIR="${DIST_DIR:-${RELEASE_OUTPUT_DIR:-dist}}"
DIST_DIR="$(release_repo_path "${DIST_DIR}")"

if [[ -n "${DMG_PATH}" ]]; then
  DMG_PATH="$(release_repo_path "${DMG_PATH}")"
else
  DMG_PATH="$(latest_dmg_in_dist "${DIST_DIR}" "${release_version}")"
fi

[[ -f "${DMG_PATH}" ]] || release_fail "DMG が見つかりません: ${DMG_PATH}"

ITCHIO_TARGET="${ITCH_TARGET_OVERRIDE:-${ITCHIO_TARGET:-}}"
[[ -n "${ITCHIO_TARGET}" ]] || release_fail "ITCHIO_TARGET が未設定です。例: user/project:osx-dmg"

BUTLER_API_KEY="${BUTLER_API_KEY:-${ITCHIO_API_KEY:-}}"
[[ -n "${BUTLER_API_KEY}" ]] || release_fail "BUTLER_API_KEY または ITCHIO_API_KEY が未設定です。"
export BUTLER_API_KEY

if [[ -n "${USER_VERSION_OVERRIDE}" ]]; then
  user_version="${USER_VERSION_OVERRIDE}"
elif [[ -n "${release_version}" && -n "${release_build}" ]]; then
  user_version="${release_version} (${release_build})"
elif [[ -n "${release_version}" ]]; then
  user_version="${release_version}"
else
  user_version="$(basename "${DMG_PATH}" .dmg)"
fi

release_step "itch.io への dry-run push を実行します"
butler push --dry-run "${DMG_PATH}" "${ITCHIO_TARGET}" --userversion "${user_version}"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "Dry-run only. No upload was performed."
  exit 0
fi

release_step "itch.io へ DMG を公開します"
butler push "${DMG_PATH}" "${ITCHIO_TARGET}" --userversion "${user_version}"

echo "Published to itch.io: ${ITCHIO_TARGET} (${user_version})"
