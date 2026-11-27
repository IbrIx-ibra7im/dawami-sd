class Student {
  final int? id;
  final String? uuid; // المعرف الفريد في Supabase UUID
  final String universityId; // Unique university ID (e.g. 2022-1045)
  final String fullName;
  final String phone;
  final String email;
  final int collegeId;
  final int departmentId;
  final int levelId;
  final int semesterId;
  final String status; // 'نشط', 'متوقف', 'متخرج'
  final String qrCode; // unique QR code string / barcode
  final String? fingerprintId; // ID linked to biometric sensor
  final String fingerprintStatus; // 'مسجلة', 'غير مسجلة', 'تحتاج إعادة تسجيل'
  final int? fingerprintQuality; // 0 - 100%
  final String? fingerprintEnrolledAt;
  final String? photoUrl;
  final bool faceRegistered;
  final String? faceEnrolledAt;
  final String? faceEmbedding;
  final String attendanceMethod; // 'all', 'fingerprint', 'barcode', 'face'
  final String? collegeName;
  final String? departmentName;
  final String? levelName;

  // Aliases for user prompt requirements
  String get studentNumber => universityId;
  String get barcodeId => qrCode;
  bool get fingerprintRegistered => hasFingerprint;
  String get college => collegeName ?? 'كلية علوم الحاسوب والتنمية البشرية';
  String get department => departmentName ?? 'علوم الحاسوب';
  String get academicLevel => levelName ?? 'المستوى الأول';

  String get attendanceMethodDisplay {
    switch (attendanceMethod) {
      case 'fingerprint':
        return 'بصمة إصبع';
      case 'barcode':
        return 'باركود / QR';
      case 'face':
        return 'بصمة وجه';
      case 'all':
      default:
        return 'كافة الوسائل';
    }
  }

  bool allowsAttendanceMethod(String method) {
    if (attendanceMethod == 'all' || attendanceMethod.isEmpty) return true;
    final clean = method.trim().toLowerCase();
    if (attendanceMethod == 'fingerprint') {
      return clean.contains('fingerprint') || clean == 'manual';
    }
    if (attendanceMethod == 'barcode') {
      return clean.contains('barcode') || clean.contains('qr') || clean == 'manual';
    }
    if (attendanceMethod == 'face') {
      return clean.contains('face') || clean == 'manual';
    }
    return true;
  }

  bool get hasFingerprint =>
      fingerprintId != null &&
      fingerprintId!.isNotEmpty &&
      fingerprintStatus == 'مسجلة';

  Student({
    this.id,
    this.uuid,
    required this.universityId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.collegeId,
    required this.departmentId,
    required this.levelId,
    required this.semesterId,
    this.status = 'نشط',
    required this.qrCode,
    this.fingerprintId,
    String? fingerprintStatus,
    this.fingerprintQuality,
    this.fingerprintEnrolledAt,
    this.photoUrl,
    this.faceRegistered = false,
    this.faceEnrolledAt,
    this.faceEmbedding,
    this.attendanceMethod = 'all',
    this.collegeName,
    this.departmentName,
    this.levelName,
  }) : fingerprintStatus = fingerprintStatus ??
            (fingerprintId != null && fingerprintId.isNotEmpty ? 'مسجلة' : 'غير مسجلة');

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      'university_id': universityId,
      'student_number': universityId, // Alias for Supabase column requirement
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'college_id': collegeId,
      'department_id': departmentId,
      'level_id': levelId,
      'semester_id': semesterId,
      'status': status,
      'qr_code': qrCode,
      'barcode_id': qrCode, // Alias for Supabase column requirement
      'fingerprint_id': fingerprintId,
      'fingerprint_status': fingerprintStatus,
      'fingerprint_registered': hasFingerprint, // Alias for Supabase column requirement
      if (fingerprintQuality != null) 'fingerprint_quality': fingerprintQuality,
      if (fingerprintEnrolledAt != null) 'fingerprint_enrolled_at': fingerprintEnrolledAt,
      'photo_url': photoUrl,
      'face_registered': faceRegistered ? 1 : 0,
      if (faceEnrolledAt != null) 'face_enrolled_at': faceEnrolledAt,
      if (faceEmbedding != null) 'face_embedding': faceEmbedding,
      'attendance_method': attendanceMethod,
      'college': collegeName ?? 'كلية علوم الحاسوب والتنمية البشرية',
      'department': departmentName ?? 'علوم الحاسوب',
      'academic_level': levelName ?? 'المستوى الأول',
      if (collegeName != null) 'college_name': collegeName,
      if (departmentName != null) 'department_name': departmentName,
      if (levelName != null) 'level_name': levelName,
    };
  }

  /// Map suitable strictly for SQLite relational table (without joined text columns)
  Map<String, dynamic> toDbMap() {
    return {
      if (id != null) 'id': id,
      'university_id': universityId,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'college_id': collegeId,
      'department_id': departmentId,
      'level_id': levelId,
      'semester_id': semesterId,
      'status': status,
      'qr_code': qrCode,
      'fingerprint_id': fingerprintId,
      'photo_url': photoUrl,
    };
  }

  /// Map مطابقة لجدول dawami_records الموحد في Supabase
  Map<String, dynamic> toDawamiRecord() {
    final sNum = studentNumber.isNotEmpty ? studentNumber : universityId;
    return {
      'record_type': 'student',
      'record_key': sNum,
      'student_number': sNum,
      'full_name': fullName,
      'barcode_id': barcodeId,
      'status': status,
      'sync_status': 'مزامنة',
      'data': {
        'id': id,
        'uuid': uuid,
        'student_number': sNum,
        'university_id': universityId,
        'full_name': fullName,
        'college': college,
        'department': department,
        'academic_level': academicLevel,
        'college_name': collegeName,
        'department_name': departmentName,
        'level_name': levelName,
        'college_id': collegeId,
        'department_id': departmentId,
        'level_id': levelId,
        'semester_id': semesterId,
        'phone': phone,
        'email': email,
        'barcode_id': barcodeId,
        'qr_code': qrCode,
        'fingerprint_id': fingerprintId,
        'fingerprint_registered': hasFingerprint,
        'fingerprint_status': fingerprintStatus,
        'fingerprint_quality': fingerprintQuality,
        'fingerprint_enrolled_at': fingerprintEnrolledAt,
        'photo_url': photoUrl,
        'face_registered': faceRegistered,
        'face_enrolled_at': faceEnrolledAt,
        'face_embedding': faceEmbedding,
        'attendance_method': attendanceMethod,
        'status': status,
      },
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Alias for backward compatibility
  Map<String, dynamic> toSupabaseMap() => toDawamiRecord();

  factory Student.fromDawamiRecord(Map<dynamic, dynamic> record) {
    final data = record['data'] is Map ? Map<String, dynamic>.from(record['data'] as Map) : <String, dynamic>{};
    data['student_number'] = record['student_number'] ?? data['student_number'];
    data['university_id'] = record['student_number'] ?? data['university_id'] ?? record['record_key'];
    data['full_name'] = record['full_name'] ?? data['full_name'];
    data['barcode_id'] = record['barcode_id'] ?? data['barcode_id'];
    data['status'] = record['status'] ?? data['status'];
    if (record['id'] != null) {
      data['uuid'] = record['id'].toString();
    }
    return Student.fromMap(data);
  }

  factory Student.fromMap(Map<dynamic, dynamic> map) {
    final fpId = map['fingerprint_id']?.toString();
    final explicitFpStatus = map['fingerprint_status']?.toString();
    final fpRegistered = map['fingerprint_registered'] == true ||
        map['fingerprint_registered'] == 1 ||
        map['fingerprint_registered'] == 'true';

    final effectiveStatus = explicitFpStatus ??
        (fpRegistered || (fpId != null && fpId.isNotEmpty) ? 'مسجلة' : 'غير مسجلة');

    final uniId = (map['student_number'] ?? map['university_id'])?.toString() ?? '';
    final code = (map['barcode_id'] ?? map['qr_code'])?.toString() ?? '';
    final cName = (map['college'] ?? map['college_name'])?.toString();
    final dName = (map['department'] ?? map['department_name'])?.toString();
    final lName = (map['academic_level'] ?? map['level_name'])?.toString();

    final isFace = map['face_registered'] == true ||
        map['face_registered'] == 1 ||
        map['face_registered'] == '1' ||
        map['face_registered'] == 'true';

    final rawId = map['id'];
    int? parsedId;
    String? parsedUuid;
    if (rawId is num) {
      parsedId = rawId.toInt();
    } else if (rawId is String) {
      parsedId = int.tryParse(rawId);
      if (parsedId == null) {
        parsedUuid = rawId;
      }
    }

    return Student(
      id: parsedId,
      uuid: parsedUuid ?? map['uuid']?.toString(),
      universityId: uniId,
      fullName: map['full_name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      collegeId: (map['college_id'] as num?)?.toInt() ?? 1,
      departmentId: (map['department_id'] as num?)?.toInt() ?? 1,
      levelId: (map['level_id'] as num?)?.toInt() ?? 1,
      semesterId: (map['semester_id'] as num?)?.toInt() ?? 1,
      status: map['status']?.toString() ?? 'نشط',
      qrCode: code,
      fingerprintId: fpId,
      fingerprintStatus: effectiveStatus,
      fingerprintQuality: (map['fingerprint_quality'] as num?)?.toInt(),
      fingerprintEnrolledAt: map['fingerprint_enrolled_at']?.toString(),
      photoUrl: map['photo_url']?.toString(),
      faceRegistered: isFace,
      faceEnrolledAt: map['face_enrolled_at']?.toString(),
      faceEmbedding: map['face_embedding']?.toString(),
      attendanceMethod: map['attendance_method']?.toString() ?? 'all',
      collegeName: cName,
      departmentName: dName,
      levelName: lName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Student &&
          runtimeType == other.runtimeType &&
          ((id != null && id == other.id) ||
              (universityId.isNotEmpty && universityId == other.universityId));

  @override
  int get hashCode => id?.hashCode ?? universityId.hashCode;

  Student copyWith({
    int? id,
    String? uuid,
    String? universityId,
    String? fullName,
    String? phone,
    String? email,
    int? collegeId,
    int? departmentId,
    int? levelId,
    int? semesterId,
    String? status,
    String? qrCode,
    String? fingerprintId,
    String? fingerprintStatus,
    int? fingerprintQuality,
    String? fingerprintEnrolledAt,
    String? photoUrl,
    bool? faceRegistered,
    String? faceEnrolledAt,
    String? faceEmbedding,
    String? attendanceMethod,
    String? collegeName,
    String? departmentName,
    String? levelName,
    bool clearFingerprint = false,
  }) {
    return Student(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      universityId: universityId ?? this.universityId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      collegeId: collegeId ?? this.collegeId,
      departmentId: departmentId ?? this.departmentId,
      levelId: levelId ?? this.levelId,
      semesterId: semesterId ?? this.semesterId,
      status: status ?? this.status,
      qrCode: qrCode ?? this.qrCode,
      fingerprintId:
          clearFingerprint ? null : fingerprintId ?? this.fingerprintId,
      fingerprintStatus: fingerprintStatus ??
          (clearFingerprint ? 'غير مسجلة' : this.fingerprintStatus),
      fingerprintQuality: clearFingerprint
          ? null
          : fingerprintQuality ?? this.fingerprintQuality,
      fingerprintEnrolledAt: clearFingerprint
          ? null
          : fingerprintEnrolledAt ?? this.fingerprintEnrolledAt,
      photoUrl: photoUrl ?? this.photoUrl,
      faceRegistered: faceRegistered ?? this.faceRegistered,
      faceEnrolledAt: faceEnrolledAt ?? this.faceEnrolledAt,
      faceEmbedding: faceEmbedding ?? this.faceEmbedding,
      attendanceMethod: attendanceMethod ?? this.attendanceMethod,
      collegeName: collegeName ?? this.collegeName,
      departmentName: departmentName ?? this.departmentName,
      levelName: levelName ?? this.levelName,
    );
  }
}
