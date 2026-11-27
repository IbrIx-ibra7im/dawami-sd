class MobileDevice {
  final String id;
  final String studentId;
  final String universityId;
  final String deviceUuid;
  final String deviceModel;
  final String osName;
  final String osVersion;
  final bool isApproved;
  final bool antiSpoofingEnabled;
  final String boundAt;
  final String? lastUsedAt;

  const MobileDevice({
    required this.id,
    required this.studentId,
    required this.universityId,
    required this.deviceUuid,
    required this.deviceModel,
    this.osName = 'Android',
    this.osVersion = '14',
    this.isApproved = true,
    this.antiSpoofingEnabled = true,
    required this.boundAt,
    this.lastUsedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'university_id': universityId,
      'device_uuid': deviceUuid,
      'device_model': deviceModel,
      'os_name': osName,
      'os_version': osVersion,
      'is_approved': isApproved ? 1 : 0,
      'anti_spoofing_enabled': antiSpoofingEnabled ? 1 : 0,
      'bound_at': boundAt,
      'last_used_at': lastUsedAt,
    };
  }

  Map<String, dynamic> toDawamiRecord() {
    return {
      'record_type': 'mobile_device',
      'record_key': id,
      'student_number': universityId,
      'full_name': deviceModel,
      'barcode_id': deviceUuid,
      'status': isApproved ? 'معتمد' : 'معلق',
      'sync_status': 'مزامنة',
      'data': toMap(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory MobileDevice.fromMap(Map<dynamic, dynamic> map) {
    return MobileDevice(
      id: map['id']?.toString() ?? '',
      studentId: map['student_id']?.toString() ?? '',
      universityId: map['university_id']?.toString() ?? '',
      deviceUuid: map['device_uuid']?.toString() ?? '',
      deviceModel: map['device_model']?.toString() ?? 'هاتف ذكي',
      osName: map['os_name']?.toString() ?? 'Android',
      osVersion: map['os_version']?.toString() ?? '14',
      isApproved: (map['is_approved'] == 1 || map['is_approved'] == true),
      antiSpoofingEnabled: (map['anti_spoofing_enabled'] == 1 || map['anti_spoofing_enabled'] == true),
      boundAt: map['bound_at']?.toString() ?? DateTime.now().toIso8601String(),
      lastUsedAt: map['last_used_at']?.toString(),
    );
  }
}
