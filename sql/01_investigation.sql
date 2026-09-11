-- Xeno Comm-Log Reconciliation - Investigation SQL
-- SQLite

-- 1. Naive starting count
SELECT COUNT(*) AS naive_count
FROM communication_log;

-- 2. Inspect campaign-level send volumes
SELECT
    communication_id,
    COUNT(*) AS send_attempts
FROM communication_log
GROUP BY communication_id
ORDER BY communication_id;

-- 3. Inspect campaign eligibility/status
SELECT
    id,
    parent_id,
    name,
    creation_status,
    processing_status
FROM campaign
WHERE merchant_id = 501
ORDER BY id;

-- 4. Identify root vs retry campaigns
SELECT
    id AS campaign_id,
    parent_id,
    name,
    CASE
        WHEN parent_id IS NULL THEN 'ROOT'
        ELSE 'RETRY'
    END AS campaign_role
FROM campaign
WHERE merchant_id = 501
ORDER BY id;

-- 5. Show the pending campaign's send rows
SELECT
    cl.id,
    cl.communication_id,
    cl.customer_id,
    cl.delivery_status,
    cl.sent_time
FROM communication_log cl
JOIN campaign c
    ON c.id = cl.communication_id
WHERE c.id = 9004
ORDER BY cl.sent_time;

-- 6. Inspect Family A retry chain
SELECT
    cl.communication_id,
    cl.customer_id,
    cl.delivery_status,
    cl.sent_time
FROM communication_log cl
WHERE cl.communication_id IN (9001, 9002, 9003)
ORDER BY cl.customer_id, cl.sent_time;

-- 7. Inspect Family B retry chain
SELECT
    cl.communication_id,
    cl.customer_id,
    cl.delivery_status,
    cl.sent_time
FROM communication_log cl
WHERE cl.communication_id IN (9201, 9202)
ORDER BY cl.customer_id, cl.sent_time;

-- 8. Inspect standalone campaign 9101
SELECT
    cl.communication_id,
    cl.customer_id,
    cl.delivery_status,
    cl.sent_time
FROM communication_log cl
WHERE cl.communication_id = 9101
ORDER BY cl.customer_id, cl.sent_time;

-- 9. Build the retry-family mapping.
-- This handles multi-level chains such as 9001 -> 9002 -> 9003.
WITH RECURSIVE campaign_tree AS (
    SELECT
        id AS campaign_id,
        id AS root_campaign_id
    FROM campaign
    WHERE merchant_id = 501
      AND parent_id IS NULL

    UNION ALL

    SELECT
        c.id AS campaign_id,
        ct.root_campaign_id
    FROM campaign c
    JOIN campaign_tree ct
        ON c.parent_id = ct.campaign_id
    WHERE c.merchant_id = 501
)
SELECT
    campaign_id,
    root_campaign_id
FROM campaign_tree
ORDER BY root_campaign_id, campaign_id;
