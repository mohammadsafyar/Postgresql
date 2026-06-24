-- =====================================================
-- Name: Cache Hit Ratio Analysis
-- Category: Performance / Memory
-- Severity: MEDIUM
-- Purpose:
--   بررسی میزان استفاده از cache در سطح table/index/db
--   (تشخیص اینکه workload بیشتر از RAM سرو می‌شود یا disk)
--
-- Notes:
--   - PostgreSQL cache = shared_buffers
--   - OS cache اینجا دیده نمی‌شود
-- =====================================================

-- =========================================
-- 1. Overall Table Cache Hit Ratio
-- =========================================
SELECT
    sum(heap_blks_read)  AS heap_read,
    sum(heap_blks_hit)   AS heap_hit,
    round(
        sum(heap_blks_hit)::numeric /
        NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0) * 100,
        2
    ) AS cache_hit_ratio_pct
FROM pg_statio_user_tables;


-- =========================================
-- 2. Per Table Cache Efficiency
-- =========================================

SELECT
    relname AS table_name,
    heap_blks_read,
    heap_blks_hit,
    round(
        heap_blks_hit::numeric /
        NULLIF(heap_blks_hit + heap_blks_read, 0) * 100,
        2
    ) AS cache_hit_ratio_pct
FROM pg_statio_user_tables
WHERE heap_blks_read + heap_blks_hit > 0
ORDER BY cache_hit_ratio_pct ASC, heap_blks_read DESC
LIMIT 20;




-- =========================================
-- 3. Index Cache Efficiency
-- =========================================

SELECT
    relname AS table_name,
    indexrelname AS index_name,
    idx_blks_read,
    idx_blks_hit,
    round(
        idx_blks_hit::numeric /
        NULLIF(idx_blks_hit + idx_blks_read, 0) * 100,
        2
    ) AS cache_hit_ratio_pct
FROM pg_statio_user_indexes
WHERE idx_blks_read + idx_blks_hit > 0
ORDER BY cache_hit_ratio_pct ASC, idx_blks_read DESC
LIMIT 20;



-- =========================================
-- 4. Database Level Cache Overview
-- =========================================

SELECT
    datname,
    blks_read,
    blks_hit,
    round(
        blks_hit::numeric /
        NULLIF(blks_hit + blks_read, 0) * 100,
        2
    ) AS cache_hit_ratio_pct
FROM pg_stat_database
WHERE datname NOT IN ('template0', 'template1')
ORDER BY cache_hit_ratio_pct ASC;

