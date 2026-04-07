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
        DATEDIFF(DAY, MAX(d.full_date), (SELECT MAX(full_date) FROM dim_date)) AS recency_days,
        COUNT(o.order_id) AS frequency_orders,
        SUM(o.net_total) AS monetary_value
    FROM dim_customers c
    JOIN fact_sales_orders o
        ON c.customer_id = o.customer_id
    JOIN dim_date d
        ON o.order_date_id = d.date_id
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