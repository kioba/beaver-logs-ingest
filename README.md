# Beaver Logs Ingest — GitHub Action

Upload build telemetry to [Beaver Logs](https://www.beaverlogs.app) from any CI
job. One composite action, auto-detecting:

- **`.apk` / `.aab`** → artifact **size metrics** (`artifact-analyzer`), any runner.
- **`.xcactivitylog`** → Xcode build **traces** (`xcode-parser`), macOS runners only
  (needs [XCLogParser](https://github.com/MobileNativeFoundation/XCLogParser), which
  the action installs via Homebrew).
- **A raw OTLP/HTTP-JSON file** → POSTed as-is to `/v1/<signal>`.

It never fails your build: a missing artifact or log emits a warning and exits 0.
The API key is masked in logs (`::add-mask::`) and never echoed.

## Usage

> The advertised, versioned ref is **`kioba/beaver-logs-ingest@v1`** (a mirror repo
> with `action.yml` at its root — required by the GitHub Marketplace). Until that
> mirror is published you can pin the in-monorepo path as a dev fallback:
> `kioba/beaver_logs/github-action@<ref>`.

### Android / JVM (`.aab` size metrics on Linux)

```yaml
- uses: kioba/beaver-logs-ingest@v1
  with:
    api-key: ${{ secrets.BEAVER_LOGS_API_KEY }}
    project-id: 00000000-0000-0000-0000-000000000000
    # artifact: defaults to the newest **/build/outputs/**/*.{apk,aab}
```

### iOS (`.xcactivitylog` traces on macOS)

```yaml
runs-on: macos-14
steps:
  - uses: kioba/beaver-logs-ingest@v1
    with:
      api-key: ${{ secrets.BEAVER_LOGS_API_KEY }}
      project-id: 00000000-0000-0000-0000-000000000000
      # xcactivitylog: defaults to the newest under DerivedData/**/Logs/Build
```

### Raw OTLP file

```yaml
- uses: kioba/beaver-logs-ingest@v1
  with:
    api-key: ${{ secrets.BEAVER_LOGS_API_KEY }}
    project-id: 00000000-0000-0000-0000-000000000000
    otlp-file: build/telemetry.json
    otlp-signal: traces   # traces | metrics | logs
```

## Inputs

| Input | Required | Default | Notes |
|---|---|---|---|
| `api-key` | yes | — | Sent as `Authorization: Bearer <key>`. Use `${{ secrets.BEAVER_LOGS_API_KEY }}`. |
| `project-id` | yes | — | Project UUID → `service.namespace` (the scoping key). |
| `endpoint` | no | `https://ingest.beaverlogs.app/ingest` | OTLP base; the CLIs append `/v1/traces`, `/v1/metrics`. |
| `xcactivitylog` | no | auto | Path/glob (macOS). Empty → newest under `DerivedData/**/Logs/Build`. |
| `artifact` | no | auto | Path/glob to `.apk`/`.aab`. Empty → newest `**/build/outputs/**/*.{apk,aab}`. |
| `otlp-file` | no | — | Raw OTLP/HTTP-JSON file to POST verbatim. |
| `otlp-signal` | no | `traces` | Signal for `otlp-file`: `traces`/`metrics`/`logs`. |
| `cli-version-xcode` | no | `1.0.0` | `xcode-parser` release to download. |
| `cli-version-artifact` | no | `0.1.0` | `artifact-analyzer` release to download. |

Branch, commit, PR number, and CI run id are derived automatically from the
GitHub event — you don't pass them.

## How it works

A **composite** action (not Docker, because iOS log parsing needs macOS-only
XCLogParser). Steps: derive build context → `setup-java@v4` (JDK 21) → download
the pinned CLI release zips → run the any-OS artifact/OTLP leg → on macOS, install
XCLogParser and run the Xcode-log leg. The CLIs authenticate with `--api-key`
(Bearer) and stamp `service.namespace = project-id`.

## Notes

- Bump the pinned CLI versions in one place: the `cli-version-*` defaults in
  `action.yml`.
- `brew install xclogparser` adds ~30–60s to macOS runs (cached if already present).
- Android size metrics only (`.apk`/`.aab`); iOS size (`.ipa`) is not yet supported
  — use the `.xcactivitylog` trace path for iOS.
