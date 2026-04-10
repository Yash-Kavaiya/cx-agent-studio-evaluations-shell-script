#!/usr/bin/env bash
# cx_eval.sh — Interactive CLI for the CX Agent Studio Evaluations API
# Usage: bash cx_eval.sh
# Requires: gcloud, curl; python3 for CSV export (options 29-31)
set -uo pipefail

# ── Global state ──────────────────────────────────────────────────────────────
PROJECT_ID=""
LOCATION=""
APP_ID=""
TOKEN=""
BASE_URL=""
LAST_RESPONSE=""

# ── Dependency checks ─────────────────────────────────────────────────────────
check_deps() {
    local missing=0
    for cmd in gcloud curl; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "ERROR: '$cmd' is required but not installed." >&2
            case "$cmd" in
                gcloud) echo "  Install: https://cloud.google.com/sdk/docs/install" >&2 ;;
                curl)   echo "  Install: apt install curl  OR  brew install curl  OR  winget install curl.curl" >&2 ;;
            esac
            missing=1
        fi
    done
    [[ $missing -eq 1 ]] && exit 1
    # python3 only needed for CSV export — warn but don't exit
    if ! command -v python3 &>/dev/null; then
        echo "WARNING: 'python3' not found. CSV export (options 29-31) will not work." >&2
    fi
}
