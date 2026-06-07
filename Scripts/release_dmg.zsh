#!/usr/bin/env zsh
set -euo pipefail

exec "${0:A:h}/release/dmg/release_dmg.zsh" "$@"
