# CX Agent Studio Evaluations CLI

Interactive Bash CLI for the CX Agent Studio Evaluations REST API (`ces.googleapis.com/v1beta`).

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| `gcloud` | Auth token | [cloud.google.com/sdk](https://cloud.google.com/sdk/docs/install) |
| `curl` | HTTP requests | `apt install curl` / `brew install curl` / `winget install curl.curl` |
| `python3` | CSV export (options 29–31) | Usually pre-installed |

You must be authenticated: `gcloud auth login`

## Usage

```bash
chmod +x cx_eval.sh
./cx_eval.sh
```

Enter **Project ID**, **Location** (default: `us`), and **App ID** at startup. All 31 menu options are then available.

## Menu Options

| Range | Resource |
|-------|----------|
| 1–5 | Scheduled Evaluation Runs |
| 6–12 | Evaluations |
| 13–15 | Evaluation Results |
| 16–18 | Evaluation Runs |
| 19–23 | Evaluation Datasets |
| 24–28 | Evaluation Expectations |
| 29–31 | CSV Export |

## CSV Export

Options 29–31 write timestamped CSV files to a directory you specify:

| File | Contents |
|------|----------|
| `evaluation_runs_<ts>.csv` | Run summaries: state, type, pass/fail counts, overall score |
| `evaluation_results_<ts>.csv` | Per-result detail: outcomes, scores, latency fields |
