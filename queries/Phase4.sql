/* Full Order Summary: Write a query that joins orders, line items, customers, products, regions,
and sales reps into a single result set, producing a complete order line record with all business-
relevant attributes. This query will form the foundation of the reporting layer.  */
SELECT
    o.order_id,
    c.customer_name,
    c.country_name,
    r.region_name,
    sr.first_name,
    sr.last_name,
    p.product_name,
    oli.quantity,
    oli.unit_price,
    oli.discount_amount,
    oli.line_total
FROM fact_sales_orders o
INNER JOIN fact_order_line_items oli
    ON o.order_id = oli.order_id
INNER JOIN dim_customers c
    ON o.customer_id = c.customer_id
INNER JOIN dim_products p
    ON oli.product_id = p.product_id
INNER JOIN dim_regions r
    ON o.region_id = r.region_id
INNER JOIN dim_sales_reps sr
    ON o.sales_rep_id = sr.sales_rep_id;

/*Orphan Detection: Using LEFT JOIN, identify any customer records that exist in dim_customers
but have never placed an order. These are dormant accounts that require a sales follow-up. */
SELECT
    c.customer_id,
    c.customer_name
FROM dim_customers c
LEFT JOIN fact_sales_orders o
    ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;

/*Rep-Customer Mismatch: Identify all orders where the sales rep who processed the order is not
the assigned rep for that customer account according to the rep_customer_assignments table. */
WITH latest_assignment AS (
    SELECT
        rca.customer_id,
        rca.sales_rep_id,
        ROW_NUMBER() OVER (
            PARTITION BY rca.customer_id
            ORDER BY rca.start_date_id DESC
        ) AS rn
    FROM rep_customer_assignments rca
)
SELECT
    o.order_id,
    c.customer_name,
    o.sales_rep_id AS order_rep,
    la.sales_rep_id AS assigned_rep
FROM fact_sales_orders o
JOIN dim_customers c
    ON o.customer_id = c.customer_id
JOIN latest_assignment la
    ON o.customer_id = la.customer_id
   AND la.rn = 1
WHERE o.sales_rep_id <> la.sales_rep_id;

/*Revenue by Geography: Join orders, customers, and regions to produce a complete revenue
breakdown at Country → Region → Territory level, including subtotals.    */
SELECT
    c.country_name,
    r.region_name,
    r.territory_name,
    SUM(oli.line_total) AS total_revenue
FROM fact_sales_orders o
JOIN fact_order_line_items oli
    ON o.order_id = oli.order_id
JOIN dim_customers c
    ON o.customer_id = c.customer_id
JOIN dim_regions r
    ON o.region_id = r.region_id
GROUP BY
    c.country_name,
    r.region_name,
    r.territory_name
ORDER BY
    c.country_name,
    r.region_name;

/*Product Cost vs. Actual Sell Price: Join order line items with products to compute the realized
margin on every line item, comparing the actual sell price (after discount) against the product&#39;s
unit cost.*/
SELECT
    p.product_name,
    oli.quantity,
    oli.unit_price,
    oli.discount_amount,
    oli.line_total AS actual_price,
    p.unit_cost,
    (oli.line_total - (oli.quantity * p.unit_cost)) AS profit
FROM fact_order_line_items oli
JOIN dim_products p
    ON oli.product_id = p.product_id;

/*Unordered Products: Identify all active products that appear in dim_products but have not
appeared in any order line item in the last 12 months. These are candidates for discontinuation.*/
SELECT
    p.product_id,
    p.product_name
FROM dim_products p
LEFT JOIN fact_order_line_items oli
    ON p.product_id = oli.product_id
LEFT JOIN fact_sales_orders o
    ON oli.order_id = o.order_id
LEFT JOIN dim_date d
    ON o.order_date_id = d.date_id
    AND d.full_date >= DATEADD(MONTH, -12, GETDATE())
WHERE d.date_id IS NULL
  AND p.is_active = 1;