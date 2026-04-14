/* =========================================================
   PHASE 5 - ADVANCED SQL
========================================================= */


/* =========================================================
   Query 1: Top Customer Per Country
========================================================= */
WITH customer_country_revenue AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.country_name,
        c.account_tier,
        SUM(o.net_total) AS total_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY c.country_name
            ORDER BY SUM(o.net_total) DESC
        ) AS row_num
    FROM dim_customers c
    JOIN fact_sales_orders o
        ON c.customer_id = o.customer_id
    JOIN dim_date d
        ON o.order_date_id = d.date_id
    WHERE d.year_num = (SELECT MAX(year_num) FROM dim_date)
    GROUP BY
        c.customer_id,
        c.customer_name,
        c.country_name,
        c.account_tier
)
SELECT
    customer_id,
    customer_name,
    country_name,
    account_tier,
    total_revenue
FROM customer_country_revenue
WHERE row_num = 1
ORDER BY country_name;
/* =========================================================
   Query 2: Month-over-Month Revenue Change
========================================================= */
WITH monthly_revenue AS (
    SELECT
        r.country_name,
        d.year_num,
        d.month_num,
        SUM(o.net_total) AS monthly_net_revenue
    FROM fact_sales_orders o
    JOIN dim_date d
        ON o.order_date_id = d.date_id
    JOIN dim_regions r
        ON o.region_id = r.region_id
    GROUP BY
        r.country_name,
        d.year_num,
        d.month_num
)
SELECT
    country_name,
    year_num,
    month_num,
    monthly_net_revenue,
    LAG(monthly_net_revenue) OVER (
        PARTITION BY country_name
        ORDER BY year_num, month_num
    ) AS previous_month_revenue,
    monthly_net_revenue
      - LAG(monthly_net_revenue) OVER (
            PARTITION BY country_name
            ORDER BY year_num, month_num
        ) AS revenue_change,
    ROUND(
        (
            monthly_net_revenue
          - LAG(monthly_net_revenue) OVER (
                PARTITION BY country_name
                ORDER BY year_num, month_num
            )
        ) * 100.0
        / NULLIF(
            LAG(monthly_net_revenue) OVER (
                PARTITION BY country_name
                ORDER BY year_num, month_num
            ),
            0
        ),
        2
    ) AS revenue_change_pct
FROM monthly_revenue
ORDER BY country_name, year_num, month_num;



/* =========================================================
   Query 3: Running Total by Quarter
========================================================= */
SELECT
    o.order_id,
    r.region_name,
    d.year_num,
    d.quarter_num,
    d.full_date,
    o.net_total,
    SUM(o.net_total) OVER (
        PARTITION BY r.region_name, d.year_num, d.quarter_num
        ORDER BY d.full_date, o.order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_quarter_revenue
FROM fact_sales_orders o
JOIN dim_date d
    ON o.order_date_id = d.date_id
JOIN dim_regions r
    ON o.region_id = r.region_id
ORDER BY
    r.region_name,
    d.year_num,
    d.quarter_num,
    d.full_date,
    o.order_id;


/* =========================================================
   Query 4: Rank Sales Reps Within Region
========================================================= */
WITH rep_revenue AS (
    SELECT
        s.sales_rep_id,
        s.first_name,
        s.last_name,
        s.region_id,
        r.region_name,
        d.year_num,
        d.quarter_num,
        SUM(o.net_total) AS actual_revenue
    FROM dim_sales_reps s
    JOIN fact_sales_orders o
        ON s.sales_rep_id = o.sales_rep_id
    JOIN dim_date d
        ON o.order_date_id = d.date_id
    JOIN dim_regions r
        ON s.region_id = r.region_id
    GROUP BY
        s.sales_rep_id,
        s.first_name,
        s.last_name,
        s.region_id,
        r.region_name,
        d.year_num,
        d.quarter_num
),
rep_quota AS (
    SELECT
        q.sales_rep_id,
        q.region_id,
        d.year_num,
        d.quarter_num,
        SUM(q.quota_target) AS quota_target
    FROM fact_quotas q
    JOIN dim_date d
        ON q.date_id = d.date_id
    GROUP BY
        q.sales_rep_id,
        q.region_id,
        d.year_num,
        d.quarter_num
)
SELECT
    rr.sales_rep_id,
    rr.first_name,
    rr.last_name,
    rr.region_name,
    rr.year_num,
    rr.quarter_num,
    rr.actual_revenue,
    rq.quota_target,
    ROUND((rr.actual_revenue * 100.0) / NULLIF(rq.quota_target, 0), 2) AS quota_attainment_pct,
    RANK() OVER (
        PARTITION BY rr.region_name, rr.year_num, rr.quarter_num
        ORDER BY (rr.actual_revenue * 1.0) / NULLIF(rq.quota_target, 0) DESC
    ) AS rep_rank_in_region
FROM rep_revenue rr
JOIN rep_quota rq
    ON rr.sales_rep_id = rq.sales_rep_id
   AND rr.region_id = rq.region_id
   AND rr.year_num = rq.year_num
   AND rr.quarter_num = rq.quarter_num
ORDER BY
    rr.region_name,
    rr.year_num,
    rr.quarter_num,
    rep_rank_in_region;



/* =========================================================
   Query 5: Customer RFM Segmentation
========================================================= */
WITH customer_rfm AS (
    SELECT
        c.customer_id,
        c.customer_name,
        MAX(d.full_date) AS last_order_date,
        DATEDIFF(
            DAY,
            MAX(d.full_date),
            (SELECT MAX(full_date) FROM dim_date)
        ) AS recency_days,
        COUNT(o.order_id) AS frequency_orders,
        SUM(o.net_total) AS monetary_value
    FROM dim_customers c
    JOIN fact_sales_orders o
        ON c.customer_id = o.customer_id
    JOIN dim_date d
        ON o.order_date_id = d.date_id
    WHERE d.full_date >= DATEADD(
        YEAR,
        -1,
        (SELECT MAX(full_date) FROM dim_date)
    )
    GROUP BY
        c.customer_id,
        c.customer_name
)
SELECT
    customer_id,
    customer_name,
    last_order_date,
    recency_days,
    frequency_orders,
    monetary_value,
    CASE
        WHEN recency_days <= 30 AND frequency_orders >= 20 AND monetary_value >= 70000 THEN 'Champions'
        WHEN recency_days <= 90 AND frequency_orders >= 10 AND monetary_value >= 30000 THEN 'Loyal'
        WHEN recency_days > 180 AND frequency_orders >= 10 THEN 'At Risk'
        WHEN recency_days > 365 THEN 'Lost'
        ELSE 'New'
    END AS rfm_segment
FROM customer_rfm
ORDER BY monetary_value DESC;


/* =========================================================
   Query 6: Products Never Ordered in High-Revenue Regions
========================================================= */
WITH high_revenue_regions AS (
    SELECT
        o.region_id
    FROM fact_sales_orders o
    JOIN dim_date d
        ON o.order_date_id = d.date_id
    WHERE d.full_date >= DATEADD(YEAR, -1, (SELECT MAX(full_date) FROM dim_date))
    GROUP BY
        o.region_id
    HAVING SUM(o.net_total) > 1000000
)
SELECT
    p.product_id,
    p.product_name,
    p.category_id
FROM dim_products p
WHERE NOT EXISTS (
    SELECT 1
    FROM fact_order_line_items li
    JOIN fact_sales_orders o
        ON li.order_id = o.order_id
    WHERE li.product_id = p.product_id
      AND o.region_id IN (
          SELECT region_id
          FROM high_revenue_regions
      )
)
ORDER BY p.product_name;

/* Phase 5 Query 1 - Customer Quarter-over-Quarter Activity Comparison
   Compare each customer's quarterly order count and revenue with the previous quarter
   using LAG() to identify customers whose activity declined.
*/
WITH customer_quarterly_activity AS (
    SELECT
        o.customer_id,
        c.customer_name,
        c.account_tier,
        d.year_num,
        d.quarter_num,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(o.net_total) AS quarter_revenue
    FROM dbo.fact_sales_orders AS o
    INNER JOIN dbo.dim_customers AS c
        ON o.customer_id = c.customer_id
    INNER JOIN dbo.dim_date AS d
        ON o.order_date_id = d.date_id
    GROUP BY
        o.customer_id,
        c.customer_name,
        c.account_tier,
        d.year_num,
        d.quarter_num
),
activity_with_previous AS (
    SELECT
        customer_id,
        customer_name,
        account_tier,
        year_num,
        quarter_num,
        order_count,
        quarter_revenue,
        LAG(order_count) OVER (
            PARTITION BY customer_id
            ORDER BY year_num, quarter_num
        ) AS previous_quarter_order_count,
        LAG(quarter_revenue) OVER (
            PARTITION BY customer_id
            ORDER BY year_num, quarter_num
        ) AS previous_quarter_revenue
    FROM customer_quarterly_activity
)
SELECT
    customer_id,
    customer_name,
    account_tier,
    year_num,
    quarter_num,
    order_count,
    previous_quarter_order_count,
    quarter_revenue,
    previous_quarter_revenue,
    order_count - previous_quarter_order_count AS order_count_change,
    quarter_revenue - previous_quarter_revenue AS revenue_change
FROM activity_with_previous
WHERE previous_quarter_order_count IS NOT NULL
  AND (
        order_count < previous_quarter_order_count
        OR quarter_revenue < previous_quarter_revenue
      )
ORDER BY
    year_num DESC,
    quarter_num DESC,
    customer_name ASC;


/* Phase 5 Query 2 - Products Purchased Most by Above-Average Revenue Customers
   Identify the products purchased most often by customers whose total lifetime
   revenue is above the overall average customer revenue.
   This uses a CTE, a subquery, aggregation, and ROW_NUMBER() ranking logic.
*/
WITH high_value_customers AS (
    SELECT
        o.customer_id
    FROM dbo.fact_sales_orders AS o
    GROUP BY
        o.customer_id
    HAVING SUM(o.net_total) > (
        SELECT AVG(customer_revenue * 1.0)
        FROM (
            SELECT
                customer_id,
                SUM(net_total) AS customer_revenue
            FROM dbo.fact_sales_orders
            GROUP BY
                customer_id
        ) AS revenue_summary
    )
),
product_sales AS (
    SELECT
        p.product_id,
        p.product_name,
        SUM(li.quantity) AS total_quantity_sold,
        SUM(li.line_total) AS total_revenue
    FROM dbo.fact_sales_orders AS o
    INNER JOIN high_value_customers AS hvc
        ON o.customer_id = hvc.customer_id
    INNER JOIN dbo.fact_order_line_items AS li
        ON o.order_id = li.order_id
    INNER JOIN dbo.dim_products AS p
        ON li.product_id = p.product_id
    GROUP BY
        p.product_id,
        p.product_name
)
SELECT
    ROW_NUMBER() OVER (
        ORDER BY total_quantity_sold DESC, total_revenue DESC, product_name ASC
    ) AS product_rank,
    product_id,
    product_name,
    total_quantity_sold,
    total_revenue
FROM product_sales
ORDER BY
    product_rank;