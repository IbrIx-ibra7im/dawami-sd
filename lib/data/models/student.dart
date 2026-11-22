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

  bool get hasFingerprint =>
      fingerprintId != null &&
      fingerprintId!.isNotEmpty &&
      fingerprintStatus != 'غير مسجلة';

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
    this.collegeName,
    this.departmentName,
    this.levelName,
  }) : fingerprintStatus = fingerprintStatus ??
            (fingerprintId != null && fingerprintId.isNotEmpty ? 'مسجلة' : 'غير مسجلة');

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
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
      'fingerprint_status': fingerprintStatus,
      'fingerprint_quality': fingerprintQuality,
      'fingerprint_enrolled_at': fingerprintEnrolledAt,
      'photo_url': photoUrl,
    };
  }

  /// Map مطابقة حصرياً لأعمدة جدول Supabase المعتمد: public.students فقط
  Map<String, dynamic> toSupabaseMap() {
    return {
      'student_number': universityId,
      'full_name': fullName,
      'college': collegeName ?? 'كلية علوم الحاسوب والتنمية البشرية',
      'department': departmentName ?? 'علوم الحاسوب',
      'academic_level': levelName ?? 'المستوى الأول',
      'phone': phone.trim().isNotEmpty ? phone.trim() : '0000000000',
      'status': status,
      'university_id': universityId,
      'barcode_id': qrCode,
      'fingerprint_registered': hasFingerprint,
    };
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
    String? collegeName,
    String? departmentName,
    String? levelName,
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
      fingerprintId: fingerprintId ?? this.fingerprintId,
      fingerprintStatus: fingerprintStatus ?? this.fingerprintStatus,
      fingerprintQuality: fingerprintQuality ?? this.fingerprintQuality,
      fingerprintEnrolledAt: fingerprintEnrolledAt ?? this.fingerprintEnrolledAt,
      photoUrl: photoUrl ?? this.photoUrl,
      collegeName: collegeName ?? this.collegeName,
      departmentName: departmentName ?? this.departmentName,
      levelName: levelName ?? this.levelName,
    );
  }
}
