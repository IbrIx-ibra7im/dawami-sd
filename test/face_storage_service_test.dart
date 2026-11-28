import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/services/face_storage_service.dart';
import 'package:my_app/data/models/face_profile.dart';
import 'package:my_app/data/models/face_verification_result.dart';
import 'package:my_app/data/models/student.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FaceStorageService - Permanent Local Image Storage & Formats', () {
    final storage = FaceStorageService.instance;

    test('saveStudentFacePermanently handles bytes and generates clean identifier paths', () async {
      final sampleBytes = List<int>.generate(128, (i) => (i * 11) % 256);
      final resultPath = await storage.saveStudentFacePermanently(
        universityId: '2024-TEST-001',
        imageBytes: sampleBytes,
      );

      expect(resultPath, isNotEmpty);
      expect(resultPath.contains('student_face_2024_TEST_001') || resultPath.startsWith('data:'), isTrue);
    });

    test('saveStudentFacePermanently throws on empty bytes', () async {
      expect(
        () async => await storage.saveStudentFacePermanently(
          universityId: 'TEST-EMPTY',
          imageBytes: [],
        ),
        throwsArgumentError,
      );
    });
  });

  group('FaceVerificationStatus & Result Model Tests', () {
    test('FaceVerificationStatus returns required Arabic messages and styles', () {
      const mismatchStatus = FaceVerificationStatus.mismatchedFeatures;
      expect(mismatchStatus.arabicTitle, 'ملامح غير متطابقة');
      expect(
        mismatchStatus.arabicMessage,
        'لم يتم التعرف على الوجه، ملامح الوجه غير متطابقة مع بيانات الطالب المسجلة.',
      );

      const livenessStatus = FaceVerificationStatus.livenessFailed;
      expect(livenessStatus.arabicTitle, 'فحص الحيوية مرفوض');
      expect(livenessStatus.arabicMessage.contains('Liveness'), isTrue);

      const successStatus = FaceVerificationStatus.recognizedSuccess;
      expect(successStatus.arabicTitle, 'طالب معتمد');
    });

    test('Student and FaceProfile model local permanent paths cleanly', () {
      final student = Student(
        universityId: '2026-ST-01',
        fullName: 'عمر خالد',
        phone: '0912345678',
        email: 'omar@example.com',
        collegeId: 1,
        departmentId: 1,
        levelId: 1,
        semesterId: 1,
        qrCode: 'QR-01',
        faceRegistered: true,
        faceImagePath: '/data/user/0/dawami/faces/student_face_2026_ST_01.jpg',
        faceImageUrl: 'https://supabase.co/storage/v1/object/public/student_faces/face_2026_ST_01.jpg',
      );

      final map = student.toMap();
      expect(map['face_image_path'], '/data/user/0/dawami/faces/student_face_2026_ST_01.jpg');
      expect(map['face_image_url'], 'https://supabase.co/storage/v1/object/public/student_faces/face_2026_ST_01.jpg');

      final profile = FaceProfile(
        id: 'FACE-2026-ST-01',
        studentId: '1',
        universityId: '2026-ST-01',
        faceEmbeddingHash: 'HASH123',
        referenceImagePath: '/data/user/0/dawami/faces/student_face_2026_ST_01.jpg',
        referenceImageUrl: 'https://supabase.co/storage/v1/object/public/student_faces/face_2026_ST_01.jpg',
        enrolledAt: '2026-01-01',
      );

      final pMap = profile.toMap();
      expect(pMap['reference_image_path'], '/data/user/0/dawami/faces/student_face_2026_ST_01.jpg');
      expect(pMap['reference_image_url'], 'https://supabase.co/storage/v1/object/public/student_faces/face_2026_ST_01.jpg');
    });
  });
}
