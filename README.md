# Xeno Comm-Log Send Reconciliation

A SQL-based reconciliation of Finance's reported `target_base = 22` for merchant `501`, October 2026, communication type `2`.

## Table of Contents

- [Project Overview](#project-overview)
- [Objective](#objective)
- [Data and Business Rules](#data-and-business-rules)
- [Approach](#approach)
- [Reconciliation Bridge](#reconciliation-bridge)
- [Final SQL](#final-sql)
- [How to Run](#how-to-run)
- [Python Query Executor](#python-query-executor)
- [Repository Structure](#repository-structure)
- [Latest Update](#latest-update)

## Project Overview

The task is to reproduce Finance's reported `target_base` from the supplied campaign and communication-log data.

A simple row count gives `30`, but the reporting rules require two important adjustments:

1. Exclude communication rows belonging to campaigns that are not eligible for reporting.
2. Treat retries as part of the same underlying communication and count the same customer once within a retry family.

Standalone campaigns are different: each send event is counted separately.

The analysis therefore combines campaign eligibility, recursive retry-family mapping, customer-level deduplication for retry families, and event-level counting for standalone campaigns.

## Objective

Reproduce:

```text
target_base = 22
```

Scope:

| Filter | Value |
|---|---|
| Merchant | `501` |
| Period | October 2026 |
| Communication type | `2` |

## Data and Business Rules

### Campaign eligibility

A campaign is eligible only when:

- `creation_status` is one of `approved`, `aborted`, `resumed`, `stopped`; and
- `processing_status = 'processed'`.

`approval_awaiting` is not eligible, even if communication-log rows already exist.

### Retry campaigns

A retry is identified through `parent_id`. Retry chains may have more than one level, so the analysis maps each campaign to its root campaign using a recursive CTE.

Within a retry family, a customer is counted once across all eligible attempts in that family.

### Standalone campaigns

A root campaign with no child retries is standalone. For a standalone campaign, every send event counts separately, even when the same customer appears more than once.

## Approach

### Step 0 — Naive count

All communication-log rows in scope:

```text
30
```

### Step 1 — Exclude ineligible campaign `9004`

Campaign `9004` is `approval_awaiting` and contributes 4 communication rows. These rows are excluded.

```text
30 - 4 = 26
```

### Step 2 — Retry family `9001 → 9002 → 9003`

This family has 13 raw attempts representing 10 distinct customers. Repeated attempts for C2 and C3 are retries of the same underlying communication.

```text
26 - 3 = 23
```

### Step 3 — Retry family `9201 → 9202`

This family has 6 raw attempts representing 5 distinct customers. D1 failed in `9201` and was retried in `9202`.

```text
23 - 1 = 22
```

### Step 4 — Standalone campaign `9101`

Campaign `9101` has 7 send events. C20 appears twice on different dates, but both events remain counted because `9101` is standalone.

## Reconciliation Bridge

| Step | Description | Result | Adjustment |
|---:|---|---:|---:|
| 0 | Naive count of all communication-log rows | 30 | — |
| 1 | Exclude ineligible campaign `9004` | 26 | -4 |
| 2 | Collapse retry family `9001 → 9002 → 9003` | 23 | -3 |
| 3 | Collapse retry family `9201 → 9202` | 22 | -1 |
| 4 | Keep standalone `9101` events separate | 22 | 0 |
| **Final** | **Finance target_base** | **22** | |

Final reconciliation:

```text
30 - 4 - 3 - 1 = 22
```

## Final SQL

The final logic is implemented in [`sql/final_reconciliation.sql`](sql/final_reconciliation.sql).

It:

- filters to merchant `501`, October 2026, communication type `2`;
- applies campaign eligibility rules;
- recursively maps retry campaigns to their root campaign;
- identifies retry families versus standalone campaigns;
- counts distinct customers within retry families; and
- counts every send event in standalone campaigns.

Expected result:

```text
target_base
-----------
22
```

## How to Run

### Option 1 — Run the Python wrapper

The simplest reproducible workflow is to run the Python wrapper from the `sql` directory:

```bash
cd sql
python query_executor.py
```

The wrapper reads the investigation SQL, executes each statement, prints its results with a separate heading, and then runs the final reconciliation query.

Expected ending:

```text
====================== Final Reconciliation Result ======================

Final Result:
(22,)

Target Base: 22
```

### Option 2 — Run the SQL manually

Open `sql/comm_log.db` in a SQLite-compatible environment and run:

```text
sql/01_investigation.sql
sql/final_reconciliation.sql
```

Run the investigation file first to inspect the reasoning, then run the final query to obtain `target_base`.

### Requirements

- Python 3.x for `query_executor.py`.
- No external Python packages are required; the wrapper uses the built-in `sqlite3` module.
- A SQLite-compatible tool can be used for manual SQL execution.

## Python Query Executor

`sql/query_executor.py` is an execution helper, not the business-logic layer.

It:

1. Reads `01_investigation.sql`.
2. Splits it into individual SQL statements.
3. Connects to `comm_log.db` using Python's built-in `sqlite3` module.
4. Executes the investigation statements sequentially.
5. Prints a heading and the returned rows for each query.
6. Reads and executes `final_reconciliation.sql`.
7. Prints the final `target_base`.
8. Closes the database connection.

## Repository Structure

```text
xeno-comm-log-reconciliation/
├── README.md
├── sql/
│   ├── README.md
│   ├── 01_investigation.sql
│   ├── final_reconciliation.sql
│   ├── query_executor.py
│   └── comm_log.db
├── outputs/
│   └── reconciliation_bridge.csv
└── .gitignore
```

| File | Purpose |
|---|---|
| `README.md` | Overall project documentation, reasoning, result, and usage |
| `sql/README.md` | Documentation specific to the SQL folder and its execution workflow |
| `sql/01_investigation.sql` | Exploratory SQL used to inspect counts, eligibility, retries, and campaign hierarchy |
| `sql/final_reconciliation.sql` | Final recursive SQL reconciliation query |
| `sql/query_executor.py` | Python wrapper for running the investigation and final SQL |
| `sql/comm_log.db` | SQLite database used by the execution workflow |
| `outputs/reconciliation_bridge.csv` | Reconciliation bridge from 30 to 22 |

## Latest Update

### Commit

The latest functional update added the local execution layer to the repository.

**Commit:** `76513ab7a918ed9a048317c22b420b380c0a25c3`

**Message:** `Added database and python wrapper to execute all queries`

**Date:** September 12, 2026

### What changed

- Added `sql/comm_log.db` so the repository contains the SQLite database used by the analysis.
- Added `sql/query_executor.py` to run the investigation SQL and final reconciliation from Python.
- Added formatted headings and query-result output for the investigation steps.
- Added automatic execution of `final_reconciliation.sql` after the investigation.
- Added a clear final `Target Base: 22` output.

### How to use the update

```bash
cd sql
python query_executor.py
```

This runs the repository's investigation-to-reconciliation workflow end to end.