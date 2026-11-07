# رفع خطای GitHub Actions — برق خودرو مهندس

این نسخه اصلاح شده است: دیگر از `./gradlew` یا دستور `chmod +x gradlew` استفاده نمی‌کند و Gradle 8.9 را در GitHub Actions آماده کرده و با دستور `gradle assembleDebug` می‌سازد.

## روش جایگزینی در مخزن GitHub
1. فایل ZIP را Extract کنید.
2. وارد مخزن GitHub شوید و فایل‌های ریشه را ببینید؛ `settings.gradle` باید مستقیماً در صفحه اصلی مخزن باشد.
3. فایل workflow قبلی را حذف کنید: `.github/workflows/android.yml` یا هر workflow قدیمی که در لاگ آن `chmod +x gradlew` دیده می‌شود.
4. تمام محتویات این پوشه استخراج‌شده را در ریشه مخزن بارگذاری کنید؛ پوشه مادر را به‌عنوان یک لایه اضافی آپلود نکنید. فایل جدید `.github/workflows/android.yml` را نیز همراه آن آپلود کنید.
5. Commit changes را بزنید.
6. Actions → Build Android APK → Run workflow را اجرا کنید.
7. پس از سبز شدن اجرا، از بخش Artifacts فایل `bargh-khodro-mohandes-debug-apk` را دانلود و Extract کنید؛ فایل `app-debug.apk` خروجی نصب است.

اگر workflow قدیمی باقی بماند، ممکن است همچنان خطای `gradlew: No such file or directory` بدهد؛ حتماً آن را حذف یا جایگزین کنید.
