# SQL Investigation & Execution Guide

This folder contains the SQL analysis, final reconciliation query, SQLite database, and Python wrapper used to reproduce Finance's reported `target_base = 22`.

## Table of Contents

- [Folder Overview](#folder-overview)
- [Workflow](#workflow)
- [01 Investigation SQL](#01-investigation-sql)
- [Final Reconciliation SQL](#final-reconciliation-sql)
- [Python Query Executor](#python-query-executor)
- [How to Run](#how-to-run)
- [Expected Output](#expected-output)
- [Latest Update](#latest-update)

## Folder Overview

| File | Purpose |
|---|---|
| `01_investigation.sql` | Exploratory SQL queries used to understand row counts, eligibility, campaign relationships, retries, and the communication families |
| `final_reconciliation.sql` | Final SQLite query that applies the reporting rules and returns `target_base` |
| `query_executor.py` | Python wrapper that runs the investigation queries and final reconciliation in sequence |
| `comm_log.db` | SQLite database used by the analysis and Python execution workflow |
| `README.md` | Documentation for the SQL files, execution flow, and latest changes |

## Workflow

The SQL analysis follows this sequence:

```text
Communication log
      ↓
Naive count
      ↓
Campaign eligibility check
      ↓
Root / retry family identification
      ↓
Recursive campaign hierarchy
      ↓
Customer deduplication inside retry families
      ↓
Keep standalone send events separate
      ↓
Final target_base
```

For this dataset:

```text
30  raw communication-log rows
-4  exclude campaign 9004 (approval_awaiting)
-3  collapse duplicate customers in 9001 → 9002 → 9003
-1  collapse duplicate customer in 9201 → 9202
---
22  final target_base
```

## 01 Investigation SQL

`01_investigation.sql` contains the exploratory queries used to build and validate the reconciliation logic before the final query was written.

### What it investigates

The file covers:

1. Naive communication-log row count.
2. Send volume by campaign.
3. Campaign creation and processing statuses.
4. Root campaigns and retry campaigns.
5. The ineligible `9004` branch.
6. Retry family `9001 → 9002 → 9003`.
7. Retry family `9201 → 9202`.
8. Repeated sends in standalone campaign `9101`.
9. Recursive campaign-family mapping.

### Why it is separate

The investigation file shows the reasoning and intermediate evidence. It is useful for reviewing how the final number was obtained rather than relying only on one final query.

## Final Reconciliation SQL

`final_reconciliation.sql` is the production-style query for the assignment result.

It applies the following filters and rules:

- merchant `501`;
- October 2026;
- communication type `2`;
- eligible creation statuses: `approved`, `aborted`, `resumed`, `stopped`;
- `processing_status = 'processed'`;
- recursive mapping of retry campaigns to their root campaign;
- distinct-customer counting within retry families;
- event-level counting for standalone campaigns.

It supports multi-level retry chains, including:

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

The final query returns:

```text
target_base
-----------
22
```

## Python Query Executor

`query_executor.py` is a lightweight execution wrapper. It does not implement the reconciliation rules; those remain in the SQL files.

### What was added

The script:

- reads `01_investigation.sql`;
- splits the file into individual SQL statements;
- connects to `comm_log.db` with Python's built-in `sqlite3` module;
- executes the investigation queries one by one;
- prints a separate heading for each query;
- displays the returned rows;
- reads and executes `final_reconciliation.sql`;
- prints the final result;
- closes the database connection.

This makes the complete investigation-to-reconciliation workflow executable with one command.

## How to Run

### Run everything with Python

Open a terminal in the repository and move into this directory:

```bash
cd sql
```

Then run:

```bash
python query_executor.py
```

No external Python package is required. The script uses the standard-library `sqlite3` module.

### Run the SQL manually

You can also open `comm_log.db` in a SQLite-compatible tool and run:

```text
01_investigation.sql
final_reconciliation.sql
```

Run the investigation file first to inspect the evidence and then run the final reconciliation query for the final answer.

## Expected Output

The Python script prints each investigation query with its result and finishes with a section similar to:

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

### What changed in that update

The repository previously contained the SQL analysis, but the execution workflow was manual. This update added the pieces needed to run the analysis directly from the repository:

| Change | Details |
|---|---|
| Added database | `comm_log.db` is included under `sql/` so the SQL and Python workflow can run against the same SQLite data |
| Added Python wrapper | `query_executor.py` executes the SQL investigation and final reconciliation |
| Added sequential execution | All statements in `01_investigation.sql` are executed in order |
| Added query headings | Each investigation query is clearly separated in the terminal output |
| Added result display | Returned rows are printed after each investigation query |
| Added final execution | `final_reconciliation.sql` runs automatically after the investigation |
| Added final result display | The script prints `Target Base: 22` at the end |

### How to use the new functionality

From the `sql` directory:

```bash
python query_executor.py
```

This command runs the complete workflow without requiring the SQL statements to be copied and executed manually one by one.
