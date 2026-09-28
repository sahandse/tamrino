# تمرینو

اپ فارسی مدیریت تمرین با Flutter؛ کاملاً آفلاین، خصوصی و بدون دیتای Demo / Fake / Test.

## نسخه
`0.4.0+4`

## قابلیت‌ها
- Flutter + Material 3 + RTL فارسی
- SQLite به‌عنوان منبع اصلی داده
- برنامه تمرینی، جلسات، ست‌ها، PR و 1RM
- Rest Timer، Superset، Drop Set، Warm-up و Rest-Pause
- تقویم تمرین، Heatmap و آمار عضلات
- ثبت وزن و اندازه‌های بدن
- بکاپ و بازیابی فقط به‌صورت فایل محلی
- یادآوری محلی هفتگی تمرین
- بازیابی جلسه نیمه‌کاره
- بدون حساب کاربری و بدون Google Drive

## Android
Package ID:

`ir.sahandse.tamrino`

Bootstrap پروژه Android:

```bash
python3 tool/bootstrap_android.py
flutter pub get
flutter run
```

مجوزهای اصلی Android فقط برای اعلان تمرین و بازیابی اعلان بعد از Restart هستند. برنامه برای قابلیت‌های اصلی خود نیاز به اینترنت ندارد.

## CI / GitHub Actions
Workflow `.github/workflows/android-build.yml` روی Push به `main` اجرا می‌شود و APK/AAB را برای اعتبارسنجی Build می‌سازد.

## Release امضاشده
Workflow `.github/workflows/release.yml` برای Tagهای `v*` آماده است و از GitHub Secrets برای Keystore استفاده می‌کند:

- `KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD`
- `KEY_ALIAS`
- `KEY_PASSWORD`

کلید امضا یا رمزها نباید داخل Repository Commit شوند.

نمونه Tag انتشار:

```bash
git tag v0.4.0
git push origin v0.4.0
```

## حریم خصوصی
اطلاعات تمرین فقط روی دستگاه ذخیره می‌شود. بکاپ فقط با انتخاب کاربر به‌صورت فایل محلی ساخته یا بازیابی می‌شود. هیچ بکاپ ابری یا اتصال Google Drive در برنامه وجود ندارد.
