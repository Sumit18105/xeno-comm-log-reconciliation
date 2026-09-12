# Xeno Data Analyst Take-Home — Comm-Log Reconciliation

## Assignment Question

Finance reports `target_base = 22` for merchant `501` in October 2026 across the Diwali campaigns. The task is to reproduce that number from the raw communication data and explain the gap between the Finance number and a straightforward count.

The submission requirements are:

1. Show a reconciliation bridge starting from the most naive query, with every adjustment in the order discovered and a short reason.
2. Provide the SQL used to calculate the final correct number.
3. Describe something surprising in the data, even if it does not change the final number.

The analysis below is the answer to those requirements.

## 1. Scope and Reporting Rules

| Filter | Value |
|---|---|
| Merchant | `501` |
| Period | October 2026 |
| Communication type | `2` (Campaign) |

A campaign is eligible for reporting when `creation_status` is one of `approved`, `aborted`, `resumed`, or `stopped`, and `processing_status = 'processed'`. A campaign in `approval_awaiting` is not eligible even when communication-log rows exist.

For retry campaigns, `parent_id` links a campaign to its previous campaign. A retry chain represents the same underlying communication, so a customer is counted once across the eligible attempts in that family. Retry chains can be multiple levels deep.

A standalone campaign has no parent and no child retries. For a standalone campaign, each send event is counted separately, even if the same customer appears more than once.

## 2. Investigation and Reconciliation

### Step 0 — Naive starting point

First, count all communication-log rows in the requested scope.

```sql
SELECT COUNT(*)
FROM communication_log
WHERE merchant_id = 501
  AND communication_type = '2'
  AND sent_time >= '2026-10-01'
  AND sent_time < '2026-11-01';
```

**Result: 30**

This is the most straightforward count, but it does not yet apply campaign eligibility or retry-family rules.

### Step 1 — Exclude the ineligible campaign

Campaign `9004` has `creation_status = 'approval_awaiting'`. It has 4 communication-log rows, but these rows are not eligible for official reporting.

```text
30 - 4 = 26
```

**Adjustment: -4**

### Step 2 — Reconcile retry family `9001 → 9002 → 9003`

The three campaigns form one retry family. There are 13 eligible send attempts but only 10 distinct customers in the family. Customers `C2` and `C3` appear across multiple attempts because of retries.

```text
26 - (13 - 10) = 23
```

**Adjustment: -3**

### Step 3 — Reconcile retry family `9201 → 9202`

This is another retry family. There are 6 eligible attempts but only 5 distinct customers. Customer `D1` failed in `9201` and was retried successfully in `9202`.

```text
23 - (6 - 5) = 22
```

**Adjustment: -1**

### Step 4 — Verify standalone campaign `9101`

Campaign `9101` is standalone and has 7 send events. Customer `C20` appears twice on different dates, but these are separate legitimate send events rather than retries, so both remain counted.

**Adjustment: 0**

## 3. Reconciliation Bridge

| Step | Description | Result | Adjustment | Reason |
|---:|---|---:|---:|---|
| 0 | Naive count of communication-log rows | 30 | — | Starting point: every row is a send attempt |
| 1 | Exclude ineligible campaign `9004` | 26 | -4 | `approval_awaiting` campaigns are excluded from official reporting |
| 2 | Collapse retry family `9001 → 9002 → 9003` | 23 | -3 | 13 attempts represent 10 distinct customers in one retry chain |
| 3 | Collapse retry family `9201 → 9202` | 22 | -1 | 6 attempts represent 5 distinct customers in one retry chain |
| 4 | Verify standalone campaign `9101` | 22 | 0 | Repeated `C20` sends are separate standalone events |
| **Final** | **Finance `target_base`** | **22** | | **Reconciled** |

### Final arithmetic

```text
30 - 4 - 3 - 1 = 22
```

## 4. Final SQL

The final reconciliation query is in [`sql/final_reconciliation.sql`](sql/final_reconciliation.sql).

It:

- applies the merchant, date, and communication-type filters;
- applies campaign eligibility;
- recursively maps campaigns to their root campaign;
- distinguishes retry families from standalone campaigns;
- counts distinct customers within retry families; and
- counts individual send events for standalone campaigns.

The query returns:

```text
target_base
-----------
22
```

## 5. Surprising Finding

One surprising aspect of the data is that campaign `9004` already has four communication-log rows even though its creation status is still `approval_awaiting`. Those rows therefore appear in the raw communication log but are excluded from the official metric because the campaign has not cleared the approval gate. Another interesting case is standalone campaign `9101`, where customer `C20` appears twice on different dates. Because this is a standalone campaign rather than a retry chain, both sends are legitimate separate events and should remain in the count.

## 6. Repository Files

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
| `README.md` | Main assignment answer and project-level documentation |
| `sql/01_investigation.sql` | Exploratory queries used to investigate the mismatch step by step |
| `sql/final_reconciliation.sql` | Final SQL solution that returns `target_base = 22` |
| `sql/query_executor.py` | Python wrapper for executing the investigation and final SQL |
| `sql/comm_log.db` | SQLite database used by the repository execution workflow |
| `sql/README.md` | Technical documentation for the SQL folder and execution workflow |
| `outputs/reconciliation_bridge.csv` | Machine-readable version of the reconciliation bridge |

## 7. How to Reproduce

There are two ways to reproduce the analysis. The two SQL stages are **investigation first** and **final reconciliation second**.

### Option A — Run the complete workflow with Python

The Python wrapper is path-safe: it locates the SQL files and database relative to its own location. You can run it from either the repository root or from inside `sql/`.

**From the repository root:**

```bash
python sql/query_executor.py
```

**Or from inside the SQL folder:**

```bash
cd sql
python query_executor.py
```

Both commands execute all investigation queries first and then execute the final reconciliation query. The script should finish with:

```text
====================== Final Reconciliation Result ======================

Final Result:
(22,)

Target Base: 22
```

No external Python packages are required; the wrapper uses Python's built-in `sqlite3` module.

### Option B — Open and run the two SQL stages manually

If you want to inspect the work step by step, open the supplied database:

```text
sql/comm_log.db
```

Then run the SQL files in this order.

#### Stage 1 — Investigation

Open:

```text
sql/01_investigation.sql
```

This stage does **not** produce only one final number. It shows the evidence used to understand the mismatch, including raw counts, campaign statuses, retry relationships, the ineligible `9004` rows, both retry families, the standalone campaign, and the recursive campaign mapping.

Example workflow in a SQLite GUI such as DB Browser for SQLite:

1. Open `sql/comm_log.db`.
2. Go to the **Execute SQL** / SQL editor area.
3. Open or paste `sql/01_investigation.sql`.
4. Run the statements and inspect the result after each query.

The first query should show the naive count of **30**.

#### Stage 2 — Final reconciliation

After reviewing the investigation, open:

```text
sql/final_reconciliation.sql
```

Run that query against the **same `sql/comm_log.db` database**.

Expected result:

```text
target_base
-----------
22
```

**Important:** Do not open `final_reconciliation.sql` as if it were a separate database. Both SQL files are queries that must be executed against `comm_log.db`.

### Quick reference

```text
Repository root
│
├── sql/comm_log.db              ← open this database
│
├── sql/01_investigation.sql    ← Stage 1: inspect and investigate
│
└── sql/final_reconciliation.sql ← Stage 2: calculate final target_base
```

## Final Answer

**Finance's reported `target_base = 22` is fully reconciled:**

```text
30 naive rows
- 4 ineligible campaign rows
- 3 duplicate retry attempts in family 9001 → 9002 → 9003
- 1 duplicate retry attempt in family 9201 → 9202
-----------------------------------------------
22 final target_base
```
