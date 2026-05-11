-- Q1. Store-level gross margin per order.
WITH store_fin AS (
  SELECT
    s.store_id,
    s.store_name,
    COUNT(DISTINCT o.order_id) AS orders,
    SUM(oi.line_total) AS revenue,
    SUM(oi.quantity * p.unit_cost) AS cost,
    SUM(oi.line_total - oi.quantity * p.unit_cost) AS gross_margin
  FROM Stores s
  JOIN Orders o ON o.store_id = s.store_id
  JOIN OrderItems oi ON oi.order_id = o.order_id
  JOIN Products p ON p.product_id = oi.product_id
  WHERE o.order_status <> 'cancelled'
  GROUP BY s.store_id, s.store_name
)
SELECT
  store_name,
  orders,
  ROUND(revenue, 2) AS total_revenue,
  ROUND(cost, 2) AS total_cost,
  ROUND(gross_margin, 2) AS total_gross_margin,
  ROUND(gross_margin / NULLIF(orders, 0), 2) AS gross_margin_per_order,
  ROUND(100.0 * gross_margin / NULLIF(revenue, 0), 2) AS margin_pct
FROM store_fin
WHERE orders >= 20 AND gross_margin > 0
ORDER BY gross_margin_per_order DESC
LIMIT 20;

-- Q2. Average order value by customer segment and promotion usage.
WITH customer_segments AS (
  SELECT
    customer_id,
    CASE
      WHEN COUNT(*) = 1 THEN 'One-Time'
      WHEN COUNT(*) BETWEEN 2 AND 5 THEN 'Occasional'
      ELSE 'Repeat'
    END AS customer_segment
  FROM Orders
  WHERE order_status <> 'cancelled'
  GROUP BY customer_id
),
orders_with_promo AS (
  SELECT
    o.order_id,
    o.customer_id,
    o.order_total,
    COUNT(op.promo_id) AS promos_used,
    CASE WHEN COUNT(op.promo_id) > 0 THEN 1 ELSE 0 END AS used_any_promo
  FROM Orders o
  LEFT JOIN OrderPromotions op ON op.order_id = o.order_id
  WHERE o.order_status <> 'cancelled'
  GROUP BY o.order_id, o.customer_id, o.order_total
)
SELECT
  cs.customer_segment,
  COUNT(DISTINCT ow.customer_id) AS customers,
  COUNT(*) AS orders,
  ROUND(AVG(ow.order_total), 2) AS avg_order_value,
  ROUND(AVG(ow.promos_used), 2) AS avg_promos_per_order,
  ROUND(100.0 * AVG(ow.used_any_promo), 2) AS pct_orders_with_promo
FROM orders_with_promo ow
JOIN customer_segments cs ON cs.customer_id = ow.customer_id
GROUP BY cs.customer_segment
ORDER BY
  CASE cs.customer_segment
    WHEN 'One-Time' THEN 1
    WHEN 'Occasional' THEN 2
    ELSE 3
  END;

-- Q3. Promotion discount-to-revenue ratio.
WITH order_discount AS (
  SELECT
    o.order_id,
    o.order_subtotal,
    SUM(op.discount_amount_applied) AS total_discount
  FROM Orders o
  JOIN OrderPromotions op ON op.order_id = o.order_id
  WHERE o.order_status <> 'cancelled'
  GROUP BY o.order_id, o.order_subtotal
),
promo_perf AS (
  SELECT
    pr.promo_id,
    pr.promo_code,
    pr.promo_type,
    COUNT(DISTINCT op.order_id) AS orders_using_promo,
    ROUND(SUM(op.discount_amount_applied), 2) AS total_discount_given,
    ROUND(SUM(od.order_subtotal), 2) AS subtotal_on_orders,
    ROUND(100.0 * SUM(op.discount_amount_applied) / NULLIF(SUM(od.order_subtotal), 0), 2) AS discount_to_revenue_pct
  FROM OrderPromotions op
  JOIN Promotions pr ON pr.promo_id = op.promo_id
  JOIN order_discount od ON od.order_id = op.order_id
  GROUP BY pr.promo_id, pr.promo_code, pr.promo_type
)
SELECT *
FROM promo_perf
ORDER BY discount_to_revenue_pct DESC
LIMIT 20;

-- Q4. Promotional stacking risk.
WITH order_discount AS (
  SELECT
    o.order_id,
    o.order_subtotal,
    SUM(op.discount_amount_applied) AS total_discount,
    COUNT(op.promo_id) AS promos_applied
  FROM Orders o
  JOIN OrderPromotions op ON op.order_id = o.order_id
  WHERE o.order_status <> 'cancelled'
  GROUP BY o.order_id, o.order_subtotal
)
SELECT
  COUNT(*) AS high_risk_orders,
  ROUND(AVG(total_discount), 2) AS avg_discount_amount,
  ROUND(AVG(100.0 * total_discount / NULLIF(order_subtotal, 0)), 2) AS avg_discount_pct
FROM order_discount
WHERE promos_applied > 1
  AND total_discount > 0.30 * order_subtotal;

-- Q5. Product return rates and net margin after refunds.
WITH product_sales AS (
  SELECT
    oi.product_id,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.line_total) AS revenue,
    SUM(oi.quantity * p.unit_cost) AS cost,
    SUM(oi.line_total - oi.quantity * p.unit_cost) AS gross_margin
  FROM OrderItems oi
  JOIN Orders o ON o.order_id = oi.order_id
  JOIN Products p ON p.product_id = oi.product_id
  WHERE o.order_status <> 'cancelled'
  GROUP BY oi.product_id
),
product_returns AS (
  SELECT
    oi.product_id,
    SUM(ri.return_quantity) AS units_returned,
    SUM(ri.refund_amount) AS refunds
  FROM ReturnItems ri
  JOIN OrderItems oi ON oi.order_item_id = ri.order_item_id
  JOIN Returns r ON r.return_id = ri.return_id
  WHERE r.return_status IN ('approved', 'received', 'refunded')
  GROUP BY oi.product_id
)
SELECT
  prd.product_id,
  prd.product_name,
  ps.units_sold,
  COALESCE(rt.units_returned, 0) AS units_returned,
  ROUND(100.0 * COALESCE(rt.units_returned, 0) / NULLIF(ps.units_sold, 0), 2) AS return_rate_pct,
  ROUND(ps.gross_margin, 2) AS gross_margin_before_refunds,
  ROUND(COALESCE(rt.refunds, 0), 2) AS total_refunds,
  ROUND(ps.gross_margin - COALESCE(rt.refunds, 0), 2) AS net_margin_after_refunds
FROM product_sales ps
JOIN Products prd ON prd.product_id = ps.product_id
LEFT JOIN product_returns rt ON rt.product_id = ps.product_id
WHERE ps.units_sold >= 30
ORDER BY return_rate_pct DESC
LIMIT 20;

-- Q6. Category net contribution margin after discounts and refunds.
WITH order_cat AS (
  SELECT
    o.order_id,
    c.category_id,
    c.category_name,
    SUM(oi.line_total) AS cat_revenue,
    SUM(oi.quantity * p.unit_cost) AS cat_cost
  FROM Orders o
  JOIN OrderItems oi ON oi.order_id = o.order_id
  JOIN Products p ON p.product_id = oi.product_id
  JOIN Categories c ON c.category_id = p.category_id
  WHERE o.order_status <> 'cancelled'
  GROUP BY o.order_id, c.category_id, c.category_name
),
order_tot AS (
  SELECT order_id, SUM(cat_revenue) AS order_revenue
  FROM order_cat
  GROUP BY order_id
),
order_disc AS (
  SELECT
    o.order_id,
    COALESCE(SUM(op.discount_amount_applied), 0) AS promo_discount
  FROM Orders o
  LEFT JOIN OrderPromotions op ON op.order_id = o.order_id
  WHERE o.order_status <> 'cancelled'
  GROUP BY o.order_id
),
cat_alloc AS (
  SELECT
    oc.category_id,
    oc.category_name,
    oc.cat_revenue,
    oc.cat_cost,
    od.promo_discount * (oc.cat_revenue / NULLIF(ot.order_revenue, 0)) AS allocated_promo_discount
  FROM order_cat oc
  JOIN order_tot ot ON ot.order_id = oc.order_id
  JOIN order_disc od ON od.order_id = oc.order_id
),
cat_refunds AS (
  SELECT
    c.category_id,
    SUM(ri.refund_amount) AS refunds
  FROM ReturnItems ri
  JOIN Returns r ON r.return_id = ri.return_id
  JOIN OrderItems oi ON oi.order_item_id = ri.order_item_id
  JOIN Products p ON p.product_id = oi.product_id
  JOIN Categories c ON c.category_id = p.category_id
  WHERE r.return_status IN ('approved', 'received', 'refunded')
  GROUP BY c.category_id
),
cat_summary AS (
  SELECT
    ca.category_id,
    ca.category_name,
    SUM(ca.cat_revenue) AS gross_revenue,
    SUM(ca.cat_cost) AS total_cost,
    SUM(ca.allocated_promo_discount) AS promo_discounts_allocated,
    COALESCE(cr.refunds, 0) AS refunds,
    SUM(ca.cat_revenue) - SUM(ca.cat_cost) - SUM(ca.allocated_promo_discount) - COALESCE(cr.refunds, 0) AS net_contribution_margin
  FROM cat_alloc ca
  LEFT JOIN cat_refunds cr ON cr.category_id = ca.category_id
  GROUP BY ca.category_id, ca.category_name
)
SELECT
  category_name,
  ROUND(gross_revenue, 2) AS gross_revenue,
  ROUND(total_cost, 2) AS total_cost,
  ROUND(promo_discounts_allocated, 2) AS promo_discounts_allocated,
  ROUND(refunds, 2) AS refunds,
  ROUND(net_contribution_margin, 2) AS net_contribution_margin,
  ROUND(100.0 * net_contribution_margin / NULLIF(gross_revenue, 0), 2) AS net_margin_pct,
  CASE
    WHEN 100.0 * net_contribution_margin / NULLIF(gross_revenue, 0) < 30 THEN 'At Risk'
    ELSE 'Healthy'
  END AS margin_status
FROM cat_summary
ORDER BY net_margin_pct ASC;
