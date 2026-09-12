# Xeno Comm-Log Send Reconciliation

Reconciliation of Finance's reported `target_base = 22` for merchant `501`, October 2026, using the supplied SQLite communication data.

## Table of Contents

- [Objective](#objective)
- [Business Rules](#business-rules)
- [Investigation](#investigation)
- [Reconciliation Bridge](#reconciliation-bridge)
- [Final Result](#final-result)
- [Repository Structure](#repository-structure)
- [Latest Commit](#latest-commit)

## Objective

Reproduce Finance's reported `target_base = 22` for merchant `501`, October 2026, across the Diwali campaigns.

## Business Rules

- A campaign is eligible only when its creation workflow has cleared (`approved`, `aborted`, `resumed`, `stopped`) and `processing_status = 'processed'`.
- A retry campaign is represented by `campaign.parent_id` and belongs to the same underlying communication as its parent chain.
- Within a retry chain, the same customer counts once across all eligible attempts in that chain.
- A standalone campaign has no child retries; every send event counts separately, even when the same customer appears more than once.

## Investigation

### Step 0 — Naive count

`communication_log` contains 30 send-attempt rows.

**Result: 30**

### Step 1 — Campaign eligibility

Campaign `9004` is `approval_awaiting`, although four communication-log rows already exist for it. It therefore fails the reporting eligibility gate.

**30 - 4 = 26**

### Step 2 — Retry family 9001 → 9002 → 9003

The family contains 13 raw send attempts but only 10 distinct customers. C2 is retried once and C3 is retried twice; these attempts belong to the same underlying communication.

**26 - 3 = 23**

### Step 3 — Retry family 9201 → 9202

The family contains 6 raw attempts but only 5 distinct customers. D1 failed in 9201 and was successfully retried in 9202.

**23 - 1 = 22**

### Step 4 — Standalone campaign 9101

Campaign `9101` has 7 send events. C20 appears twice on different dates, but because 9101 is standalone, both sends are legitimate separate events and remain counted.

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

`30 - 4 - 3 - 1 = 22`

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

## Latest Commit

### `76513ab7a918ed9a048317c22b420b380c0a25c3`

**Message:** `Added database and python wrapper to execute all queries`

**Date:** September 12, 2026

This commit adds the SQLite database copy used by the repository and a Python query-execution wrapper. The wrapper reads `01_investigation.sql`, executes the investigation queries sequentially, formats their results for display, and then executes `final_reconciliation.sql` to produce the final reconciliation result. The commit also records the new files under `sql/` so the SQL investigation and execution workflow can be reproduced from the repository.
