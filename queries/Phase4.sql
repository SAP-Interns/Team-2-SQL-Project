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
WITH matched_assignments AS (
    SELECT
        o.order_id,
        c.customer_name,
        o.sales_rep_id AS order_rep,
        rca.sales_rep_id AS assigned_rep,
        ROW_NUMBER() OVER (
            PARTITION BY o.order_id
            ORDER BY ad_start.full_date DESC
        ) AS rn
    FROM fact_sales_orders o
    JOIN dim_customers c
        ON o.customer_id = c.customer_id
    JOIN dim_date od
        ON o.order_date_id = od.date_id
    JOIN rep_customer_assignments rca
        ON o.customer_id = rca.customer_id
    JOIN dim_date ad_start
        ON rca.start_date_id = ad_start.date_id
    LEFT JOIN dim_date ad_end
        ON rca.end_date_id = ad_end.date_id
    WHERE od.full_date >= ad_start.full_date
      AND (ad_end.full_date IS NULL OR od.full_date <= ad_end.full_date)
)
SELECT
    order_id,
    customer_name,
    order_rep,
    assigned_rep
FROM matched_assignments
WHERE rn = 1
  AND order_rep <> assigned_rep;

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
WHERE p.is_active = 1
AND NOT EXISTS (
    SELECT 1
    FROM fact_order_line_items oli
    JOIN fact_sales_orders o
        ON oli.order_id = o.order_id
    JOIN dim_date d
        ON o.order_date_id = d.date_id
    WHERE oli.product_id = p.product_id
      AND d.full_date >= DATEADD(MONTH, -12, GETDATE())
);

  
/* Phase 4 Query 1: Revenue by Geography
   Calculate total sales revenue across the geographic hierarchy by joining orders, line items, and regions, 
   while also generating subtotal rows at the country and region levels and a grand total for overall revenue.
*/
/*4.Revenue by Geography: Join orders, customers, and regions to produce a complete revenue
breakdown at Country → Region → Territory level, including subtotals.    */
SELECT
    COALESCE(c.country_name, 'ALL COUNTRIES') AS country_name,
    COALESCE(r.region_name, 'ALL REGIONS') AS region_name,
    COALESCE(r.territory_name, 'ALL TERRITORIES') AS territory_name,
    SUM(oli.line_total) AS total_revenue
FROM fact_sales_orders o
JOIN fact_order_line_items oli
    ON o.order_id = oli.order_id
JOIN dim_customers c
    ON o.customer_id = c.customer_id
JOIN dim_regions r
    ON o.region_id = r.region_id
GROUP BY ROLLUP (
    c.country_name,
    r.region_name,
    r.territory_name
)
ORDER BY
    c.country_name,
    r.region_name;



/* Phase 4 Query 2 – Product Cost vs Actual Sell Price
   Compare the actual selling price per unit on each order line with the product’s 
   standard unit cost in order to measure realized unit margin.
*/
SELECT
    oli.line_item_id,
    oli.order_id,
    p.product_name,
    p.sku,
    cat.category_name,
    oli.quantity,
    p.unit_cost,
    CAST(oli.line_total / NULLIF(oli.quantity, 0) AS DECIMAL(10,2)) AS actual_unit_sell_price,
    CAST(
        (oli.line_total / NULLIF(oli.quantity, 0)) - p.unit_cost
        AS DECIMAL(10,2)
    ) AS unit_margin
FROM dbo.fact_order_line_items AS oli
INNER JOIN dbo.dim_products AS p
    ON oli.product_id = p.product_id
INNER JOIN dbo.dim_categories AS cat
    ON p.category_id = cat.category_id
ORDER BY
    unit_margin DESC,
    p.product_name ASC;


/* Customer Order Performance Summary:
   Join customers, orders, order line items, regions, and sales reps
   to show total orders, total quantity purchased, and total revenue per customer. */
SELECT
    c.customer_id,
    c.customer_name,
    c.country_name,
    r.region_name,
    sr.first_name,
    sr.last_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oli.quantity) AS total_quantity_purchased,
    SUM(oli.line_total) AS total_revenue
FROM dim_customers c
JOIN fact_sales_orders o
    ON c.customer_id = o.customer_id
JOIN fact_order_line_items oli
    ON o.order_id = oli.order_id
JOIN dim_regions r
    ON o.region_id = r.region_id
JOIN dim_sales_reps sr
    ON o.sales_rep_id = sr.sales_rep_id
GROUP BY
    c.customer_id,
    c.customer_name,
    c.country_name,
    r.region_name,
    sr.first_name,
    sr.last_name
ORDER BY total_revenue DESC;

/* Returns Analysis by Product and Region:
   Join returns, order line items, products, orders, and regions
   to identify returned products and estimate their financial impact by region. */
SELECT
    p.product_id,
    p.product_name,
    r.region_name,
    COUNT(fr.return_id) AS total_returns,
    SUM(fr.return_quantity) AS total_returned_quantity,
    SUM(
        (oli.line_total * 1.0 / NULLIF(oli.quantity, 0)) * fr.return_quantity
    ) AS estimated_return_value
FROM fact_returns fr
JOIN fact_order_line_items oli
    ON fr.line_item_id = oli.line_item_id
JOIN dim_products p
    ON oli.product_id = p.product_id
JOIN fact_sales_orders o
    ON oli.order_id = o.order_id
JOIN dim_regions r
    ON o.region_id = r.region_id
GROUP BY
    p.product_id,
    p.product_name,
    r.region_name
ORDER BY estimated_return_value DESC;