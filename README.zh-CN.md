# WeDeliver 电商数据库分析项目

本仓库是一个学术小组项目整理后的作品集版本，项目对象是一个虚构的电商赋能平台 **WeDeliver**。项目展示了从业务理解、关系型数据库设计、合成数据生成、SQL 数据验证到商业分析的完整流程。

WeDeliver 可以理解为类似 Shopify 的平台：独立商家可以在平台上开设线上店铺、上传商品、处理订单、设置促销活动，并管理客户退货与退款。

## 项目概览

本项目围绕一个完整的数据分析工作流展开：

1. 定义业务场景和需要回答的商业问题。
2. 设计关系型数据库结构，包括主键、外键、约束和中间表。
3. 使用 Python 和 Faker 生成模拟电商交易数据。
4. 使用 SQL 对数据库进行完整性和一致性验证。
5. 使用 SQL 分析销售表现、客户行为、促销效果、退货率和利润表现。

## 数据库设计

数据库共包含 11 张主要表：

- `Stores`：商家信息
- `Customers`：客户信息
- `Categories`：商品类别
- `Products`：商品信息
- `Orders`：订单主表
- `OrderItems`：订单明细
- `Payments`：支付记录
- `Promotions`：促销活动
- `OrderPromotions`：订单和促销的关联表
- `Returns`：退货记录
- `ReturnItems`：退货明细

关键设计思路：

- `Orders` 和 `OrderItems` 分开，区分订单层面信息和商品明细信息。
- `OrderPromotions` 用于处理订单和促销之间的多对多关系。
- `Returns` 和 `ReturnItems` 分开，支持部分退货和商品级别退款分析。
- `unit_price_at_purchase` 用于保留商品购买当时的历史价格，避免商品后续调价影响历史订单分析。
- `Payments.order_id` 设置唯一约束，用于表达一个订单对应一条支付记录。

## 合成数据生成

项目使用 Python 的 `sqlite3`、`random` 和 `Faker` 库生成模拟交易数据。

大致数据规模如下：

| 表名 | 记录数 |
|---|---:|
| Stores | 500 |
| Customers | 5,000 |
| Categories | 40 |
| Products | 8,000 |
| Orders | 20,000 |
| OrderItems | 50,000+ |
| Payments | 20,000 |
| Promotions | 1,200 |
| Returns | 1,300+ |
| ReturnItems | 1,600+ |

数据生成时按照父表到子表的顺序插入数据，例如先生成商家、客户和商品，再生成订单、订单明细、支付和退货，从而保证外键关系的有效性。

## 数据验证

在进行商业分析前，项目使用 SQL 进行了数据质量检查，包括：

- 核心表记录数检查
- 外键关系检查
- 孤立记录检查
- 每个订单是否有支付记录
- 支付记录和客户邮箱是否存在重复
- 退货总金额是否等于退货明细金额加总
- 退款金额是否超过原支付金额

这些检查用于确保后续 SQL 分析建立在可靠的数据基础上。

## 商业分析问题

SQL 分析主要围绕以下六个问题展开：

1. 哪些商家的单均毛利最高？
2. 不同客户分层的平均订单金额和促销使用情况有何差异？
3. 哪些促销活动存在较高的折扣成本或叠加风险？
4. 使用促销和不使用促销的订单在平均订单金额上有何差异？
5. 哪些商品退货率较高，退款对利润有什么影响？
6. 扣除商品成本、促销折扣和退款后，哪些品类的净贡献利润较低？

## 文件结构

```text
.
├── README.md
├── README.zh-CN.md
├── schema.sql
├── data_generation.py
├── validation_checks.sql
├── analysis_queries.sql
├── docs/
│   └── er_diagram.jpeg
└── sample_outputs/
    └── query_results_summary.md
```

## 运行方式

安装依赖：

```bash
pip install -r requirements.txt
```

生成 SQLite 数据库：

```bash
python data_generation.py
```

运行验证和分析 SQL：

```bash
sqlite3 wedeliver.db < validation_checks.sql
sqlite3 wedeliver.db < analysis_queries.sql
```

也可以使用 DB Browser for SQLite 或其他支持 SQLite 的工具运行这些 SQL 文件。

## 我的贡献

这是一个学术小组项目。我主要参与了前期业务理解、mini-world 定义、商业问题梳理和数据库设计逻辑说明，并围绕商家利润、客户分层、促销效果、退货率和品类贡献利润等问题进行了 SQL 查询探索。

在整理作品集版本时，我重新复盘了完整项目流程，包括 ERD 设计、SQLite schema、Python/Faker 合成数据生成、SQL 数据验证和商业分析查询。这个仓库用于展示我对关系型数据库设计、数据质量验证和 SQL 商业分析流程的理解。

