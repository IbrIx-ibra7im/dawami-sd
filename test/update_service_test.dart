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

  group('AppReleaseInfo Model Tests (Windows Desktop Updates)', () {
    test('Parses GitHub Release JSON with Windows EXE installer asset', () {
      final json = {
        'tag_name': 'v1.1.0',
        'name': 'Dawami Windows Release 1.1.0',
        'body': 'Features:\n- Added Windows Desktop Setup\n- Real biometric face capture',
        'html_url': 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/tag/v1.1.0',
        'published_at': '2026-11-28T12:00:00Z',
        'prerelease': false,
        'assets': [
          {
            'name': 'Dawami_Setup_v1.1.0.exe',
            'browser_download_url': 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/download/v1.1.0/Dawami_Setup_v1.1.0.exe',
            'size': 14800000,
          },
          {
            'name': 'Dawami_v1.1.0_Windows_Portable.zip',
            'browser_download_url': 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/download/v1.1.0/Dawami_v1.1.0_Windows_Portable.zip',
            'size': 14750000,
          }
        ],
      };

      final release = AppReleaseInfo.fromJson(json);
      expect(release.tagName, 'v1.1.0');
      expect(release.cleanVersion, '1.1.0');
      expect(release.name, 'Dawami Windows Release 1.1.0');
      expect(release.exeDownloadUrl, 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/download/v1.1.0/Dawami_Setup_v1.1.0.exe');
      expect(release.exeFileName, 'Dawami_Setup_v1.1.0.exe');
      expect(release.hasDirectExe, isTrue);
      expect(release.exeSizeFormatted, contains('ميجابايت'));
      expect(release.downloadUrl, 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/download/v1.1.0/Dawami_Setup_v1.1.0.exe');
    });

    test('Parses GitHub Release JSON with ZIP portable asset fallback', () {
      final json = {
        'tag_name': 'v1.2.0',
        'name': 'Dawami Portable 1.2.0',
        'body': 'Portable Windows build',
        'html_url': 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/tag/v1.2.0',
        'assets': [
          {
            'name': 'Dawami_Portable.zip',
            'browser_download_url': 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/download/v1.2.0/Dawami_Portable.zip',
            'size': 15000000,
          }
        ],
      };

      final release = AppReleaseInfo.fromJson(json);
      expect(release.cleanVersion, '1.2.0');
      expect(release.hasDirectExe, isTrue);
      expect(release.exeFileName, 'Dawami_Portable.zip');
      expect(release.downloadUrl, contains('Dawami_Portable.zip'));
    });

    test('Parses GitHub Release JSON without Desktop assets fallback to web release page', () {
      final json = {
        'tag_name': 'v1.0.0',
        'name': 'Initial Release',
        'body': 'First version',
        'html_url': 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/tag/v1.0.0',
        'assets': <dynamic>[],
      };

      final release = AppReleaseInfo.fromJson(json);
      expect(release.cleanVersion, '1.0.0');
      expect(release.hasDirectExe, isFalse);
      expect(release.exeDownloadUrl, isNull);
      expect(release.downloadUrl, 'https://github.com/IbrIx-ibra7im/dawami-sd/releases/tag/v1.0.0');
    });
  });
}
