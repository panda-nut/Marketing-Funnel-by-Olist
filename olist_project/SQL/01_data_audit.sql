USE olist_db;

/*
数据审计目标
1. 确认有哪些核心表以及各表行数
2. 检查关键主键是否唯一
3. 检查核心外键能否正常关联
4. 检查关键字段空值情况
5. 检查订单金额口径是否一致

说明
- 该文件保持为“可直接执行”的 SQL，不再混用 Markdown 语法
- 后续业务分析统一采用 delivered + payment_value + purchase month 口径
*/

-- 1) 查看库中的表
SHOW TABLES;

-- 2) 查看核心表行数
SELECT 'olist_closed_deals_dataset' AS table_name, COUNT(*) AS row_cnt FROM olist_closed_deals_dataset
UNION ALL
SELECT 'olist_customers_dataset', COUNT(*) FROM olist_customers_dataset
UNION ALL
SELECT 'olist_geolocation_dataset', COUNT(*) FROM olist_geolocation_dataset
UNION ALL
SELECT 'olist_marketing_qualified_leads_dataset', COUNT(*) FROM olist_marketing_qualified_leads_dataset
UNION ALL
SELECT 'olist_order_items_dataset', COUNT(*) FROM olist_order_items_dataset
UNION ALL
SELECT 'olist_order_payments_dataset', COUNT(*) FROM olist_order_payments_dataset
UNION ALL
SELECT 'olist_order_reviews_dataset', COUNT(*) FROM olist_order_reviews_dataset
UNION ALL
SELECT 'olist_orders_dataset', COUNT(*) FROM olist_orders_dataset
UNION ALL
SELECT 'olist_products_dataset', COUNT(*) FROM olist_products_dataset
UNION ALL
SELECT 'olist_sellers_dataset', COUNT(*) FROM olist_sellers_dataset
UNION ALL
SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation;

-- 3) 检查主键唯一性
SELECT
    'olist_orders_dataset.order_id' AS pk_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS distinct_pk,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_rows
FROM olist_orders_dataset
UNION ALL
SELECT
    'olist_customers_dataset.customer_id',
    COUNT(*),
    COUNT(DISTINCT customer_id),
    COUNT(*) - COUNT(DISTINCT customer_id)
FROM olist_customers_dataset
UNION ALL
SELECT
    'olist_products_dataset.product_id',
    COUNT(*),
    COUNT(DISTINCT product_id),
    COUNT(*) - COUNT(DISTINCT product_id)
FROM olist_products_dataset
UNION ALL
SELECT
    'olist_sellers_dataset.seller_id',
    COUNT(*),
    COUNT(DISTINCT seller_id),
    COUNT(*) - COUNT(DISTINCT seller_id)
FROM olist_sellers_dataset
UNION ALL
SELECT
    'olist_order_items_dataset.(order_id, order_item_id)',
    COUNT(*),
    COUNT(DISTINCT CONCAT(order_id, '-', order_item_id)),
    COUNT(*) - COUNT(DISTINCT CONCAT(order_id, '-', order_item_id))
FROM olist_order_items_dataset
UNION ALL
SELECT
    'olist_order_payments_dataset.(order_id, payment_sequential)',
    COUNT(*),
    COUNT(DISTINCT CONCAT(order_id, '-', payment_sequential)),
    COUNT(*) - COUNT(DISTINCT CONCAT(order_id, '-', payment_sequential))
FROM olist_order_payments_dataset;

-- 4) 检查核心外键是否存在无法关联的记录
SELECT
    'orders -> customers' AS relation_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN c.customer_id IS NULL THEN 1 ELSE 0 END) AS unmatched_rows
FROM olist_orders_dataset o
LEFT JOIN olist_customers_dataset c
    ON o.customer_id = c.customer_id
UNION ALL
SELECT
    'order_items -> orders',
    COUNT(*),
    SUM(CASE WHEN o.order_id IS NULL THEN 1 ELSE 0 END)
FROM olist_order_items_dataset oi
LEFT JOIN olist_orders_dataset o
    ON oi.order_id = o.order_id
UNION ALL
SELECT
    'order_items -> products',
    COUNT(*),
    SUM(CASE WHEN p.product_id IS NULL THEN 1 ELSE 0 END)
FROM olist_order_items_dataset oi
LEFT JOIN olist_products_dataset p
    ON oi.product_id = p.product_id
UNION ALL
SELECT
    'order_items -> sellers',
    COUNT(*),
    SUM(CASE WHEN s.seller_id IS NULL THEN 1 ELSE 0 END)
FROM olist_order_items_dataset oi
LEFT JOIN olist_sellers_dataset s
    ON oi.seller_id = s.seller_id
UNION ALL
SELECT
    'payments -> orders',
    COUNT(*),
    SUM(CASE WHEN o.order_id IS NULL THEN 1 ELSE 0 END)
FROM olist_order_payments_dataset p
LEFT JOIN olist_orders_dataset o
    ON p.order_id = o.order_id
UNION ALL
SELECT
    'reviews -> orders',
    COUNT(*),
    SUM(CASE WHEN o.order_id IS NULL THEN 1 ELSE 0 END)
FROM olist_order_reviews_dataset r
LEFT JOIN olist_orders_dataset o
    ON r.order_id = o.order_id;

-- 5) 检查订单表关键字段空值情况
SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END) AS null_order_status,
    SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END) AS null_purchase_ts,
    SUM(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) AS null_estimated_delivery_date
FROM olist_orders_dataset;

-- 6) 检查金额口径: order_items 与 payments 是否一致
WITH item_amount AS (
    SELECT
        order_id,
        SUM(price) AS item_amount,
        SUM(freight_value) AS freight_amount,
        SUM(price + freight_value) AS item_total
    FROM olist_order_items_dataset
    GROUP BY order_id
),
payment_amount AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM olist_order_payments_dataset
    GROUP BY order_id
)
SELECT
    COUNT(*) AS diff_order_cnt,
    ROUND(COUNT(*) / (SELECT COUNT(DISTINCT order_id) FROM olist_order_items_dataset) * 100, 4) AS diff_order_rate_pct,
    ROUND(AVG(i.item_total - p.payment_total), 2) AS avg_diff_amount,
    ROUND(MIN(i.item_total - p.payment_total), 2) AS min_diff_amount,
    ROUND(MAX(i.item_total - p.payment_total), 2) AS max_diff_amount
FROM item_amount i
JOIN payment_amount p
    ON i.order_id = p.order_id
WHERE ABS(i.item_total - p.payment_total) > 0.01;

-- 7) 查看金额不一致的样例订单
WITH item_amount AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS item_total
    FROM olist_order_items_dataset
    GROUP BY order_id
),
payment_amount AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM olist_order_payments_dataset
    GROUP BY order_id
)
SELECT
    i.order_id,
    i.item_total,
    p.payment_total,
    ROUND(i.item_total - p.payment_total, 2) AS diff_amount
FROM item_amount i
JOIN payment_amount p
    ON i.order_id = p.order_id
WHERE ABS(i.item_total - p.payment_total) > 0.01
ORDER BY ABS(i.item_total - p.payment_total) DESC
LIMIT 20;
