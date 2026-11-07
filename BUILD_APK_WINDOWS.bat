@echo off
chcp 65001 >nul
echo ============================================
echo  برق خودرو مهندس - ساخت APK نسخه آزمايشي
echo ============================================
echo.
where gradle >nul 2>nul
if errorlevel 1 (
  echo Gradle در PATH پيدا نشد.
  echo روش پيشنهادي: پروژه را در Android Studio باز کنيد و از Build ^> Build APK(s) استفاده کنيد.
  pause
  exit /b 1
)
gradle --no-daemon assembleDebug
if errorlevel 1 (
  echo ساخت APK ناموفق بود. خطاهاي بالا را بررسي کنيد.
  pause
  exit /b 1
)
echo.
echo APK ساخته شد:
echo app\build\outputs\apk\debug\app-debug.apk
pause
