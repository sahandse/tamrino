# تمرینو

اپ فارسی مدیریت تمرین با Flutter.

## اصول پروژه
- بدون دیتای Demo / Fake / Test
- SQLite محلی به‌عنوان منبع اصلی داده
- بکاپ محلی روی گوشی
- بکاپ Google Drive در `appDataFolder`
- رابط فارسی RTL با Material 3
- Light/Dark Mode
- شروع برنامه با Empty State واقعی

## Google Drive
برای فعال‌سازی بکاپ ابری باید Google Drive API و OAuth Android برای package name و SHA-1/SHA-256 نسخه Release تنظیم شود.

Scope مورد استفاده:
`https://www.googleapis.com/auth/drive.appdata`
