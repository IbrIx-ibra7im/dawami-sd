class Student {
  final int? id;
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

  bool get hasFingerprint =>
      fingerprintId != null &&
      fingerprintId!.isNotEmpty &&
      fingerprintStatus != 'غير مسجلة';

  Student({
    this.id,
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
      if (fingerprintQuality != null) 'fingerprint_quality': fingerprintQuality,
      if (fingerprintEnrolledAt != null) 'fingerprint_enrolled_at': fingerprintEnrolledAt,
      'photo_url': photoUrl,
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

  factory Student.fromMap(Map<dynamic, dynamic> map) {
    final fpId = map['fingerprint_id']?.toString();
    final explicitFpStatus = map['fingerprint_status']?.toString();

    return Student(
      id: (map['id'] as num?)?.toInt(),
      universityId: map['university_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      collegeId: (map['college_id'] as num?)?.toInt() ?? 1,
      departmentId: (map['department_id'] as num?)?.toInt() ?? 1,
      levelId: (map['level_id'] as num?)?.toInt() ?? 1,
      semesterId: (map['semester_id'] as num?)?.toInt() ?? 1,
      status: map['status']?.toString() ?? 'نشط',
      qrCode: map['qr_code']?.toString() ?? '',
      fingerprintId: fpId,
      fingerprintStatus: explicitFpStatus ?? (fpId != null && fpId.isNotEmpty ? 'مسجلة' : 'غير مسجلة'),
      fingerprintQuality: (map['fingerprint_quality'] as num?)?.toInt(),
      fingerprintEnrolledAt: map['fingerprint_enrolled_at']?.toString(),
      photoUrl: map['photo_url']?.toString(),
      collegeName: map['college_name']?.toString(),
      departmentName: map['department_name']?.toString(),
      levelName: map['level_name']?.toString(),
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
