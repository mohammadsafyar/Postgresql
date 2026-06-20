WITH idx AS (
    SELECT
        ns.nspname AS schema_name,
        t.relname  AS table_name,
        i.relname  AS index_name,
        i.oid      AS index_oid,

        array_agg(a.attname ORDER BY k.ordinality)
            FILTER (WHERE k.attnum > 0) AS key_cols

    FROM pg_index ix
    JOIN pg_class i      ON i.oid = ix.indexrelid
    JOIN pg_class t      ON t.oid = ix.indrelid
    JOIN pg_namespace ns ON ns.oid = t.relnamespace

    JOIN LATERAL unnest(ix.indkey) WITH ORDINALITY k(attnum, ordinality)
        ON true

    LEFT JOIN pg_attribute a
        ON a.attrelid = t.oid AND a.attnum = k.attnum

    WHERE ns.nspname NOT IN ('pg_catalog','information_schema')
      AND t.relkind = 'r'

    GROUP BY ns.nspname, t.relname, i.relname, i.oid
),

usage AS (
    SELECT
        indexrelid AS index_oid,
        idx_scan
    FROM pg_stat_user_indexes
),

norm AS (
    SELECT
        i.schema_name,
        i.table_name,
        i.index_name,
        i.key_cols,
        COALESCE(u.idx_scan,0) AS idx_scan,
        array_to_string(i.key_cols, ', ') AS cols_text
    FROM idx i
    LEFT JOIN usage u ON i.index_oid = u.index_oid
)

SELECT
    a.schema_name,
    a.table_name,

    a.index_name AS index_1,
    b.index_name AS index_2,

    a.cols_text AS index_1_columns,
    b.cols_text AS index_2_columns,

    a.idx_scan AS index_1_usage,
    b.idx_scan AS index_2_usage,

    CASE
        WHEN a.cols_text = b.cols_text THEN 'EXACT_DUPLICATE'

        WHEN a.key_cols <@ b.key_cols THEN 'INDEX_2_COVERS_INDEX_1'

        WHEN b.key_cols <@ a.key_cols THEN 'INDEX_1_COVERS_INDEX_2'

        ELSE 'OVERLAP'
    END AS relation

FROM norm a
JOIN norm b
  ON a.schema_name = b.schema_name
 AND a.table_name  = b.table_name
 AND a.index_name  < b.index_name

ORDER BY table_name, relation;