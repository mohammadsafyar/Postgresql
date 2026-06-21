-- =====================================================
-- Name: Blocking Sessions Detection
-- Severity: CRITICAL
-- =====================================================

SELECT
    blocked.pid AS blocked_pid,
    blocked.query AS blocked_query,
    blocker.pid AS blocking_pid,
    blocker.query AS blocking_query,
    now() - blocked.query_start AS blocked_duration
FROM pg_stat_activity blocked
JOIN pg_locks bl ON blocked.pid = bl.pid
JOIN pg_locks blk ON bl.locktype = blk.locktype
JOIN pg_stat_activity blocker ON blocker.pid = blk.pid
WHERE NOT bl.granted;
