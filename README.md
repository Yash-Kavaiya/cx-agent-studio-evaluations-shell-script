# CX Agent Studio Evaluations CLI

Interactive Bash CLI for the **CX Agent Studio Evaluations REST API** (`ces.googleapis.com/v1beta`).

Covers all 28 REST operations across 6 resource types plus 3 CSV export options — 31 menu items total.

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| `gcloud` | Auth token via `gcloud auth print-access-token` | [cloud.google.com/sdk](https://cloud.google.com/sdk/docs/install) |
| `curl` | HTTP requests | `apt install curl` / `brew install curl` / `winget install curl.curl` |
| `python3` | CSV export (options 29–31 only) | Usually pre-installed on macOS/Linux/WSL |

Authenticate before running:

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

---

## Quick Start

```bash
chmod +x cx_eval.sh
./cx_eval.sh
```

At startup you will be prompted for three values:

| Prompt | Example | Notes |
|--------|---------|-------|
| Project ID | `genaiguruyoutube` | GCP project ID |
| Location | `us` | Press Enter to accept default (`us`) |
| App ID | `9551a041-e6de-4dfa-9296-7fb4737cb527` | CX Agent Studio app UUID |

These are used to build the base URL:
```
https://ces.googleapis.com/v1beta/projects/{PROJECT_ID}/locations/{LOCATION}/apps/{APP_ID}
```

---

## Full Menu Reference

```
=== CX Agent Studio Evaluations CLI ===
Project: <PROJECT_ID> | Location: <LOCATION> | App: <APP_ID>

--- Scheduled Evaluation Runs ---
  1. List scheduled evaluation runs
  2. Get scheduled evaluation run
  3. Create scheduled evaluation run
  4. Patch scheduled evaluation run
  5. Delete scheduled evaluation run

--- Evaluations ---
  6. List evaluations
  7. Get evaluation
  8. Create evaluation
  9. Patch evaluation
 10. Delete evaluation
 11. Export evaluations
 12. Upload evaluation audio

--- Evaluation Results ---
 13. List evaluation results
 14. Get evaluation result
 15. Delete evaluation result

--- Evaluation Runs ---
 16. List evaluation runs
 17. Get evaluation run
 18. Delete evaluation run

--- Evaluation Datasets ---
 19. List evaluation datasets
 20. Get evaluation dataset
 21. Create evaluation dataset
 22. Patch evaluation dataset
 23. Delete evaluation dataset

--- Evaluation Expectations ---
 24. List evaluation expectations
 25. Get evaluation expectation
 26. Create evaluation expectation
 27. Patch evaluation expectation
 28. Delete evaluation expectation

--- Export to CSV ---
 29. Save evaluation runs to CSV
 30. Save evaluation results to CSV
 31. Save ALL to CSV (runs + results)

  0. Exit
```

---

## Per-Operation Input Guide

| Option | Operation | Extra prompts required |
|--------|-----------|----------------------|
| 1 | List scheduled runs | *(none)* |
| 2 | Get scheduled run | Scheduled Run ID |
| 3 | Create scheduled run | Display Name, Cron Schedule (e.g. `0 9 * * 1`), Evaluation ID |
| 4 | Patch scheduled run | Scheduled Run ID, Field name, New value |
| 5 | Delete scheduled run | Scheduled Run ID |
| 6 | List evaluations | *(none)* |
| 7 | Get evaluation | Evaluation ID |
| 8 | Create evaluation | Display Name, Type (`1`=GOLDEN / `2`=SCENARIO) |
| 9 | Patch evaluation | Evaluation ID, Field name, New value |
| 10 | Delete evaluation | Evaluation ID |
| 11 | Export evaluations | Format (`1`=JSON / `2`=CSV) |
| 12 | Upload evaluation audio | Evaluation ID, Local audio file path |
| 13 | List evaluation results | Evaluation ID |
| 14 | Get evaluation result | Evaluation ID, Result ID |
| 15 | Delete evaluation result | Evaluation ID, Result ID |
| 16 | List evaluation runs | *(none)* |
| 17 | Get evaluation run | Evaluation Run ID |
| 18 | Delete evaluation run | Evaluation Run ID |
| 19 | List evaluation datasets | *(none)* |
| 20 | Get evaluation dataset | Dataset ID |
| 21 | Create evaluation dataset | Display Name |
| 22 | Patch evaluation dataset | Dataset ID, Field name, New value |
| 23 | Delete evaluation dataset | Dataset ID |
| 24 | List evaluation expectations | *(none)* |
| 25 | Get evaluation expectation | Expectation ID |
| 26 | Create evaluation expectation | Display Name, LLM Criteria Instruction |
| 27 | Patch evaluation expectation | Expectation ID, Field name, New value |
| 28 | Delete evaluation expectation | Expectation ID |
| 29 | Save runs to CSV | Output directory (default: `.`) |
| 30 | Save results to CSV | Output directory (default: `.`) |
| 31 | Save ALL to CSV | Output directory (default: `.`) |

> **Patch operations** accept a single field name (e.g. `displayName`) and a new value. The field name must be alphanumeric (dots allowed for nested fields, e.g. `config.timeout`).

---

## CSV Export

Options 29–31 generate timestamped CSV files in the specified output directory.

### Evaluation Runs Summary (`evaluation_runs_<YYYYMMDD_HHMMSS>.csv`)

One row per evaluation run. Columns:

| Column | Source field |
|--------|-------------|
| `name` | Full resource name |
| `state` | `RUNNING` / `SUCCEEDED` / `FAILED` / `CANCELLED` |
| `evaluationType` | `GOLDEN` / `SCENARIO` |
| `createTime` | ISO 8601 timestamp |
| `updateTime` | ISO 8601 timestamp |
| `endTime` | ISO 8601 timestamp |
| `progress.completedCount` | Completed scenario/golden count |
| `progress.totalCount` | Total scenario/golden count |
| `summary.passCount` | Number of passing results |
| `summary.failCount` | Number of failing results |
| `summary.totalCount` | Total result count |
| `summary.overallScore` | Aggregate score (0.0–1.0) |

### Evaluation Results Detail (`evaluation_results_<YYYYMMDD_HHMMSS>.csv`)

One row per evaluation result (aggregated across all evaluations). Columns:

| Column | Source field |
|--------|-------------|
| `name` | Full resource name |
| `executionState` | `SUCCESS` / `FAILED` / `SKIPPED` |
| `outcome` | `PASS` / `FAIL` |
| `evaluationRunName` | Parent evaluation run resource name |
| `createTime` | ISO 8601 timestamp |
| `updateTime` | ISO 8601 timestamp |
| `scenarioResult.taskCompletionResult.outcome` | Task completion PASS/FAIL |
| `scenarioResult.userGoalSatisfactionResult.outcome` | User goal satisfaction PASS/FAIL |
| `hallucinationResult.outcome` | Hallucination check PASS/FAIL |
| `overallToolInvocationResult.outcome` | Tool invocation PASS/FAIL |
| `semanticSimilarityResult.score` | Semantic similarity score (0.0–1.0) |
| `goldenExpectationOutcome.toolInvocationResult.outcome` | Golden tool invocation PASS/FAIL |

---

## API Reference

All requests target:
```
https://ces.googleapis.com/v1beta/projects/{PROJECT_ID}/locations/{LOCATION}/apps/{APP_ID}
```

| # | Method | Endpoint |
|---|--------|----------|
| 1 | GET | `.../scheduledEvaluationRuns` |
| 2 | GET | `.../scheduledEvaluationRuns/{id}` |
| 3 | POST | `.../scheduledEvaluationRuns` |
| 4 | PATCH | `.../scheduledEvaluationRuns/{id}?updateMask={field}` |
| 5 | DELETE | `.../scheduledEvaluationRuns/{id}` |
| 6 | GET | `.../evaluations` |
| 7 | GET | `.../evaluations/{id}` |
| 8 | POST | `.../evaluations` |
| 9 | PATCH | `.../evaluations/{id}?updateMask={field}` |
| 10 | DELETE | `.../evaluations/{id}` |
| 11 | POST | `.../evaluations:export` |
| 12 | POST | `.../evaluations/{id}:uploadEvaluationAudio` |
| 13 | GET | `.../evaluations/{evalId}/results` |
| 14 | GET | `.../evaluations/{evalId}/results/{id}` |
| 15 | DELETE | `.../evaluations/{evalId}/results/{id}` |
| 16 | GET | `.../evaluationRuns` |
| 17 | GET | `.../evaluationRuns/{id}` |
| 18 | DELETE | `.../evaluationRuns/{id}` |
| 19 | GET | `.../evaluationDatasets` |
| 20 | GET | `.../evaluationDatasets/{id}` |
| 21 | POST | `.../evaluationDatasets` |
| 22 | PATCH | `.../evaluationDatasets/{id}?updateMask={field}` |
| 23 | DELETE | `.../evaluationDatasets/{id}` |
| 24 | GET | `.../evaluationExpectations` |
| 25 | GET | `.../evaluationExpectations/{id}` |
| 26 | POST | `.../evaluationExpectations` |
| 27 | PATCH | `.../evaluationExpectations/{id}?updateMask={field}` |
| 28 | DELETE | `.../evaluationExpectations/{id}` |

---

## Troubleshooting

**`ERROR: Failed to fetch access token`**
```bash
gcloud auth login
gcloud auth application-default login
```

**`ERROR: 'gcloud' is required but not installed`**
Install the Google Cloud SDK: https://cloud.google.com/sdk/docs/install

**HTTP 403 Forbidden**
Your account may lack IAM permissions on the project. Required role: `roles/dialogflow.admin` or equivalent CX Agent Studio role.

**HTTP 404 Not Found**
Check that your Project ID, Location, and App ID are correct. Use option `6` (List evaluations) to verify connectivity.

**CSV export produces empty file**
No data returned from the API. Verify evaluation runs exist with option `16` (List evaluation runs) first.

**`python3: command not found`**
CSV export (options 29–31) requires Python 3. Install it or use `python` if your system aliases it:
```bash
# On some systems:
alias python3=python
```

---

## Project Structure

```
cx-agent-studio-evaluations-shell-script/
├── cx_eval.sh                          # Main interactive CLI script
├── README.md                           # This file
└── docs/
    └── superpowers/
        └── specs/
            └── 2026-04-10-cx-eval-cli-design.md   # Design spec
```
