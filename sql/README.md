# SQL Investigation & Execution Guide

This folder contains the SQL analysis, final reconciliation query, SQLite database, and Python wrapper used to reproduce Finance's reported `target_base = 22`.

## Table of Contents

- [Folder Overview](#folder-overview)
- [How the SQL Workflow Works](#how-the-sql-workflow-works)
- [01 Investigation SQL](#01-investigation-sql)
- [Final Reconciliation SQL](#final-reconciliation-sql)
- [Python Query Executor](#python-query-executor)
- [How to Run](#how-to-run)
- [Expected Result](#expected-result)
- [Latest Update](#latest-update)

## Folder Overview

| File | Purpose |
|---|---|
| `01_investigation.sql` | Exploratory queries used to understand the raw communication data, campaign eligibility, retries, and campaign hierarchy |
| `final_reconciliation.sql` | Final SQLite query that applies all reporting rules and returns `target_base` |
| `query_executor.py` | Python wrapper that executes all investigation queries and the final reconciliation query |
| `comm_log.db` | SQLite database used by the analysis |

## How the SQL Workflow Works

The analysis follows this sequence:

```text
Raw communication-log rows
          ↓
Check campaign eligibility
          ↓
Identify root/retry campaign families
          ↓
Collapse duplicate customers within retry families
          ↓
Keep standalone send events separate
          ↓
Calculate Finance target_base
```

The final reconciliation is:

```text
30  naive send-attempt rows
-4  ineligible campaign 9004
-3  duplicate attempts in retry family 9001 → 9002 → 9003
-1  duplicate attempt in retry family 9201 → 9202
---
22  final target_base
```

## 01 Investigation SQL

`01_investigation.sql` contains the exploratory queries used before writing the final reconciliation logic.

The queries cover:

1. Establishing the naive communication-log row count.
2. Inspecting send volume by campaign.
3. Inspecting campaign eligibility statuses.
4. Identifying root campaigns and retry campaigns.
5. Inspecting the ineligible `9004` branch.
6. Inspecting retry family `9001 → 9002 → 9003`.
7. Inspecting retry family `9201 → 9202`.
8. Verifying repeated sends in standalone campaign `9101`.
9. Building a recursive campaign-family mapping.

These queries make the reasoning auditable rather than hiding the reconciliation inside one query.

## Final Reconciliation SQL

`final_reconciliation.sql` contains the final query used to reproduce Finance's number.

It:

- restricts the analysis to merchant `501`;
- restricts the period to October 2026;
- restricts communication type to `2`;
- filters campaigns using the eligible creation and processing statuses;
- uses a recursive CTE to map every retry campaign to its root campaign;
- treats a root with child campaigns as a retry family;
- counts distinct customers within retry families;
- counts every send event for standalone campaigns.

The query handles multi-level retry chains such as:

```text
9001
  └── 9002
        └── 9003
```

and:

```text
9201
  └── 9202
```

## Python Query Executor

`query_executor.py` is a lightweight Python wrapper for running the SQL workflow.

It does not contain the business reconciliation rules. Those rules remain in the SQL files. The Python script simply provides an easy way to execute and inspect the SQL.

### What the script does

1. Opens `01_investigation.sql`.
2. Splits the SQL file into individual statements.
3. Connects to `comm_log.db` using Python's built-in `sqlite3` module.
4. Executes each investigation query sequentially.
5. Prints a heading for every query and displays its returned rows.
6. Opens `final_reconciliation.sql`.
7. Executes the final query.
8. Prints the final `target_base`.
9. Closes the database connection.

## How to Run

Open a terminal in this `sql` directory:

```bash
cd sql
```

Then run:

```bash
python query_executor.py
```

No external Python package is required because `sqlite3` is included with Python.

### Run the SQL manually

If you prefer to execute SQL directly, open `comm_log.db` in a SQLite-compatible tool and run `01_investigation.sql` first, followed by `final_reconciliation.sql`.

The investigation queries show how the number is reconciled, while the final query returns the final answer.

## Expected Result

The final query should return:

```text
target_base
-----------
22
```

The Python wrapper should end with output similar to:

```text
====================== Final Reconciliation Result ======================

Final Result:
(22,)

Target Base: 22
```

## Latest Update

### Commit: `76513ab7a918ed9a048317c22b420b380c0a25c3`

**Message:** `Added database and python wrapper to execute all queries`

**Date:** September 12, 2026

### What was updated

This update added the files required to execute the SQL workflow directly from the repository:

- Added `comm_log.db` as the SQLite database for the analysis.
- Added `query_executor.py` as the Python execution wrapper.
- The wrapper executes the investigation queries from `01_investigation.sql` one by one.
- Query results are displayed with separate headings so each investigation step can be identified.
- The wrapper executes `final_reconciliation.sql` after the investigation queries.
- The final result is displayed as `Target Base: 22`.

### How to use the update

From the `sql` directory:

```bash
python query_executor.py
```

This runs the complete investigation-to-reconciliation workflow without requiring every SQL statement to be executed manually.
