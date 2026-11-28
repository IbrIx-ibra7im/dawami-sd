@echo off
chcp 65001 >nul
title دوامي - بناء وتجميع تطبيق الويندوز (Dawami Windows Release Builder)

echo =====================================================================
echo           دوامي - نظام الحضور والغياب الذكي للطلاب والمؤسسات
echo              Dawami Desktop Release & Packaging Script
echo =====================================================================
echo.

cd /d "%~dp0"

echo [1/4] تجميع واجهة ومحرك فلاتر المكتبي...
call flutter build web --release --no-tree-shake-icons
if %ERRORLEVEL% neq 0 (
    echo [X] فشل تجميع ملفات الواجهة.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/4] تجميع الحزمة المدمجة والملف التنفيذي الذاتي Dawami.exe...
powershell -NoProfile -Command "Compress-Archive -Path 'build\web\*' -DestinationPath 'windows\launcher\web_bundle.zip' -Force"
if not exist "dist\Dawami_Release\data\web" mkdir "dist\Dawami_Release\data\web"

set "CSC_EXE=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
"%CSC_EXE%" /target:winexe /r:System.IO.Compression.FileSystem.dll /r:System.IO.Compression.dll /resource:"windows\launcher\web_bundle.zip,DawamiWebBundle" /win32icon:"windows\runner\resources\app_icon.ico" /out:"dist\Dawami.exe" "windows\launcher\DawamiLauncher.cs"
if %ERRORLEVEL% neq 0 (
    echo [X] حدث خطأ أثناء تجميع Dawami.exe.
    pause
    exit /b %ERRORLEVEL%
)
copy /Y "dist\Dawami.exe" "dist\Dawami_Release\Dawami.exe" >nul

echo.
echo [3/4] نسخ ملفات التشغيل والمكتبات إلى مجلد dist\Dawami_Release...
xcopy "build\web\*" "dist\Dawami_Release\data\web\" /E /I /Y /Q >nul
copy /Y "windows\runner\resources\app_icon.ico" "dist\Dawami_Release\" >nul

echo [√] تم بنجاح إنشاء المجلد القابل للتشغيل المباشر: dist\Dawami_Release\Dawami.exe

echo.
echo [4/4] تجميع مثبت ويندوز الرسمي (Inno Setup Installer)...
set "ISCC_PATH=C:\Users\%USERNAME%\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
if not exist "%ISCC_PATH%" (
    if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" set "ISCC_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    if exist "C:\Program Files\Inno Setup 6\ISCC.exe" set "ISCC_PATH=C:\Program Files\Inno Setup 6\ISCC.exe"
)

if exist "%ISCC_PATH%" (
    "%ISCC_PATH%" "windows\installer\dawami_installer.iss"
    if %ERRORLEVEL% equ 0 (
        echo.
        echo [√] تم إنشاء برنامج التثبيت الرسمي: dist\Dawami_Setup_v1.1.0.exe
    )
) else (
    echo [!] لم يتم العثور على ISCC.exe، تم تجهيز المجلد المكتبي المباشر بنجاح.
)

echo.
echo =====================================================================
echo                     اكتملت العملية بنجاح!
echo =====================================================================
echo.
echo الملف التنفيذي المحمول:
echo dist\Dawami_Release\Dawami.exe
echo.
echo مثبت ويندوز الكامل:
echo dist\Dawami_Setup_v1.1.0.exe
echo.
explorer.exe "dist"
pause
