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