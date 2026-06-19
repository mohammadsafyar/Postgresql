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



/* * مانیتورینگ جداول حجیم (> 1GB) برای شناسایی Bloat 
 * هدف: شناسایی جداولی که نیاز به تنظیم مجدد پارامترهای Autovacuum دارند 
 * نکته: این کوئری سبک است و از آمار جمع‌آوری شده در pg_stat_user_tables استفاده می‌کند
 */

SELECT 
    relname AS tablename,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    n_dead_tup AS dead_tuples,
    n_live_tup AS live_tuples,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS bloat_pct,

    CASE 
        WHEN ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) > 30 THEN '⚠️ HIGH BLOAT'
        WHEN ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) > 15 THEN '⚠️ MODERATE BLOAT'
        ELSE '✅ OK'
    END AS recommendation
FROM pg_stat_user_tables
WHERE 
    -- فقط بررسی جداول بزرگتر از 1 گیگابایت برای جلوگیری از هدررفت منابع
    pg_total_relation_size(relid) > 1073741824 
    AND (n_live_tup + n_dead_tup) > 0
ORDER BY bloat_pct DESC
LIMIT 10;


/* * 🔍 گزارش وضعیت و تاخیر Autovacuum (Monitoring Health Check)
 * * هدف: شناسایی جداولی که به دلیل حجم بالای رکوردهای مرده (Dead Tuples) یا 
 * فاصله زمانی زیاد از آخرین عملیات Autovacuum، نیازمند توجه هستند.
 * * فیلترهای منطقی:
 * 1. بررسی جداول با حداقل ۱۰۰۰ رکورد مرده (جهت کاهش نویز).
 * 2. سطح قرمز (Critical): گذشت بیش از ۲۴ ساعت و رکوردهای مرده بیش از ۱۰ هزار.
 * 3. سطح زرد (Warning): گذشت بیش از ۱۲ ساعت و رکوردهای مرده بیش از ۵ هزار.
 */

WITH vacuum_lag AS (
    SELECT 
        relname,
        last_autovacuum,
        n_dead_tup,
        n_live_tup,
        autovacuum_count,
        -- محاسبه زمان سپری شده از آخرین اجرای اتوماتیک (به ساعت)
        EXTRACT(EPOCH FROM (NOW() - COALESCE(last_autovacuum, '1900-01-01'))) / 3600 AS hours_since_last
    FROM pg_stat_user_tables
    WHERE n_dead_tup > 0
)
SELECT 
    relname,
    n_dead_tup,
    -- محاسبه نرخ تورم (Bloat Ratio)
    ROUND(n_dead_tup * 100.0 / NULLIF(n_live_tup, 0), 2) AS dead_pct,
    ROUND(hours_since_last, 2) AS hours_since_last_vacuum,
    autovacuum_count,
    CASE 
        WHEN hours_since_last > 24 AND n_dead_tup > 10000 THEN '🔴 CRITICAL - Long time without vacuum'
        WHEN hours_since_last > 12 AND n_dead_tup > 5000 THEN '🟡 WARNING - Check autovacuum'
        ELSE '🟢 OK'
    END AS status
FROM vacuum_lag
ORDER BY hours_since_last DESC NULLS FIRST;



/* * 🛠 تحلیل هوشمند وضعیت جداول و پیشنهاد برای Autovacuum
 * هدف: شناسایی جداول حجیم که نرخ تغییرات آن‌ها از توان عملیاتی فعلی Autovacuum فراتر رفته است.
 * * منطق عملیاتی:
 * 1. فیلتر کردن نویز: فقط جداولی که حداقل 5000 رکورد مرده یا 10000 تغییرِ آنالیز نشده دارند.
 * 2. محاسبه آستانه پویا (Dynamic Threshold): ترکیب مقادیر کل کلاستر و تنظیمات خاص جدول.
 * 3. خروجی اکشن‌محور (Actionable):
 * - قرمز (🔴): فشار شدید به Vacuum؛ نیاز به مداخله دستی یا افزایش منابع (Workers).
 * - زرد (🟡): نیاز به بازنگری در پارامترهای tuning جدول (مثلاً کاهش scale_factor).
 * * نکته: در صورت دریافت مداوم هشدار قرمز، اولویت اول بررسی تعداد 'autovacuum_max_workers' 
 * و سپس تنظیم اختصاصی 'autovacuum_vacuum_scale_factor' برای همان جدول است.
 */
SELECT 
    relname,
    n_live_tup,
    n_dead_tup,
    n_mod_since_analyze,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_pct,
    last_autovacuum,
    last_analyze,
    autovacuum_count,
    -- محاسبه دقیق‌تر threshold با در نظر گرفتن تنظیمات جدول
    COALESCE(
        (SELECT setting::int FROM pg_settings WHERE name = 'autovacuum_vacuum_threshold'),
        50
    ) + 
    COALESCE(
        (SELECT setting::float FROM pg_settings WHERE name = 'autovacuum_vacuum_scale_factor'),
        0.2
    ) * n_live_tup AS threshold_now,
    -- توصیه برای تنظیمات اختصاصی
    CASE 
        WHEN n_dead_tup > 100000 AND (last_autovacuum IS NULL OR NOW() - last_autovacuum > INTERVAL '2 hours') 
            THEN '🔴 Consider manual VACUUM or increase autovacuum workers'
        WHEN n_dead_tup > 50000 AND (n_dead_tup * 100.0 / NULLIF(n_live_tup, 0)) > 20
            THEN '🟡 Review autovacuum settings for this table'
        ELSE '🟢 OK'
    END AS action_needed
FROM pg_stat_user_tables
--WHERE  (n_dead_tup > 5000 OR n_mod_since_analyze > 10000)  -- فیلتر نویز
 WHERE n_live_tup > 0
ORDER BY dead_pct DESC NULLS LAST;




/* * 🛡 مانیتورینگ جامع ریسک Wraparound (XID و MultiXact)
 * * هدف: جلوگیری از توقف کامل دیتابیس (Database Shutdown) به دلیل سرریز شدن شناسه تراکنش‌ها.
 * * منطق فنی:
 * 1. پایش datfrozenxid: شناسایی دیتابیس‌هایی که به حداکثر سن مجاز (Freeze Max Age) نزدیک می‌شوند.
 * 2. پایش MultiXact: بررسی ریسک سرریز شدن شناسه تراکنش‌های گروهی (مرتبط با Row Locking).
 * * اهمیت: رسیدن به عدد 100٪ باعث قفل شدن دیتابیس در حالت Read-Only می‌شود.
 * * فیلترها:
 * - فقط دیتابیس‌هایی که بیش از 50٪ از عمرِ مجازِ تراکنشی خود را مصرف کرده‌اند نمایش داده می‌شوند.
 * * اکشن‌پلن:
 * - در صورت رسیدن به سطح CRITICAL، اجرای دستی 'VACUUM FREEZE' روی جدول‌های بزرگ یا کل دیتابیس الزامی است.
 */

 -- نسخه بهبودیافته با در نظر گرفتن multixact
WITH xid_config AS (
    SELECT 
        current_setting('autovacuum_freeze_max_age')::bigint AS max_age,
        current_setting('autovacuum_multixact_freeze_max_age')::bigint AS max_multixact_age
)
SELECT 
    datname,
    age(datfrozenxid) AS xid_age,
    age(datminmxid) AS multixact_age,
    ROUND(100.0 * age(datfrozenxid) / max_age, 2) AS pct_used,
    ROUND(100.0 * age(datminmxid) / max_multixact_age, 2) AS multixact_pct,
    CASE 
        WHEN age(datfrozenxid) > max_age * 0.9 THEN '⚠️ CRITICAL - IMMEDIATE VACUUM FREEZE NEEDED'
        WHEN age(datfrozenxid) > max_age * 0.75 THEN '⚠️ WARNING - Schedule aggressive vacuum'
        WHEN age(datfrozenxid) > max_age * 0.6 THEN 'ℹ️ INFO - Monitor closely'
        ELSE '✅ OK'
    END AS status
FROM pg_database, xid_config
--WHERE age(datfrozenxid) > (max_age * 0.5)  -- فقط دیتابیس‌های با مصرف بالا
ORDER BY pct_used DESC;




-- 🚨 شناسایی جدول‌هایی که هرگز VACUUM نشده‌اند (Never Vaccumed Tables)
-- جداول بدون Vacuum (حتی یک بار)
SELECT 
    schemaname,
    relname AS tablename, -- اصلاح نام ستون به relname
    pg_size_pretty(pg_total_relation_size(relid)) AS size,
    n_dead_tup,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE 
    (last_vacuum IS NULL AND last_autovacuum IS NULL)
    AND n_dead_tup > 1000
ORDER BY n_dead_tup DESC 
LIMIT 100;


-- ⚙️ بررسی منابع اختصاص داده شده به Autovacuum
SELECT 
    name,
    setting,
    unit,
    short_desc
FROM pg_settings
WHERE name IN (
    'autovacuum_max_workers',           -- تعداد Workers همزمان
    'autovacuum_naptime',               -- زمان بین چک‌ها (پیش‌فرض: 1 دقیقه)
    'autovacuum_work_mem',              -- حافظه هر Worker (پیش‌فرض: -1 = استفاده از maintenance_work_mem)
    'autovacuum_vacuum_cost_limit',     -- سقف هزینه (پیش‌فرض: -1 = استفاده از vacuum_cost_limit)
    'autovacuum_vacuum_cost_delay'      -- تاخیر (پیش‌فرض: 2ms)
)
ORDER BY name;



