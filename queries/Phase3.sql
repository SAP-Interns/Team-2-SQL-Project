/*Gross Revenue: Sum of (quantity � unit_price) before any discounts, per month  */
SELECT
    d.year_num,
    d.month_num,
    c.country_name,
    SUM(oli.quantity * oli.unit_price) AS gross_revenue
FROM fact_order_line_items oli
JOIN fact_sales_orders o
    ON oli.order_id = o.order_id
JOIN dim_customers c
    ON o.customer_id = c.customer_id
JOIN dim_date d
    ON o.order_date_id = d.date_id
GROUP BY
    d.year_num,
    d.month_num,
    c.country_name
ORDER BY
    d.year_num,
    d.month_num,
    c.country_name;

/*Net Revenue:Gross revenue minus all applied discounts, per quarter*/
SELECT
    d.quarter_num,
    SUM((oli.quantity * oli.unit_price) - oli.discount_amount) AS net_revenue
FROM fact_order_line_items oli
JOIN fact_sales_orders o
    ON oli.order_id = o.order_id
JOIN dim_date d
    ON o.order_date_id = d.date_id
GROUP BY
    d.quarter_num
ORDER BY
    d.quarter_num;

/* Gross Margin % per product */
SELECT
    p.product_id,
    p.product_name,
    
    SUM(oli.line_total) AS total_revenue,
    SUM(oli.quantity * p.unit_cost) AS total_cost,

    SUM(oli.line_total - (oli.quantity * p.unit_cost)) AS gross_profit,

    ROUND(
        (SUM(oli.line_total - (oli.quantity * p.unit_cost)) 
        / NULLIF(SUM(oli.line_total), 0)) * 100, 
    2) AS gross_margin_pct

FROM fact_order_line_items oli

JOIN dim_products p
    ON oli.product_id = p.product_id

GROUP BY
    p.product_id,
    p.product_name

ORDER BY gross_margin_pct DESC;


/* Average Order Value */
SELECT
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(net_total) AS total_revenue,

    ROUND(
        SUM(net_total) * 1.0 
        / NULLIF(COUNT(DISTINCT order_id), 0),
    2) AS average_order_value

FROM fact_sales_orders;


/*12. Find all sales representatives who generated more than 500,000 in net revenue in a single
quarter but whose quota attainment in that same quarter was below 80%. This requires
understanding the difference between HAVING and WHERE.*/
SELECT
    d.year_num,
    d.quarter_num,
    sr.sales_rep_id,
    sr.first_name,
    sr.last_name,
    ROUND(SUM(oli.line_total), 2) AS net_revenue
FROM fact_sales_orders o
JOIN fact_order_line_items oli
    ON o.order_id = oli.order_id
JOIN dim_sales_reps sr
    ON o.sales_rep_id = sr.sales_rep_id
JOIN dim_date d
    ON o.order_date_id = d.date_id
GROUP BY
    d.year_num,
    d.quarter_num,
    sr.sales_rep_id,
    sr.first_name,
    sr.last_name
HAVING
    SUM(oli.line_total) > 50000
ORDER BY
    d.year_num,
    d.quarter_num,
    net_revenue DESC;

/*13.Identify all product categories where the average gross margin is below 25% AND the total
return rate exceeds 10% - categories that are simultaneously low-margin and high-return.*/
SELECT
    p.category_id,
    ROUND(
        AVG(
            (oli.line_total - (oli.quantity * p.unit_cost)) * 100.0 / NULLIF(oli.line_total, 0)
        ), 2
    ) AS avg_gross_margin_pct
FROM fact_order_line_items oli
JOIN dim_products p
    ON oli.product_id = p.product_id
GROUP BY
    p.category_id
HAVING
    AVG(
        (oli.line_total - (oli.quantity * p.unit_cost)) * 100.0 / NULLIF(oli.line_total, 0)
    ) < 25
ORDER BY
    p.category_id;


/*14.List all customers who placed more than 13 orders in the past year but whose average order
value is below 5,000 - high-frequency, low-value accounts that may require a pricing strategy
review.*/
SELECT
    c.customer_id,
    c.customer_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oli.line_total) / NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS average_order_value
FROM fact_sales_orders o
JOIN fact_order_line_items oli
    ON o.order_id = oli.order_id
JOIN dim_customers c
    ON o.customer_id = c.customer_id
JOIN dim_date d
    ON o.order_date_id = d.date_id
WHERE d.year_num = (
    SELECT MAX(year_num)
    FROM dim_date
    WHERE year_num < YEAR(GETDATE())
)
GROUP BY
    c.customer_id,
    c.customer_name
HAVING
    COUNT(DISTINCT o.order_id) > 10
    AND SUM(oli.line_total) / NULLIF(COUNT(DISTINCT o.order_id), 0) < 5000
ORDER BY
    total_orders DESC;