USE olist_db;

/*
Goal:
- Explain monthly GMV changes instead of only reporting the total
- Decompose GMV into order count, active buyers, orders per buyer and AOV

Formula:
- GMV = paid_order_cnt * AOV
- paid_order_cnt = active_buyer_cnt * orders_per_buyer
*/

-- 1) Monthly GMV decomposition panel
做GMV的拆分：(某个月的GMV变化，到底是买家变化还是客单价变化)

GMV = 订单数 × 客单价
订单数 = 买家数 × 人均订单数

WITH delivered_order_payment AS (
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
),
monthly_metrics AS (
    SELECT
        order_month,
        ROUND(SUM(payment_amount), 2) AS gmv,
        COUNT(DISTINCT order_id) AS paid_order_cnt,
        COUNT(DISTINCT customer_unique_id) AS active_buyer_cnt,
        ROUND(SUM(payment_amount) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS aov,
        ROUND(COUNT(DISTINCT order_id) / NULLIF(COUNT(DISTINCT customer_unique_id), 0), 2) AS orders_per_buyer
    FROM delivered_order_payment
    GROUP BY order_month
)
SELECT
    order_month,
    gmv,
    paid_order_cnt,
    active_buyer_cnt,
    orders_per_buyer,
    aov
FROM monthly_metrics
ORDER BY order_month;

-- 2) Month-over-month change by driver
WITH delivered_order_payment AS (
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
),
monthly_metrics AS (
    SELECT
        order_month,
        ROUND(SUM(payment_amount), 2) AS gmv,
        COUNT(DISTINCT order_id) AS paid_order_cnt,
        COUNT(DISTINCT customer_unique_id) AS active_buyer_cnt,
        ROUND(SUM(payment_amount) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS aov,
        ROUND(COUNT(DISTINCT order_id) / NULLIF(COUNT(DISTINCT customer_unique_id), 0), 2) AS orders_per_buyer
    FROM delivered_order_payment
    GROUP BY order_month
)
SELECT
    order_month,
    gmv,
    ROUND(gmv - LAG(gmv) OVER (ORDER BY order_month), 2) AS gmv_mom_change,
    paid_order_cnt,
    paid_order_cnt - LAG(paid_order_cnt) OVER (ORDER BY order_month) AS order_cnt_mom_change,
    active_buyer_cnt,
    active_buyer_cnt - LAG(active_buyer_cnt) OVER (ORDER BY order_month) AS buyer_cnt_mom_change,
    orders_per_buyer,
    ROUND(orders_per_buyer - LAG(orders_per_buyer) OVER (ORDER BY order_month), 2) AS opb_mom_change,
    aov,
    ROUND(aov - LAG(aov) OVER (ORDER BY order_month), 2) AS aov_mom_change
FROM monthly_metrics
ORDER BY order_month;

-- 3) Quick ranking: best / worst month by GMV growth
WITH delivered_order_payment AS (
    SELECT
        o.order_id,
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        p.payment_amount
    FROM olist_orders_dataset o
    JOIN (
        SELECT
            order_id,
            SUM(payment_value) AS payment_amount
        FROM olist_order_payments_dataset
        GROUP BY order_id
    ) p
        ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
),
monthly_metrics AS (
    SELECT
        order_month,
        ROUND(SUM(payment_amount), 2) AS gmv
    FROM delivered_order_payment
    GROUP BY order_month
),
growth_table AS (
    SELECT
        order_month,
        gmv,
        ROUND(gmv - LAG(gmv) OVER (ORDER BY order_month), 2) AS gmv_mom_change
    FROM monthly_metrics
)
SELECT
    order_month,
    gmv,
    gmv_mom_change
FROM growth_table
WHERE gmv_mom_change IS NOT NULL
ORDER BY gmv_mom_change DESC, order_month
LIMIT 5;
