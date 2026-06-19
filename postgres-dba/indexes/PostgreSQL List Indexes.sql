--SQL Query to Check Uptime
SELECT date_trunc('second', current_timestamp - pg_postmaster_start_time()) AS uptime;

SELECT pg_postmaster_start_time();




SELECT
    tablename,
    indexname,
    indexdef
FROM
    pg_indexes
-- WHERE
    --schemaname = 'public'
   -- tablename= 'users_mini'
ORDER BY
    tablename,
    indexname;


SELECT
    schemaname,
    relname AS table_name,
    indexrelname AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    
    idx_scan AS number_of_scans
FROM pg_stat_user_indexes
--WHERE idx_scan = 0
  --AND indexrelname NOT LIKE '%_pkey'  -- کلیدهای اصلی را حذف کنید
ORDER BY pg_relation_size(indexrelid) DESC;


SELECT
    indrelid::regclass AS table_name,
    array_agg(indexrelid::regclass) AS duplicate_indexes
FROM pg_index
GROUP BY indrelid, indkey
HAVING count(*) > 1;



CREATE TABLE orders
(
    id          BIGSERIAL PRIMARY KEY,
    customer_id INT,
    status      VARCHAR(20),
    city        VARCHAR(50),
    created_at  TIMESTAMP,
    amount      NUMERIC(10,2)
);

INSERT INTO orders
(
    customer_id,
    status,
    city,
    created_at,
    amount
)
SELECT
    (random()*100000)::int,

    CASE
        WHEN random() < 0.90 THEN 'ACTIVE'
        WHEN random() < 0.95 THEN 'PENDING'
        ELSE 'CANCELLED'
    END,

    CASE
        WHEN random() < 0.7 THEN 'Berlin'
        WHEN random() < 0.9 THEN 'Frankfurt'
        ELSE 'Munich'
    END,

    now() - (random()*365||' days')::interval,

    round((random()*10000)::numeric,2)

FROM generate_series(1,1000000);

SELECT * FROM orders

select status,count(*) FROM public.orders
GROUP BY status

CREATE INDEX idx_orders_status
ON orders(status);


CREATE INDEX idx_orders_status_city
ON orders(status,city);

CREATE INDEX idx_orders_status_include
ON orders(status)
INCLUDE(amount,created_at);

CREATE INDEX idx_orders_created_brin
ON orders
USING brin(created_at);


SELECT
    attname,
    n_distinct,
    most_common_vals,
    most_common_freqs
FROM pg_stats
WHERE tablename='orders';


EXPLAIN (ANALYZE,BUFFERS)
SELECT *
FROM orders
WHERE status='ACTIVE';


EXPLAIN (ANALYZE,BUFFERS)
SELECT *
FROM orders
WHERE status='CANCELLED';


EXPLAIN (ANALYZE,BUFFERS)
SELECT *
FROM orders
WHERE status='ACTIVE'
AND city='Munich';