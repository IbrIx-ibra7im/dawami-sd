import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/data/models/biometric_models.dart';
import 'package:my_app/data/models/student.dart';
import 'package:my_app/features/fingerprint/fingerprint_provider.dart';

Student _student({
  String fingerprintStatus = 'مسجلة',
  String fingerprintId = 'FP-001',
  String universityId = '2024-001',
}) {
  return Student(
    id: 1,
    universityId: universityId,
    fullName: 'طالب تجريبي',
    phone: '0912345678',
    email: '',
    collegeId: 1,
    departmentId: 1,
    levelId: 1,
    semesterId: 1,
    qrCode: 'DAWAMI:STUDENT:$universityId',
    fingerprintId: fingerprintId,
    fingerprintStatus: fingerprintStatus,
  );
}

StudentFingerprint _fingerprint({
  int studentId = 1,
  String universityId = '2024-001',
  String fingerprintId = 'FP-001',
  bool isActive = true,
}) {
  return StudentFingerprint(
    studentId: studentId,
    universityId: universityId,
    fingerprintId: fingerprintId,
    templateHash: 'stored-template-hash',
    enrolledAt: '2026-01-01T00:00:00.000',
    deviceModel: 'test-reader',
    isActive: isActive,
  );
}

void main() {
  group('Fingerprint verification', () {
    test('accepts a match only when the active record matches student identity', () {
      final student = _student();

      final matched = FingerprintProvider.validateFingerprintMatch(
        candidate: student,
        students: [student],
        fingerprints: [_fingerprint()],
      );

      expect(matched, same(student));
    });

    test('rejects inactive, mismatched, or not-activated fingerprint records', () {
      final student = _student();

      expect(
        FingerprintProvider.validateFingerprintMatch(
          candidate: student,
          students: [student],
          fingerprints: [_fingerprint(isActive: false)],
        ),
        isNull,
      );
      expect(
        FingerprintProvider.validateFingerprintMatch(
          candidate: student,
          students: [student],
          fingerprints: [_fingerprint(universityId: '2024-999')],
        ),
        isNull,
      );
      expect(
        FingerprintProvider.validateFingerprintMatch(
          candidate: _student(fingerprintStatus: 'تحتاج إعادة تسجيل'),
          students: [student],
          fingerprints: [_fingerprint()],
        ),
        isNull,
      );
    });

    test('clearing a fingerprint removes every activation field', () {
      final cleared = _student().copyWith(clearFingerprint: true);

      expect(cleared.fingerprintId, isNull);
      expect(cleared.fingerprintStatus, 'غير مسجلة');
      expect(cleared.hasFingerprint, isFalse);
    });

    test('simulated reader never enrolls or identifies a student', () async {
      final reader = SimulatedFingerprintAdapter(
        deviceName: 'test simulator',
        deviceModel: 'test',
      );

      expect(reader.isHardwareBacked, isFalse);
      expect(await reader.scanAndIdentify([_student()]), isNull);
      expect(await reader.captureFingerprint(_student()), isNull);
    });
  });
}
