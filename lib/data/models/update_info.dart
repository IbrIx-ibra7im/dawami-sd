/// نموذج معلومات إصدار وتحديث تطبيق دوامي لسطح المكتب (Windows Desktop) من مستودع GitHub Releases
class AppReleaseInfo {
  final String tagName; // رقم الإصدار من GitHub (مثال: v1.1.0 أو 1.1.0)
  final String cleanVersion; // رقم الإصدار بعد إزالة v والرموز (مثال: 1.1.0)
  final String name; // عنوان الإصدار
  final String body; // تفاصيل وملاحظات التحديث (Release Notes / Changelog)
  final String htmlUrl; // رابط صفحة الإصدار على GitHub
  final String? exeDownloadUrl; // رابط تنزيل تطبيق سطح المكتب المباشر (EXE / Installer / Zip)
  final String? exeFileName; // اسم ملف تطبيق سطح المكتب
  final int? exeSize; // حجم ملف التطبيق بالبايت
  final String? publishedAt; // تاريخ وتوقيت النشر
  final bool hasExe; // هل يتوفر تطبيق سطح المكتب قابل للتنزيل المباشر

  const AppReleaseInfo({
    required this.tagName,
    required this.cleanVersion,
    required this.name,
    required this.body,
    required this.htmlUrl,
    this.exeDownloadUrl,
    this.exeFileName,
    this.exeSize,
    this.publishedAt,
    this.hasExe = false,
  });

  /// مسميات بديلة ومتوافقة مع النظام
  String get version => cleanVersion;
  String get changelog => body;
  bool get hasDirectExe => hasExe;

  String get exeSizeFormatted {
    if (exeSize == null || exeSize == 0) return '';
    final mb = exeSize! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} ميجابايت';
  }

  /// الرابط المباشر لتنزيل تطبيق سطح المكتب لويندوز (.exe / installer)، وفي حال عدم توفره يتم الانتقال لصفحة الإصدار
  String get downloadUrl {
    if (exeDownloadUrl != null && exeDownloadUrl!.isNotEmpty) {
      return exeDownloadUrl!;
    }
    return htmlUrl.isNotEmpty
        ? htmlUrl
        : 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/tag/$tagName';
  }

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final rawTag = json['tag_name']?.toString() ?? 'v1.1.0';
    final clean = rawTag.replaceAll(RegExp(r'^[vV]'), '').trim();

    // استخراج رابط واسم وحجم تطبيق سطح المكتب لويندوز (.exe أو .msi أو .zip) من مرفقات الإصدار
    String? exeUrl;
    String? exeName;
    int? exeSize;

    final assets = json['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      for (final asset in assets) {
        final name = asset['name']?.toString() ?? '';
        final lower = name.toLowerCase();

        // إعطاء الأولوية لملفات مثبت ويندوز (.exe أو .msi) أو الحزم المضغوطة (.zip)
        if (lower.endsWith('.exe') || lower.endsWith('.msi')) {
          exeUrl = asset['browser_download_url']?.toString();
          exeName = name;
          exeSize = asset['size'] is int ? asset['size'] as int : int.tryParse(asset['size']?.toString() ?? '');
          break; // تم العثور على التطبيق التنفيذي المباشر
        } else if (lower.endsWith('.zip') && exeUrl == null) {
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
      body: json['body']?.toString() ?? 'يتضمن هذا الإصدار تحسينات وإصلاحات جديدة لزيادة استقرار وسرعة تطبيق سطح المكتب.',
      htmlUrl: releaseHtmlUrl,
      exeDownloadUrl: exeUrl,
      exeFileName: exeName,
      exeSize: exeSize,
      publishedAt: json['published_at']?.toString(),
      hasExe: exeUrl != null && exeUrl.isNotEmpty,
    );
  }
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
