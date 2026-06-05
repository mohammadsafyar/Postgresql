-- نمایش نام دیتابیسی که الان بهش وصل هستیم
SELECT current_database();

-- کاربری که الان باهاش به دیتابیس لاگین کردیم
SELECT CURRENT_USER;

-- کاربر سشن فعلی (ممکنه با CURRENT_USER فرق داشته باشه در حالت SET ROLE)
SELECT session_user;

-- شناسه پروسس بک‌اند PostgreSQL برای همین connection
SELECT pg_backend_pid();

-- آدرس IP کلاینتی که به دیتابیس وصل شده
SELECT inet_client_addr();

-- پورتی که کلاینت برای اتصال استفاده کرده
SELECT inet_client_port();

