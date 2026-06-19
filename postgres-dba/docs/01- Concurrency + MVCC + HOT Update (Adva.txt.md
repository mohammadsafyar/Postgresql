## 🧪 Concurrency + MVCC + HOT Update (Advanced PostgreSQL

```sql

DROP TABLE IF EXISTS mvcc_hot_demo;

CREATE TABLE mvcc_hot_demo (
    id INT PRIMARY KEY,
    value INT,
    note TEXT
);

CREATE INDEX idx_mvcc_hot_demo_value ON mvcc_hot_demo(value);

INSERT INTO mvcc_hot_demo VALUES (1, 100, 'initial');

```

🧪 Phase 1 — دو Session باز کن

🟦 Session A

```sql
BEGIN;
SELECT * FROM mvcc_hot_demo WHERE id = 1;
```
🟩 Session B

```sql
BEGIN;

SELECT * FROM mvcc_hot_demo WHERE id = 1;

```
🧠 نکته مهم

Session A هنوز مقدار قدیمی را می‌بیند.

چرا؟

👉 چون MVCC snapshot isolation است
👉 هیچ shared lock روی read وجود ندارد
🧪 Phase 2 — Visibility test

🟦 Session A

```sql
SELECT * FROM mvcc_hot_demo WHERE id = 1;
```

📌 نتیجه:

value = 100

🟩 Session B
COMMIT;

🟦 Session A دوباره:

```sql
SELECT * FROM mvcc_hot_demo WHERE id = 1;

```
📌 حالا:
value = 200

🧠 نتیجه MVCC (خیلی مهم برای تیم)
هر transaction snapshot خودش را دارد
تغییرات commit شده فقط بعد از commit قابل مشاهده‌اند
هیچ blocking روی read نداریم

