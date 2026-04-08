 1.月度GMV(以“月”为聚度看交易)

o.order_status描述状态是在olist_orders_dataset o
payment_value是在olist_order_payments_dataset p (一次JOIN)
```sql
SELECT 
    DATE_FORMATE(order_purchase_timestamp, '%Y-%m') AS month,
    SUM(payment_value) AS monthly_gmv
FROM olist_orders_dataset o
JOIN olist_order_payments_dataset p
    ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
```
基于上述代码做些许变动完成以下功能

- 月度已交付订单趋势

- 月度取消率(SUM(CASE WHEN))

2.月度滚动(在月度GMV的基础上,增加环比分析)

上一步的GMV数据直接用WITH进行打包,再使用窗口函数实现时间的滚动,LAG OVER(ORDER BY month)
```sql
ROUND(
        monthly_gmv - LAG(monthly_gmv) OVER (ORDER BY month),2) AS mom_change,
ROUND((
            monthly_gmv - LAG(monthly_gmv) OVER (ORDER BY month)
        ) / LAG(monthly_gmv) OVER (ORDER BY month) * 100,2) AS mom_growth_rate_pct
```

