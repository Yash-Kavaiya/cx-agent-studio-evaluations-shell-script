# CX Agent Studio Evaluations CLI — Design Spec
**Date:** 2026-04-10
**Status:** Approved

---

## Context

The CX Agent Studio Evaluations API (`ces.googleapis.com/v1beta`) exposes 6 REST resource types with 28+ operations for managing evaluation datasets, expectations, evaluations, evaluation runs, results, and scheduled evaluation runs. Developers and QA engineers working with Conversational AI apps need a convenient way to call these endpoints interactively without writing `curl` commands by hand. This script also provides CSV export so that evaluation results can be analyzed in spreadsheet tools.

---

## Goals

- Single interactive Bash CLI (`cx_eval.sh`) covering all 28 API operations
- Minimal dependencies: `gcloud` (auth) + `curl` (HTTP) + `python3` (CSV export only)
- Flat numbered menu — no sub-menus
- Three base parameters collected once at startup: `PROJECT_ID`, `LOCATION`, `APP_ID`
- CSV export for evaluation run summaries and detailed evaluation results

---

## Architecture

### Single file: `cx_eval.sh`

No library files. All logic in one script organized into sections:
1. **Dependency check** — verify `gcloud`, `curl`, `python3` are on PATH
2. **Startup prompts** — collect `PROJECT_ID`, `LOCATION` (default: `us`), `APP_ID`
3. **Token fetch** — `TOKEN=$(gcloud auth print-access-token)`
4. **Base URL** — `BASE_URL="https://ces.googleapis.com/v1beta/projects/$PROJECT_ID/locations/$LOCATION/apps/$APP_ID"`
5. **Helper functions** — `do_get`, `do_post`, `do_patch`, `do_delete` wrappers around `curl`
6. **Operation handler functions** — one function per operation (28 total)
7. **CSV export functions** — `save_runs_csv`, `save_results_csv`
8. **Menu loop** — display menu, read choice, dispatch, repeat

### Token refresh
Token is fetched once at startup. If any `curl` call returns HTTP 401, the script automatically re-fetches the token and retries once before reporting failure.

---

## Menu Layout

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

## Per-Operation Input Requirements

| Operation type | Extra prompts |
|---|---|
| **List** (all except results) | None — fires immediately |
| **List evaluation results (#13)** | `evaluationId` |
| **Get** (all except results) | Resource ID (last path segment) |
| **Get evaluation result (#14)** | `evaluationId`, `resultId` |
| **Delete** (all except results) | Resource ID |
| **Delete evaluation result (#15)** | `evaluationId`, `resultId` |
| **Create (dataset)** | `displayName` |
| **Create (expectation)** | `displayName`, `llmCriteria.instruction` |
| **Create (evaluation)** | `displayName`, `evaluationType` (GOLDEN / SCENARIO) |
| **Create (scheduledEvaluationRun)** | `displayName`, `cronSchedule`, `evaluationId` |
| **Patch** | Resource ID, field name, new value |
| **Export evaluations** | Output format (`JSON` / `CSV`) |
| **Upload audio** | Resource ID, local audio file path |
| **CSV export** | Output directory (default: current dir) |

---

## API Endpoints

Base URL: `https://ces.googleapis.com/v1beta/projects/{PROJECT_ID}/locations/{LOCATION}/apps/{APP_ID}`

| # | Method | Endpoint |
|---|---|---|
| 1 | GET | `.../scheduledEvaluationRuns` |
| 2 | GET | `.../scheduledEvaluationRuns/{id}` |
| 3 | POST | `.../scheduledEvaluationRuns` |
| 4 | PATCH | `.../scheduledEvaluationRuns/{id}` |
| 5 | DELETE | `.../scheduledEvaluationRuns/{id}` |
| 6 | GET | `.../evaluations` |
| 7 | GET | `.../evaluations/{id}` |
| 8 | POST | `.../evaluations` |
| 9 | PATCH | `.../evaluations/{id}` |
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
| 22 | PATCH | `.../evaluationDatasets/{id}` |
| 23 | DELETE | `.../evaluationDatasets/{id}` |
| 24 | GET | `.../evaluationExpectations` |
| 25 | GET | `.../evaluationExpectations/{id}` |
| 26 | POST | `.../evaluationExpectations` |
| 27 | PATCH | `.../evaluationExpectations/{id}` |
| 28 | DELETE | `.../evaluationExpectations/{id}` |

---

## CSV Export

### CSV 1 — Evaluation Runs Summary
**Filename:** `evaluation_runs_<YYYYMMDD_HHMMSS>.csv`
**Source:** List all evaluationRuns, flatten each run into one row.

**Columns:**
`name`, `state`, `evaluationType`, `createTime`, `updateTime`, `endTime`,
`progress.completedCount`, `progress.totalCount`,
`summary.passCount`, `summary.failCount`, `summary.totalCount`, `summary.overallScore`

### CSV 2 — Evaluation Results Detail
**Filename:** `evaluation_results_<YYYYMMDD_HHMMSS>.csv`
**Source:** For each evaluation, list its results and flatten each result into one row.

**Columns:**
`name`, `executionState`, `outcome`, `evaluationRunName`, `createTime`, `updateTime`,
`scenarioResult.taskCompletionResult.outcome`,
`scenarioResult.userGoalSatisfactionResult.outcome`,
`hallucinationResult.outcome`,
`overallToolInvocationResult.outcome`,
`semanticSimilarityResult.score`,
`goldenExpectationOutcome.toolInvocationResult.outcome`

**Implementation:** `python3 -c` inline script reads the JSON response string passed via shell variable and writes the CSV using Python's `csv` module.

---

## Error Handling

- Missing dependency at startup → print install instruction and exit
- HTTP 4xx (not 401) → print status code + raw response body
- HTTP 401 → refresh token and retry once; if still 401, print auth error
- HTTP 5xx → print status code + raw response body
- Empty list responses → print "No items found."
- Invalid menu choice → print "Invalid option, try again." and redisplay menu

---

## File Output

| File | Purpose |
|---|---|
| `cx_eval.sh` | Main interactive CLI script |
| `evaluation_runs_<ts>.csv` | Evaluation run summaries (generated on demand) |
| `evaluation_results_<ts>.csv` | Detailed evaluation results (generated on demand) |

---

## Verification

1. Run `bash cx_eval.sh` — confirm dependency checks pass
2. Enter a valid project/location/app — confirm token fetch and base URL construction
3. Pick option 1 (List scheduled evaluation runs) — verify `curl` request fires and raw JSON is printed
4. Pick option 21 (Create evaluation dataset) — enter a display name, verify POST body and 200 response
5. Pick option 22 (Patch evaluation dataset) — enter dataset ID + field + value, verify PATCH body
6. Pick option 23 (Delete evaluation dataset) — confirm DELETE fires against correct URL
7. Pick option 29 (Save evaluation runs to CSV) — verify CSV file created with correct headers and data
8. Pick option 31 (Save ALL) — verify both CSV files created
9. Simulate 401 — verify token refresh and retry
10. Pick option 0 — verify clean exit
