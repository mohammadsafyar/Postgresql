# Cache Hit Ratio Investigation Runbook

## 🎯 هدف
بررسی اینکه workload تا چه حد از RAM (cache) سرو می‌شود.

---

## 📊 Interpretation

### ✅ Good State
- > 99% → healthy system
- workload mostly in memory

### ⚠️ Warning
- 95% - 99% → normal but monitor

### 🔴 Bad State
- < 95% → احتمال disk I/O high

---

## 🧪 If ratio is low:

### 1. Check shared_buffers
Run:
- `SHOW shared_buffers;`

👉 recommendation:
- ~25% of system RAM

---

### 2. Check working set size
If single big table causes low ratio:
→ normal behavior (table too big for RAM)

---

### 3. Check recent restart
After restart:
- cache is cold
- ratio temporarily low

---

### 4. OS cache note
PostgreSQL cache ≠ OS cache
Even if ratio is low:
- OS may still cache data

---

## 🚨 When to worry

- Low ratio + high disk read I/O
- Slow queries + high blks_read
- Frequent full table scans
