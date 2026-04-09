USE olist_db;

/*
Goal:
- Build an order funnel from purchase to delivery
- Measure fulfillment efficiency and delivery quality
*/

-- 1) Monthly funnel overview
SELECT
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS order_month,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(CASE WHEN order_approved_at IS NOT NULL THEN 1 ELSE 0 END) AS approved_orders,
    SUM(CASE WHEN order_delivered_carrier_date IS NOT NULL THEN 1 ELSE 0 END) AS shipped_orders,
    SUM(CASE WHEN order_delivered_customer_date IS NOT NULL THEN 1 ELSE 0 END) AS delivered_orders,
    SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) AS canceled_orders,
    SUM(CASE WHEN order_status = 'unavailable' THEN 1 ELSE 0 END) AS unavailable_orders,
    ROUND(SUM(CASE WHEN order_delivered_customer_date IS NOT NULL THEN 1 ELSE 0 END) / COUNT(DISTINCT order_id) * 100, 2) AS delivery_rate_pct,
    ROUND(SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) / COUNT(DISTINCT order_id) * 100, 2) AS cancel_rate_pct
FROM olist_orders_dataset
GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
ORDER BY order_month;

-- 2) Monthly delivery SLA and timeliness for delivered orders
SELECT
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS order_month,
    COUNT(*) AS delivered_orders,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, order_purchase_timestamp, order_approved_at)), 2) AS avg_approve_hours,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, order_approved_at, order_delivered_carrier_date)), 2) AS avg_ship_hours,
    ROUND(AVG(TIMESTAMPDIFF(DAY, order_delivered_carrier_date, order_delivered_customer_date)), 2) AS avg_last_mile_days,
    ROUND(AVG(TIMESTAMPDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)), 2) AS avg_total_delivery_days,
    ROUND(SUM(CASE WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS on_time_delivery_rate_pct,
    ROUND(SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS late_delivery_rate_pct
FROM olist_orders_dataset
WHERE order_status = 'delivered'
  AND order_approved_at IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
ORDER BY order_month;

-- 3) Monthly customer feedback quality for delivered orders
-- Deduplicate reviews at order level to avoid one order being counted multiple times.
WITH ranked_reviews AS (
    SELECT
        order_id,
        review_score,
        review_creation_date,
        review_answer_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY review_creation_date DESC, review_answer_timestamp DESC, review_id DESC
        ) AS rn
    FROM olist_order_reviews_dataset
),
review_dedup AS (
    SELECT
        order_id,
        review_score
    FROM ranked_reviews
    WHERE rn = 1
),
review_base AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        o.order_id,
        r.review_score
    FROM olist_orders_dataset o
    LEFT JOIN review_dedup r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
)
SELECT
    order_month,
    COUNT(DISTINCT order_id) AS delivered_orders,
    COUNT(DISTINCT CASE WHEN review_score IS NOT NULL THEN order_id END) AS reviewed_orders,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(
        SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(DISTINCT CASE WHEN review_score IS NOT NULL THEN order_id END), 0) * 100,
        2
    ) AS bad_review_rate_pct,
    ROUND(
        SUM(CASE WHEN review_score >= 4 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(DISTINCT CASE WHEN review_score IS NOT NULL THEN order_id END), 0) * 100,
        2
    ) AS good_review_rate_pct
FROM review_base
GROUP BY order_month
ORDER BY order_month;
