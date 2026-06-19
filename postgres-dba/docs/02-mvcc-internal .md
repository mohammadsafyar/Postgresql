# MVCC Demo in PostgreSQL (Using pageinspect)

## 🎯 هدف این دمو
در این مثال می‌خواهیم ببینیم PostgreSQL چگونه با استفاده از MVCC (Multi-Version Concurrency Control)  
نسخه‌های مختلف یک رکورد را مدیریت می‌کند.


## 🔧 آماده‌سازی محیط

```sql
CREATE EXTENSION IF NOT EXISTS pageinspect;

DROP TABLE IF EXISTS mvcc_demo;

CREATE TABLE mvcc_demo (
    id INT PRIMARY KEY,
    balance INT
);

INSERT INTO mvcc_demo (id, balance) VALUES (1, 100);

```
## وضعیت اولیه رکورد

```sql

SELECT xmin, xmax, ctid, cmin, cmax, id, balance
FROM mvcc_demo;
```
## 📌 خروجی نمونه:

```resualt set
xmin = 1442
xmax = 0
ctid = (0,1)
balance = 100

```
## 🧠 تحلیل:

- xmin → تراکنشی که رکورد را ساخته  
- xmax = 0 → هنوز حذف یا invalidate نشده  
- ctid → آدرس فیزیکی tuple در صفحه  

---

## 🔍 بررسی سطح page (heap)

```sql
SELECT lp, t_xmin, t_xmax
FROM heap_page_items(get_raw_page('mvcc_demo', 0));
```

## 📌 اینجا می‌بینیم:

```sql
tuple در page 0 قرار دارد
t_xmin = تراکنش insert
t_xmax = هنوز خالی
```
## ✏️ عملیات UPDATE
```sql
UPDATE mvcc_demo
SET balance = 200
WHERE id = 1;
```
## 🔎 بعد از UPDATE
```sql
SELECT xmin, xmax, id, balance
FROM mvcc_demo;
```
## 📌 نکته مهم:

در MVCC، UPDATE یعنی:- نسخه قبلی mark شده   - نسخه جدید ساخته شده  
```sql
 SELECT lp, t_xmin, t_xmax
FROM heap_page_items(get_raw_page('mvcc_demo', 0));
```

## 🧠 تحلیل:

- رکورد قبلی هنوز در page هست   
- فقط `t_xmax` آن set شده (یعنی obsolete شده)  
## 🗑️ عملیات DELETE
```sql
DELETE FROM mvcc_demo WHERE id = 1;
```
## 🔎 بعد از DELETE
```sql
SELECT lp, t_xmin, t_xmax
FROM heap_page_items(get_raw_page('mvcc_demo', 0));
```
## 📌 تحلیل:

## رکورد هنوز physically وجود دارد
### فقط علامت‌گذاری شده به عنوان deleted (t_xmax پر شده)
### 🧹 VACUUM
```sql

VACUUM mvcc_demo;
```

## 🔎 بعد از VACUUM
```sql
SELECT t_xmin, t_xmax
FROM heap_page_items(get_raw_page('mvcc_demo', 0));
```

## 📌 نتیجه

- tupleهای dead پاک یا قابل reuse می‌شوند  
- فضای page بهینه می‌شود  

---

## 🧠 جمع‌بندی مهم MVCC

### PostgreSQL چه کار می‌کند؟

- **UPDATE = INSERT + mark old version as dead**
- **DELETE = mark as dead (نه حذف فوری)**
- **VACUUM = cleanup واقعی**

---

### ⚠️ نکته طلایی

> PostgreSQL هیچ‌وقت رکورد را فوراً overwrite نمی‌کند