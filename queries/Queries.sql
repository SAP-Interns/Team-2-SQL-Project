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

/* Discount impact analysis per product */
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

/* Ranking line items within each order */
SELECT
    line_item_id,
    order_id,
    product_id,
    line_number,
    quantity,
    unit_price,
    line_total,
    RANK() OVER (
        PARTITION BY order_id
        ORDER BY line_total DESC
    ) AS revenue_rank_in_order
FROM fact_order_line_items
WHERE line_total > 0;