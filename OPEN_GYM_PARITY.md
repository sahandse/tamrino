# Tamrino ↔ openGym feature parity

این فایل برای مقایسه قابلیت‌های تمرینو با `DuarteSantos8/openGym` است.

> نکته مجوز: openGym تحت AGPL-3.0 منتشر شده است. تمرینو کد، دیتاست یا Assetهای آن را کپی نمی‌کند؛ قابلیت‌های عمومی به‌صورت مستقل برای Flutter/SQLite پیاده‌سازی می‌شوند.
>
> تمرینو عمداً Offline-first و بدون حساب کاربری/سرور باقی می‌ماند.

## پوشش فعلی تمرینو

### برنامه و اجرای تمرین
- [x] برنامه هفتگی
- [x] تغییر برنامه فقط برای همان هفته
- [x] تمرین آزاد (Freestyle)
- [x] ثبت تمرین گذشته با تاریخ و ساعت دلخواه
- [x] ویرایش جلسه ذخیره‌شده
- [x] افزودن حرکت وسط تمرین
- [x] حذف حرکت فقط از جلسه جاری
- [x] Swap Exercise
- [x] Drag & Drop ترتیب حرکات برنامه
- [x] کپی برنامه
- [x] ذخیره جلسه قبلی به‌عنوان برنامه جدید
- [x] یادداشت جلسه و حرکت
- [x] Warm-up / Drop Set / Rest-Pause / Superset
- [x] حرکت‌های زمانی
- [x] حرکت‌های وزن بدن
- [x] تکرار هر سمت
- [x] زمان استراحت اختصاصی هر حرکت
- [x] Rest Timer
- [x] پیشنهاد مقادیر جلسه قبل
- [x] ادامه جلسه نیمه‌کاره بعد از بازکردن دوباره اپ
- [x] روشن ماندن صفحه در جلسه فعال (قابل خاموش‌کردن)

### Progression و ابزار وزنه
- [x] Progressive Overload اختیاری
- [x] Double Progression
- [x] Greyskull-style progression مستقل و محافظه‌کارانه
- [x] Recovery / Deload mode
- [x] 1RM تخمینی از ست‌های ثبت‌شده
- [x] 1RM Calculator مستقل (فقط 1 تا 12 تکرار)
- [x] Plate Math داخل تمرین
- [x] Plate Calculator مستقل
- [x] موجودی صفحه‌های هالتر قابل تنظیم
- [x] وزن میله جدا برای حرکت
- [x] RPE / RIR data model و انتخاب مقیاس

### Cardio و انواع حرکت
- [x] حرکت Strength
- [x] حرکت Timed
- [x] حرکت Cardio
- [x] مدت Cardio
- [x] مسافت Cardio
- [x] سرعت Cardio
- [x] RPE/RIR برای Cardio

### Exercise Library
- [x] ساخت/ویرایش حرکت سفارشی
- [x] Favorite
- [x] عضله و تجهیزات
- [x] فیلتر عضله/تجهیزات
- [x] تصویر/GIF/ویدئوی محلی برای حرکت سفارشی
- [x] لینک راهنمای اختیاری برای حرکت
- [x] حالت نمایش مدیا (بزرگ/کوچک/مخفی) در Preferences
- [ ] نمایش کامل عکس/GIF/ویدئو داخل Workout UI
- [ ] صفحه History اختصاصی هر حرکت داخل Workout

### تاریخچه و آمار
- [x] تاریخچه جلسه‌ها
- [x] ویرایش ست ذخیره‌شده
- [x] افزودن/حذف ست در جلسه ذخیره‌شده
- [x] حجم تمرین
- [x] PR و 1RM تخمینی
- [x] نمودار Volume
- [x] Activity Heatmap
- [x] تقویم تمرین
- [x] شروع هفته قابل تنظیم (شنبه/یکشنبه/دوشنبه)
- [x] درگیری عضلات بر اساس دیتای واقعی
- [x] مقایسه رکوردهای قدرت بدون امتیازدهی بدنی
- [x] Copy Workout as Text
- [x] عکس/GIF/ویدئو به‌عنوان Attachment جلسه

### برنامه قابل انتقال
- [x] Export برنامه به JSON کوچک
- [x] Import و Merge برنامه
- [x] فایل انتقال برنامه شامل تاریخچه یا اطلاعات بدن نیست

### تنظیمات و UX
- [x] Light / Dark mode
- [x] RTL فارسی
- [x] Reminder هفتگی محلی
- [x] Start of week setting
- [x] Keep screen awake setting
- [x] Timer visual flash preference
- [x] Exercise media visibility preference
- [x] Local backup / restore
- [x] بدون Demo/Test data
- [x] بدون حساب کاربری و بدون Cloud
- [ ] اعمال Visual Flash در پایان تایمر داخل Workout UI
- [ ] Theme accent انتخابی

## مواردی که عمداً از openGym وارد نمی‌شوند

این موارد با معماری آفلاین تمرینو یا مدل انتشار مستقل آن تضاد دارند:

- Passkey / WebAuthn / account authentication
- Server-side multi-device sync
- Server admin dashboard
- User management / moderation
- Server-side image storage
- کپی دیتاست حرکات openGym
- کپی Animationها یا سایر Assetهای AGPL openGym
- کپی سورس‌کد openGym

برای Exercise Library بزرگ، در صورت اضافه‌شدن دیتاست آماده باید منبعی با مجوز مستقل و مناسب انتشار انتخاب شود.

## مرحله Parity بعدی

1. Media preview واقعی در Workout (image/GIF/video)
2. Exercise History در همان صفحه اجرای تمرین
3. اعمال RIR/RPE انتخاب‌شده روی تمام Strength Setهای جدید
4. اعمال Plate Inventory روی Plate Math داخل هر Set
5. Visual Flash واقعی در پایان Rest Timer
6. Year heatmap / فیلتر بازه آمار
7. ابزارهای Muscle Map بیشتر با برچسب‌های توصیفی و غیرپزشکی
8. On-demand starter templates بدون Seed/Demo خودکار
