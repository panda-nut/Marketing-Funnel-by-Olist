# category_performance

## 1. 类目 GMV 结构

按分摊后的支付金额计算，平台头部类目集中度较高。前 5 大类目贡献了约 `39.26%` 的类目 GMV。

| category_name | allocated_gmv | gmv_share_pct | delivered_order_cnt |
| --- | ---: | ---: | ---: |
| health_beauty | 1,412,038.44 | 9.16 | 8,646 |
| watches_gifts | 1,264,428.73 | 8.20 | 5,495 |
| bed_bath_table | 1,225,747.63 | 7.95 | 9,272 |
| sports_leisure | 1,118,357.52 | 7.25 | 7,530 |
| computers_accessories | 1,032,840.48 | 6.70 | 6,530 |
| furniture_decor | 880,548.08 | 5.71 | 6,307 |
| housewares | 758,480.71 | 4.92 | 5,743 |
| cool_stuff | 691,810.26 | 4.49 | 3,559 |
| auto | 669,470.86 | 4.34 | 3,810 |
| garden_tools | 567,209.44 | 3.68 | 3,448 |

## 2. 类目体验风险

按订单去重后的评价结果看，以下类目需要优先关注：

| category_name | delivered_order_cnt | avg_review_score | bad_review_rate_pct |
| --- | ---: | ---: | ---: |
| office_furniture | 1,254 | 3.64 | 21.95 |
| unknown | 1,392 | 4.01 | 17.51 |
| bed_bath_table | 9,272 | 4.00 | 16.04 |
| furniture_decor | 6,307 | 4.06 | 15.35 |
| computers_accessories | 6,530 | 4.08 | 14.56 |
| baby | 2,809 | 4.10 | 14.28 |
| telephony | 4,093 | 4.05 | 14.13 |

解读：

- `office_furniture` 评分最低，差评率最高，是最明确的高风险体验类目。
- `bed_bath_table` 和 `computers_accessories` 体量大、GMV高，但体验并不突出，优化收益最大。
- `unknown` 类目反映出一部分商品品类映射缺失，既影响分析精度，也影响运营归因。

## 3. 类目取消风险

在 `1000+` 订单量的类目中，取消率最高的主要有：

| category_name | total_order_cnt | canceled_order_cnt | cancel_rate_pct |
| --- | ---: | ---: | ---: |
| unknown | 1,451 | 14 | 0.96 |
| toys | 3,886 | 31 | 0.80 |
| consoles_games | 1,062 | 8 | 0.75 |
| housewares | 5,884 | 37 | 0.63 |
| auto | 3,897 | 24 | 0.62 |
| sports_leisure | 7,720 | 47 | 0.61 |
| computers_accessories | 6,689 | 35 | 0.52 |
| bed_bath_table | 9,417 | 18 | 0.19 |
| office_furniture | 1,273 | 1 | 0.08 |

解读：

- 整体取消率不高，类目问题更多体现在“交付后体验”而不是“交付前流失”。
- `office_furniture` 的取消率很低，但评分显著偏低，说明问题更像是商品质量、安装体验或运输破损。
- `unknown` 类目在取消和差评两个维度都偏高，优先级高。

## 4. 类目结论

- 平台收入主要由头部类目驱动，类目结构集中度较高。
- 优先优化应放在“高体量且体验一般”的类目，而不是只盯取消率最高的长尾类目。
- 最值得优先跟进的类目是 `bed_bath_table`、`computers_accessories`、`furniture_decor` 和 `office_furniture`。
