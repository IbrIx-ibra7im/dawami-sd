class AttendanceRecord {
  final String id; // UUID
  final int studentId;
  final int sessionId;
  final String checkIn; // ISO timestamp
  final String? checkOut; // ISO timestamp
  final String method; // 'qr', 'fingerprint', 'manual'
  final String status; // 'حاضر', 'متأخر', 'غائب', 'انصراف'
  final String deviceId;
  final String createdAt;
  final String? studentName;
  final String? universityId;
  final String? lectureName;
  final String? classroomName;
  final bool isSynced;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.sessionId,
    required this.checkIn,
    this.checkOut,
    required this.method,
    required this.status,
    required this.deviceId,
    required this.createdAt,
    this.studentName,
    this.universityId,
    this.lectureName,
    this.classroomName,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'session_id': sessionId,
      'check_in': checkIn,
      'check_out': checkOut,
      'method': method,
      'status': status,
      'device_id': deviceId,
      'created_at': createdAt,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id']?.toString() ?? '',
      studentId: (map['student_id'] as num?)?.toInt() ?? 0,
      sessionId: (map['session_id'] as num?)?.toInt() ?? 1,
      checkIn: map['check_in'] as String? ?? '',
      checkOut: map['check_out'] as String?,
      method: map['method'] as String? ?? 'qr',
      status: map['status'] as String? ?? 'حاضر',
      deviceId: map['device_id'] as String? ?? 'DEV-01',
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      studentName: map['student_name'] as String?,
      universityId: map['university_id'] as String?,
      lectureName: map['lecture_name'] as String?,
      classroomName: map['classroom_name'] as String?,
      isSynced: (map['is_synced'] == 1 || map['is_synced'] == true),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceRecord && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

