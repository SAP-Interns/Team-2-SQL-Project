/*List all customers in Germany whose account tier is Gold and whose credit limit exceeds
50,000, ordered by credit limit descending.*/
SELECT 
    customer_name,
    country_name,
    account_tier,
    credit_limit
FROM dim_customers
WHERE country_name = 'Germany'
  AND account_tier = 'Gold'
  AND credit_limit > 5000
ORDER BY credit_limit DESC;


/*Retrieve all sales orders placed in Q3 of the most recent complete year that have a status of
Pending or Partially Delivered, showing the customer name, order date, and total value. */
SELECT 
    c.customer_name,
    d.full_date AS order_date,
    o.net_total AS total_value
FROM fact_sales_orders o
JOIN dim_customers c
    ON o.customer_id = c.customer_id
JOIN dim_date d
    ON o.order_date_id = d.date_id
WHERE d.year_num = (
        SELECT MAX(year_num)
        FROM dim_date
        WHERE year_num < YEAR(GETDATE())
)
  AND d.quarter_num = 3
  AND o.order_status IN ('Pending', 'Partially Delivered');


/*Find all products whose list price is more than three times their unit cost (i.e., gross margin
above 66%), ordered by margin descending.*/
SELECT 
    product_name,
    unit_cost,
    list_price,
    ((list_price - unit_cost) * 100.0 / list_price) AS margin_percentage
FROM dim_products
WHERE list_price > 3 * unit_cost
ORDER BY margin_percentage DESC;

/*Identify all sales representatives who have not been assigned to any customer territory in the
last 6 months, using appropriate NULL-awareness in your filter. */
SELECT 
    sr.sales_rep_id,
    sr.first_name,
    sr.last_name,
    sr.email
FROM dim_sales_reps sr
LEFT JOIN rep_customer_assignments r
    ON sr.sales_rep_id = r.sales_rep_id
LEFT JOIN dim_date d
    ON r.start_date_id = d.date_id
    AND d.full_date >= DATEADD(MONTH, -6, GETDATE())
WHERE d.date_id IS NULL;

/* List all orders where the shipping date is more than 14 days after the order date, indicating a
delivery delay, filtered by a specific country of your choice.  */
SELECT 
    o.order_number,
    c.customer_name,
    c.country_name,
    od.full_date AS order_date,
    sd.full_date AS shipping_date
FROM fact_sales_orders o
JOIN dim_customers c
    ON o.customer_id = c.customer_id
JOIN dim_date od
    ON o.order_date_id = od.date_id
JOIN dim_date sd
    ON o.shipping_date_id = sd.date_id
WHERE c.country_name = 'Germany'
  AND DATEDIFF(DAY, od.full_date, sd.full_date) > 14;

/*Find all products where the product name contains the word Pro,Plus, or Max, regardless of case.*/
SELECT *
FROM dim_products
WHERE LOWER(product_name) LIKE '%pro%'
   OR LOWER(product_name) LIKE '%plus%'
   OR LOWER(product_name) LIKE '%max%';