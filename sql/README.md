# SQL Investigation & Execution Guide

This folder contains the SQL analysis and the small execution layer used for the Xeno communication-log reconciliation.

> The root [`README.md`](../README.md) is the main project documentation. This README is intentionally focused on the files and workflow inside `sql/`.

## Table of Contents

- [Folder Purpose](#folder-purpose)
- [Files](#files)
- [Investigation SQL](#investigation-sql)
- [Final Reconciliation SQL](#final-reconciliation-sql)
- [Python Query Executor](#python-query-executor)
- [How to Run](#how-to-run)
- [Expected Result](#expected-result)
- [Latest Update](#latest-update)

## Folder Purpose

The `sql/` folder contains everything needed to inspect the supplied SQLite data and reproduce Finance's `target_base = 22`:

- exploratory SQL;
- the final reconciliation SQL;
- the SQLite database; and
- a Python wrapper that executes the SQL workflow.

The reconciliation/business rules live in SQL. The Python file is only an execution and display helper.

## Files

| File | Purpose |
|---|---|
| `01_investigation.sql` | Step-by-step exploratory queries used to inspect counts, campaign eligibility, retry relationships, and campaign hierarchy |
| `final_reconciliation.sql` | Final recursive CTE query that applies the reporting rules and returns `target_base` |
| `query_executor.py` | Runs the investigation queries sequentially and then runs the final reconciliation query |
| `comm_log.db` | SQLite database used by the SQL and Python workflow |
| `README.md` | Documentation for this SQL folder and its execution workflow |

## Investigation SQL

`01_investigation.sql` is the investigation layer. It is designed to show the evidence behind the final number rather than immediately returning only `22`.

### Queries covered

1. Naive communication-log row count.
2. Communication volume by campaign.
3. Campaign creation and processing statuses.
4. Root and retry campaign relationships.
5. Ineligible campaign `9004`.
6. Retry family `9001 → 9002 → 9003`.
7. Retry family `9201 → 9202`.
8. Standalone campaign `9101` and its repeated C20 send.
9. Recursive campaign-family mapping.

### Investigation outcome

```text
30  raw rows
-4  campaign 9004 is ineligible
-3  duplicate attempts within 9001 → 9002 → 9003
-1  duplicate attempt within 9201 → 9202
---
22  final target_base
```

## Final Reconciliation SQL

`final_reconciliation.sql` is the final answer query.

It applies the assignment rules for:

- merchant `501`;
- October 2026;
- communication type `2`;
- eligible creation statuses (`approved`, `aborted`, `resumed`, `stopped`);
- `processing_status = 'processed'`;
- recursive parent/child campaign mapping;
- one customer counted once within a retry family; and
- every send event counted separately for a standalone campaign.

The recursive structure handles multi-level chains such as:

```text
9001 → 9002 → 9003
```

and:

```text
9201 → 9202
```

Expected result:

```text
target_base
-----------
22
```

## Python Query Executor

`query_executor.py` provides a simple way to run the whole workflow without manually executing each SQL statement.

It does not contain the reconciliation logic. It only:

1. reads `01_investigation.sql`;
2. splits it into SQL statements;
3. connects to `comm_log.db` with Python's built-in `sqlite3` module;
4. executes the investigation queries in order;
5. prints a heading and returned rows for each query;
6. reads and executes `final_reconciliation.sql`;
7. prints the final `target_base`; and
8. closes the connection.

## How to Run

From the repository root:

```bash
cd sql
python query_executor.py
```

No external Python package is required. `sqlite3` is part of Python's standard library.

### Manual SQL execution

You can also open `comm_log.db` in any SQLite-compatible tool and run:

```text
01_investigation.sql
final_reconciliation.sql
```

Run the investigation first if you want to inspect the reasoning, then run the final query for the final result.

## Expected Result

The final query should return:

```text
target_base
-----------
22
```

The Python wrapper should finish with output similar to:

```text
=========================================================================
====================== Final Reconciliation Result ======================
=========================================================================

Final Result:
(22,)

Target Base: 22
```

## Latest Update

### Commit

`76513ab7a918ed9a048317c22b420b380c0a25c3`

### Message

`Added database and python wrapper to execute all queries`

### Date

September 12, 2026

### What changed

The SQL analysis was extended with a repository-level execution workflow:

- `comm_log.db` was added under `sql/` so the repository includes the SQLite database used by the analysis.
- `query_executor.py` was added as a Python wrapper around the existing SQL files.
- Investigation statements in `01_investigation.sql` can now be executed sequentially.
- Each investigation result is displayed with a separate terminal heading.
- `final_reconciliation.sql` is executed automatically after the investigation.
- The final result is printed clearly as `Target Base: 22`.

### How to use the update

Run one command from this directory:

```bash
python query_executor.py
```

This executes the investigation-to-reconciliation workflow end to end using the included SQLite database.