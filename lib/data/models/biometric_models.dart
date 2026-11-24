// نماذج بيانات البصمة الحيوية وسجلات التحقق ومنع التلاعب

const String fingerprintNotActivatedMessage =
    'عذراً، لم يتم تفعيل البصمة لهذا الطالب، يرجى مراجعة إدارة النظام';

class StudentFingerprint {
  final int? id;
  final int studentId;
  final String universityId;
  final String fingerprintId; // معرّف البصمة في الحساس (مثال: FP-1045)
  final String templateHash; // التمثيل الآمن لقالب البصمة (هاش مشفر دون حفظ الصورة الخام)
  final int qualityScore; // جودة البصمة (0 - 100%)
  final String enrolledAt; // تاريخ ووقت تسجيل البصمة
  final String deviceModel; // طراز الجهاز المستخدم في التسجيل
  final bool isActive;

  StudentFingerprint({
    this.id,
    required this.studentId,
    required this.universityId,
    required this.fingerprintId,
    required this.templateHash,
    this.qualityScore = 90,
    required this.enrolledAt,
    required this.deviceModel,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'student_id': studentId,
      'university_id': universityId,
      'fingerprint_id': fingerprintId,
      'template_hash': templateHash,
      'quality_score': qualityScore,
      'enrolled_at': enrolledAt,
      'device_model': deviceModel,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory StudentFingerprint.fromMap(Map<dynamic, dynamic> map) {
    return StudentFingerprint(
      id: (map['id'] as num?)?.toInt(),
      studentId: (map['student_id'] as num?)?.toInt() ?? 0,
      universityId: map['university_id']?.toString() ?? '',
      fingerprintId: map['fingerprint_id']?.toString() ?? '',
      templateHash: map['template_hash']?.toString() ?? '',
      qualityScore: (map['quality_score'] as num?)?.toInt() ?? 90,
      enrolledAt: map['enrolled_at']?.toString() ?? DateTime.now().toIso8601String(),
      deviceModel: map['device_model']?.toString() ?? 'ZK-F18',
      isActive: (map['is_active'] == 1 || map['is_active'] == true),
    );
  }
}

class BiometricVerificationLog {
  final int? id;
  final String timestamp;
  final String method; // 'fingerprint_1_N', 'fingerprint_1_1', 'barcode'
  final int? studentId;
  final String? studentName;
  final String? universityId;
  final String status; // 'نجاح', 'فشل'
  final String reason; // سبب النتيجة (مثال: تم التحقق بنجاح، البصمة غير مطابقة، تكرار الحضور)
  final String deviceModel;

  BiometricVerificationLog({
    this.id,
    required this.timestamp,
    required this.method,
    this.studentId,
    this.studentName,
    this.universityId,
    required this.status,
    required this.reason,
    required this.deviceModel,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'timestamp': timestamp,
      'method': method,
      if (studentId != null) 'student_id': studentId,
      if (studentName != null) 'student_name': studentName,
      if (universityId != null) 'university_id': universityId,
      'status': status,
      'reason': reason,
      'device_model': deviceModel,
    };
  }

  factory BiometricVerificationLog.fromMap(Map<dynamic, dynamic> map) {
    return BiometricVerificationLog(
      id: (map['id'] as num?)?.toInt(),
      timestamp: map['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      method: map['method']?.toString() ?? 'fingerprint_1_N',
      studentId: (map['student_id'] as num?)?.toInt(),
      studentName: map['student_name']?.toString(),
      universityId: map['university_id']?.toString(),
      status: map['status']?.toString() ?? 'فشل',
      reason: map['reason']?.toString() ?? '',
      deviceModel: map['device_model']?.toString() ?? 'ZK-F18',
    );
  }
}
