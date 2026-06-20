
-- این کوئری ایندکس‌های بلااستفاده (Unused) در دیتابیس PostgreSQL را شناسایی کرده، 
-- حجم هر کدام را نمایش می‌دهد و دستور DROP INDEX CONCURRENTLY جهت حذف ایمن آن‌ها تولید می‌کند.
WITH restart_time AS (
    SELECT pg_postmaster_start_time() AS last_restart
)
SELECT
    s.schemaname,
    s.relname AS tablename,
    s.indexrelname AS indexname,
    
    array_agg(a.attname ORDER BY x.ordinality) AS index_columns,

    s.idx_scan,
    s.idx_tup_read,
    s.idx_tup_fetch,

    pg_size_pretty(pg_relation_size(s.indexrelid)) AS index_size,
    r.last_restart,

    'DROP INDEX CONCURRENTLY '
        || quote_ident(s.schemaname)
        || '.'
        || quote_ident(s.indexrelname)
        || ';' AS drop_command

FROM pg_stat_user_indexes s
CROSS JOIN restart_time r

JOIN pg_index i
    ON i.indexrelid = s.indexrelid

JOIN LATERAL unnest(i.indkey) WITH ORDINALITY AS x(attnum, ordinality)
    ON TRUE

JOIN pg_attribute a
    ON a.attnum = x.attnum
   AND a.attrelid = i.indrelid

WHERE s.idx_scan = 0
  AND s.idx_tup_read = 0
  AND s.idx_tup_fetch = 0
  AND NOT i.indisprimary
  AND NOT i.indisunique
  AND NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        WHERE c.conindid = s.indexrelid
  )

GROUP BY
    s.schemaname,
    s.relname,
    s.indexrelname,
    s.idx_scan,
    s.idx_tup_read,
    s.idx_tup_fetch,
    s.indexrelid,
    s.relid,
    r.last_restart

ORDER BY pg_relation_size(s.indexrelid) DESC;

