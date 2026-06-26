# PostgreSQL — Invalid Index Monitoring

> **Wiki | Database Operations | PostgreSQL**
> نسخه: PostgreSQL 12+  |  آخرین بروزرسانی: 2026-06

---

## ۱. Index Invalid چیست؟

در PostgreSQL، یک index می‌تواند در حالت **`INVALID`** قرار بگیرد. این یعنی index وجود دارد، اما **توسط query planner استفاده نمی‌شود** و داده‌های آن ناقص یا نادرست است.

Index در موارد زیر به حالت INVALID می‌رود:

| سناریو | توضیح |
|--------|-------|
| `CREATE INDEX CONCURRENTLY` ناموفق | اگر عملیات در میانه راه interrupt شود |
| Replication conflict | در standby هنگام conflict با replication stream |
| `REINDEX CONCURRENTLY` ناموفق | مشابه CREATE CONCURRENTLY |
| Constraint violation هنگام ایجاد index | داده‌های duplicate در unique index |
| Crash یا timeout | قطع ناگهانی connection حین index build |

---

## ۲. شناسایی Invalid Index‌ها

### ۲.۱ کوئری اصلی (سریع)

```sql
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
JOIN pg_index USING (indexrelid)
WHERE NOT indisvalid;
```

### ۲.۲ کوئری جامع‌تر

```sql
SELECT
    n.nspname                                      AS schema_name,
    t.relname                                      AS table_name,
    i.relname                                      AS index_name,
    ix.indisprimary                                AS is_primary,
    ix.indisunique                                 AS is_unique,
    ix.indisready                                  AS is_ready,
    ix.indisvalid                                  AS is_valid,
    pg_size_pretty(pg_relation_size(i.oid))        AS index_size,
    pg_get_indexdef(ix.indexrelid)                 AS index_definition
FROM
    pg_class t
    JOIN pg_index ix    ON t.oid = ix.indrelid
    JOIN pg_class i     ON i.oid = ix.indexrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE
    t.relkind = 'r'
    AND NOT ix.indisvalid
    AND n.nspname NOT IN ('pg_catalog', 'pg_toast', 'information_schema')
ORDER BY
    n.nspname, t.relname, i.relname;
```

### ۲.۳ بررسی از طریق `pg_indexes` + `pg_class`

```sql
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE indexname IN (
    SELECT i.relname
    FROM pg_class i
    JOIN pg_index ix ON ix.indexrelid = i.oid
    WHERE NOT ix.indisvalid
);
```

### ۲.۴ بررسی سریع با psql

```bash
psql -U postgres -d your_db -c \
  "SELECT schemaname, tablename, indexname FROM pg_stat_user_indexes \
   JOIN pg_index USING (indexrelid) WHERE NOT indisvalid;"
```

---

## ۳. تفسیر فیلدهای کلیدی

| فیلد | مقدار | معنی |
|------|-------|-------|
| `indisvalid` | `false` | index قابل استفاده نیست |
| `indisready` | `false` | index هنوز در حال ساخت است |
| `indislive` | `false` | index باید حذف شود |
| `indisprimary` | `true` | این PRIMARY KEY index است — خطر بسیار جدی! |

> ⚠️ **هشدار:** اگر `indisvalid = false` روی یک **unique index** یا **primary key** باشد، integrity داده در خطر است.

---

## ۴. علت‌یابی (Root Cause)

### ۴.۱ بررسی لاگ PostgreSQL

```bash
grep -i "invalid\|index.*failed\|concurrent" /var/log/postgresql/postgresql-*.log | tail -50
```

### ۴.۲ بررسی `pg_stat_activity` (اگر index هنوز در حال build است)

```sql
SELECT pid, state, wait_event_type, wait_event, query, now() - query_start AS duration
FROM pg_stat_activity
WHERE query ILIKE '%create index%'
   OR query ILIKE '%reindex%';
```

### ۴.۳ بررسی bloat و phase ساخت index

```sql
SELECT
    phase,
    blocks_done,
    blocks_total,
    tuples_done,
    tuples_total,
    partitions_done,
    partitions_total
FROM pg_stat_progress_create_index;
```

---

## ۵. رفع مشکل (Remediation)

### ۵.۱ حذف و بازسازی (ساده‌ترین روش)

```sql
-- گام ۱: حذف index نامعتبر
DROP INDEX CONCURRENTLY schema_name.index_name;

-- گام ۲: بازسازی (با CONCURRENTLY برای production)
CREATE INDEX CONCURRENTLY index_name ON schema_name.table_name (column_name);
```

### ۵.۲ استفاده از REINDEX

```sql
-- برای یک index خاص
REINDEX INDEX CONCURRENTLY schema_name.index_name;

-- برای تمام index‌های یک table
REINDEX TABLE CONCURRENTLY schema_name.table_name;

-- برای کل database (نیاز به اتصال جداگانه)
REINDEX DATABASE your_database_name;
```

> **نکته:** `REINDEX ... CONCURRENTLY` از PostgreSQL 12 در دسترس است و table lock نمی‌گیرد.

### ۵.۳ بازیابی از CREATE INDEX CONCURRENTLY ناموفق

وقتی `CREATE INDEX CONCURRENTLY` قطع می‌شود، یک index با نام اصلی در حالت INVALID باقی می‌ماند:

```sql
-- ابتدا index باقی‌مانده را پیدا کنید
SELECT indexname, indexdef FROM pg_indexes
WHERE tablename = 'your_table'
  AND indexname IN (
      SELECT i.relname FROM pg_class i
      JOIN pg_index ix ON ix.indexrelid = i.oid
      WHERE NOT ix.indisvalid
  );

-- حذف index ناموفق
DROP INDEX CONCURRENTLY public.your_index_name;

-- بازسازی مجدد
CREATE INDEX CONCURRENTLY your_index_name ON public.your_table (your_column);
```

---

## ۶. مانیتورینگ پیوسته

### ۶.۱ ایجاد View برای monitoring

```sql
CREATE OR REPLACE VIEW monitoring.invalid_indexes AS
SELECT
    current_database()                             AS database_name,
    n.nspname                                      AS schema_name,
    t.relname                                      AS table_name,
    i.relname                                      AS index_name,
    ix.indisprimary                                AS is_primary_key,
    ix.indisunique                                 AS is_unique,
    pg_size_pretty(pg_relation_size(i.oid))        AS index_size,
    pg_get_indexdef(ix.indexrelid)                 AS index_definition,
    now()                                          AS checked_at
FROM pg_class t
JOIN pg_index ix    ON t.oid = ix.indrelid
JOIN pg_class i     ON i.oid = ix.indexrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE t.relkind = 'r'
  AND NOT ix.indisvalid
  AND n.nspname NOT IN ('pg_catalog', 'pg_toast', 'information_schema');
```

### ۶.۲ Alert Function (pgAgent / cron)

```sql
CREATE OR REPLACE FUNCTION monitoring.check_invalid_indexes()
RETURNS TABLE(severity TEXT, message TEXT) AS $$
DECLARE
    v_count INT;
    v_pk_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count   FROM monitoring.invalid_indexes;
    SELECT COUNT(*) INTO v_pk_count FROM monitoring.invalid_indexes WHERE is_primary_key;

    IF v_pk_count > 0 THEN
        RETURN QUERY SELECT 'CRITICAL'::TEXT,
            format('CRITICAL: %s PRIMARY KEY index(es) are INVALID!', v_pk_count);
    END IF;

    IF v_count > 0 THEN
        RETURN QUERY SELECT 'WARNING'::TEXT,
            format('WARNING: %s invalid index(es) detected', v_count);
    ELSE
        RETURN QUERY SELECT 'OK'::TEXT, 'All indexes are valid'::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;
```

### ۶.۳ Shell Script برای Nagios/Zabbix/Prometheus

```bash
#!/bin/bash
# check_pg_invalid_indexes.sh
# خروجی: 0=OK, 1=WARNING, 2=CRITICAL

DB_HOST="${1:-localhost}"
DB_PORT="${2:-5432}"
DB_NAME="${3:-postgres}"
DB_USER="${4:-postgres}"

INVALID_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc \
  "SELECT COUNT(*) FROM pg_index WHERE NOT indisvalid;")

PK_INVALID=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc \
  "SELECT COUNT(*) FROM pg_index WHERE NOT indisvalid AND indisprimary;")

if [ "$PK_INVALID" -gt 0 ]; then
    echo "CRITICAL: $PK_INVALID primary key index(es) invalid"
    exit 2
elif [ "$INVALID_COUNT" -gt 0 ]; then
    echo "WARNING: $INVALID_COUNT invalid index(es) found"
    exit 1
else
    echo "OK: All indexes valid"
    exit 0
fi
```

---

## ۷. سناریوهای خاص در Patroni (HA)

در محیط Patroni با primary/replica، نکات اضافه‌ای باید رعایت شود:

```sql
-- بررسی روی هر node به‌صورت مستقل
-- (اجرا روی primary و هر standby جداگانه)

SELECT
    pg_is_in_recovery()                           AS is_replica,
    inet_server_addr()                            AS node_ip,
    COUNT(*)                                      AS invalid_index_count
FROM pg_index
WHERE NOT indisvalid
HAVING COUNT(*) > 0;
```

**نکات مهم در Patroni:**

- `REINDEX CONCURRENTLY` فقط روی **primary** اجرا می‌شود؛ standby‌ها از طریق replication بروز می‌شوند.
- اگر invalid index روی **standby** باشد و روی primary valid باشد، احتمال replication lag یا split-brain وجود دارد.
- قبل از هرگونه `DROP INDEX` در محیط HA، وضعیت Patroni را بررسی کنید:

```bash
patronictl -c /etc/patroni/patroni.yml list
```

---

## ۸. پیشگیری

| اقدام | توضیح |
|-------|-------|
| **مانیتور کردن لاگ‌ها** | بعد از هر `CREATE INDEX CONCURRENTLY` لاگ را چک کنید |
| **تنظیم `lock_timeout`** | جلوگیری از hang شدن عملیات index |
| **زمان‌بندی مناسب** | عملیات index را در off-peak hours انجام دهید |
| **بررسی disk space** | کمبود فضا باعث ناموفق شدن index build می‌شود |
| **Maintenance window** | برای major version upgrade، همه index‌ها را بعد از upgrade verify کنید |

```sql
-- چک disk space قبل از ایجاد index
SELECT
    pg_size_pretty(pg_total_relation_size('your_table')) AS table_size,
    pg_size_pretty(pg_database_size(current_database())) AS db_size;
```

---

## ۹. جمع‌بندی — Checklist سریع

```
□ کوئری شناسایی invalid index اجرا شد؟
□ آیا primary key یا unique constraint تحت تأثیر است؟
□ علت (لاگ، interruption، disk space) مشخص شد؟
□ DROP + CREATE CONCURRENTLY یا REINDEX CONCURRENTLY اجرا شد؟
□ بعد از fix، کوئری تأیید اجرا شد؟
□ View/Alert مانیتورینگ برای جلوگیری از تکرار تنظیم شد؟
```

---

## ۱۰. منابع

- [PostgreSQL Docs — `pg_index`](https://www.postgresql.org/docs/current/catalog-pg-index.html)
- [PostgreSQL Docs — REINDEX](https://www.postgresql.org/docs/current/sql-reindex.html)
- [PostgreSQL Docs — CREATE INDEX CONCURRENTLY](https://www.postgresql.org/docs/current/sql-createindex.html#SQL-CREATEINDEX-CONCURRENTLY)
