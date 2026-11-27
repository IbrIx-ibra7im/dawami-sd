class AttendanceRecord {
  final String id; // UUID
  final int studentId;
  final int sessionId;
  final String checkIn; // ISO timestamp
  final String? checkOut; // ISO timestamp
  final String method; // 'fingerprint', 'face', 'mobile', 'barcode_qr', 'qr', 'manual'
  final String status; // 'حاضر', 'متأخر', 'غائب', 'منصرف', 'تم الانصراف'
  final String deviceId;
  final String? deviceName;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final int durationMinutes;
  final int delayMinutes;
  final String? notes;
  final String createdAt;
  final String? studentName;
  final String? universityId;
  final String? lectureName;
  final String? classroomName;
  final bool isSynced;

  // اختصارات وتوافق مع متطلبات نظام الحضور
  String get studentNumber => universityId ?? '';
  String get attendanceDate => checkIn.length >= 10 ? checkIn.substring(0, 10) : '';
  String get attendanceTime => checkIn.length >= 16 ? checkIn.substring(11, 16) : '';
  String get checkOutTime => (checkOut != null && checkOut!.length >= 16) ? checkOut!.substring(11, 16) : '';
  int get lectureId => sessionId;
  String get syncStatus => isSynced ? 'مزامنة' : 'غير مزامنة';

  bool get hasDeparted => checkOut != null && checkOut!.isNotEmpty;

  String get durationFormatted {
    if (durationMinutes <= 0) {
      if (checkOut != null && checkIn.isNotEmpty) {
        try {
          final inTime = DateTime.parse(checkIn);
          final outTime = DateTime.parse(checkOut!);
          final diff = outTime.difference(inTime).inMinutes;
          if (diff > 0) {
            final hours = diff ~/ 60;
            final mins = diff % 60;
            return hours > 0 ? '$hours س و $mins د' : '$mins دقيقة';
          }
        } catch (_) {}
      }
      return 'قيد التواجد';
    }
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    return hours > 0 ? '$hours س و $mins د' : '$mins دقيقة';
  }

  String get delayFormatted {
    if (delayMinutes <= 0) return 'في الموعد';
    final hours = delayMinutes ~/ 60;
    final mins = delayMinutes % 60;
    return hours > 0 ? 'تأخير $hours س و $mins د' : 'تأخير $mins دقيقة';
  }

  String get methodDisplayName {
    switch (method.toLowerCase()) {
      case 'fingerprint':
        return 'بصمة الإصبع';
      case 'face':
        return 'التعرف على الوجه';
      case 'mobile':
        return 'تطبيق الهاتف (GPS)';
      case 'barcode_qr':
      case 'qr':
        return 'الباركود وQR';
      case 'manual':
      default:
        return 'تسجيل إداري';
    }
  }

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.sessionId,
    required this.checkIn,
    this.checkOut,
    required this.method,
    required this.status,
    required this.deviceId,
    this.deviceName,
    this.locationName,
    this.latitude,
    this.longitude,
    this.durationMinutes = 0,
    this.delayMinutes = 0,
    this.notes,
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
      'student_number': universityId ?? '',
      'university_id': universityId ?? '',
      'student_name': studentName ?? '',
      'session_id': sessionId,
      'lecture_id': sessionId,
      'check_in': checkIn,
      'check_out': checkOut,
      'attendance_date': attendanceDate,
      'attendance_time': attendanceTime,
      'method': method,
      'status': status,
      'device_id': deviceId,
      'device_name': deviceName,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'duration_minutes': durationMinutes,
      'delay_minutes': delayMinutes,
      'notes': notes,
      'created_at': createdAt,
      'is_synced': isSynced ? 1 : 0,
      'sync_status': isSynced ? 'مزامنة' : 'غير مزامنة',
      if (lectureName != null) 'lecture_name': lectureName,
      if (classroomName != null) 'classroom_name': classroomName,
    };
  }

  /// Map مطابقة لجدول dawami_records الموحد في Supabase
  Map<String, dynamic> toDawamiRecord() {
    return {
      'record_type': 'attendance',
      'record_key': id,
      'student_number': studentNumber,
      'full_name': studentName ?? '',
      'barcode_id': studentNumber,
      'record_date': attendanceDate,
      'record_time': attendanceTime,
      'method': method,
      'status': status,
      'sync_status': 'مزامنة',
      'data': toMap(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory AttendanceRecord.fromDawamiRecord(Map<dynamic, dynamic> record) {
    final data = record['data'] is Map ? Map<String, dynamic>.from(record['data'] as Map) : <String, dynamic>{};
    data['id'] = record['record_key'] ?? record['id']?.toString() ?? data['id'];
    data['student_number'] = record['student_number'] ?? data['student_number'];
    data['university_id'] = record['student_number'] ?? data['university_id'] ?? data['student_number'];
    data['student_name'] = record['full_name'] ?? data['student_name'];
    data['attendance_date'] = record['record_date']?.toString() ?? data['attendance_date'];
    data['attendance_time'] = record['record_time']?.toString() ?? data['attendance_time'];
    data['method'] = record['method'] ?? data['method'];
    data['status'] = record['status'] ?? data['status'];
    data['sync_status'] = record['sync_status'] ?? 'مزامنة';
    data['is_synced'] = 1;
    return AttendanceRecord.fromMap(data);
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id']?.toString() ?? '',
      studentId: (map['student_id'] as num?)?.toInt() ?? 0,
      sessionId: (map['session_id'] as num?)?.toInt() ?? (map['lecture_id'] as num?)?.toInt() ?? 1,
      checkIn: map['check_in'] as String? ?? '',
      checkOut: map['check_out'] as String?,
      method: map['method'] as String? ?? 'qr',
      status: map['status'] as String? ?? 'حاضر',
      deviceId: map['device_id'] as String? ?? 'DEV-01',
      deviceName: map['device_name'] as String?,
      locationName: map['location_name'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 0,
      delayMinutes: (map['delay_minutes'] as num?)?.toInt() ?? 0,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      studentName: map['student_name'] as String? ?? map['full_name'] as String?,
      universityId: map['university_id'] as String? ?? map['student_number'] as String?,
      lectureName: map['lecture_name'] as String?,
      classroomName: map['classroom_name'] as String?,
      isSynced: (map['is_synced'] == 1 || map['is_synced'] == true || map['sync_status'] == 'مزامنة' || map['sync_status'] == 'synced'),
    );
  }

  AttendanceRecord copyWith({
    String? id,
    int? studentId,
    int? sessionId,
    String? checkIn,
    String? checkOut,
    String? method,
    String? status,
    String? deviceId,
    String? deviceName,
    String? locationName,
    double? latitude,
    double? longitude,
    int? durationMinutes,
    int? delayMinutes,
    String? notes,
    String? createdAt,
    String? studentName,
    String? universityId,
    String? lectureName,
    String? classroomName,
    bool? isSynced,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      sessionId: sessionId ?? this.sessionId,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      method: method ?? this.method,
      status: status ?? this.status,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      delayMinutes: delayMinutes ?? this.delayMinutes,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      studentName: studentName ?? this.studentName,
      universityId: universityId ?? this.universityId,
      lectureName: lectureName ?? this.lectureName,
      classroomName: classroomName ?? this.classroomName,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceRecord && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
