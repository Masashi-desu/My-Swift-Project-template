#!/usr/bin/env zsh
set -euo pipefail

source "${0:A:h}/../release_common.zsh"
cd "${RELEASE_REPO_ROOT}"

MODE="deploy"
APPCAST_PATH=""

print_usage() {
  cat <<'EOF'
Usage: ./Scripts/release/sparkle/deploy_appcast_ftp.zsh [options] [appcast-path]

Options:
  --preflight    Verify FTP write/rename/delete capability without replacing appcast.xml.
  --verify-only  Verify SPARKLE_APPCAST_URL without uploading.
  -h, --help     Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --preflight)
      MODE="preflight"
      shift
      ;;
    --verify-only)
      MODE="verify"
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    --*)
      release_fail "Unknown option: $1"
      ;;
    *)
      APPCAST_PATH="$1"
      shift
      ;;
  esac
done

release_load_env

APPCAST_PATH="$(release_repo_path "${APPCAST_PATH:-${SPARKLE_APPCAST_OUTPUT:-dist/sparkle/appcast.xml}}")"
FTP_PORT="${FTP_PORT:-21}"
SPARKLE_APPCAST_URL="${SPARKLE_APPCAST_URL:-}"

release_require_command "curl" "curl が見つかりません。"
if [[ "${MODE}" != "verify" ]]; then
  release_require_command "lftp" "lftp が見つかりません。以下でインストールしてください: brew install lftp"
fi

[[ -f "${APPCAST_PATH}" ]] || release_fail "appcast.xml が見つかりません: ${APPCAST_PATH}"

if [[ "${MODE}" != "verify" ]]; then
  for required_name in FTP_HOST FTP_USERNAME FTP_PASSWORD FTP_REMOTE_DIR; do
    if [[ -z "${(P)required_name:-}" ]]; then
      release_fail "${required_name} が未設定です。"
    fi
  done
fi

verify_appcast_file() {
  local target_path="$1"

  if [[ -z "${EXPECTED_SPARKLE_VERSION:-}" && -z "${EXPECTED_SPARKLE_BUILD:-}" ]]; then
    return 0
  fi

  EXPECTED_SPARKLE_VERSION="${EXPECTED_SPARKLE_VERSION:-}" \
    EXPECTED_SPARKLE_BUILD="${EXPECTED_SPARKLE_BUILD:-}" \
    ruby -rrexml/document -rrexml/xpath -e '
      path = ARGV.fetch(0)
      expected_version = ENV.fetch("EXPECTED_SPARKLE_VERSION", "")
      expected_build = ENV.fetch("EXPECTED_SPARKLE_BUILD", "")
      doc = REXML::Document.new(File.read(path))
      ns = { "sparkle" => "https://sparkle-project.org/xml-namespaces/sparkle" }
      versions = REXML::XPath.match(doc, "//sparkle:shortVersionString", ns).map { |node| node.text.to_s }
      builds = REXML::XPath.match(doc, "//sparkle:version", ns).map { |node| node.text.to_s }
      unless expected_version.empty? || versions.include?(expected_version)
        abort("appcast shortVersionString mismatch: expected #{expected_version}, got #{versions.join(", ")}")
      end
      unless expected_build.empty? || builds.include?(expected_build)
        abort("appcast version mismatch: expected #{expected_build}, got #{builds.join(", ")}")
      end
    ' "${target_path}" || release_fail "appcast.xml のバージョン検証に失敗しました: ${target_path}"
}

verify_public_appcast() {
  [[ -n "${SPARKLE_APPCAST_URL}" ]] || release_fail "SPARKLE_APPCAST_URL が未設定です。"

  release_step "公開 appcast を検証します"
  local downloaded_appcast=""
  downloaded_appcast="$(mktemp)"
  trap 'rm -f "${downloaded_appcast:-}"' EXIT

  for attempt in 1 2 3; do
    if curl -fsS "${SPARKLE_APPCAST_URL}?release_verify=$(date +%s)" -o "${downloaded_appcast}"; then
      verify_appcast_file "${downloaded_appcast}"
      echo "Verified: ${SPARKLE_APPCAST_URL}"
      return 0
    fi
    sleep 5
  done

  release_fail "appcast.xml を公開 URL で確認できません: ${SPARKLE_APPCAST_URL}"
}

ftp_session() {
  lftp -u "${FTP_USERNAME},${FTP_PASSWORD}" -p "${FTP_PORT}" "${FTP_HOST}"
}

remote_dir_candidates() {
  local primary="${FTP_REMOTE_DIR}"
  print -r -- "${primary}"
  if [[ "${primary}" == /* ]]; then
    print -r -- "${primary#/}"
  fi
}

verify_appcast_file "${APPCAST_PATH}"

if [[ "${MODE}" == "verify" ]]; then
  verify_public_appcast
  exit 0
fi

if [[ "${MODE}" == "preflight" ]]; then
  release_step "FTP 書き込み preflight を実行します"
  preflight_base=".release-preflight-$(date +%Y%m%d%H%M%S)-$$"
  preflight_one="$(mktemp)"
  preflight_two="$(mktemp)"
  preflight_ok=0
  remote_dir=""
  trap 'rm -f "${preflight_one:-}" "${preflight_two:-}"' EXIT

  printf 'release preflight one\n' > "${preflight_one}"
  printf 'release preflight two\n' > "${preflight_two}"

  while IFS= read -r remote_dir; do
    if ftp_session <<EOF
set cmd:fail-exit yes
set ftp:passive-mode on
cd "${remote_dir}"
put "${preflight_one}" -o "${preflight_base}.target"
put "${preflight_two}" -o "${preflight_base}.tmp"
mv "${preflight_base}.tmp" "${preflight_base}.target"
rm "${preflight_base}.target"
bye
EOF
    then
      preflight_ok=1
      echo "FTP preflight OK: ${remote_dir}"
      break
    fi
  done < <(remote_dir_candidates)

  [[ "${preflight_ok}" -eq 1 ]] || release_fail "FTP 書き込み preflight に失敗しました。FTP_REMOTE_DIR と公開ディレクトリを確認してください。"
  exit 0
fi

release_step "Sparkle appcast を FTP へアップロードします"
remote_tmp="appcast.xml.tmp-$(date +%Y%m%d%H%M%S)-$$"
deploy_ok=0
remote_dir=""

while IFS= read -r remote_dir; do
  if ftp_session <<EOF
set cmd:fail-exit yes
set ftp:passive-mode on
cd "${remote_dir}"
put "${APPCAST_PATH}" -o "${remote_tmp}"
mv "${remote_tmp}" appcast.xml
bye
EOF
  then
    deploy_ok=1
    echo "Uploaded appcast.xml to FTP: ${remote_dir}"
    break
  fi
done < <(remote_dir_candidates)

[[ "${deploy_ok}" -eq 1 ]] || release_fail "Sparkle appcast の FTP アップロードに失敗しました。"

if [[ -n "${SPARKLE_APPCAST_URL}" ]]; then
  verify_public_appcast
else
  echo "SPARKLE_APPCAST_URL is not set. Public verification was skipped."
fi
