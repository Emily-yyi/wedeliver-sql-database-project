# Query Results Summary

This file summarises the intended business interpretation of the SQL analysis queries.

## Q1. Store Gross Margin Per Order

This query identifies stores with strong commercial performance by calculating revenue, product cost, gross margin, gross margin per order, and margin percentage. It filters to stores with at least 20 orders to avoid ranking stores with too little transaction volume.

## Q2. Customer Segmentation and Promotion Usage

Customers are segmented by order frequency:

- One-Time: 1 order
- Occasional: 2-5 orders
- Repeat: 6+ orders

The query compares average order value and promotion usage across these segments.

## Q3. Promotion Discount-to-Revenue Ratio

This query ranks promotions by the proportion of order subtotal given away as discount. It helps identify promotions that may be expensive relative to the revenue they support.

## Q4. Promotional Stacking Risk

This query flags orders where multiple promotions were applied and the combined discount exceeded 30% of the order subtotal. These orders may create margin leakage.

## Q5. Product Return Rates and Refund Impact

This query calculates units sold, units returned, return rate, gross margin before refunds, refund cost, and net margin after refunds. It helps identify products where returns materially reduce profitability.

## Q6. Category Net Contribution Margin

This query estimates net category contribution by subtracting product cost, allocated promotional discounts, and refunds from category revenue. Categories below a 30% net margin threshold are flagged as at risk.
