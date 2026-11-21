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
  final String? publishedAt; // تاريخ وتوقيت النشر
  final bool hasApk; // هل يتوفر ملف APK قابل للتنزيل

  const AppReleaseInfo({
    required this.tagName,
    required this.cleanVersion,
    required this.name,
    required this.body,
    required this.htmlUrl,
    this.apkDownloadUrl,
    this.apkFileName,
    this.apkSize,
    this.publishedAt,
    this.hasApk = false,
  });

  bool get hasDirectApk => hasApk;

  String get apkSizeFormatted {
    if (apkSize == null || apkSize == 0) return '';
    final mb = apkSize! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} ميجابايت';
  }

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final rawTag = json['tag_name']?.toString() ?? '1.0.0';
    final clean = rawTag.replaceAll(RegExp(r'^[vV]'), '').trim();

    // استخراج رابط واسم وحجم ملف APK من مرفقات الإصدار (Assets)
    String? apkUrl;
    String? apkName;
    int? size;
    final assets = json['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      for (final asset in assets) {
        final name = asset['name']?.toString() ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apkUrl = asset['browser_download_url']?.toString();
          apkName = name;
          size = asset['size'] is int ? asset['size'] as int : int.tryParse(asset['size']?.toString() ?? '');
          break;
        }
      }
    }

    return AppReleaseInfo(
      tagName: rawTag,
      cleanVersion: clean,
      name: json['name']?.toString() ?? 'تحديث جديد',
      body: json['body']?.toString() ?? 'يتضمن هذا الإصدار تحسينات وإصلاحات جديدة لزيادة استقرار النظام.',
      htmlUrl: json['html_url']?.toString() ?? 'https://github.com/IbrIx-ibra7im/dawami-sd/releases',
      apkDownloadUrl: apkUrl,
      apkFileName: apkName,
      apkSize: size,
      publishedAt: json['published_at']?.toString(),
      hasApk: apkUrl != null && apkUrl.isNotEmpty,
    );
  }

  /// الرابط النهائي للتحديث: ملف الـ APK المباشر أو رابط صفحة الإصدار على GitHub
  String get downloadUrl => apkDownloadUrl ?? htmlUrl;
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
