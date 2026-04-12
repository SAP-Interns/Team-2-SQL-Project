/* SELECT with column aliases */
select region_id as id,
       region_name as name
from dim_regions;

/* WHERE clause with comparison operators */
select * from dim_regions
where region_name = 'America';

/* BETWEEN clause */
select * from dim_customers
where created_at between '2023-09-09' and '2026-01-31';

/* IN clause */
select * from dim_date
where year_num in (2022, 2023, 2024);

/* LIKE clause */
select * from dim_sales_reps
where first_name like 'A%';

/* IS NULL clause */
select * from dim_customers
where postal_code is null;

/* ORDER BY with multi-column sorting */
select first_name, last_name, status
from dim_sales_reps
order by first_name asc, last_name desc;

/* LIMIT / FETCH  */
select top 10 *
from dim_customers;

/* Product price ranking by category */
SELECT
    product_id,
    product_name,
    category_id,
    list_price,
    unit_cost,
    RANK() OVER (
        PARTITION BY category_id
        ORDER BY list_price DESC
    ) AS price_rank_in_category
FROM dim_products
WHERE is_active = 1;

/* Product gross margin analysis */
SELECT
    product_id,
    product_name,
    category_id,
    unit_cost,
    list_price,
    (list_price - unit_cost) AS gross_profit,
    ROUND(((list_price - unit_cost) / NULLIF(list_price, 0)) * 100, 2) AS gross_margin_pct,
    CASE
        WHEN ((list_price - unit_cost) / NULLIF(list_price, 0)) * 100 >= 60 THEN 'High Margin'
        WHEN ((list_price - unit_cost) / NULLIF(list_price, 0)) * 100 >= 30 THEN 'Medium Margin'
        ELSE 'Low Margin'
    END AS margin_category
FROM dim_products
WHERE is_active = 1
ORDER BY gross_margin_pct DESC;

/* Discount impact per product */
SELECT
    product_id,
    SUM(discount_amount) AS total_discount,
    SUM(line_total) AS total_revenue,
    ROUND(SUM(discount_amount) / NULLIF(SUM(line_total), 0) * 100, 2) AS discount_impact_pct,
    CASE
        WHEN SUM(discount_amount) / NULLIF(SUM(line_total), 0) > 0.2 THEN 'High Discount'
        WHEN SUM(discount_amount) / NULLIF(SUM(line_total), 0) > 0.1 THEN 'Medium Discount'
        ELSE 'Low Discount'
    END AS discount_level
FROM fact_order_line_items
GROUP BY product_id
ORDER BY total_revenue DESC;

/* Sales summary per product */
SELECT
    product_id,
    COUNT(*) AS total_items_sold,
    SUM(quantity) AS total_quantity,
    SUM(line_total) AS total_revenue
FROM fact_order_line_items
GROUP BY product_id
ORDER BY total_revenue DESC;

/* =========================
   Phase 1 – Validation Queries
   ========================= */

/* Phase 1 Validation Query 1: Inspect high-credit customer records and validate key customer fields 
   Inspect high-credit customer records while also validating whether important customer dimension fields 
   are complete and logically valid.
*/
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_code,
    c.billing_address,
    c.city,
    c.country_name,
    c.credit_limit,
    c.account_tier,
    CASE
        WHEN c.customer_code IS NULL OR LTRIM(RTRIM(c.customer_code)) = '' THEN 'Missing customer code'
        WHEN c.customer_name IS NULL OR LTRIM(RTRIM(c.customer_name)) = '' THEN 'Missing customer name'
        WHEN c.country_name IS NULL OR LTRIM(RTRIM(c.country_name)) = '' THEN 'Missing country'
        WHEN c.credit_limit IS NULL THEN 'Missing credit limit'
        WHEN c.credit_limit < 0 THEN 'Invalid credit limit'
        ELSE 'Valid'
    END AS validation_status
FROM dbo.dim_customers AS c
WHERE c.credit_limit > 45000
ORDER BY
    c.credit_limit DESC,
    c.customer_name ASC;

/* Phase 1 Validation Query 2: Inspect high-value sales orders and validate key order fields   
   Inspect high-value sales orders while also validating whether key transactional fields 
   are present and logically usable for later analysis.
*/
SELECT
    o.order_id,
    o.order_number,
    o.customer_id,
    o.sales_rep_id,
    o.order_status,
    o.net_total,
    o.order_date_id,
    CASE
        WHEN o.customer_id IS NULL THEN 'Missing customer'
        WHEN o.sales_rep_id IS NULL THEN 'Missing sales rep'
        WHEN o.order_date_id IS NULL THEN 'Missing date reference'
        WHEN o.net_total IS NULL THEN 'Missing net total'
        WHEN o.net_total <= 0 THEN 'Invalid total'
        ELSE 'Valid'
    END AS validation_status
FROM dbo.fact_sales_orders AS o
WHERE o.net_total > 1000
ORDER BY
    o.net_total DESC,
    o.order_id ASC;


/* =========================
   Phase 2 – Basic Querying
   ========================= */
/* Phase 2 Query 1: High-value Gold-tier customers in Germany with high credit limit 
   Identify high-value Gold-tier customers in Germany whose credit limit exceeds €50,000.
*/
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_code,
    c.city,
    c.country_name,
    c.credit_limit,
    c.account_tier
FROM dbo.dim_customers AS c
WHERE c.account_tier = 'Gold'
  AND c.country_name = 'Germany'
  AND c.credit_limit > 50000
ORDER BY
    c.credit_limit DESC,
    c.customer_name ASC;

/* Phase 2 Query 2: High markup products (list price more than three times unit cost) 
   Identify products whose list price is more than three times their unit cost, 
   highlighting items with unusually high markup.
*/
SELECT
    p.product_id,
    p.sku,
    p.product_name,
    p.unit_cost,
    p.list_price,
    CAST(((p.list_price - p.unit_cost) / NULLIF(p.list_price, 0)) * 100.0 AS DECIMAL(10,2)) AS margin_pct_on_price
FROM dbo.dim_products AS p
WHERE p.list_price > 3 * p.unit_cost
ORDER BY
    margin_pct_on_price DESC,
    p.product_name ASC;


/* =========================
   Phase 3 – Aggregations & KPIs
   ========================= */

/* Phase 3 Query 1: Gross revenue by month and country
   Calculate gross revenue by month and country by summing line-item quantity
   multiplied by unit price before any discounts are applied.
*/
SELECT
    d.year_num,
    d.month_num,
    c.country_name,
    CAST(SUM(li.quantity * li.unit_price) AS DECIMAL(14,2)) AS gross_revenue
FROM dbo.fact_order_line_items AS li
INNER JOIN dbo.fact_sales_orders AS o
    ON li.order_id = o.order_id
INNER JOIN dbo.dim_date AS d
    ON o.order_date_id = d.date_id
INNER JOIN dbo.dim_customers AS c
    ON o.customer_id = c.customer_id
GROUP BY
    d.year_num,
    d.month_num,
    c.country_name
ORDER BY
    d.year_num,
    d.month_num,
    c.country_name;

/* Phase 3 Query 2: Average Order Value (AOV) by region and month 
   Calculate Average Order Value by region and month by dividing total net revenue by 
   the number of orders in each regional time period.
*/
SELECT
    d.year_num,
    d.month_num,
    r.region_name,
    CAST(SUM(o.net_total) / NULLIF(COUNT(o.order_id), 0) AS DECIMAL(12,2)) AS avg_order_value,
    COUNT(o.order_id) AS order_count
FROM dbo.fact_sales_orders AS o
INNER JOIN dbo.dim_date AS d
    ON o.order_date_id = d.date_id
INNER JOIN dbo.dim_regions AS r
    ON o.region_id = r.region_id
GROUP BY
    d.year_num,
    d.month_num,
    r.region_name
ORDER BY
    d.year_num,
    d.month_num,
    r.region_name;