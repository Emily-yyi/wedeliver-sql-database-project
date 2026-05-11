PRAGMA foreign_keys = ON;

-- 1. Record counts for all core tables.
SELECT 'Stores' AS table_name, COUNT(*) AS row_count FROM Stores
UNION ALL SELECT 'Customers', COUNT(*) FROM Customers
UNION ALL SELECT 'Categories', COUNT(*) FROM Categories
UNION ALL SELECT 'Products', COUNT(*) FROM Products
UNION ALL SELECT 'Orders', COUNT(*) FROM Orders
UNION ALL SELECT 'OrderItems', COUNT(*) FROM OrderItems
UNION ALL SELECT 'Payments', COUNT(*) FROM Payments
UNION ALL SELECT 'Promotions', COUNT(*) FROM Promotions
UNION ALL SELECT 'OrderPromotions', COUNT(*) FROM OrderPromotions
UNION ALL SELECT 'Returns', COUNT(*) FROM Returns
UNION ALL SELECT 'ReturnItems', COUNT(*) FROM ReturnItems;

-- 2. Check for products without valid parent stores.
SELECT COUNT(*) AS orphan_products_stores
FROM Products p
LEFT JOIN Stores s ON p.store_id = s.store_id
WHERE s.store_id IS NULL;

-- 3. Check for orders without valid parent customers or stores.
SELECT COUNT(*) AS orphan_orders_customers
FROM Orders o
LEFT JOIN Customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

SELECT COUNT(*) AS orphan_orders_stores
FROM Orders o
LEFT JOIN Stores s ON o.store_id = s.store_id
WHERE s.store_id IS NULL;

-- 4. Check for order items without valid parent orders or products.
SELECT COUNT(*) AS orphan_orderitems_orders
FROM OrderItems oi
LEFT JOIN Orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT COUNT(*) AS orphan_orderitems_products
FROM OrderItems oi
LEFT JOIN Products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- 5. One payment per order checks.
SELECT COUNT(*) AS orders_without_payment
FROM Orders o
LEFT JOIN Payments p ON p.order_id = o.order_id
WHERE p.order_id IS NULL;

SELECT COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_payment_order_ids
FROM Payments;

-- 6. Refund header total should match item-level refund totals.
SELECT COUNT(*) AS refund_total_mismatches
FROM (
  SELECT
    r.return_id,
    ROUND(r.refund_total, 2) AS refund_total,
    ROUND(COALESCE(SUM(ri.refund_amount), 0), 2) AS item_refund_total
  FROM Returns r
  LEFT JOIN ReturnItems ri ON ri.return_id = r.return_id
  GROUP BY r.return_id
  HAVING ABS(refund_total - item_refund_total) > 0.01
);

-- 7. Refund should not exceed amount paid.
SELECT COUNT(*) AS refunds_exceeding_amount_paid
FROM Returns r
JOIN Payments p ON p.order_id = r.order_id
WHERE r.refund_total > p.amount_paid;

-- 8. Customer emails should be unique.
SELECT COUNT(*) - COUNT(DISTINCT email) AS duplicate_customer_emails
FROM Customers;
