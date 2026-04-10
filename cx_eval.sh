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

# ── JSON helper ───────────────────────────────────────────────────────────────
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"   # escape backslashes first
    s="${s//\"/\\\"}"   # then escape double-quotes
    printf '%s' "$s"
}

# ── HTTP helpers ──────────────────────────────────────────────────────────────
# _run_curl METHOD URL DATA OUTPUT_FILE [MODE]  →  prints http_code to stdout
_run_curl() {
    local method="$1" url="$2" data="$3" out="$4" mode="${5:-json}"
    local -a base_args=(-s -o "$out" -w "%{http_code}"
        -H "Authorization: Bearer ${TOKEN}"
        -X "$method")
    if [[ "$mode" == "multipart" ]]; then
        curl "${base_args[@]}" -F "$data" "$url"
    elif [[ -n "$data" ]]; then
        curl "${base_args[@]}" -H "Content-Type: application/json" -d "$data" "$url"
    else
        curl "${base_args[@]}" "$url"
    fi
}

# do_request METHOD URL [JSON_DATA] [MODE]
# Sets LAST_RESPONSE; prints "--- HTTP NNN ---" + body
do_request() {
    local method="$1"
    local url="$2"
    local data="${3:-}"
    local mode="${4:-json}"
    local tmp_body
    tmp_body=$(mktemp)

    local http_code
    http_code=$(_run_curl "$method" "$url" "$data" "$tmp_body" "$mode")

    if [[ "$http_code" == "401" ]]; then
        echo "(Token expired — refreshing...)"
        refresh_token
        http_code=$(_run_curl "$method" "$url" "$data" "$tmp_body" "$mode")
    fi

    if [[ "$http_code" == "401" ]]; then
        echo "ERROR: Authentication failed after token refresh. Run 'gcloud auth login'." >&2
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
    [[ -z "$id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    do_request "GET" "${BASE_URL}/scheduledEvaluationRuns/${id}"
}

create_scheduled_run() {
    read -rp "Display Name: " displayName
    read -rp "Cron Schedule (e.g. 0 9 * * 1): " cronSchedule
    read -rp "Evaluation ID: " evaluationId
    local body
    body=$(printf '{"displayName":"%s","cronSchedule":"%s","evaluation":"%s/evaluations/%s"}' \
        "$(json_escape "$displayName")" "$(json_escape "$cronSchedule")" "$BASE_URL" "$(json_escape "$evaluationId")")
    do_request "POST" "${BASE_URL}/scheduledEvaluationRuns" "$body"
}

patch_scheduled_run() {
    read -rp "Scheduled Run ID: " id
    [[ -z "$id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    read -rp "Field to update (e.g. displayName): " field
    if [[ ! "$field" =~ ^[a-zA-Z][a-zA-Z0-9.]*$ ]]; then
        echo "ERROR: Field name must be alphanumeric (e.g. displayName, nested.field)." >&2
        return
    fi
    read -rp "New value: " value
    local body
    body=$(printf '{"%s":"%s"}' "$(json_escape "$field")" "$(json_escape "$value")")
    do_request "PATCH" "${BASE_URL}/scheduledEvaluationRuns/${id}?updateMask=${field}" "$body"
}

delete_scheduled_run() {
    read -rp "Scheduled Run ID: " id
    [[ -z "$id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    do_request "DELETE" "${BASE_URL}/scheduledEvaluationRuns/${id}"
}

# ── Evaluations (6–12) ───────────────────────────────────────────────────────
list_evaluations() {
    do_request "GET" "${BASE_URL}/evaluations"
}

get_evaluation() {
    read -rp "Evaluation ID: " id
    [[ -z "$id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    do_request "GET" "${BASE_URL}/evaluations/${id}"
}

create_evaluation() {
    read -rp "Display Name: " displayName
    echo "Evaluation Type:"
    echo "  1) GOLDEN"
    echo "  2) SCENARIO"
    read -rp "Choice [1]: " type_choice
    local evaluationType
    case "${type_choice:-1}" in
        2) evaluationType="SCENARIO" ;;
        *) evaluationType="GOLDEN" ;;
    esac
    local body
    body=$(printf '{"displayName":"%s","evaluationType":"%s"}' "$(json_escape "$displayName")" "$evaluationType")
    do_request "POST" "${BASE_URL}/evaluations" "$body"
}

patch_evaluation() {
    read -rp "Evaluation ID: " id
    [[ -z "$id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    read -rp "Field to update (e.g. displayName): " field
    if [[ ! "$field" =~ ^[a-zA-Z][a-zA-Z0-9.]*$ ]]; then
        echo "ERROR: Field name must be alphanumeric (e.g. displayName, nested.field)." >&2
        return
    fi
    read -rp "New value: " value
    local body
    body=$(printf '{"%s":"%s"}' "$(json_escape "$field")" "$(json_escape "$value")")
    do_request "PATCH" "${BASE_URL}/evaluations/${id}?updateMask=${field}" "$body"
}

delete_evaluation() {
    read -rp "Evaluation ID: " id
    [[ -z "$id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    do_request "DELETE" "${BASE_URL}/evaluations/${id}"
}

export_evaluations() {
    echo "Export format:"
    echo "  1) JSON"
    echo "  2) CSV"
    read -rp "Choice [1]: " fmt_choice
    local format
    case "${fmt_choice:-1}" in
        2) format="CSV" ;;
        *) format="JSON" ;;
    esac
    local body
    body=$(printf '{"outputFormat":"%s"}' "$format")
    do_request "POST" "${BASE_URL}/evaluations:export" "$body"
}

upload_evaluation_audio() {
    read -rp "Evaluation ID: " id
    read -rp "Local audio file path: " audio_path
    if [[ ! -f "$audio_path" ]]; then
        echo "ERROR: File not found: ${audio_path}" >&2
        return
    fi
    do_request "POST" "${BASE_URL}/evaluations/${id}:uploadEvaluationAudio" \
        "audio=@${audio_path}" "multipart"
}

# ── Evaluation Results (13–15) ───────────────────────────────────────────────
list_eval_results() {
    read -rp "Evaluation ID: " eval_id
    [[ -z "$eval_id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    do_request "GET" "${BASE_URL}/evaluations/${eval_id}/results"
}

get_eval_result() {
    read -rp "Evaluation ID: " eval_id
    [[ -z "$eval_id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    read -rp "Result ID: " result_id
    [[ -z "$result_id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    do_request "GET" "${BASE_URL}/evaluations/${eval_id}/results/${result_id}"
}

delete_eval_result() {
    read -rp "Evaluation ID: " eval_id
    [[ -z "$eval_id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    read -rp "Result ID: " result_id
    [[ -z "$result_id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    do_request "DELETE" "${BASE_URL}/evaluations/${eval_id}/results/${result_id}"
}

# ── Evaluation Runs (16–18) ──────────────────────────────────────────────────
list_eval_runs() {
    do_request "GET" "${BASE_URL}/evaluationRuns"
}

get_eval_run() {
    read -rp "Evaluation Run ID: " id
    [[ -z "$id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    do_request "GET" "${BASE_URL}/evaluationRuns/${id}"
}

delete_eval_run() {
    read -rp "Evaluation Run ID: " id
    [[ -z "$id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    do_request "DELETE" "${BASE_URL}/evaluationRuns/${id}"
}

# ── Evaluation Datasets (19–23) ──────────────────────────────────────────────
list_datasets() {
    do_request "GET" "${BASE_URL}/evaluationDatasets"
}

get_dataset() {
    read -rp "Dataset ID: " id
    [[ -z "$id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    do_request "GET" "${BASE_URL}/evaluationDatasets/${id}"
}

create_dataset() {
    read -rp "Display Name: " displayName
    local body
    body=$(printf '{"displayName":"%s"}' "$(json_escape "$displayName")")
    do_request "POST" "${BASE_URL}/evaluationDatasets" "$body"
}

patch_dataset() {
    read -rp "Dataset ID: " id
    [[ -z "$id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    read -rp "Field to update (e.g. displayName): " field
    if [[ ! "$field" =~ ^[a-zA-Z][a-zA-Z0-9.]*$ ]]; then
        echo "ERROR: Field name must be alphanumeric (e.g. displayName, nested.field)." >&2
        return
    fi
    read -rp "New value: " value
    local body
    body=$(printf '{"%s":"%s"}' "$(json_escape "$field")" "$(json_escape "$value")")
    do_request "PATCH" "${BASE_URL}/evaluationDatasets/${id}?updateMask=${field}" "$body"
}

delete_dataset() {
    read -rp "Dataset ID: " id
    [[ -z "$id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    do_request "DELETE" "${BASE_URL}/evaluationDatasets/${id}"
}

# ── Evaluation Expectations (24–28) ──────────────────────────────────────────
list_expectations() {
    do_request "GET" "${BASE_URL}/evaluationExpectations"
}

get_expectation() {
    read -rp "Expectation ID: " id
    [[ -z "$id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    do_request "GET" "${BASE_URL}/evaluationExpectations/${id}"
}

create_expectation() {
    read -rp "Display Name: " displayName
    read -rp "LLM Criteria Instruction: " instruction
    local body
    body=$(printf '{"displayName":"%s","llmCriteria":{"instruction":"%s"}}' \
        "$(json_escape "$displayName")" "$(json_escape "$instruction")")
    do_request "POST" "${BASE_URL}/evaluationExpectations" "$body"
}

patch_expectation() {
    read -rp "Expectation ID: " id
    [[ -z "$id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    read -rp "Field to update (e.g. displayName): " field
    if [[ ! "$field" =~ ^[a-zA-Z][a-zA-Z0-9.]*$ ]]; then
        echo "ERROR: Field name must be alphanumeric (e.g. displayName, nested.field)." >&2
        return
    fi
    read -rp "New value: " value
    local body
    body=$(printf '{"%s":"%s"}' "$(json_escape "$field")" "$(json_escape "$value")")
    do_request "PATCH" "${BASE_URL}/evaluationExpectations/${id}?updateMask=${field}" "$body"
}

delete_expectation() {
    read -rp "Expectation ID: " id
    [[ -z "$id" ]] && { echo "ERROR: ID cannot be empty." >&2; return; }
    do_request "DELETE" "${BASE_URL}/evaluationExpectations/${id}"
}

# ── CSV Export (29–31) ────────────────────────────────────────────────────────
save_runs_csv() {
    local output_dir="${1:-.}"
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local output_file="${output_dir}/evaluation_runs_${ts}.csv"
    local tmp_json
    tmp_json=$(mktemp)

    echo "Fetching evaluation runs..."
    do_request "GET" "${BASE_URL}/evaluationRuns"
    echo "${LAST_RESPONSE}" > "$tmp_json"

    python3 - "$tmp_json" "$output_file" <<'PYEOF'
import json, csv, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

runs = data.get('evaluationRuns', [])
output_file = sys.argv[2]

headers = [
    'name', 'state', 'evaluationType', 'createTime', 'updateTime', 'endTime',
    'progress.completedCount', 'progress.totalCount',
    'summary.passCount', 'summary.failCount', 'summary.totalCount', 'summary.overallScore',
]

with open(output_file, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(headers)
    for run in runs:
        progress = run.get('progress', {})
        summary  = run.get('summary', {})
        writer.writerow([
            run.get('name', ''),
            run.get('state', ''),
            run.get('evaluationType', ''),
            run.get('createTime', ''),
            run.get('updateTime', ''),
            run.get('endTime', ''),
            progress.get('completedCount', ''),
            progress.get('totalCount', ''),
            summary.get('passCount', ''),
            summary.get('failCount', ''),
            summary.get('totalCount', ''),
            summary.get('overallScore', ''),
        ])

print(f"Saved {len(runs)} row(s) to {output_file}")
PYEOF

    rm -f "$tmp_json"
}

save_results_csv() {
    local output_dir="${1:-.}"
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local output_file="${output_dir}/evaluation_results_${ts}.csv"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local tmp_evals="${tmp_dir}/evals.json"

    echo "Fetching evaluations list..."
    do_request "GET" "${BASE_URL}/evaluations"
    echo "${LAST_RESPONSE}" > "$tmp_evals"

    # Extract evaluation IDs
    local eval_ids
    eval_ids=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
for ev in data.get('evaluations', []):
    name = ev.get('name', '')
    if name:
        print(name.split('/')[-1])
" "$tmp_evals")

    if [[ -z "$eval_ids" ]]; then
        echo "No evaluations found — nothing to export."
        rm -rf "$tmp_dir"
        return
    fi

    local result_file_num=0
    while IFS= read -r eval_id; do
        [[ -z "$eval_id" ]] && continue
        echo "  Fetching results for evaluation: $eval_id"
        do_request "GET" "${BASE_URL}/evaluations/${eval_id}/results"
        echo "${LAST_RESPONSE}" > "${tmp_dir}/results_${result_file_num}.json"
        result_file_num=$(( result_file_num + 1 ))
    done <<< "$eval_ids"

    python3 - "$tmp_dir" "$output_file" <<'PYEOF'
import json, csv, sys, os, glob

headers = [
    'name', 'executionState', 'outcome', 'evaluationRunName', 'createTime', 'updateTime',
    'scenarioResult.taskCompletionResult.outcome',
    'scenarioResult.userGoalSatisfactionResult.outcome',
    'hallucinationResult.outcome',
    'overallToolInvocationResult.outcome',
    'semanticSimilarityResult.score',
    'goldenExpectationOutcome.toolInvocationResult.outcome',
]

tmp_dir      = sys.argv[1]
output_file  = sys.argv[2]
all_results  = []

for results_file in sorted(glob.glob(os.path.join(tmp_dir, 'results_*.json'))):
    try:
        with open(results_file) as f:
            data = json.load(f)
        all_results.extend(data.get('evaluationResults', []))
    except (json.JSONDecodeError, KeyError):
        pass

with open(output_file, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(headers)
    for r in all_results:
        sr = r.get('scenarioResult', {})
        writer.writerow([
            r.get('name', ''),
            r.get('executionState', ''),
            r.get('outcome', ''),
            r.get('evaluationRunName', ''),
            r.get('createTime', ''),
            r.get('updateTime', ''),
            sr.get('taskCompletionResult', {}).get('outcome', ''),
            sr.get('userGoalSatisfactionResult', {}).get('outcome', ''),
            r.get('hallucinationResult', {}).get('outcome', ''),
            r.get('overallToolInvocationResult', {}).get('outcome', ''),
            r.get('semanticSimilarityResult', {}).get('score', ''),
            r.get('goldenExpectationOutcome', {}).get('toolInvocationResult', {}).get('outcome', ''),
        ])

print(f"Saved {len(all_results)} row(s) to {output_file}")
PYEOF

    rm -rf "$tmp_dir"
}

save_all_csv() {
    local output_dir="${1:-.}"
    save_runs_csv "$output_dir"
    save_results_csv "$output_dir"
}

# ── Menu ──────────────────────────────────────────────────────────────────────
show_menu() {
    echo ""
    echo "=== CX Agent Studio Evaluations CLI ==="
    echo "Project: ${PROJECT_ID} | Location: ${LOCATION} | App: ${APP_ID}"
    echo ""
    echo "--- Scheduled Evaluation Runs ---"
    echo "  1. List scheduled evaluation runs"
    echo "  2. Get scheduled evaluation run"
    echo "  3. Create scheduled evaluation run"
    echo "  4. Patch scheduled evaluation run"
    echo "  5. Delete scheduled evaluation run"
    echo ""
    echo "--- Evaluations ---"
    echo "  6. List evaluations"
    echo "  7. Get evaluation"
    echo "  8. Create evaluation"
    echo "  9. Patch evaluation"
    echo " 10. Delete evaluation"
    echo " 11. Export evaluations"
    echo " 12. Upload evaluation audio"
    echo ""
    echo "--- Evaluation Results ---"
    echo " 13. List evaluation results"
    echo " 14. Get evaluation result"
    echo " 15. Delete evaluation result"
    echo ""
    echo "--- Evaluation Runs ---"
    echo " 16. List evaluation runs"
    echo " 17. Get evaluation run"
    echo " 18. Delete evaluation run"
    echo ""
    echo "--- Evaluation Datasets ---"
    echo " 19. List evaluation datasets"
    echo " 20. Get evaluation dataset"
    echo " 21. Create evaluation dataset"
    echo " 22. Patch evaluation dataset"
    echo " 23. Delete evaluation dataset"
    echo ""
    echo "--- Evaluation Expectations ---"
    echo " 24. List evaluation expectations"
    echo " 25. Get evaluation expectation"
    echo " 26. Create evaluation expectation"
    echo " 27. Patch evaluation expectation"
    echo " 28. Delete evaluation expectation"
    echo ""
    echo "--- Export to CSV ---"
    echo " 29. Save evaluation runs to CSV"
    echo " 30. Save evaluation results to CSV"
    echo " 31. Save ALL to CSV (runs + results)"
    echo ""
    echo "  0. Exit"
    echo ""
}

main() {
    check_deps
    setup

    while true; do
        show_menu
        read -rp "Choice: " choice

        case "$choice" in
            1)  list_scheduled_runs ;;
            2)  get_scheduled_run ;;
            3)  create_scheduled_run ;;
            4)  patch_scheduled_run ;;
            5)  delete_scheduled_run ;;
            6)  list_evaluations ;;
            7)  get_evaluation ;;
            8)  create_evaluation ;;
            9)  patch_evaluation ;;
            10) delete_evaluation ;;
            11) export_evaluations ;;
            12) upload_evaluation_audio ;;
            13) list_eval_results ;;
            14) get_eval_result ;;
            15) delete_eval_result ;;
            16) list_eval_runs ;;
            17) get_eval_run ;;
            18) delete_eval_run ;;
            19) list_datasets ;;
            20) get_dataset ;;
            21) create_dataset ;;
            22) patch_dataset ;;
            23) delete_dataset ;;
            24) list_expectations ;;
            25) get_expectation ;;
            26) create_expectation ;;
            27) patch_expectation ;;
            28) delete_expectation ;;
            29) read -rp "Output directory [.]: " out_dir; save_runs_csv "${out_dir:-.}" ;;
            30) read -rp "Output directory [.]: " out_dir; save_results_csv "${out_dir:-.}" ;;
            31) read -rp "Output directory [.]: " out_dir; save_all_csv "${out_dir:-.}" ;;
            0)  echo "Goodbye."; exit 0 ;;
            *)  echo "Invalid option '${choice}', try again." ;;
        esac

        echo ""
        read -rp "Press Enter to return to menu..." _
    done
}

main
