import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../data/local/hive_helper.dart';
import '../../data/remote/supabase_service.dart';
import 'local_storage_service.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  failed,
}

/// خدمة المزامنة السحابية والمحلية ومراقبة الاتصال (SyncService)
/// مسؤولة عن:
/// 1. مراقبة حالة الإنترنت (Connectivity Plus) واكتشاف عودة الاتصال تلقائياً.
/// 2. مزامنة بيانات الطلاب وسجلات الحضور مع Supabase تلقائياً عند عودة الإنترنت.
/// 3. حفظ العمليات غير المزامنة محلياً في Hive وإعادة المحاولة عند الفشل دون فقدان البيانات.
/// 4. توفير إحصائيات المزامنة للواجهة (حالة الإنترنت، حالة المزامنة، السجلات بالانتظار، آخر وقت مزامنة).
/// 5. دعم زر "مزامنة الآن" اليدوي.
class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._init();

  final Connectivity _connectivity = Connectivity();
  final LocalStorageService _localStorage = LocalStorageService.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final HiveHelper _hive = HiveHelper.instance;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  SyncStatus _status = SyncStatus.idle;
  int _pendingRecordsCount = 0;
  DateTime? _lastSyncTime;
  String? _lastError;
  Timer? _periodicCheckTimer;

  bool get isOnline => _isOnline;
  SyncStatus get status => _status;
  int get pendingRecordsCount => _pendingRecordsCount;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;
  bool get isSyncing => _status == SyncStatus.syncing;

  String get syncStatusText {
    switch (_status) {
      case SyncStatus.syncing:
        return 'جاري المزامنة...';
      case SyncStatus.success:
        return 'تمت المزامنة بنجاح';
      case SyncStatus.failed:
        return 'فشل المزامنة (محفوظ محلياً)';
      case SyncStatus.idle:
        if (_pendingRecordsCount > 0) {
          return 'بانتظار المزامنة ($_pendingRecordsCount)';
        }
        return 'مكتملة ومستقرة';
    }
  }

  String get formattedLastSyncTime {
    if (_lastSyncTime == null) return 'لم تتم المزامنة بعد';
    final formatter = DateFormat('hh:mm a', 'ar');
    return formatter.format(_lastSyncTime!);
  }

  SyncService._init() {
    _initConnectivity();
    _startPeriodicRefresh();
  }

  /// بدء الاستماع لتغيرات الاتصال بالإنترنت
  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
    } catch (e) {
      if (kDebugMode) print('Connectivity check notice: $e');
      _isOnline = true;
      notifyListeners();
    }
    await refreshPendingCount();
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasOffline = !_isOnline;
    final nowOnline = results.any((r) => r != ConnectivityResult.none);
    _isOnline = nowOnline;
    notifyListeners();

    // عند عودة الاتصال بالإنترنت تلقائياً: نبدأ المزامنة بدون تدخل المستخدم
    if (wasOffline && nowOnline) {
      if (kDebugMode) print('تمت استعادة الاتصال بالإنترنت، بدء المزامنة التلقائية مع Supabase...');
      syncNow(silent: true);
    }
  }

  void _startPeriodicRefresh() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      refreshPendingCount();
    });
  }

  /// تحديث عدد السجلات التي تنتظر المزامنة
  Future<void> refreshPendingCount() async {
    try {
      _pendingRecordsCount = await _localStorage.getPendingAttendanceCount();
      notifyListeners();
    } catch (_) {}
  }

  /// تنفيذ المزامنة الآن (تلقائياً أو يدوياً)
  Future<bool> syncNow({bool silent = false}) async {
    if (_status == SyncStatus.syncing) return false;

    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();

    try {
      // 1. التحقق من توفر الإنترنت
      if (!_isOnline) {
        _status = SyncStatus.failed;
        _lastError = 'لا يوجد اتصال بالإنترنت حالياً. السجلات محفوظة بأمان في Hive.';
        await refreshPendingCount();
        notifyListeners();
        return false;
      }

      // 2. التحقق من اتصال Supabase
      if (!_supabase.isConfigured || _supabase.client == null) {
        await _supabase.initDefault();
      }

      final client = _supabase.client;
      if (client == null) {
        _status = SyncStatus.failed;
        _lastError = 'قاعدة بيانات Supabase غير مهيأة.';
        notifyListeners();
        return false;
      }

      // 3. رفع سجلات الحضور غير المزامنة من Hive إلى Supabase (جدول dawami_records الموحد)
      final pendingAttendance = await _localStorage.getPendingAttendanceRecords();
      for (final record in pendingAttendance) {
        try {
          await client.from('dawami_records').upsert(record.toDawamiRecord(), onConflict: 'record_type,record_key');
          // تم الرفع بنجاح -> تعليم السجل كـ مزامن في Hive
          await _localStorage.markAttendanceSynced(record.id);
        } catch (e) {
          if (kDebugMode) print('فشل رفع سجل الحضور (${record.id}): $e');
        }
      }

      // 4. مزامنة الطلاب المسجلين محلياً إلى Supabase (جدول dawami_records الموحد)
      try {
        final localStudents = await _localStorage.getStudents();
        for (final s in localStudents) {
          try {
            await client.from('dawami_records').upsert(s.toDawamiRecord(), onConflict: 'record_type,record_key');
          } catch (e) {
            if (kDebugMode) print('خطأ مزامنة الطالب (${s.universityId}): $e');
          }
        }
      } catch (_) {}

      // 5. مزامنة طابور Hive العام
      try {
        await _hive.syncWithSupabase();
      } catch (_) {}

      _lastSyncTime = DateTime.now();
      _status = SyncStatus.success;
      await refreshPendingCount();
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('خطأ في المزامنة مع Supabase: $e');
      _status = SyncStatus.failed;
      _lastError = e.toString().replaceAll('Exception: ', '');
      await refreshPendingCount();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicCheckTimer?.cancel();
    super.dispose();
  }
}
