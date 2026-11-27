class ComputerStation {
  final String id;
  final String machineName;
  final String machineId;
  final String ipAddress;
  final String locationName;
  final String college;
  final String department;
  final bool cameraEnabled;
  final bool barcodeReaderEnabled;
  final bool biometricReaderEnabled;
  final String status;
  final String? lastSeenAt;

  const ComputerStation({
    required this.id,
    required this.machineName,
    required this.machineId,
    required this.ipAddress,
    required this.locationName,
    this.college = 'كلية علوم الحاسوب والتنمية البشرية',
    this.department = 'عام',
    this.cameraEnabled = true,
    this.barcodeReaderEnabled = true,
    this.biometricReaderEnabled = true,
    this.status = 'نشط',
    this.lastSeenAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'machine_name': machineName,
      'machine_id': machineId,
      'ip_address': ipAddress,
      'location_name': locationName,
      'college': college,
      'department': department,
      'camera_enabled': cameraEnabled ? 1 : 0,
      'barcode_reader_enabled': barcodeReaderEnabled ? 1 : 0,
      'biometric_reader_enabled': biometricReaderEnabled ? 1 : 0,
      'status': status,
      'last_seen_at': lastSeenAt,
    };
  }

  Map<String, dynamic> toDawamiRecord() {
    return {
      'record_type': 'computer_station',
      'record_key': id,
      'student_number': machineId,
      'full_name': machineName,
      'barcode_id': ipAddress,
      'status': status,
      'sync_status': 'مزامنة',
      'data': toMap(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory ComputerStation.fromMap(Map<dynamic, dynamic> map) {
    return ComputerStation(
      id: map['id']?.toString() ?? '',
      machineName: map['machine_name']?.toString() ?? 'محطة حاسوب',
      machineId: map['machine_id']?.toString() ?? '',
      ipAddress: map['ip_address']?.toString() ?? '127.0.0.1',
      locationName: map['location_name']?.toString() ?? 'المدخل',
      college: map['college']?.toString() ?? 'كلية علوم الحاسوب والتنمية البشرية',
      department: map['department']?.toString() ?? 'عام',
      cameraEnabled: (map['camera_enabled'] == 1 || map['camera_enabled'] == true),
      barcodeReaderEnabled: (map['barcode_reader_enabled'] == 1 || map['barcode_reader_enabled'] == true),
      biometricReaderEnabled: (map['biometric_reader_enabled'] == 1 || map['biometric_reader_enabled'] == true),
      status: map['status']?.toString() ?? 'نشط',
      lastSeenAt: map['last_seen_at']?.toString(),
    );
  }
}
