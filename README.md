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
4. APK و AAB Release می‌سازد.
5. خروجی‌ها را به‌صورت GitHub Actions Artifact نگه می‌دارد.

> خروجی CI فعلی برای تست Build است. برای انتشار مارکت باید Release Signing اختصاصی با Keystore و GitHub Secrets فعال شود.

## Google Drive
برای فعال‌شدن بکاپ ابری واقعی، در Google Cloud یک OAuth Client از نوع Android با این Package ID بسازید:

`ir.sahandse.tamrino`

SHA-1 و SHA-256 باید مربوط به کلید Release نهایی باشند و Google Drive API نیز فعال شود.

Scope استفاده‌شده:

`https://www.googleapis.com/auth/drive.appdata`

## حریم خصوصی
اطلاعات تمرین به‌صورت پیش‌فرض روی دستگاه ذخیره می‌شود. بکاپ محلی یا Google Drive فقط با اقدام خود کاربر انجام می‌شود.
