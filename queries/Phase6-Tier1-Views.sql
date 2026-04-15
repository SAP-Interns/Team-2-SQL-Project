/*1. Base sales order line View */
CREATE OR ALTER VIEW vw_base_sales_order_line AS
SELECT
    oli.line_item_id,
    oli.order_id,
    oli.product_id,
    oli.line_number,
    oli.quantity,
    oli.unit_price,
    oli.discount_pct,
    oli.discount_amount,
    oli.line_total,
    oli.created_at AS line_created_at,

    so.order_number,
    so.customer_id,
    so.sales_rep_id,
    so.order_date_id,
    so.shipping_date_id,
    so.region_id,
    so.order_status,
    so.payment_terms,
    so.currency_code,
    so.gross_total,
    so.discount_total,
    so.net_total,
    so.created_at AS order_created_at,

    cstmr.customer_code,
    cstmr.customer_name,
    cstmr.city,
    cstmr.postal_code,
    cstmr.country_name AS customer_country_name,
    cstmr.credit_limit,
    cstmr.account_tier,

    prdt.sku,
    prdt.product_name,
    prdt.unit_cost,
    prdt.list_price,
    prdt.stock_quantity,

    ctgr.segment_name,
    ctgr.category_name,
    ctgr.subcategory_name,

    rgn.country_name AS region_country_name,
    rgn.region_name,
    rgn.territory_name,
    rgn.country_code,

    sr.employee_code,
    sr.first_name,
    sr.last_name,
    sr.email,
    sr.hire_date,
    sr.status AS sales_rep_status,

    dt.full_date,
    dt.year_num,
    dt.quarter_num,
    dt.month_num,
    dt.month_name,

    cstmr.region_id AS customer_region_id,
    sr.region_id AS sales_rep_region_id,
    prdt.category_id,
    dt.date_id
FROM fact_order_line_items AS oli
INNER JOIN fact_sales_orders AS so
    ON oli.order_id = so.order_id
INNER JOIN dim_products AS prdt
    ON oli.product_id = prdt.product_id
INNER JOIN dim_customers AS cstmr
    ON so.customer_id = cstmr.customer_id
INNER JOIN dim_sales_reps AS sr
    ON so.sales_rep_id = sr.sales_rep_id
INNER JOIN dim_categories AS ctgr
    ON prdt.category_id = ctgr.category_id
INNER JOIN dim_date AS dt
    ON so.order_date_id = dt.date_id
INNER JOIN dim_regions AS rgn
    ON so.region_id = rgn.region_id;

/*2. Base returns View */
CREATE OR ALTER VIEW vw_base_returns AS
SELECT
    rt.return_id,
    rt.line_item_id,
    rt.return_date_id,
    rt.return_quantity,
    rt.return_reason_code,
    rt.credit_note_number,
    rt.credit_note_value,
    rt.created_at AS return_created_at,

    oli.order_id,
    oli.product_id,
    oli.line_number,
    oli.quantity AS sold_quantity,
    oli.unit_price,
    oli.discount_pct,
    oli.discount_amount,
    oli.line_total,
    oli.created_at AS line_created_at,

    so.order_number,
    so.customer_id,
    so.sales_rep_id,
    so.order_date_id,
    so.shipping_date_id,
    so.region_id,
    so.order_status,
    so.payment_terms,
    so.currency_code,
    so.gross_total,
    so.discount_total,
    so.net_total,
    so.created_at AS order_created_at,

    prdt.sku,
    prdt.product_name,
    prdt.category_id,
    prdt.unit_cost,
    prdt.list_price,

    ctgr.segment_name,
    ctgr.category_name,
    ctgr.subcategory_name,

    rgn.country_name,
    rgn.region_name,
    rgn.territory_name,
    rgn.country_code,

    dt.full_date AS return_full_date,
    dt.year_num AS return_year_num,
    dt.quarter_num AS return_quarter_num,
    dt.month_num AS return_month_num,
    dt.month_name AS return_month_name,
    
    cstmr.customer_code,
    cstmr.customer_name,
    cstmr.account_tier,

    sr.employee_code,
    sr.first_name,
    sr.last_name
FROM fact_returns AS rt
INNER JOIN fact_order_line_items AS oli
    ON rt.line_item_id = oli.line_item_id
INNER JOIN fact_sales_orders AS so
    ON oli.order_id = so.order_id
INNER JOIN dim_products AS prdt
    ON oli.product_id = prdt.product_id
INNER JOIN dim_categories AS ctgr
    ON prdt.category_id = ctgr.category_id
INNER JOIN dim_regions AS rgn
    ON so.region_id = rgn.region_id
INNER JOIN dim_date AS dt
    ON rt.return_date_id = dt.date_id
INNER JOIN dim_customers AS cstmr
    ON so.customer_id = cstmr.customer_id
INNER JOIN dim_sales_reps AS sr
    ON so.sales_rep_id = sr.sales_rep_id;

/*3. Base quota rep period View*/
CREATE OR ALTER VIEW vw_base_quota_rep_period AS
SELECT
    q.quota_id,
    q.sales_rep_id,
    q.region_id,
    q.date_id,
    q.quota_period_type,
    q.quota_target,
    q.created_at AS quota_created_at,

    sr.employee_code,
    sr.first_name,
    sr.last_name,
    sr.email,
    sr.hire_date,
    sr.status AS sales_rep_status,
    sr.region_id AS sales_rep_region_id,

    rgn.country_name,
    rgn.region_name,
    rgn.territory_name,
    rgn.country_code,

    dt.full_date,
    dt.year_num,
    dt.quarter_num,
    dt.month_num,
    dt.month_name    
FROM fact_quotas AS q
INNER JOIN dim_sales_reps AS sr
    ON q.sales_rep_id = sr.sales_rep_id
INNER JOIN dim_regions AS rgn
    ON q.region_id = rgn.region_id
INNER JOIN dim_date AS dt
    ON q.date_id = dt.date_id;