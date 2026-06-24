SELECT
    COUNT(*) AS total_connections,
    COUNT(*) FILTER (WHERE state <> 'idle') AS non_idle_connections,
    current_setting('max_connections')::int AS max_connections,
    ROUND(
        COUNT(*) * 100.0 /
        current_setting('max_connections')::int,
        2
    ) AS connection_utilization_percent
FROM pg_stat_activity;