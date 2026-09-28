# تمرینو

اپ فارسی مدیریت تمرین با Flutter؛ آفلاین، خصوصی و بدون دیتای Demo / Fake / Test.

## وضعیت پروژه
- Flutter + Material 3 + RTL فارسی
- SQLite به‌عنوان منبع اصلی داده
- برنامه تمرینی، جلسات، ست‌ها، PR و 1RM
- Rest Timer، Superset، Drop Set، Warm-up و Rest-Pause
- تقویم تمرین، Heatmap و آمار عضلات
- ثبت وزن و اندازه‌های بدن
- بکاپ محلی و Google Drive
- یادآوری محلی هفتگی تمرین
- بازیابی جلسه نیمه‌کاره
- GitHub Actions برای ساخت APK و AAB

## Android
Package ID نهایی پروژه:

`ir.sahandse.tamrino`

پروژه Android به‌صورت تکرارپذیر با Flutter Stable ساخته و تنظیم می‌شود:

```bash
python3 tool/bootstrap_android.py
flutter pub get
flutter run
```

Bootstrap این تنظیمات را اعمال می‌کند:
- نام برنامه: تمرینو
- Package ID: `ir.sahandse.tamrino`
- Permission اینترنت برای Google Drive
- Permission اعلان Android 13+
- بازیابی یادآوری‌ها بعد از Restart دستگاه
- Core Library Desugaring موردنیاز اعلان‌های زمان‌بندی‌شده

## CI / GitHub Actions
Workflow فایل `.github/workflows/android-build.yml` روی Push به `main` اجرا می‌شود و:

1. Flutter Stable 3.47.5 را نصب می‌کند.
2. Android project را Bootstrap می‌کند.
3. `flutter pub get` و `flutter analyze` اجرا می‌کند.
4. APK و AAB برای اعتبارسنجی Build می‌سازد.
5. خروجی‌ها را به‌صورت GitHub Actions Artifact نگه می‌دارد.

## Release امضاشده
Workflow فایل `.github/workflows/release.yml` برای Tagهای `v*` ساخته شده است.

برای Release واقعی، در GitHub از مسیر `Settings → Secrets and variables → Actions` این Secretها را بسازید:

- `KEYSTORE_BASE64` — محتوای Base64 کل فایل Keystore
- `KEYSTORE_PASSWORD` — رمز Keystore
- `KEY_ALIAS` — Alias کلید
- `KEY_PASSWORD` — رمز همان کلید

Keystore و رمزها هرگز نباید داخل Repository Commit شوند.

بعد از تنظیم Secrets، یک Tag نسخه ایجاد کنید، برای مثال:

```bash
git tag v0.3.0
git push origin v0.3.0
```

GitHub Actions به‌صورت خودکار:

1. Keystore را فقط داخل Runner موقت بازیابی می‌کند.
2. APK و AAB را با کلید Release امضا می‌کند.
3. SHA-256 فایل‌ها را می‌سازد.
4. فایل‌ها را به‌صورت Artifact ذخیره می‌کند.
5. GitHub Release همان Tag را همراه APK، AAB و `SHA256SUMS.txt` منتشر می‌کند.
6. فایل Keystore موقت را در پایان حذف می‌کند.

## Google Drive
برای فعال‌شدن بکاپ ابری واقعی، در Google Cloud یک OAuth Client از نوع Android با این Package ID بسازید:

`ir.sahandse.tamrino`

SHA-1 و SHA-256 باید مربوط به کلید Release نهایی باشند و Google Drive API نیز فعال شود.

Scope استفاده‌شده:

`https://www.googleapis.com/auth/drive.appdata`

## حریم خصوصی
اطلاعات تمرین به‌صورت پیش‌فرض روی دستگاه ذخیره می‌شود. بکاپ محلی یا Google Drive فقط با اقدام خود کاربر انجام می‌شود.
