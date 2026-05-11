# WeDeliver SQL Database Analytics Project

[中文版 README](README.zh-CN.md)

This repository is a cleaned portfolio version of an academic group project for a fictional e-commerce enablement platform called **WeDeliver**. The project demonstrates relational database design, synthetic data generation, SQL validation, and business analysis using SQLite and Python.

WeDeliver is modelled as a Shopify-style platform where independent stores list products, customers place orders, payments are processed, promotions are applied, and products can be returned after purchase.

## Project Scope

The project follows a full database workflow:

1. Define the business mini-world and analytical questions.
2. Design a relational database schema with primary keys, foreign keys, constraints, and junction tables.
3. Generate synthetic e-commerce transaction data using Python and Faker.
4. Validate database quality using SQL integrity checks.
5. Write SQL queries to answer business questions about margin, promotion effectiveness, customer behaviour, and returns.

## Database Design

The schema contains 11 main tables:

- `Stores`
- `Customers`
- `Categories`
- `Products`
- `Orders`
- `OrderItems`
- `Payments`
- `Promotions`
- `OrderPromotions`
- `Returns`
- `ReturnItems`

Key modelling choices include:

- `OrderItems` separates order-level records from item-level purchase details.
- `OrderPromotions` resolves the many-to-many relationship between orders and promotions.
- `Returns` and `ReturnItems` support partial returns and item-level refund tracking.
- `unit_price_at_purchase` preserves historical pricing at the time of purchase.
- `Payments.order_id` is unique to enforce one payment record per order.

## Synthetic Data

The data generation script creates a realistic synthetic dataset using Python's `sqlite3`, `random`, and `Faker` libraries.

Approximate generated volumes:

| Table | Rows |
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

The script inserts parent tables before child tables to preserve referential integrity.

## Validation Checks

The database is validated through SQL checks covering:

- Record counts for core entities
- Foreign key enforcement
- Orphan child records
- One payment per order
- Refund totals matching item-level refund sums
- Duplicate emails and duplicate payment records

## Business Analysis

The SQL analysis focuses on six business questions:

1. Which stores generate the highest gross margin per order?
2. How does average order value differ across customer segments?
3. Which promotions create discount-to-revenue or stacking risk?
4. How does AOV compare between promoted and non-promoted orders?
5. Which products have the highest return rates and refund impact?
6. Which categories are at risk after discounts and refunds?

## Repository Structure

```text
.
├── README.md
├── schema.sql
├── data_generation.py
├── validation_checks.sql
├── analysis_queries.sql
├── docs/
│   └── er_diagram.jpeg
└── sample_outputs/
    └── query_results_summary.md
```

## How To Run

Install dependencies:

```bash
pip install faker
```

Generate the SQLite database:

```bash
python data_generation.py
```

Run SQL files in DB Browser for SQLite, the SQLite command line, or any SQLite-compatible SQL environment:

```bash
sqlite3 wedeliver.db < validation_checks.sql
sqlite3 wedeliver.db < analysis_queries.sql
```

## My Contribution

I contributed to the business understanding and database design rationale, including the mini-world definition, business questions, and explanation of key relational modelling choices. I also explored SQL queries for store margin, customer segmentation, promotion effectiveness, returns, and net contribution analysis. This cleaned repository reflects my understanding of the full workflow from ERD design and schema implementation to synthetic data generation, validation, and SQL-based business reporting.
