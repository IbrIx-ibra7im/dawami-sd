import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/services/update_service.dart';
import 'package:my_app/data/models/update_info.dart';

void main() {
  group('UpdateService Version Comparison Tests', () {
    test('Identifies newer minor and patch versions', () {
      expect(UpdateService.isNewerVersion('1.0.0', '1.0.1'), isTrue);
      expect(UpdateService.isNewerVersion('1.0.0', '1.1.0'), isTrue);
      expect(UpdateService.isNewerVersion('1.0.0', '2.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('1.2.3', '1.2.4'), isTrue);
      expect(UpdateService.isNewerVersion('1.2.3', '1.3.0'), isTrue);
    });

    test('Identifies older or equal versions', () {
      expect(UpdateService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('1.1.0', '1.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('2.0.0', '1.9.9'), isFalse);
      expect(UpdateService.isNewerVersion('1.2.3', '1.2.3'), isFalse);
    });

    test('Handles v prefixes cleanly', () {
      expect(UpdateService.isNewerVersion('1.0.0', 'v1.1.0'), isTrue);
      expect(UpdateService.isNewerVersion('v1.0.0', 'v1.0.1'), isTrue);
      expect(UpdateService.isNewerVersion('v2.0.0', 'v1.9.0'), isFalse);
    });

    test('Handles build numbers (+1, +2)', () {
      expect(UpdateService.isNewerVersion('1.0.0+1', '1.0.0+2'), isTrue);
      expect(UpdateService.isNewerVersion('1.0.0+2', '1.0.0+1'), isFalse);
      expect(UpdateService.isNewerVersion('1.0.0+5', '1.0.1+1'), isTrue);
    });
  });

  group('AppReleaseInfo Model Tests', () {
    test('Parses GitHub Release JSON with APK asset', () {
      final json = {
        'tag_name': 'v1.2.0',
        'name': 'Dawami Release 1.2.0',
        'body': 'Features:\n- Added barcode camera scanner\n- Improved UI',
        'html_url': 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/tag/v1.2.0',
        'published_at': '2026-11-21T12:00:00Z',
        'prerelease': false,
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/download/v1.2.0/app-release.apk',
            'size': 25000000,
          },
          {
            'name': 'source.zip',
            'browser_download_url': 'https://github.com/.../source.zip',
            'size': 1000000,
          }
        ],
      };

      final release = AppReleaseInfo.fromJson(json);
      expect(release.tagName, 'v1.2.0');
      expect(release.cleanVersion, '1.2.0');
      expect(release.name, 'Dawami Release 1.2.0');
      expect(release.apkDownloadUrl, 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/download/v1.2.0/app-release.apk');
      expect(release.apkFileName, 'app-release.apk');
      expect(release.hasDirectApk, isTrue);
      expect(release.apkSizeFormatted, isNotEmpty);
    });

    test('Parses GitHub Release JSON with APK and Windows EXE assets', () {
      final json = {
        'tag_name': 'v1.1.0',
        'name': 'Dawami Release 1.1.0',
        'body': 'Features:\n- Added Windows Installer',
        'html_url': 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/tag/v1.1.0',
        'assets': [
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/download/v1.1.0/app-release.apk',
            'size': 88000000,
          },
          {
            'name': 'Dawami_Setup_v1.1.0.exe',
            'browser_download_url': 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/download/v1.1.0/Dawami_Setup_v1.1.0.exe',
            'size': 9700000,
          }
        ],
      };

      final release = AppReleaseInfo.fromJson(json);
      expect(release.cleanVersion, '1.1.0');
      expect(release.hasDirectApk, isTrue);
      expect(release.hasDirectExe, isTrue);
      expect(release.exeFileName, 'Dawami_Setup_v1.1.0.exe');
      expect(release.downloadUrl, 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/tag/v1.1.0');
    });

    test('Parses GitHub Release JSON without APK asset fallback', () {
      final json = {
        'tag_name': 'v1.0.0',
        'name': 'Initial Release',
        'body': 'First version',
        'html_url': 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/tag/v1.0.0',
        'assets': <dynamic>[],
      };

      final release = AppReleaseInfo.fromJson(json);
      expect(release.cleanVersion, '1.0.0');
      expect(release.hasDirectApk, isFalse);
      expect(release.apkDownloadUrl, isNull);
    });
  });
}
