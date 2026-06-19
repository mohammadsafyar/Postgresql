--- obsolete_tuples > threshold + scale_factor * total_tuples
--- inserted_tuples > insert_threshold + insert_scale_factor * total_tuples
-- Show autovacuum threshold for UPDATE/DELETE
-- نمایش آستانه اجرای autovacuum برای آپدیت/دیلیت
SHOW autovacuum_vacuum_threshold;

-- Show scale factor for UPDATE/DELETE
-- نمایش ضریب درصدی برای محاسبه تعداد رکوردهای تغییر کرده
SHOW autovacuum_vacuum_scale_factor;

-- Show threshold for INSERT-heavy tables
-- آستانه برای جدول‌هایی با INSERT زیاد
SHOW autovacuum_vacuum_insert_threshold;

-- Show scale factor for INSERT-heavy tables
-- ضریب درصدی برای INSERT
SHOW autovacuum_vacuum_insert_scale_factor;

-- Show max age before freeze (wraparound protection)
-- حداکثر سن transaction قبل از freeze شدن برای جلوگیری از wraparound
SHOW autovacuum_freeze_max_age;

-- Show all autovacuum-related settings
-- نمایش تمام تنظیمات مربوط به autovacuum
SELECT name, setting, unit, context
FROM pg_settings
WHERE name LIKE 'autovacuum%';


-- Show table-specific autovacuum settings
-- نمایش تنظیمات اختصاصی autovacuum برای یک جدول
SELECT relname, reloptions
FROM pg_class
WHERE relname = 'users_mini';

-- Show table statistics (live vs dead tuples)
-- نمایش آمار جدول (رکوردهای زنده و مرده)
SELECT *
FROM pg_stat_user_tables
WHERE relname = 'users_mini';

-- Check if autovacuum is running
-- بررسی اینکه آیا autovacuum در حال اجراست یا نه
SELECT *
FROM pg_stat_activity
WHERE query LIKE '%autovacuum%';


select * from pg_stat_progress_vacuum;


SELECT relname, n_tup_ins, n_tup_upd, n_tup_del, last_autovacuum
FROM pg_stat_user_tables;

--1️⃣ مانیتورینگ جامع XID با محاسبه‌ی دقیق درصد مصرف
WITH xid_config AS (
    SELECT current_setting('autovacuum_freeze_max_age')::bigint AS max_age
)
SELECT 
    datname,
    age(datfrozenxid) AS xid_age,
    ROUND(100.0 * age(datfrozenxid) / max_age, 2) AS pct_used,
    CASE 
        WHEN age(datfrozenxid) > max_age * 0.9 THEN '⚠️ CRITICAL'
        WHEN age(datfrozenxid) > max_age * 0.75 THEN '⚠️ WARNING'
        ELSE '✅ OK'
    END AS status
FROM pg_database, xid_config
ORDER BY pct_used DESC;

---2️⃣ شناسایی جداول نیازمند تنظیم اختصاصی Autovacuum

SELECT 
    relname,
    n_live_tup,
    n_dead_tup,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_pct,
    last_autovacuum,
    autovacuum_count,
    -- محاسبه‌ی آستانه‌ی واقعی
    current_setting('autovacuum_vacuum_threshold')::int + 
    current_setting('autovacuum_vacuum_scale_factor')::float * n_live_tup AS threshold_now
FROM pg_stat_user_tables
WHERE n_dead_tup > 0  -- حذف نویز
ORDER BY dead_pct DESC;

--4️⃣ وضعیت Autovacuum (اجرا شده یا نه)

SELECT 
    relname,
    last_vacuum,
    last_autovacuum,
    vacuum_count,
    autovacuum_count,
    CASE 
        WHEN last_autovacuum IS NULL THEN '❌ NEVER'
        WHEN NOW() - last_autovacuum > INTERVAL '1 day' THEN '⚠️ TOO LONG AGO'
        ELSE '✅ OK'
    END AS status
FROM pg_stat_user_tables
WHERE 
    last_autovacuum IS NULL 
    OR NOW() - last_autovacuum > INTERVAL '1 day'
ORDER BY last_autovacuum NULLS FIRST;


--5️⃣ پیشرفت Vacuum در حال اجرا (اگر باشد)
SELECT 
    p.pid,
    p.datname,
    p.relname,
    p.phase,
    ROUND(100.0 * p.blocks_done / NULLIF(p.blocks_total, 0), 2) AS progress_pct,
    NOW() - a.xact_start AS running_time
FROM pg_stat_progress_vacuum p
JOIN pg_stat_activity a ON p.pid = a.pid;


SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    ROUND(
        100.0 * (pg_total_relation_size(schemaname||'.'||tablename) - 
                pg_relation_size(schemaname||'.'||tablename)) / 
        NULLIF(pg_total_relation_size(schemaname||'.'||tablename), 0), 2
    ) AS bloat_pct
FROM pg_tables
WHERE 
    schemaname NOT IN ('information_schema', 'pg_catalog')
    AND pg_total_relation_size(schemaname||'.'||tablename) > 1073741824  -- > 1GB
ORDER BY bloat_pct DESC
LIMIT 20;





select displayname from users_mini;

update users_mini 
set displayname = 'Behrrooz_11'
where id=1;


select Count(*) from users_mini;


vacuum users_mini;