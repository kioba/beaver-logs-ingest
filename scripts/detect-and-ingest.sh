#!/usr/bin/env bash
#
# Any-OS ingest leg: resolve the build artifact (.apk/.aab) and/or a raw OTLP
# file, then dispatch — artifact-analyzer for the artifact, a curl POST for the
# raw OTLP. A missing input is a warning, not an error: this must never fail the
# customer's build (mirrors the CLIs' never-fail-the-build posture).
#
# Consumes from the environment: API_KEY, PROJECT_ID, ENDPOINT (required);
# ARTIFACT_INPUT, OTLP_FILE, OTLP_SIGNAL (optional); ANALYZER_BIN and the
# BL_BRANCH/BL_COMMIT/BL_RUN_ID/BL_PR context exported by earlier steps.
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

# Resolve the artifact: an explicit path/glob wins; otherwise the default glob.
artifact_path="${ARTIFACT_INPUT:-}"
if [ -z "$artifact_path" ]; then
  artifact_path="$(find . -type f \( -name '*.apk' -o -name '*.aab' \) \
                     -path '*/build/outputs/*' -exec ls -t {} + 2>/dev/null | head -1)"
elif [ ! -f "$artifact_path" ]; then
  # input was a glob (or a bad path) — let the shell expand it, newest first
  # shellcheck disable=SC2086
  artifact_path="$(newest $artifact_path)"
fi

common_args=(--project-id "$PROJECT_ID" --endpoint "$ENDPOINT" --api-key "$API_KEY"
             --branch "${BL_BRANCH:-local}" --commit "${BL_COMMIT:-local}"
             --ci-run-id "${BL_RUN_ID:-}")
if [ -n "${BL_PR:-}" ]; then
  common_args+=(--pr-number "$BL_PR")
fi

if [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
  echo "Analyzing artifact: $artifact_path"
  "${ANALYZER_BIN:?ANALYZER_BIN not set (install-clis.sh must run first)}" \
    --artifact "$artifact_path" "${common_args[@]}"
else
  echo "::notice::no .apk/.aab artifact found; skipping size metrics"
fi

if [ -n "${OTLP_FILE:-}" ]; then
  if [ -f "$OTLP_FILE" ]; then
    signal="${OTLP_SIGNAL:-traces}"
    echo "POSTing raw OTLP ($signal): $OTLP_FILE"
    curl -fsS -X POST "${ENDPOINT%/}/v1/${signal}" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $API_KEY" \
      --data-binary @"$OTLP_FILE"
  else
    echo "::warning::otlp-file '$OTLP_FILE' not found; skipping raw OTLP POST"
  fi
fi
