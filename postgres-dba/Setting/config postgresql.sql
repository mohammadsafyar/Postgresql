SELECT
    name,
    setting,
    unit,
    context
FROM pg_settings
WHERE name IN (
    'shared_buffers',
    'effective_cache_size',
    'work_mem',
    'maintenance_work_mem',
    'max_connections',
    'checkpoint_completion_target',
    'wal_buffers',
    'max_wal_size',
    'min_wal_size',
    'random_page_cost',
    'seq_page_cost',
    'autovacuum',
    'autovacuum_max_workers',
    'autovacuum_naptime',
    'autovacuum_vacuum_scale_factor',
    'autovacuum_analyze_scale_factor',
    'log_min_duration_statement',
    'track_io_timing',
    'track_activity_query_size',
    'shared_preload_libraries'
)
ORDER BY name;