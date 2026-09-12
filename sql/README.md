# SQL Investigation & Execution Guide

This folder contains the SQL analysis and the small execution layer used for the Xeno communication-log reconciliation.

> The root [`README.md`](../README.md) is the main project documentation. This README is intentionally focused on the files and execution workflow inside `sql/`.

## Folder Purpose

The `sql/` folder contains:

- the investigation SQL;
- the final reconciliation SQL;
- the supplied SQLite database; and
- a Python wrapper for running the complete workflow.

The reconciliation/business rules live in SQL. The Python file is only an execution and display helper.

## Files

| File | Purpose |
|---|---|
| `01_investigation.sql` | Step-by-step exploratory queries used to inspect counts, campaign eligibility, retry relationships, and campaign hierarchy |
| `final_reconciliation.sql` | Final recursive CTE query that applies the reporting rules and returns `target_base` |
| `query_executor.py` | Runs the investigation queries sequentially and then runs the final reconciliation query |
| `comm_log.db` | SQLite database used by the SQL and Python workflow |
| `README.md` | Documentation for this SQL folder and its execution workflow |

## Two-Stage SQL Workflow

The analysis is intentionally split into two stages.

### Stage 1 — Investigation

Run:

```text
01_investigation.sql
```

This stage shows the evidence behind the reconciliation rather than only returning the final number. It covers:

1. Naive communication-log row count.
2. Communication volume by campaign.
3. Campaign creation and processing statuses.
4. Root and retry campaign relationships.
5. Ineligible campaign `9004`.
6. Retry family `9001 → 9002 → 9003`.
7. Retry family `9201 → 9202`.
8. Standalone campaign `9101` and its repeated C20 send.
9. Recursive campaign-family mapping.

The investigation leads to:

```text
30  raw rows
-4  campaign 9004 is ineligible
-3  duplicate attempts within 9001 → 9002 → 9003
-1  duplicate attempt within 9201 → 9202
---
22  final target_base
```

### Stage 2 — Final Reconciliation

Run:

```text
final_reconciliation.sql
```

This is the final answer query. It applies the assignment rules for:

- merchant `501`;
- October 2026;
- communication type `2`;
- eligible creation statuses (`approved`, `aborted`, `resumed`, `stopped`);
- `processing_status = 'processed'`;
- recursive parent/child campaign mapping;
- one customer counted once within a retry family; and
- every send event counted separately for a standalone campaign.

Expected result:

```text
target_base
-----------
22
```

## How to Open and Run Manually

Both SQL stages must be run against the **same database**:

```text
comm_log.db
```

In this repository, that database is:

```text
sql/comm_log.db
```

### Example — DB Browser for SQLite

1. Open **DB Browser for SQLite** (or another SQLite-compatible tool).
2. Choose **Open Database**.
3. Select:

```text
sql/comm_log.db
```

4. Open the **Execute SQL** / SQL editor area.

**Stage 1:** open or paste:

```text
sql/01_investigation.sql
```

Run the statements and inspect the results query by query.

The first query should return:

```text
naive_count
-----------
30
```

**Stage 2:** in the same database/editor, open or paste:

```text
sql/final_reconciliation.sql
```

Run it after the investigation.

Expected result:

```text
target_base
-----------
22
```

> **Important:** `01_investigation.sql` and `final_reconciliation.sql` are SQL query files, not databases. The database to open is `sql/comm_log.db`.

## Python Query Executor

`query_executor.py` provides a simple way to run both stages automatically.

It:

1. locates the SQL files and database relative to the Python script itself;
2. reads `01_investigation.sql`;
3. executes the investigation queries in order;
4. prints a heading and returned rows for each query;
5. reads and executes `final_reconciliation.sql`;
6. prints the final `target_base`; and
7. closes the database connection.

No external Python package is required. `sqlite3` and `pathlib` are part of Python's standard library.

### Run from the repository root

```bash
python sql/query_executor.py
```

### Or run from inside the `sql` folder

```bash
cd sql
python query_executor.py
```

Both commands work and produce the same investigation-to-reconciliation workflow.

The script should finish with output similar to:

```text
====================== Final Reconciliation Result ======================

Final Result:
(22,)

Target Base: 22
```

## Quick Reference

```text
xeno-comm-log-reconciliation/
│
├── sql/
│   ├── comm_log.db               ← Open this database
│   ├── 01_investigation.sql     ← Stage 1: investigate
│   ├── final_reconciliation.sql  ← Stage 2: calculate final number
│   └── query_executor.py        ← Run both stages automatically
│
└── README.md
```

**Order:**

```text
Open sql/comm_log.db
        ↓
Stage 1: 01_investigation.sql
        ↓
Review evidence / reconciliation
        ↓
Stage 2: final_reconciliation.sql
        ↓
target_base = 22
```
