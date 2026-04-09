# data_feedback

## 1. 数据审计结论

本项目当前使用的核心业务表共 11 张，覆盖客户、订单、订单明细、支付、评价、商品、卖家和品类映射等主题。

核心表行数如下：

| table_name | row_cnt |
| --- | ---: |
| olist_closed_deals_dataset | 842 |
| olist_customers_dataset | 99,441 |
| olist_geolocation_dataset | 1,000,163 |
| olist_marketing_qualified_leads_dataset | 8,000 |
| olist_order_items_dataset | 112,650 |
| olist_order_payments_dataset | 103,886 |
| olist_order_reviews_dataset | 99,224 |
| olist_orders_dataset | 99,441 |
| olist_products_dataset | 32,951 |
| olist_sellers_dataset | 3,095 |
| product_category_name_translation | 71 |

## 2. 主键与关联检查

- `olist_orders_dataset.order_id` 唯一，订单主键可作为后续订单级分析基础。
- `olist_order_items_dataset` 需要使用复合主键 `(order_id, order_item_id)`。
- `olist_order_payments_dataset` 需要使用复合主键 `(order_id, payment_sequential)`。
- `orders -> customers` 的核心关联正常，未发现订单无法匹配客户的情况。

## 3. 订单金额口径检查

使用两种口径核对订单金额：

- 商品口径：`SUM(price + freight_value)`
- 支付口径：`SUM(payment_value)`

核对结果：

| metric | value |
| --- | ---: |
| diff_order_cnt | 303 |
| diff_order_rate_pct | 0.3071% |
| avg_diff_amount | -9.48 |
| min_diff_amount | -182.81 |
| max_diff_amount | 51.62 |

说明：

- 大部分订单金额口径一致。
- 共有 303 单存在差异，占有订单明细记录订单数的 `0.3071%`。
- 该差异规模不影响整体月度分析，但需要在异常分析中单独说明，可能与分期支付、补差、退款或数据记录方式有关。

## 4. 统一分析口径

后续所有经营分析统一采用以下口径：

- 订单范围：`order_status = 'delivered'`
- 金额口径：`SUM(payment_value)`
- 时间口径：`DATE_FORMAT(order_purchase_timestamp, '%Y-%m')`

原因：

- `payment_value` 更接近实际支付金额。
- `delivered` 能保证订单已完成履约，适合做稳定 GMV 与体验分析。
- 统一时间口径后，GMV、订单数、客单价、买家数等指标可以横向对齐。
