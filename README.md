# Xeno Comm-Log Send Reconciliation

Reconciliation of Finance's reported `target_base = 22` for merchant `501`, October 2026, using the supplied SQLite communication data.

## Table of Contents

- [Objective](#objective)
- [What This Project Does](#what-this-project-does)
- [Business Rules](#business-rules)
- [Investigation and Reconciliation](#investigation-and-reconciliation)
- [Final Result](#final-result)
- [How to Use](#how-to-use)
- [Python Query Executor](#python-query-executor)
- [Repository Structure](#repository-structure)
- [Latest Update](#latest-update)

## Objective

Reproduce Finance's reported `target_base = 22` for merchant `501`, October 2026, across the Diwali campaigns.

The analysis starts from the raw communication-log count and applies campaign eligibility and retry-family rules until the result reconciles to Finance's number.

## What This Project Does

This repository contains:

- SQL queries for investigating the campaign and communication data.
- A final SQLite reconciliation query that calculates `target_base`.
- A Python wrapper that executes the investigation queries sequentially and displays their results.
- The SQLite database used for the analysis.
- A reconciliation bridge showing exactly how the raw count of 30 becomes 22.

## Business Rules

- A campaign is eligible only when its creation workflow has cleared (`approved`, `aborted`, `resumed`, `stopped`) and `processing_status = 'processed'`.
- `approval_awaiting` campaigns are excluded even if communication-log rows already exist.
- A retry campaign is represented by `campaign.parent_id` and belongs to the same underlying communication as its parent chain.
- Retry chains can contain multiple levels, so the analysis uses a recursive CTE to identify the root campaign.
- Within a retry chain, the same customer counts once across all eligible attempts in that chain.
- A standalone campaign has no child retries; every send event counts separately, even when the same customer appears more than once.
- Scope: merchant `501`, October 2026, communication type `2`.

## Investigation and Reconciliation

### Step 0 — Naive count

The communication log contains **30 send-attempt rows**.

**Result: 30**

### Step 1 — Campaign eligibility

Campaign `9004` is `approval_awaiting`, although four communication-log rows already exist for it. Those four rows are excluded from official reporting.

**30 - 4 = 26**

### Step 2 — Retry family `9001 → 9002 → 9003`

The family contains **13 raw send attempts** but only **10 distinct customers**. C2 is retried once and C3 is retried twice. These retries represent the same underlying customer communication and therefore must not be counted multiple times.

**26 - 3 = 23**

### Step 3 — Retry family `9201 → 9202`

The family contains **6 raw attempts** but only **5 distinct customers**. D1 failed in `9201` and was retried in `9202`.

**23 - 1 = 22**

### Step 4 — Standalone campaign `9101`

Campaign `9101` has **7 send events**. C20 appears twice on different dates, but because this campaign is standalone, both events remain valid and are counted separately.

## Reconciliation Bridge

| Step | Description | Result | Adjustment |
|---:|---|---:|---:|
| 0 | Naive count of all communication-log rows | 30 | — |
| 1 | Exclude ineligible campaign 9004 | 26 | -4 |
| 2 | Collapse retry family 9001 → 9002 → 9003 | 23 | -3 |
| 3 | Collapse retry family 9201 → 9202 | 22 | -1 |
| 4 | Verify standalone 9101 sends are not deduplicated | 22 | 0 |
| **Final** | **Finance target_base** | **22** | |

## Final Result

**`target_base = 22`**

The reconciliation is:

```text
30 - 4 - 3 - 1 = 22
```

## How to Use

### Option 1 — Run the SQL directly

Open the repository in a SQLite-compatible environment and run:

1. `sql/01_investigation.sql` to inspect the data and understand the reconciliation.
2. `sql/final_reconciliation.sql` to calculate the final `target_base`.

The final query should return:

```text
target_base
-----------
22
```

### Option 2 — Run everything using the Python wrapper

The repository includes `sql/query_executor.py` to execute the investigation SQL and then the final reconciliation query.

From the `sql` directory:

```bash
cd sql
python query_executor.py
```

The script:

1. Reads `01_investigation.sql`.
2. Splits the file into individual SQL statements.
3. Executes each investigation query in sequence.
4. Prints a heading and the returned rows for each query.
5. Reads `final_reconciliation.sql`.
6. Executes the final reconciliation query.
7. Prints the final `target_base` result.
8. Closes the SQLite connection.

Expected final output includes:

```text
====================== Final Reconciliation Result ======================

Final Result:
(22,)

Target Base: 22
```

### Requirements

- Python 3.x
- SQLite (Python's built-in `sqlite3` module is used, so no external Python package is required).

## Python Query Executor

`sql/query_executor.py` is a lightweight execution wrapper around the SQL files. It is not part of the reconciliation logic itself; the business logic remains in the SQL files.

The wrapper is useful because it provides one command to run the investigation and final query and makes the intermediate results easy to inspect.

## Repository Structure

```text
xeno-comm-log-reconciliation/
├── README.md
├── sql/
│   ├── 01_investigation.sql
│   ├── final_reconciliation.sql
│   ├── query_executor.py
│   └── comm_log.db
└── outputs/
    └── reconciliation_bridge.csv
```

### File Details

| File | Purpose |
|---|---|
| `README.md` | Complete project explanation, reconciliation logic, and usage instructions |
| `sql/01_investigation.sql` | Exploratory SQL queries used to understand the raw data and campaign hierarchy |
| `sql/final_reconciliation.sql` | Final recursive SQL query that reproduces Finance's `target_base` |
| `sql/query_executor.py` | Executes the investigation queries and final reconciliation from Python |
| `sql/comm_log.db` | SQLite database used by the SQL/Python execution workflow |
| `outputs/reconciliation_bridge.csv` | Step-by-step numerical reconciliation from 30 to 22 |

## Latest Update

### Commit: `76513ab7a918ed9a048317c22b420b380c0a25c3`

**Message:** `Added database and python wrapper to execute all queries`

**Date:** September 12, 2026

### What was updated

This update added the execution layer needed to run the SQL investigation from the repository itself:

- Added `sql/comm_log.db`, the SQLite database used by the analysis.
- Added `sql/query_executor.py`, a Python wrapper around the SQL files.
- The wrapper reads `01_investigation.sql` and executes the investigation queries sequentially.
- Each query result is displayed with a separate heading and formatted output.
- The wrapper then executes `final_reconciliation.sql` and prints the final `target_base`.
- The repository now contains both the analytical SQL and a simple way to execute it end-to-end.

The README was also updated to document how these files work together and how to reproduce the analysis.
