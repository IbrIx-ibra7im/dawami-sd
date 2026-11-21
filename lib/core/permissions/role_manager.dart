enum UserRole {
  superAdmin,
  attendanceOfficer,
  registrationStaff,
  supervisor,
  viewer,
}

class RoleManager {
  static String getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'مدير';
      case UserRole.registrationStaff:
        return 'مسجل';
      case UserRole.supervisor:
        return 'مشرف';
      case UserRole.attendanceOfficer:
        return 'مشرف الحضور';
      case UserRole.viewer:
        return 'زائر';
    }
  }

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return UserRole.superAdmin;
      case 'attendance_officer':
        return UserRole.attendanceOfficer;
      case 'registration_staff':
        return UserRole.registrationStaff;
      case 'supervisor':
        return UserRole.supervisor;
      case 'viewer':
      default:
        return UserRole.viewer;
    }
  }

  static String toRoleString(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.attendanceOfficer:
        return 'attendance_officer';
      case UserRole.registrationStaff:
        return 'registration_staff';
      case UserRole.supervisor:
        return 'supervisor';
      case UserRole.viewer:
        return 'viewer';
    }
  }

  // Permissions based on PDF page 5:
  // Super Admin: كامل الصلاحيات بما فيها الحذف
  // مسؤول الحضور: إدارة وتعديل سجلات الحضور
  // موظف تسجيل: تسجيل الحضور والغياب والانصراف
  // مشرف: متابعة وإشراف
  // عرض فقط: الاطلاع دون تعديل

  static bool canDelete(UserRole role) {
    return role != UserRole.viewer;
  }

  static bool canManageStudents(UserRole role) {
    return role != UserRole.viewer;
  }

  static bool canEditAttendance(UserRole role) {
    return role == UserRole.superAdmin || role == UserRole.attendanceOfficer;
  }

  static bool canRecordAttendance(UserRole role) {
    return role == UserRole.superAdmin ||
        role == UserRole.attendanceOfficer ||
        role == UserRole.registrationStaff;
  }

  static bool canManageLectures(UserRole role) {
    return role == UserRole.superAdmin || role == UserRole.attendanceOfficer;
  }

  static bool canViewReports(UserRole role) {
    return true; // All roles can view reports
  }

  static bool canExportData(UserRole role) {
    return role != UserRole.viewer;
  }

  static bool canAccessSettings(UserRole role) {
    return role == UserRole.superAdmin;
  }
}

