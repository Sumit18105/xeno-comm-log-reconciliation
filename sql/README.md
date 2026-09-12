# SQL Guide

## Table of Contents

- [Investigation](#investigation)
- [Final Reconciliation](#final-reconciliation)
- [Latest Commit](#latest-commit)

## Investigation

`01_investigation.sql` contains the exploratory queries used to understand the raw data:

1. Establish the naive row count.
2. Inspect send volume by campaign.
3. Inspect campaign eligibility statuses.
4. Identify root and retry campaigns.
5. Inspect the ineligible pending branch.
6. Inspect the `9001 -> 9002 -> 9003` retry chain.
7. Inspect the `9201 -> 9202` retry chain.
8. Verify that repeated sends in standalone campaign `9101` are legitimate events.
9. Build a recursive campaign-family mapping.

## Final Reconciliation

`final_reconciliation.sql` applies the reporting rules in one SQLite query:

- restrict to merchant `501`, campaign type `2`, and October 2026;
- require an eligible campaign status;
- map every retry campaign to its root using a recursive CTE;
- count distinct customers for retry families;
- count all send events for standalone root campaigns.

Expected result:

```text
 target_base
 -----------
 22
```

## Latest Commit

### `76513ab7a918ed9a048317c22b420b380c0a25c3`

**Message:** `Added database and python wrapper to execute all queries`

**Date:** September 12, 2026

This commit added the SQLite database copy and a Python query-execution wrapper. The wrapper reads `01_investigation.sql`, executes the investigation queries sequentially, formats their results for display, and then executes `final_reconciliation.sql` to produce the final reconciliation result. These additions make the SQL investigation and execution workflow reproducible directly from the repository.
