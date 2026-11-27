import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/local/hive_helper.dart';
import '../../data/models/update_info.dart';

/// خدمة إدارة والتحقق من تحديثات تطبيق دوامي عبر مستودع GitHub Releases
class UpdateService {
  static final UpdateService instance = UpdateService._internal();
  UpdateService._internal();

  // معلومات مستودع GitHub
  static const String repoOwner = 'IbrIx-ibra7im';
  static const String repoName = 'dawami-sd';
  static const String releasesApiUrl = 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
  static const String releasesWebUrl = 'https://github.com/$repoOwner/$repoName/releases';

  String? _cachedCurrentVersion;

  /// الحصول على رقم إصدار التطبيق الحالي المثبت
  Future<String> getCurrentVersion() async {
    if (_cachedCurrentVersion != null) return _cachedCurrentVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      _cachedCurrentVersion = version.isNotEmpty ? version : '1.1.0';
    } catch (e) {
      if (kDebugMode) print('PackageInfo note: $e');
      _cachedCurrentVersion = '1.1.0';
    }
    return _cachedCurrentVersion!;
  }

  /// هل التحقق التلقائي عند بدء التشغيل مفعّل؟
  Future<bool> isAutoCheckEnabled() async {
    try {
      if (HiveHelper.instance.isInitialized) {
        final val = await HiveHelper.instance.getSetting('auto_check_updates', defaultValue: 'true');
        return val != 'false';
      }
    } catch (_) {}
    return true;
  }

  /// تفعيل أو إيقاف التحقق التلقائي
  Future<void> setAutoCheckEnabled(bool enabled) async {
    try {
      if (HiveHelper.instance.isInitialized) {
        await HiveHelper.instance.setSetting('auto_check_updates', enabled ? 'true' : 'false');
      }
    } catch (_) {}
  }

  /// مقارنة رقمي إصدار (دلالي - Semantic Versioning)
  /// ترجع true إذا كان [latest] أحدث فعلياً وأعلى من [current]
  static bool isNewerVersion(String current, String latest) {
    try {
      // إزالة الأحرف والبادئات مثل v1.0.0 أو release-
      final cleanCurrent = current.replaceAll(RegExp(r'^[^\d]*'), '').split('+').first.trim();
      final cleanLatest = latest.replaceAll(RegExp(r'^[^\d]*'), '').split('+').first.trim();

      final currentParts = cleanCurrent.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final latestParts = cleanLatest.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      // مساواة عدد الخانات (Major.Minor.Patch)
      while (currentParts.length < 3) {
        currentParts.add(0);
      }
      while (latestParts.length < 3) {
        latestParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) {
          return true;
        } else if (latestParts[i] < currentParts[i]) {
          return false;
        }
      }

      // إذا تساوت الأرقام الأساسية، نتحقق من Build Number إذا توفر
      final currentBuild = current.contains('+') ? (int.tryParse(current.split('+').last) ?? 0) : 0;
      final latestBuild = latest.contains('+') ? (int.tryParse(latest.split('+').last) ?? 0) : 0;
      return latestBuild > currentBuild;
    } catch (e) {
      if (kDebugMode) print('Version comparison note: $e');
      return false;
    }
  }

  /// التحقق من مستودع GitHub Releases عن توفر إصدار جديد
  Future<CheckUpdateResult> checkForUpdate() async {
    final currentVer = await getCurrentVersion();

    try {
      final response = await http.get(
        Uri.parse(releasesApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Dawami-App-Updater',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        // لا توجد إصدارات منشورة بعد على Releases
        return CheckUpdateResult(
          status: UpdateCheckStatus.noReleases,
          currentVersion: currentVer,
          message: 'أنت تستخدم أحدث إصدار من التطبيق ($currentVer). لم يتم نشر إصدارات جديدة بعد على GitHub.',
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final release = AppReleaseInfo.fromJson(data);

        final hasNewVersion = isNewerVersion(currentVer, release.cleanVersion);

        if (hasNewVersion) {
          return CheckUpdateResult(
            status: UpdateCheckStatus.updateAvailable,
            currentVersion: currentVer,
            releaseInfo: release,
            message: 'يتوفر إصدار جديد من التطبيق (${release.cleanVersion})!',
          );
        } else {
          return CheckUpdateResult(
            status: UpdateCheckStatus.upToDate,
            currentVersion: currentVer,
            releaseInfo: release,
            message: 'أنت تستخدم أحدث إصدار من التطبيق ($currentVer).',
          );
        }
      }

      return CheckUpdateResult(
        status: UpdateCheckStatus.error,
        currentVersion: currentVer,
        message: 'تعذر التحقق من التحديثات من خادم GitHub (رمز الاستجابة: ${response.statusCode})',
      );
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socket') || errStr.contains('timeout') || errStr.contains('network') || errStr.contains('connection')) {
        return CheckUpdateResult(
          status: UpdateCheckStatus.offline,
          currentVersion: currentVer,
          message: 'تعذر الاتصال بخادم GitHub. يرجى التحقق من توفر الإنترنت والمحاولة مجدداً.',
        );
      }

      return CheckUpdateResult(
        status: UpdateCheckStatus.error,
        currentVersion: currentVer,
        message: 'حدث خطأ أثناء فحص التحديثات: $e',
      );
    }
  }

  /// فتح رابط تنزيل التحديث أو صفحة الإصدار في المتصفح الخارجي
  Future<bool> openUpdateUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (kDebugMode) print('Launch URL error: $e');
      return false;
    }
  }

  /// فتح صفحة الإصدارات الرسمية للمستودع على GitHub
  Future<bool> openReleasesPage() => openUpdateUrl(releasesWebUrl);
}
