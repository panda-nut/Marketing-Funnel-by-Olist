USE olist_db;

/*
Goal:
- Find which categories drive sales, growth and customer experience
- Keep GMV logic consistent with delivered-order payment GMV

Method:
- Aggregate payment to order level
- Allocate order payment to each item by item share within the order
*/

-- 1) Category sales panel based on allocated payment GMV
WITH delivered_order_payment AS (
    SELECT
        o.order_id,
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        SUM(p.payment_value) AS order_payment_amount
    FROM olist_orders_dataset o
    JOIN olist_order_payments_dataset p
        ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        o.order_id,
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
),
item_base AS (
    SELECT
        oi.order_id,
        oi.order_item_id,
        oi.product_id,
        (oi.price + oi.freight_value) AS item_total_amount,
        SUM(oi.price + oi.freight_value) OVER (PARTITION BY oi.order_id) AS order_item_total_amount
    FROM olist_order_items_dataset oi
),
category_base AS (
    SELECT
        dop.order_month,
        ib.order_id,
        COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category_name,
        dop.order_payment_amount,
        ib.item_total_amount,
        ib.order_item_total_amount
    FROM delivered_order_payment dop
    JOIN item_base ib
        ON dop.order_id = ib.order_id
    LEFT JOIN olist_products_dataset p
        ON ib.product_id = p.product_id
    LEFT JOIN product_category_name_translation t
        ON p.product_category_name = t.product_category_name
)
SELECT
    order_month,
    category_name,
    ROUND(SUM(order_payment_amount * item_total_amount / NULLIF(order_item_total_amount, 0)), 2) AS allocated_gmv,
    COUNT(*) AS item_line_cnt,
    COUNT(DISTINCT order_id) AS delivered_order_cnt,
    ROUND(SUM(order_payment_amount * item_total_amount / NULLIF(order_item_total_amount, 0)) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS avg_category_order_value
FROM category_base
GROUP BY order_month, category_name
ORDER BY order_month, allocated_gmv DESC;

-- 2) Category experience panel: review score and bad review rate
-- Use one review per order and one row per order-category to avoid duplicate counting.
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
order_category AS (
    SELECT DISTINCT
        o.order_id,
        COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category_name
    FROM olist_orders_dataset o
    JOIN olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    LEFT JOIN olist_products_dataset p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t
        ON p.product_category_name = t.product_category_name
    WHERE o.order_status = 'delivered'
),
delivered_category_review AS (
    SELECT
        oc.category_name,
        oc.order_id,
        r.review_score
    FROM order_category oc
    LEFT JOIN review_dedup r
        ON oc.order_id = r.order_id
)
SELECT
    category_name,
    COUNT(DISTINCT order_id) AS delivered_order_cnt,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(
        SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(DISTINCT CASE WHEN review_score IS NOT NULL THEN order_id END), 0) * 100,
        2
    ) AS bad_review_rate_pct
FROM delivered_category_review
GROUP BY category_name
HAVING COUNT(DISTINCT order_id) >= 100
ORDER BY delivered_order_cnt DESC, avg_review_score DESC;

-- 3) Category cancel risk panel based on all created orders
WITH category_order_status AS (
    SELECT DISTINCT
        o.order_id,
        COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category_name,
        o.order_status
    FROM olist_orders_dataset o
    JOIN olist_order_items_dataset oi
        ON o.order_id = oi.order_id
    LEFT JOIN olist_products_dataset p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t
        ON p.product_category_name = t.product_category_name
)
SELECT
    category_name,
    COUNT(DISTINCT order_id) AS total_order_cnt,
    SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) AS canceled_order_cnt,
    ROUND(SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) / COUNT(DISTINCT order_id) * 100, 2) AS cancel_rate_pct
FROM category_order_status
GROUP BY category_name
HAVING COUNT(DISTINCT order_id) >= 100
ORDER BY cancel_rate_pct DESC, total_order_cnt DESC;
