# دليل تحويل ونشر تطبيق دوامي على نظام ويندوز (Windows Desktop EXE & Installer)

تم إعداد وهيكلة مشروع **دوامي (Dawami)** ليتحول إلى تطبيق مكتبي متكامل ومهني لنظام **Windows 10 / Windows 11**.

---

## 1. الهوية البصرية والأيقونات الرسمية (Application Icons)
تم تصميم وتوليد أيقونة رسمية خاصة بنظام الحضور الذكي والبيومتري:
- **الملف المصدري عالي الدقة (PNG):**
  - [app_icon.png](file:///d:/ibrahim/project/dow_/my_app/windows/runner/resources/app_icon.png)
  - [app_icon.png (Assets)](file:///d:/ibrahim/project/dow_/my_app/assets/icons/app_icon.png)
- **أيقونة ويندوز متعددة الدقة (Multi-Resolution Windows .ico):**
  - [app_icon.ico](file:///d:/ibrahim/project/dow_/my_app/windows/runner/resources/app_icon.ico)
  - تتضمن الدقات القياسية لشريط المهام وسطح المكتب وقوائم ويندوز: `256x256`, `128x128`, `64x64`, `48x48`, `32x32`, `16x16`.

---

## 2. هوية وبيانات التطبيق (Windows Application Identity)
- **اسم الملف التنفيذي:** `dawami.exe` (تم ضبطه في [CMakeLists.txt](file:///d:/ibrahim/project/dow_/my_app/windows/CMakeLists.txt)).
- **عنوان النافذة المكتبي:** `دوامي - نظام إدارة حضور وغياب الطلاب الذكي` (تم ضبطه في [main.cpp](file:///d:/ibrahim/project/dow_/my_app/windows/runner/main.cpp)).
- **الأبعاد الابتدائية:** `1360x850` بكسل لتناسب شاشات الحواسيب وسطح المكتب مع دعم كامل للتحجيم وتكبير النافذة.
- **البيانات الوصفية للبرنامج (Metadata):** تم تحديثها في [Runner.rc](file:///d:/ibrahim/project/dow_/my_app/windows/runner/Runner.rc):
  - **Company:** `Dawami Systems`
  - **Product Name:** `دوامي - نظام الحضور الذكي`
  - **File Version:** `1.1.0`
  - **Copyright:** `Copyright (C) 2026 Dawami Systems. All rights reserved.`

---

## 3. حزمة التثبيت الاحترافية (Inno Setup Installer)
تم إعداد سكربت التثبيت الرسمي في:
[dawami_installer.iss](file:///d:/ibrahim/project/dow_/my_app/windows/installer/dawami_installer.iss)

- يُنشئ مثبت ويندوز كامل: `dist\Dawami_Setup_v1.1.0.exe`.
- يدعم واجهة التثبيت باللغتين **العربية** والإنجليزية.
- ينشئ اختصاراً على سطح المكتب (Desktop Shortcut) وقائمة ابدأ (Start Menu) بأيقونة التطبيق الرسمية.
- يدعم إلغاء التثبيت النظيف (Clean Uninstaller).

---

## 4. البناء والتجميع بضغطة زر (One-Click Build Script)
تم إنشاء ملف تشغيل مباشر:
[build_windows_dist.bat](file:///d:/ibrahim/project/dow_/my_app/build_windows_dist.bat)

يقوم هذا السكربت بالآتي:
1. التحقق من توفر مترجم C++ من مايكروسوفت (Visual Studio 2022).
2. تشغيل `flutter pub get`.
3. تجميع ملفات الويندوز للإنتاج: `flutter build windows --release`.
4. التحقق من إنتاج `dawami.exe` في مجلد `build\windows\x64\runner\Release\`.
5. تشغيل مترجم `Inno Setup 6` لإنتاج برنامج التثبيت `Dawami_Setup_v1.1.0.exe` تلقائياً في مجلد `dist`.

---

## 5. متطلبات مترجم ويندوز (Visual Studio Toolchain)
يتطلب Flutter لبناء ملفات `.exe` على ويندوز وجود مترجم مايكروسوفت C++:
1. تحميل [Visual Studio Community 2022](https://visualstudio.microsoft.com/downloads/) (مجاني).
2. أثناء التثبيت، وضع علامة صح على:
   **Desktop development with C++** (تطوير برامج سطح المكتب باستخدام C++).
3. بعد اكتمال التثبيت، اضغط نقراً مزدوجاً على [build_windows_dist.bat](file:///d:/ibrahim/project/dow_/my_app/build_windows_dist.bat) ليتم إنتاج البرنامج والمثبت فوراً.
