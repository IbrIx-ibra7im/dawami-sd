import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/services/attendance_service.dart';
import 'package:my_app/core/services/face_recognition_service.dart';
import 'package:my_app/data/models/face_profile.dart';
import 'package:my_app/data/models/face_recognition_log.dart';

void main() {
  group('FaceRecognitionService - 128-D Embeddings & Mathematical Similarity', () {
    final service = FaceRecognitionService.instance;

    test('extractEmbeddingFromImageBytes outputs a 128-dimensional unit vector', () {
      final sampleBytes = List<int>.generate(256, (i) => (i * 31 + 7) % 256);
      final embedding = service.extractEmbeddingFromImageBytes('2024-TEST-001', sampleBytes);

      expect(embedding.length, 128);

      // Verify L2 norm equals 1.0 (Unit Vector)
      double sumSquares = 0.0;
      for (final val in embedding) {
        sumSquares += val * val;
      }
      final norm = math.sqrt(sumSquares);
      expect(norm, closeTo(1.0, 0.001));
    });

    test('calculateCosineSimilarity returns 1.0 for identical vectors', () {
      final sampleBytes = List<int>.generate(256, (i) => (i * 13 + 5) % 256);
      final vecA = service.extractEmbeddingFromImageBytes('STUDENT-001', sampleBytes);
      final vecB = List<double>.from(vecA);

      final similarity = service.calculateCosineSimilarity(vecA, vecB);
      expect(similarity, closeTo(1.0, 0.0001));
    });

    test('calculateCosineSimilarity distinguishes different student faces', () {
      final bytesA = List<int>.generate(256, (i) => (i * 7 + 1) % 256);
      final bytesB = List<int>.generate(256, (i) => (i * 97 + 53) % 256);

      final vecA = service.extractEmbeddingFromImageBytes('STUDENT-A', bytesA);
      final vecB = service.extractEmbeddingFromImageBytes('STUDENT-B', bytesB);

      final similarity = service.calculateCosineSimilarity(vecA, vecB);
      // Different random faces should have low cross-correlation (below the 0.80 threshold)
      expect(similarity, lessThan(0.80));
    });

    test('computeCompositeEmbedding averages multiple angles into a canonical normalized vector', () {
      final bytes1 = List<int>.generate(256, (i) => (i * 11) % 256);
      final bytes2 = List<int>.generate(256, (i) => (i * 13) % 256);
      final bytes3 = List<int>.generate(256, (i) => (i * 17) % 256);

      final emb1 = service.extractEmbeddingFromImageBytes('MULTI-01', bytes1, angleOffset: 0.0);
      final emb2 = service.extractEmbeddingFromImageBytes('MULTI-01', bytes2, angleOffset: 0.25);
      final emb3 = service.extractEmbeddingFromImageBytes('MULTI-01', bytes3, angleOffset: -0.25);

      final composite = service.computeCompositeEmbedding([emb1, emb2, emb3]);
      expect(composite.length, 128);

      double sumSq = 0.0;
      for (final v in composite) {
        sumSq += v * v;
      }
      expect(math.sqrt(sumSq), closeTo(1.0, 0.001));
    });
  });

  group('FaceRecognitionService - Liveness Detection & Anti-Spoofing', () {
    final service = FaceRecognitionService.instance;

    test('evaluateLiveness rejects flat static printed photo (Zero motion variance)', () {
      final frame1 = List<int>.generate(256, (i) => 120);
      final frame2 = List<int>.generate(256, (i) => 120); // identical frame, no motion at all

      final result = service.evaluateLiveness(
        currentFrameBytes: frame1,
        previousFrameBytes: frame2,
        forcePass: false,
      );

      expect(result['passed'], isFalse);
      expect(result['score'], lessThan(0.50));
      expect(result['reason'].toString().contains('صورة ثابتة'), isTrue);
    });

    test('evaluateLiveness accepts natural biological micro-motion', () {
      final frame1 = List<int>.generate(256, (i) => (i * 7) % 256);
      // slight biological micro-variation
      final frame2 = List<int>.generate(256, (i) => ((i * 7) + (i % 5 == 0 ? 12 : 2)) % 256);

      final result = service.evaluateLiveness(
        currentFrameBytes: frame1,
        previousFrameBytes: frame2,
        forcePass: false,
      );

      expect(result['passed'], isTrue);
      expect((result['score'] as num).toDouble(), greaterThanOrEqualTo(0.70));
    });
  });

  group('FaceRecognitionService - Models & Settings Serialization', () {
    test('FaceProfile serializes and deserializes embedding vector accurately', () {
      final embedding = [0.123, -0.456, 0.789, 0.0];
      final profile = FaceProfile(
        id: 'FACE-2024-001',
        studentId: '1',
        universityId: '2024-001',
        embedding: embedding,
        faceEmbeddingHash: 'hash-abc',
        qualityScore: 98,
        livenessVerified: true,
        livenessScore: 0.99,
        sampleCount: 3,
        enrolledAt: '2026-01-01T10:00:00Z',
      );

      final map = profile.toMap();
      final reconstructed = FaceProfile.fromMap(map);

      expect(reconstructed.id, 'FACE-2024-001');
      expect(reconstructed.universityId, '2024-001');
      expect(reconstructed.embedding.length, 4);
      expect(reconstructed.embedding[0], closeTo(0.123, 0.0001));
      expect(reconstructed.embedding[1], closeTo(-0.456, 0.0001));
      expect(reconstructed.qualityScore, 98);
      expect(reconstructed.sampleCount, 3);
    });

    test('FaceRecognitionLog models all required auditing fields', () {
      final log = FaceRecognitionLog(
        id: 'LOG-001',
        studentId: '1',
        universityId: '2024-001',
        studentName: 'أحمد محمود',
        timestamp: '2026-01-01T08:30:00Z',
        actionType: 'حضور',
        confidence: 0.945,
        livenessScore: 0.982,
        cameraDeviceId: 'FACE-CAM-LIVE',
        isMultiFace: true,
        status: 'success',
      );

      final map = log.toMap();
      expect(map['action_type'], 'حضور');
      expect(map['confidence'], 0.945);
      expect(map['is_multi_face'], 1);

      final reconstructed = FaceRecognitionLog.fromMap(map);
      expect(reconstructed.studentName, 'أحمد محمود');
      expect(reconstructed.isMultiFace, isTrue);
    });

    test('FaceRecognitionSettings respects configurable thresholds', () {
      const settings = FaceRecognitionSettings(
        matchThreshold: 0.85,
        cooldownMinutes: 30,
        multiFaceEnabled: true,
        livenessEnabled: true,
        attendanceMode: AttendanceActionType.checkIn,
      );

      final map = settings.toMap();
      expect(map['match_threshold'], 0.85);
      expect(map['cooldown_minutes'], 30);
      expect(map['attendance_mode'], 'checkIn');

      final parsed = FaceRecognitionSettings.fromMap(map);
      expect(parsed.matchThreshold, 0.85);
      expect(parsed.cooldownMinutes, 30);
      expect(parsed.attendanceMode, AttendanceActionType.checkIn);
    });
  });
}
