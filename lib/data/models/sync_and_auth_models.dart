// Models for Sync Queue (PDF page 9) & Audit Log (PDF page 10)

class SyncQueueItem {
  final int? id;
  final String operation; // 'INSERT', 'UPDATE', 'DELETE'
  final String tableName; // 'attendance', 'students', etc.
  final String recordId; // UUID or string identifier
  final String payload; // JSON serialized data
  final String createdAt;
  final int attempts;
  final String status; // 'انتظار', 'جاري', 'فشل', 'تمت'
  final String? error;

  SyncQueueItem({
    this.id,
    required this.operation,
    required this.tableName,
    required this.recordId,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.status = 'انتظار',
    this.error,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'operation': operation,
    'table_name': tableName,
    'record_id': recordId,
    'payload': payload,
    'created_at': createdAt,
    'attempts': attempts,
    'status': status,
    'error': error,
  };

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) => SyncQueueItem(
    id: map['id'] as int?,
    operation: map['operation'] as String? ?? 'INSERT',
    tableName: map['table_name'] as String? ?? '',
    recordId: map['record_id'] as String? ?? '',
    payload: map['payload'] as String? ?? '{}',
    createdAt: map['created_at'] as String? ?? '',
    attempts: (map['attempts'] as num?)?.toInt() ?? 0,
    status: map['status'] as String? ?? 'انتظار',
    error: map['error'] as String?,
  );

  SyncQueueItem copyWith({
    int? id,
    String? operation,
    String? tableName,
    String? recordId,
    String? payload,
    String? createdAt,
    int? attempts,
    String? status,
    String? error,
  }) => SyncQueueItem(
    id: id ?? this.id,
    operation: operation ?? this.operation,
    tableName: tableName ?? this.tableName,
    recordId: recordId ?? this.recordId,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    status: status ?? this.status,
    error: error ?? this.error,
  );
}

class AuditLog {
  final int? id;
  final String userId;
  final String action; // 'إضافة', 'تعديل', 'حذف'
  final String tableName;
  final String? oldData;
  final String? newData;
  final String createdAt;

  AuditLog({
    this.id,
    required this.userId,
    required this.action,
    required this.tableName,
    this.oldData,
    this.newData,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'action': action,
    'table_name': tableName,
    'old_data': oldData,
    'new_data': newData,
    'created_at': createdAt,
  };

  factory AuditLog.fromMap(Map<String, dynamic> map) => AuditLog(
    id: map['id'] as int?,
    userId: map['user_id'] as String? ?? '',
    action: map['action'] as String? ?? '',
    tableName: map['table_name'] as String? ?? '',
    oldData: map['old_data'] as String?,
    newData: map['new_data'] as String?,
    createdAt: map['created_at'] as String? ?? '',
  );
}

class UserProfile {
  final String id;
  final String fullName;
  final String role; // 'super_admin', 'attendance_officer', 'registration_staff', 'supervisor', 'viewer'
  final String email;
  final String createdAt;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.email,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'full_name': fullName,
    'role': role,
    'email': email,
    'created_at': createdAt,
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    id: map['id'] as String,
    fullName: map['full_name'] as String? ?? '',
    role: map['role'] as String? ?? 'viewer',
    email: map['email'] as String? ?? '',
    createdAt: map['created_at'] as String? ?? '',
  );
}

