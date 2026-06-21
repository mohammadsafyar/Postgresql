-- =====================================================
-- Name: Daily Health Check
-- Purpose: Overview of database health
-- Severity: HIGH (Daily Monitoring)
-- =====================================================

SELECT
    datname,
    numbackends AS active_connections,
    xact_commit,
    xact_rollback,
    blks_read,
    blks_hit,
    round(
        blks_hit * 100.0 / nullif(blks_hit + blks_read, 0),
        2
    ) AS cache_hit_ratio
FROM pg_stat_database
ORDER BY active_connections DESC;

