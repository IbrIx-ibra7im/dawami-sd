@echo off
chcp 65001 >nul
title دوامي - بناء وتجميع تطبيق الويندوز (Dawami Windows Release Builder)

echo =====================================================================
echo           دوامي - نظام الحضور والغياب الذكي للطلاب والمؤسسات
echo              Dawami Desktop Release & Packaging Script
echo =====================================================================
echo.

cd /d "%~dp0"

echo [1/5] فحص متطلبات بيئة التطوير (Checking Visual Studio C++ Toolchain)...
where cl.exe >nul 2>nul
if %ERRORLEVEL% equ 0 goto :VS_FOUND

rem Check via vswhere if cl.exe is not directly in PATH
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" (
    for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
        set "VS_PATH=%%i"
    )
)

if defined VS_PATH (
    echo [√] تم العثور على Visual Studio في: %VS_PATH%
    goto :VS_FOUND
)

echo.
echo [!] تنبيه: يتطلب بناء تطبيق الويندوز (.exe) عبر Flutter تثبيت:
echo     Microsoft Visual Studio 2022 مع حزمة (Desktop development with C++)
echo.
echo هل ترغب في فتح صفحة التحميل الرسمية الآن؟ (اضغط Y للموافقة، أو N للإلغاء)
set /p USER_CHOICE="اختيارك (Y/N): "
if /i "%USER_CHOICE%"=="Y" (
    start https://aka.ms/vs/17/release/vs_community.exe
    echo.
    echo عند فتح مثبت Visual Studio:
    echo 1. اختر حزمة "Desktop development with C++"
    echo 2. اضغط Install
    echo 3. بعد اكتمال التثبيت، أعد تشغيل هذا الملف (build_windows_dist.bat)
)
echo.
pause
exit /b 1

:VS_FOUND
echo [√] تم التحقق من المترجم بنجاح!
echo.

echo [2/5] جلب الاعتماديات والمكتبات (flutter pub get)...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo [X] فشل جلب الحزم.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [3/5] بناء حزمة الويندوز المستقلة (flutter build windows --release)...
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo [X] حدث خطأ أثناء تجميع تطبيق الويندوز.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [4/5] التحقق من الملفات التنفيذية الناتجة...
if not exist "build\windows\x64\runner\Release\dawami.exe" (
    echo [X] لم يتم العثور على dawami.exe في مجلد Release.
    pause
    exit /b 1
)

echo [√] الملف التنفيذي جاهز: build\windows\x64\runner\Release\dawami.exe

echo.
echo [5/5] إنشاء حزمة التثبيت الرسمية Installer عبر Inno Setup...
if not exist "dist" mkdir "dist"

set "ISCC_PATH=C:\Users\%USERNAME%\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
if not exist "%ISCC_PATH%" (
    if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" set "ISCC_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    if exist "C:\Program Files\Inno Setup 6\ISCC.exe" set "ISCC_PATH=C:\Program Files\Inno Setup 6\ISCC.exe"
)

if exist "%ISCC_PATH%" (
    echo [√] جاري تجميع ملف التثبيت Dawami_Setup_v1.1.0.exe...
    "%ISCC_PATH%" "windows\installer\dawami_installer.iss"
    if %ERRORLEVEL% equ 0 (
        echo.
        echo [√] تم بنجاح إنشاء برنامج التثبيت في: dist\Dawami_Setup_v1.1.0.exe
    )
) else (
    echo [!] لم يتم العثور على ISCC.exe، تم إنشاء المجلد القابل للنقل فقط.
)

echo.
echo =====================================================================
echo                     اكتملت العملية بنجاح!
echo =====================================================================
echo.
echo المجلد التنفيذي القابل للتوزيع:
echo build\windows\x64\runner\Release\
echo.
if exist "dist\Dawami_Setup_v1.1.0.exe" (
    echo ملف التثبيت النهائي:
    echo dist\Dawami_Setup_v1.1.0.exe
    explorer.exe "dist"
) else (
    explorer.exe "build\windows\x64\runner\Release"
)
echo.
pause
