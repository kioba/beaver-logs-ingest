#!/usr/bin/env bash
#
# Ensures Spotify's XCLogParser is on PATH (macOS only). xcode-parser shells out
# to it to read .xcactivitylog files. Idempotent: a no-op when already installed.
set -euo pipefail

if command -v xclogparser >/dev/null 2>&1; then
  echo "xclogparser already installed: $(command -v xclogparser)"
  exit 0
fi

echo "::group::brew install xclogparser"
brew install xclogparser
echo "::endgroup::"
