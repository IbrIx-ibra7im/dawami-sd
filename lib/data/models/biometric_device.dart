class BiometricDevice {
  final String id;
  final String deviceName;
  final String serialNumber;
  final String vendor; // 'ZKTeco', 'Anviz', 'Suprema', 'Realand', 'Generic'
  final String model;
  final String ipAddress;
  final int port;
  final String protocol; // 'TCP/IP', 'UDP', 'USB', 'RS485'
  final String locationName;
  final String college;
  final String department;
  final String status; // 'متصل', 'غير متصل', 'قيد الاتصال'
  final String? lastPingAt;
  final String? lastSyncAt;
  final bool isActive;
  final int? latencyMs;

  const BiometricDevice({
    required this.id,
    required this.deviceName,
    required this.serialNumber,
    required this.vendor,
    required this.model,
    required this.ipAddress,
    this.port = 4370,
    this.protocol = 'TCP/IP',
    required this.locationName,
    this.college = 'كلية علوم الحاسوب والتنمية البشرية',
    this.department = 'عام',
    this.status = 'غير متصل',
    this.lastPingAt,
    this.lastSyncAt,
    this.isActive = true,
    this.latencyMs,
  });

  bool get isConnected => status == 'متصل';

  BiometricDevice copyWith({
    String? id,
    String? deviceName,
    String? serialNumber,
    String? vendor,
    String? model,
    String? ipAddress,
    int? port,
    String? protocol,
    String? locationName,
    String? college,
    String? department,
    String? status,
    String? lastPingAt,
    String? lastSyncAt,
    bool? isActive,
    int? latencyMs,
  }) {
    return BiometricDevice(
      id: id ?? this.id,
      deviceName: deviceName ?? this.deviceName,
      serialNumber: serialNumber ?? this.serialNumber,
      vendor: vendor ?? this.vendor,
      model: model ?? this.model,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      locationName: locationName ?? this.locationName,
      college: college ?? this.college,
      department: department ?? this.department,
      status: status ?? this.status,
      lastPingAt: lastPingAt ?? this.lastPingAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      isActive: isActive ?? this.isActive,
      latencyMs: latencyMs ?? this.latencyMs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_name': deviceName,
      'serial_number': serialNumber,
      'vendor': vendor,
      'manufacturer': vendor,
      'model': model,
      'ip_address': ipAddress,
      'port': port,
      'protocol': protocol,
      'location_name': locationName,
      'college': college,
      'department': department,
      'status': status,
      'last_ping_at': lastPingAt,
      'last_sync_at': lastSyncAt,
      'is_active': isActive ? 1 : 0,
      'latency_ms': latencyMs,
    };
  }

  Map<String, dynamic> toDawamiRecord() {
    return {
      'record_type': 'biometric_device',
      'record_key': id,
      'student_number': serialNumber,
      'full_name': deviceName,
      'barcode_id': serialNumber,
      'status': status,
      'sync_status': 'مزامنة',
      'data': toMap(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory BiometricDevice.fromMap(Map<dynamic, dynamic> map) {
    return BiometricDevice(
      id: map['id']?.toString() ?? '',
      deviceName: map['device_name']?.toString() ?? 'جهاز بصمة',
      serialNumber: map['serial_number']?.toString() ?? '',
      vendor: map['vendor']?.toString() ?? map['manufacturer']?.toString() ?? 'ZKTeco',
      model: map['model']?.toString() ?? 'ZK-F18',
      ipAddress: map['ip_address']?.toString() ?? '192.168.1.201',
      port: (map['port'] as num?)?.toInt() ?? 4370,
      protocol: map['protocol']?.toString() ?? 'TCP/IP',
      locationName: map['location_name']?.toString() ?? 'المدخل الرئيسي',
      college: map['college']?.toString() ?? 'كلية علوم الحاسوب والتنمية البشرية',
      department: map['department']?.toString() ?? 'عام',
      status: map['status']?.toString() ?? 'غير متصل',
      lastPingAt: map['last_ping_at']?.toString(),
      lastSyncAt: map['last_sync_at']?.toString(),
      isActive: (map['is_active'] == 1 || map['is_active'] == true),
      latencyMs: (map['latency_ms'] as num?)?.toInt(),
    );
  }
}
