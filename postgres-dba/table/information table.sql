WITH table_stats AS (
    SELECT
        n.nspname AS schema_name,
        c.relname AS table_name,
        c.reltuples::bigint AS estimated_live_rows,
        COALESCE(s.n_dead_tup, 0) AS dead_rows,
        COALESCE(s.n_live_tup, 0) AS live_rows_from_stats,
        s.last_vacuum,
        s.last_autovacuum,
        s.last_analyze,
        s.last_autoanalyze,
        pg_size_pretty(pg_relation_size(c.oid)) AS table_size,
        pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
        COALESCE(s.n_live_tup + s.n_dead_tup, 0) AS total_tuples,
        CASE 
            WHEN COALESCE(s.n_live_tup,0) = 0 THEN 0
            ELSE ROUND(100.0 * s.n_dead_tup / NULLIF(s.n_live_tup + s.n_dead_tup,0), 2)
        END AS dead_tuple_ratio_percent
       
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    LEFT JOIN pg_stat_user_tables s ON s.relid = c.oid
    WHERE c.relkind = 'r'
      AND n.nspname NOT IN ('pg_catalog', 'information_schema')
)
SELECT 
    *
FROM table_stats
ORDER BY 
    dead_tuple_ratio_percent DESC NULLS LAST,
    total_size DESC NULLS LAST;



    select * from public.users_mini


    update public.users_mini
    set displayname='John Doe'
    where id=3;