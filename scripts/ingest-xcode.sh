#!/usr/bin/env bash
#
# macOS/iOS ingest leg: ensure XCLogParser is present, resolve the .xcactivitylog
# (explicit input or newest under DerivedData), and run xcode-parser to POST
# OTLP traces. A missing log is a warning, not an error — never fails the build.
#
# Consumes from the environment: API_KEY, PROJECT_ID, ENDPOINT (required);
# XCACTIVITYLOG_INPUT (optional); XCODE_BIN and the BL_* context from earlier steps.
set -euo pipefail

: "${API_KEY:?api-key is required}"
: "${PROJECT_ID:?project-id is required}"
: "${ENDPOINT:?endpoint is required}"
echo "::add-mask::$API_KEY"

# Newest existing regular file among the arguments (empty if none exist).
newest() {
  local best="" f
  for f in "$@"; do
    [ -f "$f" ] || continue
    if [ -z "$best" ] || [ "$f" -nt "$best" ]; then best="$f"; fi
  done
  printf '%s' "$best"
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$script_dir/install-xclogparser.sh"

log="${XCACTIVITYLOG_INPUT:-}"
derived_data="$HOME/Library/Developer/Xcode/DerivedData"
if [ -z "$log" ] && [ -d "$derived_data" ]; then
  log="$(find "$derived_data" -type f \
           -name '*.xcactivitylog' -path '*/Logs/Build/*' \
           -exec ls -t {} + 2>/dev/null | head -1)"
elif [ -n "$log" ] && [ ! -f "$log" ]; then
  # input was a glob (or bad path) — expand it, newest first
  # shellcheck disable=SC2086
  log="$(newest $log)"
fi

if [ -z "$log" ] || [ ! -f "$log" ]; then
  echo "::warning::no .xcactivitylog found; skipping trace upload"
  exit 0
fi

echo "Parsing Xcode build log: $log"
xc_args=(--log "$log" --project-id "$PROJECT_ID" --endpoint "$ENDPOINT" --api-key "$API_KEY"
         --branch "${BL_BRANCH:-local}" --commit "${BL_COMMIT:-local}"
         --ci-run-id "${BL_RUN_ID:-}")
if [ -n "${BL_PR:-}" ]; then
  xc_args+=(--pr-number "$BL_PR")
fi

"${XCODE_BIN:?XCODE_BIN not set (install-clis.sh must run first)}" "${xc_args[@]}"
