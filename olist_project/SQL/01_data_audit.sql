1.检查有哪些表【USE、SHOW】

```sql
USE olist_db;
SHOW TABLES;
```

2.检查每张表的行数【SELECT、COUNT(*)、FROM】

```sql
SELECT COUNT(*) AS row_cnt FROM olist_customers_dataset;
SELECT COUNT(*) AS row_cnt FROM olist_products_dataset;
SELECT COUNT(*) AS row_cnt FROM olist_sellers_dataset;
```

3.主键是否符合预期【唯一性考量（单键与复键）DISTINCT与非DISTINCT结果对比，可以用CONCAT拼接来解决复键的问题】

```sql
SELECT 
    COUNT(*) as total_rows,
    COUNT(DISTINCT order_id) as disticnt_order_id
    ——————————————
    COUNT(DISTINCT CONCAT(order_id,"-",order_item_id)) AS distinct_pk
    FROM
```

4.检测外键是否能连接上【分别考察每一对关键外键LEFT JOIN、CASE WHEN】

```sql
SELECT 
    COUNT(*),
    SUM(CASE WHEN c.customer_id IS NULL THEN 1 ELSE 0 END)  AS unmatched_customer_rows
FROM olist_orders_dataset o
LEFT JOIN olist_customers_dataset c
    ON o.customer_id = c.customer_id;
```

5.检测关键字段空值（SUM、CASE）

```sql
SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
```

SUMMARY

- 'COUNT(*)'总行数正确
- 'COUNT(DISTINCT ···)'主键的唯一性，如果是复键用CONCAT()
- 'LEFT JOIN' 外键连接没有问题
- 'CASE WHEN'判断空行个数

1.检查订单金额口径

- 从`order_items`口径算订单金额`price + freight_value`
```sql
SELECT
    order_id,
    SUM(price) AS item_amount,
    SUM(freight_value) AS freight_amount,
    SUM(price + freight_value) AS total_item_amount
FROM olist_order_items_dataset
GROUP BY order_id
LIMIT 10;
```
- 从`payments`口径算订单的支付金额
```sql
SELECT
    order_id,
    SUM(payment_value) AS total_payment_amount
FROM olist_order_payments_dataset
GROUP BY order_id
LIMIT 10;
```
- 对账(两个表的不同口径描述的金额是否一致)
```sql
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
    ROUND(i.item_total - p.payment_total, 2) AS diff_amount,
    COUNT(*)
FROM item_amount i
JOIN payment_amount p
    ON i.order_id = p.order_id
WHERE ABS(i.item_total - p.payment_total) > 0.01
```
