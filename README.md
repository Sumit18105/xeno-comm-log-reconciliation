# Xeno Comm-Log Send Reconciliation

Reconciliation of Finance's reported `target_base = 22` for merchant `501`, October 2026, using the supplied SQLite communication data.

## Table of Contents

- [Project Overview](#project-overview)
- [Objective](#objective)
- [Business Rules](#business-rules)
- [Investigation and Reconciliation](#investigation-and-reconciliation)
- [Final Result](#final-result)
- [Repository Structure](#repository-structure)
- [How to Use](#how-to-use)
- [Python Query Executor](#python-query-executor)
- [What the Latest Update Added](#what-the-latest-update-added)
- [Latest Update](#latest-update)

## Project Overview

This project investigates a communication-log dataset and reproduces Finance's reported `target_base` for a specific merchant, month, and communication type.

The analysis does not simply count rows. It first determines which campaigns are eligible, identifies retry relationships, groups multi-level retry chains, and then applies the correct counting rule to each campaign family.

## Objective

Reproduce Finance's reported:

```text
target_base = 22
```

Scope:

| Filter | Value |
|---|---|
| Merchant | `501` |
| Period | October 2026 |
| Communication type | `2` |

## Business Rules

- A campaign is eligible only when `creation_status` is one of `approved`, `aborted`, `resumed`, or `stopped`, and `processing_status = 'processed'`.
- `approval_awaiting` campaigns are excluded even when communication-log rows already exist.
- Retry campaigns are identified through `parent_id` and belong to the same underlying communication as their parent chain.
- Retry chains can have multiple levels, so the analysis uses a recursive CTE to map each campaign to its root.
- Within a retry family, the same customer is counted once across the chain.
- A standalone campaign has no child retries, so every send event counts separately, even when the same customer appears multiple times.

## Investigation and Reconciliation

### Step 0 — Naive count

There are **30 communication-log send-attempt rows** in the scope.

```text
30
```

### Step 1 — Remove the ineligible campaign

Campaign `9004` is `approval_awaiting`. It has 4 communication-log rows, but those rows are not eligible for official reporting.

```text
30 - 4 = 26
```

### Step 2 — Reconcile retry family `9001 → 9002 → 9003`

This family contains **13 raw attempts** but only **10 distinct customers**. Repeated attempts for C2 and C3 are retries of the same underlying communication.

```text
26 - 3 = 23
```

### Step 3 — Reconcile retry family `9201 → 9202`

This family contains **6 raw attempts** but only **5 distinct customers**. D1 failed on `9201` and was retried on `9202`.

```text
23 - 1 = 22
```

### Step 4 — Verify standalone campaign `9101`

Campaign `9101` has **7 send events**. C20 appears twice on different dates, but because `9101` is standalone, both send events remain separate and are counted.

### Reconciliation Bridge

| Step | Description | Result | Adjustment |
|---:|---|---:|---:|
| 0 | Naive count of all communication-log rows | 30 | — |
| 1 | Exclude ineligible campaign `9004` | 26 | -4 |
| 2 | Collapse retry family `9001 → 9002 → 9003` | 23 | -3 |
| 3 | Collapse retry family `9201 → 9202` | 22 | -1 |
| 4 | Keep standalone `9101` events separate | 22 | 0 |
| **Final** | **Finance target_base** | **22** | |

## Final Result

The Finance number is reproduced exactly:

```text
30 - 4 - 3 - 1 = 22
```

Therefore:

**`target_base = 22`**

## Repository Structure

```text
xeno-comm-log-reconciliation/
├── README.md
├── sql/
│   ├── 01_investigation.sql
│   ├── final_reconciliation.sql
│   ├── query_executor.py
│   ├── comm_log.db
│   └── README.md
├── outputs/
│   └── reconciliation_bridge.csv
└── .gitignore
```

### File Details

| File | Purpose |
|---|---|
| `README.md` | Main project documentation, business rules, reconciliation and usage |
| `sql/01_investigation.sql` | Exploratory SQL used to inspect counts, eligibility, retries and campaign hierarchy |
| `sql/final_reconciliation.sql` | Final SQLite query that reproduces Finance's `target_base` |
| `sql/query_executor.py` | Python wrapper that executes the investigation SQL and final reconciliation query |
| `sql/comm_log.db` | SQLite database used for the analysis and local execution |
| `sql/README.md` | Detailed guide for the SQL folder and execution workflow |
| `outputs/reconciliation_bridge.csv` | Reconciliation bridge from 30 to 22 |

## How to Use

There are two supported ways to reproduce the analysis.

### Option 1 — Run SQL manually

Open `sql/comm_log.db` in a SQLite-compatible application and run:

```text
sql/01_investigation.sql
sql/final_reconciliation.sql
```

Run the investigation file first to understand the data and reconciliation, then run the final query to obtain the Finance number.

Expected final result:

```text
target_base
-----------
22
```

### Option 2 — Run the Python wrapper

The Python wrapper provides a single command to execute the entire workflow.

Open a terminal in the `sql` directory:

```bash
cd sql
python query_executor.py
```

The script:

1. Reads `01_investigation.sql`.
2. Splits it into individual SQL statements.
3. Connects to `comm_log.db` using Python's built-in `sqlite3` module.
4. Executes each investigation query in sequence.
5. Prints a separate heading and the returned rows for each query.
6. Reads and executes `final_reconciliation.sql`.
7. Prints the final `target_base`.
8. Closes the database connection.

Expected ending:

```text
====================== Final Reconciliation Result ======================

Final Result:
(22,)

Target Base: 22
```

### Requirements

- Python 3.x
- No external Python packages are required for `query_executor.py`.
- SQLite support is provided by Python's built-in `sqlite3` module.

## Python Query Executor

`sql/query_executor.py` is an execution helper, not the source of the business logic.

The reconciliation rules remain in the SQL files. The Python wrapper only:

- loads the SQL;
- executes the investigation statements;
- displays intermediate results;
- executes the final reconciliation query; and
- prints the final answer.

This keeps the analytical logic in SQL while making the full workflow reproducible with one Python command.

## What the Latest Update Added

The latest functional update added the local execution layer to the repository.

### Added files

- `sql/comm_log.db` — the SQLite database used by the analysis.
- `sql/query_executor.py` — a Python wrapper for executing the SQL workflow.

### Execution improvements

- Investigation queries are executed sequentially rather than manually one at a time.
- Each investigation query has its own heading in the terminal output.
- Returned query rows are displayed after each query.
- The final reconciliation query runs automatically after the investigation.
- The final `target_base` is printed clearly at the end.

### Why this update is useful

Previously, the SQL files contained the analytical logic, but the user had to run them manually. The new wrapper makes the repository easier to reproduce: one command runs the investigation and final reconciliation against the included database.

## Latest Update

### Commit

`76513ab7a918ed9a048317c22b420b380c0a25c3`

### Message

`Added database and python wrapper to execute all queries`

### Date

September 12, 2026

### Update Summary

This commit added the SQLite database copy and Python execution wrapper described above. It also made the complete SQL investigation-to-reconciliation workflow executable directly from the repository.
