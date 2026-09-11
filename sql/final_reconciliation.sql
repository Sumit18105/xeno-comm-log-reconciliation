-- Xeno Comm-Log Reconciliation - Final SQL
-- SQLite
-- Target: merchant 501, October 2026, campaign communications only.

WITH RECURSIVE campaign_tree AS (
    -- Root campaigns start their own retry family.
    SELECT
        id AS campaign_id,
        id AS root_campaign_id
    FROM campaign
    WHERE merchant_id = 501
      AND parent_id IS NULL

    UNION ALL

    -- Walk all retry levels back to the root campaign.
    SELECT
        c.id AS campaign_id,
        ct.root_campaign_id
    FROM campaign c
    JOIN campaign_tree ct
        ON c.parent_id = ct.campaign_id
    WHERE c.merchant_id = 501
),

eligible_sends AS (
    -- Keep sends only when their campaign is eligible for reporting.
    SELECT
        cl.id,
        cl.customer_id,
        ct.root_campaign_id
    FROM communication_log cl
    JOIN campaign_tree ct
        ON cl.communication_id = ct.campaign_id
    JOIN campaign c
        ON c.id = cl.communication_id
    WHERE cl.merchant_id = 501
      AND cl.communication_type = '2'
      AND cl.sent_time >= '2026-10-01'
      AND cl.sent_time <  '2026-11-01'
      AND c.creation_status IN (
          'approved',
          'aborted',
          'resumed',
          'stopped'
      )
      AND c.processing_status = 'processed'
),

root_campaigns AS (
    SELECT
        c.id AS root_campaign_id,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM campaign child
                WHERE child.parent_id = c.id
                  AND child.merchant_id = 501
            )
            THEN 0
            ELSE 1
        END AS is_standalone
    FROM campaign c
    WHERE c.merchant_id = 501
      AND c.parent_id IS NULL
),

family_counts AS (
    SELECT
        es.root_campaign_id,
        CASE
            -- Standalone campaign: every send event counts.
            WHEN rc.is_standalone = 1
                THEN COUNT(*)
            -- Retry family: same customer counts once across the family.
            ELSE COUNT(DISTINCT es.customer_id)
        END AS qualifying_sends
    FROM eligible_sends es
    JOIN root_campaigns rc
        ON rc.root_campaign_id = es.root_campaign_id
    GROUP BY
        es.root_campaign_id,
        rc.is_standalone
)

SELECT
    SUM(qualifying_sends) AS target_base
FROM family_counts;
