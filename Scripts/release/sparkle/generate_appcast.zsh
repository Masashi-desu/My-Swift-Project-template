#!/usr/bin/env zsh
set -euo pipefail

source "${0:A:h}/../release_common.zsh"
cd "${RELEASE_REPO_ROOT}"

print_usage() {
  cat <<'EOF'
Usage: ./Scripts/release/sparkle/generate_appcast.zsh [options]

Options:
  --output <path>       Appcast output path. Default: SPARKLE_APPCAST_OUTPUT or dist/sparkle/appcast.xml.
  --release-url <url>   Release page URL used in the appcast item. Default: SPARKLE_RELEASE_URL.
  --project-file <path> XcodeGen project file. Default: PROJECT_FILE or project.yml.
  -h, --help            Show this help.
EOF
}

OUTPUT_OVERRIDE=""
RELEASE_URL_OVERRIDE=""
PROJECT_FILE_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || release_fail "--output には値が必要です。"
      OUTPUT_OVERRIDE="$2"
      shift 2
      ;;
    --release-url)
      [[ $# -ge 2 ]] || release_fail "--release-url には値が必要です。"
      RELEASE_URL_OVERRIDE="$2"
      shift 2
      ;;
    --project-file)
      [[ $# -ge 2 ]] || release_fail "--project-file には値が必要です。"
      PROJECT_FILE_OVERRIDE="$2"
      shift 2
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
release_require_command "ruby" "ruby が見つかりません。"

APPCAST_OUTPUT="$(release_repo_path "${OUTPUT_OVERRIDE:-${SPARKLE_APPCAST_OUTPUT:-dist/sparkle/appcast.xml}}")"
PROJECT_FILE="$(release_repo_path "${PROJECT_FILE_OVERRIDE:-${PROJECT_FILE:-project.yml}}")"
SPARKLE_RELEASE_URL="${RELEASE_URL_OVERRIDE:-${SPARKLE_RELEASE_URL:-}}"
SPARKLE_FEED_TITLE="${SPARKLE_FEED_TITLE:-__APP_NAME__}"
SPARKLE_FEED_LINK="${SPARKLE_FEED_LINK:-https://example.com/}"
SPARKLE_FEED_DESCRIPTION="${SPARKLE_FEED_DESCRIPTION:-__APP_NAME__ Appcast}"
SPARKLE_RELEASE_TITLE_PREFIX="${SPARKLE_RELEASE_TITLE_PREFIX:-Version}"

[[ -f "${PROJECT_FILE}" ]] || release_fail "project.yml が見つかりません: ${PROJECT_FILE}"
[[ -n "${SPARKLE_RELEASE_URL}" ]] || release_fail "SPARKLE_RELEASE_URL または --release-url を設定してください。"

mkdir -p "$(dirname "${APPCAST_OUTPUT}")"

export APPCAST_OUTPUT
export PROJECT_FILE
export SPARKLE_RELEASE_URL
export SPARKLE_FEED_TITLE
export SPARKLE_FEED_LINK
export SPARKLE_FEED_DESCRIPTION
export SPARKLE_RELEASE_TITLE_PREFIX

ruby <<'RUBY'
require "cgi"
require "fileutils"
require "time"
require "yaml"

project = YAML.load_file(ENV.fetch("PROJECT_FILE"))
base_settings = project.fetch("settings").fetch("base")
version = base_settings.fetch("MARKETING_VERSION").to_s
build = base_settings.fetch("CURRENT_PROJECT_VERSION").to_s

def xml(value)
  CGI.escapeHTML(value.to_s)
end

output = ENV.fetch("APPCAST_OUTPUT")
FileUtils.mkdir_p(File.dirname(output))

content = <<~XML
  <?xml version="1.0" encoding="utf-8"?>
  <rss version="2.0"
    xmlns:sparkle="https://sparkle-project.org/xml-namespaces/sparkle"
    xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
      <title>#{xml(ENV.fetch("SPARKLE_FEED_TITLE"))}</title>
      <link>#{xml(ENV.fetch("SPARKLE_FEED_LINK"))}</link>
      <description>#{xml(ENV.fetch("SPARKLE_FEED_DESCRIPTION"))}</description>
      <language>en</language>
      <item>
        <title>#{xml(ENV.fetch("SPARKLE_RELEASE_TITLE_PREFIX"))} #{xml(version)}</title>
        <link>#{xml(ENV.fetch("SPARKLE_RELEASE_URL"))}</link>
        <pubDate>#{Time.now.utc.rfc2822}</pubDate>
        <sparkle:shortVersionString>#{xml(version)}</sparkle:shortVersionString>
        <sparkle:version>#{xml(build)}</sparkle:version>
        <sparkle:releaseNotesLink>#{xml(ENV.fetch("SPARKLE_RELEASE_URL"))}</sparkle:releaseNotesLink>
        <sparkle:informationalUpdate/>
      </item>
    </channel>
  </rss>
XML

File.write(output, content)
puts "Generated appcast: #{output}"
puts "Sparkle version: #{version} (#{build})"
RUBY

if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout "${APPCAST_OUTPUT}"
fi
