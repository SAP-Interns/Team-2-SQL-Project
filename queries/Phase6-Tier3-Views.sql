/* Monthly Trend View*/
CREATE OR ALTER VIEW vw_monthly_trend AS
SELECT
    region_country_name,
    year_num,
    month_num,
    month_name,
    net_revenue,
    order_count,
    average_order_value,
    LAG(net_revenue) OVER (
        PARTITION BY region_country_name
        ORDER BY year_num, month_num
    ) AS previous_month_revenue,
    net_revenue
        - LAG(net_revenue) OVER (
            PARTITION BY region_country_name
            ORDER BY year_num, month_num
        ) AS revenue_change,
    (
        (net_revenue
            - LAG(net_revenue) OVER (
                PARTITION BY region_country_name
                ORDER BY year_num, month_num
            )
        ) * 100.0
    ) / NULLIF(
        LAG(net_revenue) OVER (
            PARTITION BY region_country_name
            ORDER BY year_num, month_num
        ),
        0
    ) AS month_over_month_pct_change
FROM vw_sum_monthly_country_sales;


/* 2. Product Performance View*/
CREATE OR ALTER VIEW vw_product_performance AS
SELECT
    product_id,
    sku,
    product_name,
    category_id,
    category_name,
    total_units_sold,
    net_revenue,
    gross_margin_pct,
    return_rate,
    RANK() OVER (
        PARTITION BY category_id
        ORDER BY net_revenue DESC
    ) AS category_rank
FROM vw_sum_product_metrics;

/* 3. Sales Rep Performance Scorecard View */
CREATE OR ALTER VIEW vw_rep_performance_scorecard AS
WITH current_quarter AS (
    SELECT
        sales_rep_id,
        employee_code,
        first_name,
        last_name,
        region_id,
        region_name,
        country_name,
        year_num,
        quarter_num,
        month_num,
        month_name,
        quota_period_type,
        actual_revenue,
        quota_target,
        quota_attainment_pct,
        customer_count,
        'CURRENT_QUARTER' AS period_scope
    FROM vw_sum_rep_quota_attainment
    WHERE quota_period_type = 'Quarterly'
      AND year_num = (SELECT MAX(year_num) FROM vw_sum_rep_quota_attainment)
      AND quarter_num = (
          SELECT MAX(quarter_num)
          FROM vw_sum_rep_quota_attainment
          WHERE year_num = (SELECT MAX(year_num) FROM vw_sum_rep_quota_attainment)
            AND quota_period_type = 'Quarterly'
      )
),
ytd AS (
    SELECT
        sales_rep_id,
        employee_code,
        first_name,
        last_name,
        region_id,
        region_name,
        country_name,
        year_num,
        NULL AS quarter_num,
        NULL AS month_num,
        NULL AS month_name,
        'YTD' AS quota_period_type,
        SUM(actual_revenue) AS actual_revenue,
        SUM(quota_target) AS quota_target,
        SUM(actual_revenue) * 100.0 / NULLIF(SUM(quota_target), 0) AS quota_attainment_pct,
        SUM(customer_count) AS customer_count,
        'YTD' AS period_scope
    FROM vw_sum_rep_quota_attainment
    WHERE quota_period_type = 'Monthly'
      AND year_num = (SELECT MAX(year_num) FROM vw_sum_rep_quota_attainment)
    GROUP BY
        sales_rep_id,
        employee_code,
        first_name,
        last_name,
        region_id,
        region_name,
        country_name,
        year_num
),
combined AS (
    SELECT
        sales_rep_id,
        employee_code,
        first_name,
        last_name,
        region_id,
        region_name,
        country_name,
        year_num,
        quarter_num,
        month_num,
        month_name,
        quota_period_type,
        actual_revenue,
        quota_target,
        quota_attainment_pct,
        customer_count,
        period_scope
    FROM current_quarter

    UNION ALL

    SELECT
        sales_rep_id,
        employee_code,
        first_name,
        last_name,
        region_id,
        region_name,
        country_name,
        year_num,
        quarter_num,
        month_num,
        month_name,
        quota_period_type,
        actual_revenue,
        quota_target,
        quota_attainment_pct,
        customer_count,
        period_scope
    FROM ytd
)
SELECT
    sales_rep_id,
    employee_code,
    first_name,
    last_name,
    region_id,
    region_name,
    country_name,
    year_num,
    quarter_num,
    month_num,
    month_name,
    quota_period_type,
    actual_revenue,
    quota_target,
    quota_attainment_pct,
    customer_count,
    period_scope,
    RANK() OVER (
        PARTITION BY region_id, year_num, period_scope
        ORDER BY quota_attainment_pct DESC
    ) AS regional_rank
FROM combined;

/* 4. Customer 360 View */
CREATE OR ALTER VIEW vw_customer_360 AS
WITH latest_primary_rep AS (
    SELECT
        rca.customer_id,
        rca.sales_rep_id,
        ROW_NUMBER() OVER (
            PARTITION BY rca.customer_id
            ORDER BY rca.start_date_id DESC
        ) AS rn
    FROM rep_customer_assignments AS rca
    WHERE rca.is_primary_rep = 1
)
SELECT
    cm.customer_id,
    cm.customer_code,
    cm.customer_name,
    cm.account_tier,
    cm.lifetime_revenue,
    cm.order_frequency,
    cm.last_order_date,
    cm.average_order_value,
    cm.return_rate,
    CONCAT(sr.first_name, ' ', sr.last_name) AS assigned_rep,
    rfm.recency_days,
    rfm.frequency_orders,
    rfm.monetary_value,
    rfm.rfm_segment
FROM vw_sum_customer_metrics AS cm
INNER JOIN vw_sum_customer_rfm AS rfm
    ON cm.customer_id = rfm.customer_id
LEFT JOIN latest_primary_rep AS lpr
    ON cm.customer_id = lpr.customer_id
   AND lpr.rn = 1
LEFT JOIN dim_sales_reps AS sr
    ON lpr.sales_rep_id = sr.sales_rep_id;

/* 5. Returns Analysis View*/
CREATE OR ALTER VIEW vw_returns_analysis AS
SELECT
    year_num,
    quarter_num,
    month_num,
    country_name,
    category_name,
    return_reason_code,
    returned_units,
    return_count,
    total_credit_note_value,
    return_rate
FROM vw_sum_returns_metrics;

/* 6. Executive Summary View*/
CREATE OR ALTER VIEW vw_sales_executive_summary AS
SELECT
    rps.region_name,
    rps.region_country_name,
    rps.territory_name,
    rps.year_num,
    rps.quarter_num,
    rps.month_num,
    rps.month_name,
    rps.total_revenue,
    rps.gross_margin_pct,
    rps.order_count,
    rps.average_order_value,
    COALESCE(
        SUM(rqa.actual_revenue) * 100.0 / NULLIF(SUM(rqa.quota_target), 0),
        0
    ) AS quota_attainment_pct
FROM vw_sum_region_period_sales AS rps
LEFT JOIN vw_sum_rep_quota_attainment AS rqa
    ON rps.region_name = rqa.region_name
   AND rps.year_num = rqa.year_num
   AND rps.quarter_num = rqa.quarter_num
   AND rps.month_num = rqa.month_num
GROUP BY
    rps.region_name,
    rps.region_country_name,
    rps.territory_name,
    rps.year_num,
    rps.quarter_num,
    rps.month_num,
    rps.month_name,
    rps.total_revenue,
    rps.gross_margin_pct,
    rps.order_count,
    rps.average_order_value;