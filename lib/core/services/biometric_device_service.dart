import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/local/hive_helper.dart';
import '../../data/models/biometric_device.dart';
import '../../data/remote/supabase_service.dart';

abstract class BiometricDeviceAdapter {
  String get vendorName;
  Future<bool> testConnection(BiometricDevice device);
  Future<List<Map<String, dynamic>>> pullAttendanceLogs(BiometricDevice device);
}

class ZKTecoDeviceAdapter implements BiometricDeviceAdapter {
  @override
  String get vendorName => 'ZKTeco';

  @override
  Future<bool> testConnection(BiometricDevice device) async {
    try {
      final socket = await Socket.connect(
        device.ipAddress,
        device.port,
        timeout: const Duration(milliseconds: 2500),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullAttendanceLogs(BiometricDevice device) async {
    return [];
  }
}

class GenericNetworkDeviceAdapter implements BiometricDeviceAdapter {
  final String _vendor;
  GenericNetworkDeviceAdapter(this._vendor);

  @override
  String get vendorName => _vendor;

  @override
  Future<bool> testConnection(BiometricDevice device) async {
    try {
      final socket = await Socket.connect(
        device.ipAddress,
        device.port,
        timeout: const Duration(milliseconds: 2500),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullAttendanceLogs(BiometricDevice device) async {
    return [];
  }
}

class BiometricDeviceService extends ChangeNotifier {
  static final BiometricDeviceService instance = BiometricDeviceService._init();
  final HiveHelper _hive = HiveHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;

  final Map<String, BiometricDeviceAdapter> _adapters = {
    'ZKTeco': ZKTecoDeviceAdapter(),
    'Anviz': GenericNetworkDeviceAdapter('Anviz'),
    'Suprema': GenericNetworkDeviceAdapter('Suprema'),
    'Realand': GenericNetworkDeviceAdapter('Realand'),
    'Generic': GenericNetworkDeviceAdapter('Generic'),
  };

  Timer? _healthCheckTimer;
  bool _isChecking = false;

  BiometricDeviceService._init() {
    _startPeriodicHealthCheck();
  }

  void _startPeriodicHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      pingAllDevices();
    });
  }

  BiometricDeviceAdapter getAdapter(String vendor) {
    return _adapters[vendor] ?? _adapters['Generic']!;
  }

  Future<List<BiometricDevice>> getDevices() async {
    return await _hive.getBiometricDevices();
  }

  Future<void> saveDevice(BiometricDevice device) async {
    await _hive.saveBiometricDevice(device);
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        await _supabase.client!
            .from('dawami_records')
            .upsert(device.toDawamiRecord(), onConflict: 'record_type,record_key');
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> deleteDevice(String id) async {
    await _hive.deleteBiometricDevice(id);
    if (_supabase.isConfigured && _supabase.client != null) {
      try {
        await _supabase.client!
            .from('dawami_records')
            .delete()
            .eq('record_type', 'biometric_device')
            .eq('record_key', id);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> testDeviceConnection(BiometricDevice device) async {
    final stopwatch = Stopwatch()..start();
    bool connected = false;
    String message = '';

    try {
      final adapter = getAdapter(device.vendor);
      connected = await adapter.testConnection(device);
      stopwatch.stop();

      if (connected) {
        message = 'تم الاتصال بالجهاز بنجاح واستجابة المنفذ (${stopwatch.elapsedMilliseconds} ms)';
      } else {
        message = 'فشل الاتصال: الجهاز لا يستجيب على العنوان ${device.ipAddress}:${device.port}';
      }
    } catch (e) {
      stopwatch.stop();
      connected = false;
      message = 'خطأ في الاتصال: $e';
    }

    final updated = device.copyWith(
      status: connected ? 'متصل' : 'غير متصل',
      lastPingAt: DateTime.now().toIso8601String(),
      latencyMs: connected ? stopwatch.elapsedMilliseconds : null,
    );
    await _hive.saveBiometricDevice(updated);
    notifyListeners();

    return {
      'connected': connected,
      'latencyMs': stopwatch.elapsedMilliseconds,
      'message': message,
      'device': updated,
    };
  }

  Future<void> pingAllDevices() async {
    if (_isChecking) return;
    _isChecking = true;
    try {
      final devices = await getDevices();
      for (final device in devices) {
        if (!device.isActive) continue;
        await testDeviceConnection(device);
      }
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    super.dispose();
  }
}
