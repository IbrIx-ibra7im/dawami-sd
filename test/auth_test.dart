import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:my_app/data/repositories/app_repository.dart';
import 'package:my_app/core/permissions/role_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Authentication & Administration Password 00000 Tests', () {
    late AppRepository repo;

    setUp(() {
      repo = AppRepository();
    });

    test('Admin login succeeds with password 00000', () async {
      final success = await repo.login('admin@dawami.edu', '00000');
      expect(success, isTrue);
      expect(repo.isLoggedIn, isTrue);
      expect(repo.currentRole, equals(UserRole.superAdmin));
    });

    test('Admin login fails with any password other than 00000', () async {
      expect(
        () async => await repo.login('admin@dawami.edu', '123456'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('00000'),
        )),
      );

      expect(
        () async => await repo.login('admin@dawami.edu', 'wrong_password'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('00000'),
        )),
      );
    });

    test('Login fails when password or email is empty', () async {
      expect(
        () async => await repo.login('', '00000'),
        throwsA(isA<Exception>()),
      );

      expect(
        () async => await repo.login('admin@dawami.edu', ''),
        throwsA(isA<Exception>()),
      );
    });

    test('Logout clears session and resets to kiosk mode (attendance officer)', () {
      repo.logout();
      expect(repo.isLoggedIn, isFalse);
      expect(repo.currentRole, equals(UserRole.attendanceOfficer));
      expect(repo.currentUser.email, equals('attendance@dawami.edu'));
    });
  });
}
