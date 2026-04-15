/* 1. Monthly Country Sales Summary View */
CREATE OR ALTER VIEW vw_sum_monthly_country_sales AS
SELECT
    region_country_name,
    year_num,
    month_num,
    month_name,
    SUM(quantity * unit_price) AS gross_revenue,
    SUM(line_total) AS net_revenue,
    COUNT(DISTINCT order_id) AS order_count,
    SUM(line_total) / NULLIF(COUNT(DISTINCT order_id), 0) AS average_order_value
FROM vw_base_sales_order_line
GROUP BY
    region_country_name,
    year_num,
    month_num,
    month_name;

/* 2. Product Metrics Summary View */
CREATE OR ALTER VIEW vw_sum_product_metrics AS
WITH returned_units_by_product AS (
    SELECT
        product_id,
        SUM(return_quantity) AS returned_units
    FROM vw_base_returns
    GROUP BY
        product_id
)
SELECT
    sol.product_id,
    sol.sku,
    sol.product_name,
    sol.category_id,
    sol.category_name,
    SUM(sol.quantity) AS total_units_sold,
    SUM(sol.line_total) AS net_revenue,
    ((SUM(sol.line_total) - SUM(sol.quantity * sol.unit_cost)) * 100.0)
        / NULLIF(SUM(sol.line_total), 0) AS gross_margin_pct,
    COALESCE(rup.returned_units, 0) * 100.0
        / NULLIF(SUM(sol.quantity), 0) AS return_rate
FROM vw_base_sales_order_line AS sol
LEFT JOIN returned_units_by_product AS rup
    ON sol.product_id = rup.product_id
GROUP BY
    sol.product_id,
    sol.sku,
    sol.product_name,
    sol.category_id,
    sol.category_name,
    rup.returned_units;

/* 3. Customer Metrics View*/
CREATE OR ALTER VIEW vw_sum_customer_metrics AS
WITH returned_units_by_customer AS (
    SELECT
        customer_id,
        SUM(return_quantity) AS returned_units
    FROM vw_base_returns
    GROUP BY
        customer_id
)
SELECT
    sol.customer_id,
    sol.customer_code,
    sol.customer_name,
    sol.account_tier,
    SUM(sol.line_total) AS lifetime_revenue,
    COUNT(DISTINCT sol.order_id) AS order_frequency,
    MAX(sol.full_date) AS last_order_date,
    SUM(sol.line_total) / NULLIF(COUNT(DISTINCT sol.order_id), 0) AS average_order_value,
    COALESCE(ruc.returned_units, 0) * 100.0 / NULLIF(SUM(sol.quantity), 0) AS return_rate
FROM vw_base_sales_order_line AS sol
LEFT JOIN returned_units_by_customer AS ruc
    ON sol.customer_id = ruc.customer_id
GROUP BY
    sol.customer_id,
    sol.customer_code,
    sol.customer_name,
    sol.account_tier,
    ruc.returned_units;


/* 4. Customer RFM View*/
CREATE OR ALTER VIEW vw_sum_customer_rfm AS
WITH customer_rfm_base AS (
    SELECT
        customer_id,
        customer_code,
        customer_name,
        MAX(full_date) AS last_order_date,
        COUNT(DISTINCT order_id) AS frequency_orders,
        SUM(line_total) AS monetary_value
    FROM vw_base_sales_order_line
    GROUP BY
        customer_id,
        customer_code,
        customer_name
),
rfm_scored AS (
    SELECT
        customer_id,
        customer_code,
        customer_name,
        last_order_date,
        DATEDIFF(DAY, last_order_date, GETDATE()) AS recency_days,
        frequency_orders,
        monetary_value
    FROM customer_rfm_base
)
SELECT
    customer_id,
    customer_code,
    customer_name,
    recency_days,
    frequency_orders,
    monetary_value,
    CASE
        WHEN recency_days <= 30 AND frequency_orders >= 10 AND monetary_value >= 10000 THEN 'Champions'
        WHEN recency_days <= 60 AND frequency_orders >= 5 AND monetary_value >= 5000 THEN 'Loyal'
        WHEN recency_days <= 90 AND frequency_orders >= 3 THEN 'New'
        WHEN recency_days > 180 AND frequency_orders >= 5 THEN 'At Risk'
        WHEN recency_days > 180 THEN 'Lost'
        ELSE 'Regular'
    END AS rfm_segment
FROM rfm_scored;

/* 5. Sales Rep Quota Attainment View*/
CREATE OR ALTER VIEW vw_sum_rep_quota_attainment AS
SELECT
    q.sales_rep_id,
    q.employee_code,
    q.first_name,
    q.last_name,
    q.region_id,
    q.region_name,
    q.country_name,
    q.date_id,
    q.full_date,
    q.year_num,
    q.quarter_num,
    q.month_num,
    q.month_name,
    q.quota_period_type,
    q.quota_target,
    COALESCE(SUM(sol.line_total), 0) AS actual_revenue,
    COALESCE(COUNT(DISTINCT sol.customer_id), 0) AS customer_count,
    COALESCE(SUM(sol.line_total), 0) * 100.0 / NULLIF(q.quota_target, 0) AS quota_attainment_pct
FROM vw_base_quota_rep_period AS q
LEFT JOIN vw_base_sales_order_line AS sol
    ON q.sales_rep_id = sol.sales_rep_id
   AND q.year_num = sol.year_num
   AND (
        (q.quota_period_type = 'Monthly' AND q.month_num = sol.month_num)
        OR
        (q.quota_period_type = 'Quarterly' AND q.quarter_num = sol.quarter_num)
       )
GROUP BY
    q.sales_rep_id,
    q.employee_code,
    q.first_name,
    q.last_name,
    q.region_id,
    q.region_name,
    q.country_name,
    q.date_id,
    q.full_date,
    q.year_num,
    q.quarter_num,
    q.month_num,
    q.month_name,
    q.quota_period_type,
    q.quota_target;

/* 6. Returns Metrics View*/
CREATE OR ALTER VIEW vw_sum_returns_metrics AS
WITH sold_units_by_slice AS (
    SELECT
        category_name,
        region_country_name AS country_name,
        year_num,
        quarter_num,
        month_num,
        SUM(quantity) AS sold_units
    FROM vw_base_sales_order_line
    GROUP BY
        category_name,
        region_country_name,
        year_num,
        quarter_num,
        month_num
)
SELECT
    br.category_name,
    br.country_name,
    br.return_year_num AS year_num,
    br.return_quarter_num AS quarter_num,
    br.return_month_num AS month_num,
    br.return_reason_code,
    SUM(br.return_quantity) AS returned_units,
    COUNT(br.return_id) AS return_count,
    SUM(br.credit_note_value) AS total_credit_note_value,
    SUM(br.return_quantity) * 100.0 / NULLIF(MAX(sus.sold_units), 0) AS return_rate
FROM vw_base_returns AS br
LEFT JOIN sold_units_by_slice AS sus
    ON br.category_name = sus.category_name
   AND br.country_name = sus.country_name
   AND br.return_year_num = sus.year_num
   AND br.return_quarter_num = sus.quarter_num
   AND br.return_month_num = sus.month_num
GROUP BY
    br.category_name,
    br.country_name,
    br.return_year_num,
    br.return_quarter_num,
    br.return_month_num,
    br.return_reason_code;

/* 7. Region Sales per Period View */
CREATE OR ALTER VIEW vw_sum_region_period_sales AS
SELECT
    region_name,
    region_country_name,
    territory_name,
    year_num,
    quarter_num,
    month_num,
    month_name,
    SUM(line_total) AS total_revenue,
    ((SUM(line_total) - SUM(quantity * unit_cost)) * 100.0)
        / NULLIF(SUM(line_total), 0) AS gross_margin_pct,
    COUNT(DISTINCT order_id) AS order_count,
    SUM(line_total) / NULLIF(COUNT(DISTINCT order_id), 0) AS average_order_value
FROM vw_base_sales_order_line
GROUP BY
    region_name,
    region_country_name,
    territory_name,
    year_num,
    quarter_num,
    month_num,
    month_name;