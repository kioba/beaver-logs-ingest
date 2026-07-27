#!/usr/bin/env bash
#
# Downloads the pinned Beaver Logs CLI release zips and exports their launcher
# paths to $GITHUB_ENV (ANALYZER_BIN, XCODE_BIN) for later composite steps.
#
# artifact-analyzer is fetched on every runner (it only needs a JRE, which
# setup-java provides). xcode-parser is a macOS-only bundled-JRE runtime image
# (it also needs XCLogParser), so it is fetched only on macOS.
#
# The two zips unzip to different layouts — artifact-analyzer (distZip) to
# `beaver-logs-artifact-analyzer-<v>/bin/…`, xcode-parser (org.beryx.runtime
# image) under `image/bin/…` — so the launcher is located with `find` rather
# than a hard-coded path.
set -euo pipefail

REPO="kioba/beaver_logs"
ARTIFACT_VER="${CLI_VERSION_ARTIFACT:?CLI_VERSION_ARTIFACT is required}"
XCODE_VER="${CLI_VERSION_XCODE:?CLI_VERSION_XCODE is required}"

# Where to record exported vars: $GITHUB_ENV under Actions, else stdout locally.
env_out="${GITHUB_ENV:-/dev/stdout}"

fetch() { # <name> <version> -> prints the launcher path
  local name="$1" ver="$2"
  local url="https://github.com/${REPO}/releases/download/${name}-v${ver}/beaver-logs-${name}-${ver}.zip"
  local dest="/tmp/beaver-logs-${name}"
  rm -rf "$dest"
  mkdir -p "$dest"
  echo "::group::download ${name} ${ver}" >&2
  curl -fsSL "$url" -o "/tmp/beaver-logs-${name}.zip"
  unzip -q "/tmp/beaver-logs-${name}.zip" -d "$dest"
  echo "::endgroup::" >&2
  local bin
  bin="$(find "$dest" -type f -name "beaver-logs-${name}" -path '*/bin/*' | head -1)"
  if [ -z "$bin" ]; then
    echo "::error::launcher 'beaver-logs-${name}' not found under $dest (bad release asset?)" >&2
    exit 1
  fi
  chmod +x "$bin"
  printf '%s\n' "$bin"
}

analyzer_bin="$(fetch artifact-analyzer "$ARTIFACT_VER")"
echo "ANALYZER_BIN=$analyzer_bin" >> "$env_out"

if [ "${RUNNER_OS:-}" = "macOS" ]; then
  xcode_bin="$(fetch xcode-parser "$XCODE_VER")"
  echo "XCODE_BIN=$xcode_bin" >> "$env_out"
fi
