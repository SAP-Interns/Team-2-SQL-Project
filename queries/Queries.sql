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

/* Phase 1 Validation Query 1: Inspect high-credit customer records */
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_code,
    c.billing_address,
    c.city,
    c.country_name,
    c.credit_limit,
    c.account_tier
FROM dbo.dim_customers AS c
WHERE c.credit_limit > 45000
ORDER BY c.credit_limit DESC, c.customer_name ASC;

/* Phase 1 Validation Query 2: Inspect high-value sales orders */
SELECT
    o.order_id,
    o.order_number,
    o.customer_id,
    o.sales_rep_id,
    o.order_status,
    o.net_total,
    o.order_date_id
FROM dbo.fact_sales_orders AS o
WHERE o.net_total > 1000
ORDER BY o.net_total DESC, o.order_id ASC;


/*High-value Gold-tier customers with high credit limit*/
SELECT
    customer_id,
    customer_name,
    customer_code,
    city,
    country_name,
    credit_limit,
    account_tier
FROM dbo.dim_customers
WHERE account_tier = 'Gold'
  AND credit_limit > 20000
ORDER BY credit_limit DESC;

/* High markup products (price 3 times higher than the production cost)*/
SELECT
	product_id,
	sku,
	product_name,
	unit_cost,
	list_price,
	CAST(((list_price - unit_cost) / NULLIF(list_price, 0)) * 100.0 AS DECIMAL(10,2)) AS gross_margin_pct
FROM dbo.dim_products
WHERE list_price > 3 * unit_cost
ORDER BY gross_margin_pct DESC;

/* Gross Revenue by month */
SELECT
    YEAR(o.created_at) AS order_year,
    MONTH(o.created_at) AS order_month,
    ROUND(SUM(li.quantity * li.unit_price), 2) AS gross_revenue
FROM dbo.fact_order_line_items AS li
JOIN dbo.fact_sales_orders AS o
    ON li.order_id = o.order_id
GROUP BY
    YEAR(o.created_at),
    MONTH(o.created_at)
ORDER BY
    order_year,
    order_month;