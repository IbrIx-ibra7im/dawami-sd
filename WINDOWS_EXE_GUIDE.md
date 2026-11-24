# دليل تشغيل وتثبيت تطبيق دوامي لنظام ويندوز (Windows Desktop)

تم بنجاح تحويل وتجميع مشروع **دوامي (Dawami)** إلى تطبيق مكتبي كامل وتوليد ملف التثبيت والملف التنفيذي الرسمي لنظام **Windows 10 / Windows 11**.

---

## 1. المخرجات الجاهزة للاستخدام (Ready Outputs)

### أ) برنامج التثبيت الرسمي (Windows Installer):
- **المسار:** [Dawami_Setup_v1.1.0.exe](file:///d:/ibrahim/project/dow_/my_app/dist/Dawami_Setup_v1.1.0.exe)
- **الحجم:** `9.7 MB`
- **المزايا:**
  - معالج تثبيت باللغة العربية والإنجليزية.
  - إنشاء اختصار رسمي على سطح المكتب وقائمة Start بالأيقونة المعتمدة.
  - دعم إلغاء التثبيت الآمن (Clean Uninstaller).

### ب) النسخة المحمولة القابلة للتشغيل المباشر (Portable App):
- **الملف التنفيذي:** [Dawami.exe](file:///d:/ibrahim/project/dow_/my_app/dist/Dawami_Release/Dawami.exe)
- **المجلد الكامل:** [dist\Dawami_Release](file:///d:/ibrahim/project/dow_/my_app/dist/Dawami_Release)
- **طريقة التشغيل:** نقرة مزدوجة على `Dawami.exe` لتفتح نافذة التطبيق المستقلة فوراً (1360x850) بدون الحاجة إلى متصفح أو إنترنت.

---

## 2. الهوية البصرية والأيقونات المدمجة (Icons & Branding)
- **ملف الأيقونة الرسمية المتعددة الدقة:** [app_icon.ico](file:///d:/ibrahim/project/dow_/my_app/windows/runner/resources/app_icon.ico)
  - مدمجة مباشرة داخل الترويسة الثنائية لملف `Dawami.exe` وملف التثبيت.
  - دقة عالية تدعم شريط المهام وسطح المكتب (256x256 وصولاً لـ 16x16).
- **ملف الأيقونة المصدري عالي الدقة:** [app_icon.png](file:///d:/ibrahim/project/dow_/my_app/windows/runner/resources/app_icon.png).

---

## 3. إعادة التجميع في أي وقت (Build Script)
إذا قمت بإجراء أي تعديلات برمجية جديدة على التطبيق وأردت تحديث ملف `.exe`، كل ما عليك فعله هو الضغط نقراً مزدوجاً على:
- [build_windows_dist.bat](file:///d:/ibrahim/project/dow_/my_app/build_windows_dist.bat)
حيث يقوم بتحديث الملفات وتجميع `Dawami.exe` ومثبت `Dawami_Setup_v1.1.0.exe` تلقائياً بضغطة زر واحدة.
