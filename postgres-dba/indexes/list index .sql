SELECT
    ns.nspname AS schema_name,
    t.relname  AS table_name,
    i.relname  AS index_name,

    idx.indisprimary AS is_primary,
    idx.indisunique  AS is_unique,

    COALESCE(s.idx_scan, 0) AS idx_scan,
    COALESCE(s.idx_tup_read, 0) AS idx_tup_read,
    COALESCE(s.idx_tup_fetch, 0) AS idx_tup_fetch,

    pg_size_pretty(pg_relation_size(i.oid)) AS index_size,

    pg_get_indexdef(i.oid) AS index_definition

FROM pg_index idx
JOIN pg_class i      ON i.oid = idx.indexrelid
JOIN pg_class t      ON t.oid = idx.indrelid
JOIN pg_namespace ns ON ns.oid = t.relnamespace

LEFT JOIN pg_stat_user_indexes s
       ON s.indexrelid = i.oid

WHERE ns.nspname NOT IN ('pg_catalog', 'information_schema')
  AND t.relkind = 'r'

ORDER BY idx_scan ASC, pg_relation_size(i.oid) DESC;