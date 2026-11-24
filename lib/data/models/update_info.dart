/// نموذج معلومات إصدار وتحديث تطبيق دوامي من مستودع GitHub
class AppReleaseInfo {
  final String tagName; // رقم الإصدار من GitHub (مثال: v1.1.0 أو 1.1.0)
  final String cleanVersion; // رقم الإصدار بعد إزالة v والرموز (مثال: 1.1.0)
  final String name; // عنوان الإصدار
  final String body; // تفاصيل وملاحظات التحديث (Release Notes)
  final String htmlUrl; // رابط صفحة الإصدار على GitHub
  final String? apkDownloadUrl; // رابط تنزيل ملف APK المباشر من المرفقات (إن وجد)
  final String? apkFileName; // اسم ملف الـ APK
  final int? apkSize; // حجم ملف الـ APK بالبايت
  final String? exeDownloadUrl; // رابط تنزيل مثبت ويندوز EXE المباشر من المرفقات (إن وجد)
  final String? exeFileName; // اسم ملف الـ EXE
  final int? exeSize; // حجم ملف الـ EXE بالبايت
  final String? publishedAt; // تاريخ وتوقيت النشر
  final bool hasApk; // هل يتوفر ملف APK قابل للتنزيل
  final bool hasExe; // هل يتوفر ملف EXE مثبت ويندوز

  const AppReleaseInfo({
    required this.tagName,
    required this.cleanVersion,
    required this.name,
    required this.body,
    required this.htmlUrl,
    this.apkDownloadUrl,
    this.apkFileName,
    this.apkSize,
    this.exeDownloadUrl,
    this.exeFileName,
    this.exeSize,
    this.publishedAt,
    this.hasApk = false,
    this.hasExe = false,
  });

  bool get hasDirectApk => hasApk;
  bool get hasDirectExe => hasExe;

  String get apkSizeFormatted {
    if (apkSize == null || apkSize == 0) return '';
    final mb = apkSize! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} ميجابايت';
  }

  String get exeSizeFormatted {
    if (exeSize == null || exeSize == 0) return '';
    final mb = exeSize! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} ميجابايت';
  }

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final rawTag = json['tag_name']?.toString() ?? 'v1.1.0';
    final clean = rawTag.replaceAll(RegExp(r'^[vV]'), '').trim();

    // استخراج روابط واسماء وأحجام ملفات التحديث (APK و EXE) من مرفقات الإصدار
    String? apkUrl;
    String? apkName;
    int? apkSize;
    String? exeUrl;
    String? exeName;
    int? exeSize;

    final assets = json['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      for (final asset in assets) {
        final name = asset['name']?.toString() ?? '';
        final lower = name.toLowerCase();
        if (lower.endsWith('.apk')) {
          apkUrl = asset['browser_download_url']?.toString();
          apkName = name;
          apkSize = asset['size'] is int ? asset['size'] as int : int.tryParse(asset['size']?.toString() ?? '');
        } else if (lower.endsWith('.exe')) {
          exeUrl = asset['browser_download_url']?.toString();
          exeName = name;
          exeSize = asset['size'] is int ? asset['size'] as int : int.tryParse(asset['size']?.toString() ?? '');
        }
      }
    }

    final releaseHtmlUrl = json['html_url']?.toString() ??
        'https://github.com/IbrIx-ibra7im/dawami-sd/releases/tag/$rawTag';

    return AppReleaseInfo(
      tagName: rawTag,
      cleanVersion: clean,
      name: json['name']?.toString() ?? 'تحديث جديد',
      body: json['body']?.toString() ?? 'يتضمن هذا الإصدار تحسينات وإصلاحات جديدة لزيادة استقرار النظام.',
      htmlUrl: releaseHtmlUrl,
      apkDownloadUrl: apkUrl,
      apkFileName: apkName,
      apkSize: apkSize,
      exeDownloadUrl: exeUrl,
      exeFileName: exeName,
      exeSize: exeSize,
      publishedAt: json['published_at']?.toString(),
      hasApk: apkUrl != null && apkUrl.isNotEmpty,
      hasExe: exeUrl != null && exeUrl.isNotEmpty,
    );
  }

  /// رابط موقع التحميل المعتمد للإصدار على GitHub
  String get downloadUrl => htmlUrl.isNotEmpty
      ? htmlUrl
      : 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/tag/$tagName';
}

enum UpdateCheckStatus {
  updateAvailable, // يتوفر تحديث جديد
  upToDate, // التطبيق محدث بالفعل لأحدث إصدار
  noReleases, // لا توجد إصدارات منشورة بعد على GitHub Releases
  offline, // لا يوجد اتصال بالإنترنت
  error, // حدث خطأ أثناء الاتصال
}

/// نتيجة فحص التحديثات
class CheckUpdateResult {
  final UpdateCheckStatus status;
  final String currentVersion;
  final AppReleaseInfo? releaseInfo;
  final String message;

  const CheckUpdateResult({
    required this.status,
    required this.currentVersion,
    this.releaseInfo,
    required this.message,
  });
}
