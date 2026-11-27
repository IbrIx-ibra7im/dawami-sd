import 'dart:convert';

/// نموذج بيانات بصمة وملف الوجه الحيوي للطالب
class FaceProfile {
  final String id;
  final String studentId;
  final String universityId;
  final List<double> embedding; // البصمة الرقمية المتجهة للوجه (128-dimensional embedding vector)
  final String faceEmbeddingHash; // تجزئة أمان فريدة للبصمة
  final String? referencePhotoUrl; // صورة مرجعية لوجه الطالب
  final int qualityScore; // نسبة جودة ووضوح الوجه (0 - 100)
  final bool livenessVerified; // هل تم اجتياز فحص الحيوية
  final double livenessScore; // درجة الحيوية المقاسة (0.0 - 1.0)
  final int sampleCount; // عدد العينات المأخوذة للوجه (مثال: 3 زوايا)
  final String enrolledAt;
  final bool isActive;

  const FaceProfile({
    required this.id,
    required this.studentId,
    required this.universityId,
    this.embedding = const [],
    required this.faceEmbeddingHash,
    this.referencePhotoUrl,
    this.qualityScore = 95,
    this.livenessVerified = true,
    this.livenessScore = 0.98,
    this.sampleCount = 3,
    required this.enrolledAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'university_id': universityId,
      'embedding': jsonEncode(embedding),
      'face_embedding_hash': faceEmbeddingHash,
      'reference_photo_url': referencePhotoUrl,
      'quality_score': qualityScore,
      'liveness_verified': livenessVerified ? 1 : 0,
      'liveness_score': livenessScore,
      'sample_count': sampleCount,
      'enrolled_at': enrolledAt,
      'is_active': isActive ? 1 : 0,
    };
  }

  Map<String, dynamic> toDawamiRecord() {
    return {
      'record_type': 'face_profile',
      'record_key': universityId,
      'student_number': universityId,
      'full_name': 'بصمة وجه $universityId',
      'barcode_id': faceEmbeddingHash,
      'status': isActive ? 'نشط' : 'معطل',
      'sync_status': 'مزامنة',
      'data': toMap(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory FaceProfile.fromMap(Map<dynamic, dynamic> map) {
    List<double> parsedEmbedding = [];
    final rawEmbedding = map['embedding'];
    if (rawEmbedding is List) {
      parsedEmbedding = rawEmbedding.map((e) => (e as num).toDouble()).toList();
    } else if (rawEmbedding is String && rawEmbedding.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawEmbedding) as List<dynamic>;
        parsedEmbedding = decoded.map((e) => (e as num).toDouble()).toList();
      } catch (_) {}
    }

    return FaceProfile(
      id: map['id']?.toString() ?? '',
      studentId: map['student_id']?.toString() ?? '',
      universityId: map['university_id']?.toString() ?? '',
      embedding: parsedEmbedding,
      faceEmbeddingHash: map['face_embedding_hash']?.toString() ?? '',
      referencePhotoUrl: map['reference_photo_url']?.toString(),
      qualityScore: (map['quality_score'] as num?)?.toInt() ?? 95,
      livenessVerified: (map['liveness_verified'] == 1 || map['liveness_verified'] == true),
      livenessScore: (map['liveness_score'] as num?)?.toDouble() ?? 0.98,
      sampleCount: (map['sample_count'] as num?)?.toInt() ?? 3,
      enrolledAt: map['enrolled_at']?.toString() ?? DateTime.now().toIso8601String(),
      isActive: (map['is_active'] == 1 || map['is_active'] == true),
    );
  }

  FaceProfile copyWith({
    String? id,
    String? studentId,
    String? universityId,
    List<double>? embedding,
    String? faceEmbeddingHash,
    String? referencePhotoUrl,
    int? qualityScore,
    bool? livenessVerified,
    double? livenessScore,
    int? sampleCount,
    String? enrolledAt,
    bool? isActive,
  }) {
    return FaceProfile(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      universityId: universityId ?? this.universityId,
      embedding: embedding ?? this.embedding,
      faceEmbeddingHash: faceEmbeddingHash ?? this.faceEmbeddingHash,
      referencePhotoUrl: referencePhotoUrl ?? this.referencePhotoUrl,
      qualityScore: qualityScore ?? this.qualityScore,
      livenessVerified: livenessVerified ?? this.livenessVerified,
      livenessScore: livenessScore ?? this.livenessScore,
      sampleCount: sampleCount ?? this.sampleCount,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
