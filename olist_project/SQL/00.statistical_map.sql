USE olist_db;

/*
Metric map for the Olist project.

Core business grain:
- Order grain for GMV / order count / buyer count
- Order item grain for category analysis

Recommended default scope:
- Use delivered orders as the core paid-order scope
- Use SUM(payment_value) as GMV
- Use order_purchase_timestamp as the business month
*/

-- 1) Order-level base table for downstream analysis
WITH order_payment AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_amount
    FROM olist_order_payments_dataset
    GROUP BY order_id
),
order_item AS (
    SELECT
        order_id,
        COUNT(*) AS item_qty,
        SUM(price) AS item_amount,
        SUM(freight_value) AS freight_amount,
        SUM(price + freight_value) AS item_total_amount
    FROM olist_order_items_dataset
    GROUP BY order_id
)
SELECT
    o.order_id,
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
    o.order_purchase_timestamp,
    o.order_status,
    c.customer_unique_id,
    c.customer_state,
    op.payment_amount AS gmv_amount,
    oi.item_qty,
    oi.item_amount,
    oi.freight_amount,
    oi.item_total_amount
FROM olist_orders_dataset o
LEFT JOIN olist_customers_dataset c
    ON o.customer_id = c.customer_id
LEFT JOIN order_payment op
    ON o.order_id = op.order_id
LEFT JOIN order_item oi
    ON o.order_id = oi.order_id
LIMIT 50;

-- 2) KPI definition board at monthly level
WITH delivered_order_base AS (
    SELECT
        o.order_id,
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        c.customer_unique_id,
        p.payment_amount
    FROM olist_orders_dataset o
    JOIN olist_customers_dataset c
        ON o.customer_id = c.customer_id
    JOIN (
        SELECT
            order_id,
            SUM(payment_value) AS payment_amount
        FROM olist_order_payments_dataset
        GROUP BY order_id
    ) p
        ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
)
SELECT
    order_month,
    ROUND(SUM(payment_amount), 2) AS gmv,
    COUNT(DISTINCT order_id) AS paid_order_cnt,
    COUNT(DISTINCT customer_unique_id) AS active_buyer_cnt,
    ROUND(SUM(payment_amount) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS aov,
    ROUND(COUNT(DISTINCT order_id) / NULLIF(COUNT(DISTINCT customer_unique_id), 0), 2) AS orders_per_buyer
FROM delivered_order_base
GROUP BY order_month
ORDER BY order_month;
