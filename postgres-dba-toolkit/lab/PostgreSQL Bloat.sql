
CREATE DATABASE bloatpostgres;
اما در ادامه جدول `users` را در **همان دیتابیس جاری** (نه دیتابیسی به نام bloatpostgres) ایجاد می‌کنید. دستور `DROP DATABASE` کل دیتابیس را حذف می‌کند و سپس دستورات بعدی در دیتابیس دیگری اجرا می‌شوند (یا خطا می‌دهند). احتمالاً منظور شما این بوده است:

DROP TABLE IF EXISTS users;



## 2. مراحل اجرا و تعداد رکوردهای مرده (Dead Tuples)

### مرحله اول: ایجاد جدول و درج یک ردیف

CREATE TABLE users (id INT PRIMARY KEY, name TEXT, email TEXT);

ALTER TABLE users SET (autovacuum_enabled = false);

SELECT pg_size_pretty(pg_relation_size('users')) AS initial_empty_size;


INSERT INTO users VALUES (1, 'Alice', 'alice@wonderland.com');

SELECT ctid, xmin, xmax, * FROM users;

SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'users';

CREATE EXTENSION IF NOT EXISTS pgstattuple;

### مرحله دوم: سه بار بروزرسانی روی همان ردیف

UPDATE users SET email = 'alice@newdomain.com' WHERE id = 1;
UPDATE users SET email = 'alice@company.com' WHERE id = 1;
UPDATE users SET email = 'alice@final.com' WHERE id = 1;

### مرحله سوم: نمایش نهایی جدول

SELECT * from users;

فقط ردیف زنده را نشان می‌دهد:
| id | name  | email              |
|----|-------|--------------------|
| 1  | Alice | alice@final.com    |

### مرحله چهارم: مشاهده ctid و xmin/xmax

SELECT ctid, xmin, xmax, * FROM users;

ردیف زنده (تنها ردیف موجود) را نشان می‌دهد. مقدار `ctid` مکان فیزیکی آن در فایل داده است (مثلاً `(0,4)`). مقادیر `xmin` و `xmax` مربوط به تراکنش‌ها هستند.

### مرحله پنجم: پرس‌وجو از pg_stat_user_tables

SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'users';


این جدول سیستم، آمار لحظه‌ای جدول را نشان می‌دهد. پس از سه آپدیت و بدون اجرای **VACUUM**، خروجی به این صورت است:
```
 n_live_tup | n_dead_tup
------------+------------
          1 |          3
```

CREATE TABLE products (id INT PRIMARY KEY, name TEXT, price NUMERIC);

ALTER TABLE products SET (autovacuum_enabled = false);

INSERT INTO products SELECT generate_series(1, 500), 'Product', 99.99;

EXPLAIN (ANALYZE, BUFFERS) SELECT COUNT(*) FROM products;

DELETE FROM products WHERE id <= 450;

SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname = 'products';

EXPLAIN (ANALYZE, BUFFERS) SELECT COUNT(*) FROM products;

 CREATE EXTENSION  pgstattuple;


 SELECT * FROM pgstattuple('products');

 CREATE EXTENSION pageinspect;

 SELECT COUNT(*) FROM bt_page_items('products_pkey', 1);


 SELECT pg_size_pretty(pg_relation_size('products_pkey')) AS index_size;