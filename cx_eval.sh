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

# ── Auth & setup ──────────────────────────────────────────────────────────────
refresh_token() {
    TOKEN=$(gcloud auth print-access-token 2>&1) || {
        echo "ERROR: Failed to fetch access token. Run 'gcloud auth login' and retry." >&2
        exit 1
    }
    if [[ -z "$TOKEN" ]]; then
        echo "ERROR: gcloud returned an empty token. Run 'gcloud auth login' and retry." >&2
        exit 1
    fi
}

setup() {
    echo ""
    echo "=== CX Agent Studio Evaluations CLI ==="
    echo ""
    read -rp "Project ID: " PROJECT_ID
    read -rp "Location [us]: " LOCATION
    LOCATION="${LOCATION:-us}"
    read -rp "App ID: " APP_ID
    if [[ -z "$PROJECT_ID" ]]; then
        echo "ERROR: Project ID cannot be empty." >&2
        exit 1
    fi
    if [[ -z "$APP_ID" ]]; then
        echo "ERROR: App ID cannot be empty." >&2
        exit 1
    fi
    echo ""
    echo "Fetching access token..."
    refresh_token
    BASE_URL="https://ces.googleapis.com/v1beta/projects/${PROJECT_ID}/locations/${LOCATION}/apps/${APP_ID}"
    echo "Ready." >&2
    echo "Base URL: ${BASE_URL}" >&2
    echo ""
}

# ── HTTP helpers ──────────────────────────────────────────────────────────────
# _run_curl METHOD URL DATA OUTPUT_FILE  →  prints http_code to stdout
_run_curl() {
    local method="$1" url="$2" data="$3" out="$4"
    if [[ -n "$data" ]]; then
        curl -s -o "$out" -w "%{http_code}" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            -X "$method" -d "$data" "$url"
    else
        curl -s -o "$out" -w "%{http_code}" \
            -H "Authorization: Bearer ${TOKEN}" \
            -X "$method" "$url"
    fi
}

# do_request METHOD URL [JSON_DATA]
# Sets LAST_RESPONSE; prints "--- HTTP NNN ---" + body
do_request() {
    local method="$1"
    local url="$2"
    local data="${3:-}"
    local tmp_body
    tmp_body=$(mktemp)

    local http_code
    http_code=$(_run_curl "$method" "$url" "$data" "$tmp_body")

    if [[ "$http_code" == "401" ]]; then
        echo "(Token expired — refreshing...)"
        refresh_token
        http_code=$(_run_curl "$method" "$url" "$data" "$tmp_body")
    fi

    LAST_RESPONSE=$(cat "$tmp_body")
    rm -f "$tmp_body"

    echo "--- HTTP ${http_code} ---"
    echo "${LAST_RESPONSE}"
    echo ""
}

# ── Scheduled Evaluation Runs (1–5) ──────────────────────────────────────────
list_scheduled_runs() {
    do_request "GET" "${BASE_URL}/scheduledEvaluationRuns"
}

get_scheduled_run() {
    read -rp "Scheduled Run ID: " id
    do_request "GET" "${BASE_URL}/scheduledEvaluationRuns/${id}"
}

create_scheduled_run() {
    read -rp "Display Name: " displayName
    read -rp "Cron Schedule (e.g. 0 9 * * 1): " cronSchedule
    read -rp "Evaluation ID: " evaluationId
    local body
    body=$(printf '{"displayName":"%s","cronSchedule":"%s","evaluation":"%s/evaluations/%s"}' \
        "$displayName" "$cronSchedule" "$BASE_URL" "$evaluationId")
    do_request "POST" "${BASE_URL}/scheduledEvaluationRuns" "$body"
}

patch_scheduled_run() {
    read -rp "Scheduled Run ID: " id
    read -rp "Field to update (e.g. displayName): " field
    read -rp "New value: " value
    local body
    body=$(printf '{"%s":"%s"}' "$field" "$value")
    do_request "PATCH" "${BASE_URL}/scheduledEvaluationRuns/${id}?updateMask=${field}" "$body"
}

delete_scheduled_run() {
    read -rp "Scheduled Run ID: " id
    do_request "DELETE" "${BASE_URL}/scheduledEvaluationRuns/${id}"
}
