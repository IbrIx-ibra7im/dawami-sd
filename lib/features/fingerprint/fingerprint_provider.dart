import 'package:flutter/foundation.dart';
import '../../data/models/biometric_models.dart';
import '../../data/models/student.dart';
import '../../data/local/database_helper.dart';
import '../../data/local/hive_helper.dart';

enum BiometricDeviceStatus {
  disconnected,
  connecting,
  connected,
  scanning,
  matched,
  unmatched,
  error,
}

enum BiometricMode {
  auto,          // Auto-detect: Device native (Phone/Laptop) or fallback
  deviceNative,  // Native Phone (Android/iOS) or Laptop (Windows Hello)
  usbReader,     // Dedicated USB/Network scanner (e.g. ZK-F18)
  simulator,     // Interactive touch simulation
}

abstract class FingerprintAdapter {
  String get deviceName;
  String get deviceModel;
  BiometricDeviceStatus get status;
  bool get isHardwareBacked;
  Future<bool> connect();
  Future<void> disconnect();
  Future<Student?> scanAndIdentify(List<Student> activeStudents);
  Future<FingerprintCapture?> captureFingerprint(Student student);
}

class FingerprintCapture {
  final String fingerprintId;
  final String templateHash;
  final int qualityScore;

  const FingerprintCapture({
    required this.fingerprintId,
    required this.templateHash,
    required this.qualityScore,
  });
}

// Extensible provider implementation supporting Dedicated Hardware Readers (ZKTeco, DigitalPersona, SecuGen)
class FingerprintProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  FingerprintAdapter? _activeAdapter;
  BiometricDeviceStatus _status = BiometricDeviceStatus.disconnected;
  String _statusMessage = 'قارئ البصمة الحقيقي غير متصل';
  Student? _lastIdentifiedStudent;
  String _selectedDeviceModel = 'قارئ بصمات جامعي USB (ZKTeco ZK9500)';
  BiometricMode _currentMode = BiometricMode.usbReader;
  static const String notActivatedMessage = fingerprintNotActivatedMessage;

  // مواصفات الأجهزة والـ SDK المطلوبة للبصمة البرمجية
  static const String requiredDeviceSpecs =
      'قارئ بصمات بصري خارجي USB معتمد للحضور الجماعي (مثل ZKTeco ZK9500 أو ZKTeco ZK4500 أو DigitalPersona 4500 أو جهاز شبكي ZKTeco F18).';
  static const String requiredSdkSpecs =
      'ZKTeco ZKBioOnline SDK / ZKFinger SDK أو DigitalPersona One Touch SDK (مكتبات استخراج ومطابقة قوالب Minutiae 1:N المتوافقة مع معيار ANSI/ISO 19794-2).';
  static const String mobileBiometricNotice =
      'تنبيه فني: بصمة الهاتف الشخصية (LocalAuth) مخصصة فقط لقفل الهاتف وتتعرف على إصبع مالك الجهاز فقط، ولا يمكنها برمجياً تخزين أو مطابقة بصمات مئات الطلاب. لذلك يعتمد نظام دوامي على قوالب البصمة الحيوية المستقلة (Fingerprint Template ID) وقارئات البصمة المخصصة.';

  BiometricDeviceStatus get status => _status;
  FingerprintAdapter? get activeAdapter => _activeAdapter;
  String get statusMessage => _statusMessage;
  Student? get lastIdentifiedStudent => _lastIdentifiedStudent;
  String get selectedDeviceModel => _selectedDeviceModel;
  BiometricMode get currentMode => _currentMode;
  bool get isConnected =>
      _activeAdapter?.isHardwareBacked == true &&
      _status != BiometricDeviceStatus.disconnected;
  bool get isExternalHardwareConnected =>
      _activeAdapter?.isHardwareBacked ?? false;
  bool get isDeviceBiometricsSupported => isExternalHardwareConnected;
  bool get canCheckBiometrics => isExternalHardwareConnected;
  bool get canEnrollFingerprints => isExternalHardwareConnected;

  FingerprintProvider() {
    _initDefaultAdapter();
  }

  void _initDefaultAdapter() {
    _activeAdapter = SimulatedFingerprintAdapter(
      deviceName: 'محاكاة قارئ البصمة (لا تتحقق من الهوية)',
      deviceModel: _selectedDeviceModel,
    );
  }

  void setMode(BiometricMode mode) {
    _currentMode = mode;
    switch (mode) {
      case BiometricMode.usbReader:
        _selectedDeviceModel = 'قارئ بصمات USB (ZKTeco ZK9500 / ZK4500)';
        break;
      case BiometricMode.deviceNative:
        _selectedDeviceModel = 'محطة الحضور البيومترية المستقلة (ZK-F18 Terminal)';
        break;
      case BiometricMode.simulator:
        _selectedDeviceModel = 'مستشعر المحاكاة والاختبار البيومتري';
        break;
      case BiometricMode.auto:
        _selectedDeviceModel = 'قارئ البصمة البيومتري الجامعي';
        break;
    }
    notifyListeners();
  }

  void selectDevice(String model) {
    _selectedDeviceModel = model;
    _activeAdapter = SimulatedFingerprintAdapter(
      deviceName: 'محاكاة قارئ البصمة (لا تتحقق من الهوية)',
      deviceModel: model,
    );
    notifyListeners();
  }

  /// لا يُقبل التطابق إلا من قارئ حقيقي ومع سجل تفعيل مرتبط بهوية الطالب.
  Future<Student?> triggerFingerprintScan() async {
    _status = BiometricDeviceStatus.scanning;
    _statusMessage = 'جاري التحقق من البصمة المسجلة...';
    _lastIdentifiedStudent = null;
    notifyListeners();

    final adapter = _activeAdapter;
    if (adapter == null || !adapter.isHardwareBacked) {
      _status = BiometricDeviceStatus.disconnected;
      _statusMessage =
          'لا يمكن التحقق بالبصمة حالياً: لم يتم ربط قارئ بصمة حقيقي وSDK معتمد.';
      notifyListeners();
      return null;
    }

    try {
      final hiveStudents = await HiveHelper.instance.getStudents(status: 'نشط');
      final students = hiveStudents.isNotEmpty
          ? hiveStudents
          : await _db.getStudents(status: 'نشط');
      final hiveFingerprints =
          await HiveHelper.instance.getStudentFingerprints();
      final fingerprints = hiveFingerprints.isNotEmpty
          ? hiveFingerprints
          : await _db.getStudentFingerprints();
      final enrolledStudents = students
          .where(
            (student) => _hasActiveFingerprint(student, fingerprints),
          )
          .toList();

      if (enrolledStudents.isEmpty) {
        _status = BiometricDeviceStatus.unmatched;
        _statusMessage = notActivatedMessage;
        notifyListeners();
        return null;
      }

      final adapterMatch = await adapter.scanAndIdentify(enrolledStudents);
      final matchedStudent = validateFingerprintMatch(
        candidate: adapterMatch,
        students: enrolledStudents,
        fingerprints: fingerprints,
      );
      if (matchedStudent == null) {
        _status = BiometricDeviceStatus.unmatched;
        _statusMessage = notActivatedMessage;
        notifyListeners();
        return null;
      }

      _lastIdentifiedStudent = matchedStudent;
      _status = BiometricDeviceStatus.matched;
      _statusMessage =
          'تم التحقق من بصمة الطالب: ${matchedStudent.fullName} (${matchedStudent.universityId})';
      notifyListeners();
      return matchedStudent;
    } catch (error) {
      _status = BiometricDeviceStatus.error;
      _statusMessage = 'تعذر التحقق من البصمة: $error';
      notifyListeners();
      return null;
    }
  }

  Future<FingerprintCapture?> captureFingerprint(Student student) {
    final adapter = _activeAdapter;
    if (adapter == null || !adapter.isHardwareBacked) {
      return Future.value(null);
    }
    return adapter.captureFingerprint(student);
  }

  @visibleForTesting
  static Student? validateFingerprintMatch({
    required Student? candidate,
    required List<Student> students,
    required List<StudentFingerprint> fingerprints,
  }) {
    if (candidate == null ||
        candidate.id == null ||
        candidate.status != 'نشط' ||
        !candidate.hasFingerprint) {
      return null;
    }

    final fingerprintIsActive = fingerprints.any(
      (fingerprint) =>
          fingerprint.isActive &&
          fingerprint.studentId == candidate.id &&
          fingerprint.universityId == candidate.universityId &&
          fingerprint.fingerprintId == candidate.fingerprintId,
    );
    if (!fingerprintIsActive) return null;

    for (final student in students) {
      if (student.id == candidate.id &&
          student.universityId == candidate.universityId &&
          student.status == 'نشط' &&
          student.hasFingerprint &&
          student.fingerprintId == candidate.fingerprintId) {
        return student;
      }
    }
    return null;
  }

  static bool _hasActiveFingerprint(
    Student student,
    List<StudentFingerprint> fingerprints,
  ) {
    return student.id != null &&
        student.status == 'نشط' &&
        student.hasFingerprint &&
        fingerprints.any(
          (fingerprint) =>
              fingerprint.isActive &&
              fingerprint.studentId == student.id &&
              fingerprint.universityId == student.universityId &&
              fingerprint.fingerprintId == student.fingerprintId,
        );
  }

  void resetState() {
    _status = _activeAdapter?.isHardwareBacked == true
        ? BiometricDeviceStatus.connected
        : BiometricDeviceStatus.disconnected;
    _statusMessage = _activeAdapter?.isHardwareBacked == true
        ? 'ضع إصبعك على القارئ بانتظار التحقق'
        : 'قارئ البصمة الحقيقي غير متصل';
    _lastIdentifiedStudent = null;
    notifyListeners();
  }
}

class SimulatedFingerprintAdapter implements FingerprintAdapter {
  @override
  final String deviceName;
  @override
  final String deviceModel;

  BiometricDeviceStatus _status = BiometricDeviceStatus.disconnected;
  @override
  bool get isHardwareBacked => false;

  SimulatedFingerprintAdapter({
    required this.deviceName,
    required this.deviceModel,
  });

  @override
  BiometricDeviceStatus get status => _status;

  @override
  Future<bool> connect() async {
    _status = BiometricDeviceStatus.disconnected;
    return false;
  }

  @override
  Future<void> disconnect() async {
    _status = BiometricDeviceStatus.disconnected;
  }

  @override
  Future<Student?> scanAndIdentify(List<Student> activeStudents) async {
    return null;
  }

  @override
  Future<FingerprintCapture?> captureFingerprint(Student student) async {
    return null;
  }
}
