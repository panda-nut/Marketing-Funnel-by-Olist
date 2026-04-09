USE olist_db;

/*
月度 GMV 分析

统一口径
- 订单状态: delivered
- 金额口径: SUM(payment_value)
- 时间口径: order_purchase_timestamp 所在月份
*/

-- 1) 月度 GMV
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
    ROUND(SUM(p.payment_value), 2) AS monthly_gmv
FROM olist_orders_dataset o
JOIN olist_order_payments_dataset p
    ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
ORDER BY order_month;

-- 2) 月度 GMV 环比
WITH monthly_gmv AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        ROUND(SUM(p.payment_value), 2) AS monthly_gmv
    FROM olist_orders_dataset o
    JOIN olist_order_payments_dataset p
        ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
)
SELECT
    order_month,
    monthly_gmv,
    ROUND(monthly_gmv - LAG(monthly_gmv) OVER (ORDER BY order_month), 2) AS mom_change,
    ROUND(
        (monthly_gmv - LAG(monthly_gmv) OVER (ORDER BY order_month))
        / NULLIF(LAG(monthly_gmv) OVER (ORDER BY order_month), 0) * 100,
        2
    ) AS mom_growth_rate_pct
FROM monthly_gmv
ORDER BY order_month;

-- 3) 月度 GMV + 订单数 + 买家数 + 客单价
WITH delivered_order_payment AS (
    SELECT
        o.order_id,
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        c.customer_unique_id,
        SUM(p.payment_value) AS payment_amount
    FROM olist_orders_dataset o
    JOIN olist_customers_dataset c
        ON o.customer_id = c.customer_id
    JOIN olist_order_payments_dataset p
        ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        o.order_id,
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m'),
        c.customer_unique_id
)
SELECT
    order_month,
    ROUND(SUM(payment_amount), 2) AS gmv,
    COUNT(DISTINCT order_id) AS paid_order_cnt,
    COUNT(DISTINCT customer_unique_id) AS active_buyer_cnt,
    ROUND(COUNT(DISTINCT order_id) / NULLIF(COUNT(DISTINCT customer_unique_id), 0), 2) AS orders_per_buyer,
    ROUND(SUM(payment_amount) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS aov
FROM delivered_order_payment
GROUP BY order_month
ORDER BY order_month;
