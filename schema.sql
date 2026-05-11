PRAGMA foreign_keys = ON;

-- =========================
-- MASTER DATA
-- =========================

DROP TABLE IF EXISTS ReturnItems;
DROP TABLE IF EXISTS Returns;
DROP TABLE IF EXISTS OrderPromotions;
DROP TABLE IF EXISTS Promotions;
DROP TABLE IF EXISTS Payments;
DROP TABLE IF EXISTS OrderItems;
DROP TABLE IF EXISTS Orders;
DROP TABLE IF EXISTS Products;
DROP TABLE IF EXISTS Categories;
DROP TABLE IF EXISTS Customers;
DROP TABLE IF EXISTS Stores;

CREATE TABLE Stores (
  store_id       INTEGER PRIMARY KEY AUTOINCREMENT,
  store_name     TEXT NOT NULL,
  plan_type      TEXT NOT NULL,                 -- Basic/Growth/Pro
  signup_date    TEXT NOT NULL,                 -- ISO date YYYY-MM-DD
  store_city     TEXT,
  store_country  TEXT,
  store_status   TEXT NOT NULL                  -- active/suspended/closed
);

CREATE TABLE Customers (
  customer_id      INTEGER PRIMARY KEY AUTOINCREMENT,
  first_name       TEXT NOT NULL,
  last_name        TEXT NOT NULL,
  email            TEXT NOT NULL UNIQUE,
  signup_date      TEXT NOT NULL,               -- ISO date
  customer_city    TEXT,
  customer_country TEXT,
  marketing_opt_in INTEGER NOT NULL DEFAULT 0   -- 0/1
);

CREATE TABLE Categories (
  category_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  category_name TEXT NOT NULL UNIQUE,
  category_desc TEXT
);

CREATE TABLE Products (
  product_id    INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id      INTEGER NOT NULL,
  category_id   INTEGER NOT NULL,
  product_name  TEXT NOT NULL,
  unit_price    NUMERIC NOT NULL CHECK(unit_price >= 0),
  unit_cost     NUMERIC NOT NULL CHECK(unit_cost >= 0),
  is_active     INTEGER NOT NULL DEFAULT 1,     -- 0/1
  created_date  TEXT NOT NULL,                  -- ISO date
  FOREIGN KEY (store_id) REFERENCES Stores(store_id),
  FOREIGN KEY (category_id) REFERENCES Categories(category_id)
);

-- =========================
-- TRANSACTIONS
-- =========================

CREATE TABLE Orders (
  order_id        INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id        INTEGER NOT NULL,
  customer_id     INTEGER NOT NULL,
  order_datetime  TEXT NOT NULL,                -- ISO datetime YYYY-MM-DD HH:MM:SS
  order_status    TEXT NOT NULL,                -- paid/shipped/delivered/cancelled
  shipping_fee    NUMERIC NOT NULL DEFAULT 0 CHECK(shipping_fee >= 0),
  tax_amount      NUMERIC NOT NULL DEFAULT 0 CHECK(tax_amount >= 0),
  order_subtotal  NUMERIC NOT NULL CHECK(order_subtotal >= 0),
  discount_total  NUMERIC NOT NULL DEFAULT 0 CHECK(discount_total >= 0),
  order_total     NUMERIC NOT NULL CHECK(order_total >= 0),
  FOREIGN KEY (store_id) REFERENCES Stores(store_id),
  FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
);

CREATE TABLE OrderItems (
  order_item_id           INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id                INTEGER NOT NULL,
  product_id              INTEGER NOT NULL,
  quantity                INTEGER NOT NULL CHECK(quantity > 0),
  unit_price_at_purchase  NUMERIC NOT NULL CHECK(unit_price_at_purchase >= 0),
  line_subtotal           NUMERIC NOT NULL CHECK(line_subtotal >= 0),
  line_discount           NUMERIC NOT NULL DEFAULT 0 CHECK(line_discount >= 0),
  line_total              NUMERIC NOT NULL CHECK(line_total >= 0),
  FOREIGN KEY (order_id) REFERENCES Orders(order_id),
  FOREIGN KEY (product_id) REFERENCES Products(product_id)
);

CREATE TABLE Payments (
  payment_id       INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id         INTEGER NOT NULL UNIQUE,     -- Enforces 1 payment per order
  payment_datetime TEXT NOT NULL,
  payment_method   TEXT NOT NULL,
  payment_status   TEXT NOT NULL,               -- succeeded/failed/refunded/partial_refund
  amount_paid      NUMERIC NOT NULL CHECK(amount_paid >= 0),
  currency         TEXT NOT NULL DEFAULT 'GBP',
  FOREIGN KEY (order_id) REFERENCES Orders(order_id)
);

-- =========================
-- PROMOTIONS (MULTI-PROMO)
-- =========================

CREATE TABLE Promotions (
  promo_id      INTEGER PRIMARY KEY AUTOINCREMENT,
  store_id      INTEGER NOT NULL,
  promo_code    TEXT NOT NULL UNIQUE,
  promo_type    TEXT NOT NULL,                  -- percent/fixed/free_shipping
  promo_value   NUMERIC NOT NULL CHECK(promo_value >= 0),
  min_spend     NUMERIC NOT NULL DEFAULT 0 CHECK(min_spend >= 0),
  start_date    TEXT NOT NULL,
  end_date      TEXT NOT NULL,
  promo_status  TEXT NOT NULL,                  -- active/expired/paused
  FOREIGN KEY (store_id) REFERENCES Stores(store_id)
);

CREATE TABLE OrderPromotions (
  order_promo_id          INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id                INTEGER NOT NULL,
  promo_id                INTEGER NOT NULL,
  discount_amount_applied NUMERIC NOT NULL CHECK(discount_amount_applied >= 0),
  applied_datetime        TEXT NOT NULL,
  FOREIGN KEY (order_id) REFERENCES Orders(order_id),
  FOREIGN KEY (promo_id) REFERENCES Promotions(promo_id),
  UNIQUE (order_id, promo_id)
);

-- =========================
-- RETURNS (PARTIAL RETURNS)
-- =========================

CREATE TABLE Returns (
  return_id            INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id             INTEGER NOT NULL,
  customer_id          INTEGER NOT NULL,
  return_request_date  TEXT NOT NULL,
  return_status        TEXT NOT NULL,           -- requested/approved/rejected/received/refunded
  return_reason_group  TEXT NOT NULL,           -- damaged/late/not_as_described/changed_mind
  refund_total         NUMERIC NOT NULL DEFAULT 0 CHECK(refund_total >= 0),
  FOREIGN KEY (order_id) REFERENCES Orders(order_id),
  FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
);

CREATE TABLE ReturnItems (
  return_item_id    INTEGER PRIMARY KEY AUTOINCREMENT,
  return_id         INTEGER NOT NULL,
  order_item_id     INTEGER NOT NULL,
  return_quantity   INTEGER NOT NULL CHECK(return_quantity > 0),
  refund_amount     NUMERIC NOT NULL CHECK(refund_amount >= 0),
  item_reason_detail TEXT,
  FOREIGN KEY (return_id) REFERENCES Returns(return_id),
  FOREIGN KEY (order_item_id) REFERENCES OrderItems(order_item_id)
);