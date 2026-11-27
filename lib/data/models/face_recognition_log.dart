/// نموذج سجل عمليات التعرف على الوجه وفحص الحيوية
class FaceRecognitionLog {
  final String id;
  final String? studentId;
  final String universityId;
  final String studentName;
  final String timestamp;
  final String actionType; // 'حضور', 'انصراف'
  final double confidence; // نسبة التطابق (0.00 - 1.00)
  final double livenessScore; // درجة التحقق من الحيوية (0.00 - 1.00)
  final String cameraDeviceId; // معرف الكاميرا أو المحطة
  final bool isMultiFace; // هل تم التعرف ضمن مجموعة وجوه في نفس الإطار
  final String status; // 'success', 'spoof_rejected', 'low_confidence', 'cooldown_skipped'

  const FaceRecognitionLog({
    required this.id,
    this.studentId,
    required this.universityId,
    required this.studentName,
    required this.timestamp,
    required this.actionType,
    required this.confidence,
    required this.livenessScore,
    this.cameraDeviceId = 'FACE-CAM-01',
    this.isMultiFace = false,
    this.status = 'success',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'university_id': universityId,
      'student_name': studentName,
      'timestamp': timestamp,
      'action_type': actionType,
      'confidence': confidence,
      'liveness_score': livenessScore,
      'camera_device_id': cameraDeviceId,
      'is_multi_face': isMultiFace ? 1 : 0,
      'status': status,
    };
  }

  factory FaceRecognitionLog.fromMap(Map<dynamic, dynamic> map) {
    return FaceRecognitionLog(
      id: map['id']?.toString() ?? '',
      studentId: map['student_id']?.toString(),
      universityId: map['university_id']?.toString() ?? '',
      studentName: map['student_name']?.toString() ?? 'طالب',
      timestamp: map['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      actionType: map['action_type']?.toString() ?? 'حضور',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      livenessScore: (map['liveness_score'] as num?)?.toDouble() ?? 0.0,
      cameraDeviceId: map['camera_device_id']?.toString() ?? 'FACE-CAM-01',
      isMultiFace: (map['is_multi_face'] == 1 || map['is_multi_face'] == true),
      status: map['status']?.toString() ?? 'success',
    );
  }
}
