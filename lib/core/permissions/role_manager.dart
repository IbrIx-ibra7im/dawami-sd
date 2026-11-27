enum UserRole {
  superAdmin,
  universityAdmin,
  studentAffairs,
  biometricAdmin,
  supervisor,
  student,
  attendanceOfficer,
  registrationStaff,
  viewer,
}

class RoleManager {
  static String getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'مدير النظام';
      case UserRole.universityAdmin:
        return 'إدارة الجامعة';
      case UserRole.studentAffairs:
        return 'مسؤول شؤون الطلاب';
      case UserRole.biometricAdmin:
        return 'مسؤول أجهزة البصمة';
      case UserRole.supervisor:
        return 'المشرف';
      case UserRole.student:
        return 'الطالب';
      case UserRole.attendanceOfficer:
        return 'مشرف الحضور';
      case UserRole.registrationStaff:
        return 'مسجل شؤون الطلاب';
      case UserRole.viewer:
        return 'زائر';
    }
  }

  static UserRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return UserRole.superAdmin;
      case 'university_admin':
      case 'universityadmin':
        return UserRole.universityAdmin;
      case 'student_affairs':
      case 'studentaffairs':
        return UserRole.studentAffairs;
      case 'biometric_admin':
      case 'biometricadmin':
        return UserRole.biometricAdmin;
      case 'supervisor':
        return UserRole.supervisor;
      case 'student':
        return UserRole.student;
      case 'attendance_officer':
        return UserRole.attendanceOfficer;
      case 'registration_staff':
        return UserRole.registrationStaff;
      case 'viewer':
      default:
        return UserRole.viewer;
    }
  }

  static String toRoleString(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.universityAdmin:
        return 'university_admin';
      case UserRole.studentAffairs:
        return 'student_affairs';
      case UserRole.biometricAdmin:
        return 'biometric_admin';
      case UserRole.supervisor:
        return 'supervisor';
      case UserRole.student:
        return 'student';
      case UserRole.attendanceOfficer:
        return 'attendance_officer';
      case UserRole.registrationStaff:
        return 'registration_staff';
      case UserRole.viewer:
        return 'viewer';
    }
  }

  static bool canDelete(UserRole role) {
    return role == UserRole.superAdmin || role == UserRole.universityAdmin;
  }

  static bool canManageStudents(UserRole role) {
    return role == UserRole.superAdmin ||
        role == UserRole.universityAdmin ||
        role == UserRole.studentAffairs ||
        role == UserRole.registrationStaff;
  }

  static bool canManageBiometricDevices(UserRole role) {
    return role == UserRole.superAdmin ||
        role == UserRole.universityAdmin ||
        role == UserRole.biometricAdmin;
  }

  static bool canEditAttendance(UserRole role) {
    return role == UserRole.superAdmin ||
        role == UserRole.universityAdmin ||
        role == UserRole.attendanceOfficer ||
        role == UserRole.supervisor;
  }

  static bool canRecordAttendance(UserRole role) {
    return role != UserRole.viewer && role != UserRole.student;
  }

  static bool canStudentSelfAttend(UserRole role) {
    return role == UserRole.student;
  }

  static bool canViewReports(UserRole role) {
    return role != UserRole.student;
  }

  static bool canExportData(UserRole role) {
    return role == UserRole.superAdmin ||
        role == UserRole.universityAdmin ||
        role == UserRole.studentAffairs ||
        role == UserRole.attendanceOfficer;
  }

  static bool canAccessSettings(UserRole role) {
    return role == UserRole.superAdmin || role == UserRole.universityAdmin;
  }

  static bool canViewAuditLogs(UserRole role) {
    return role == UserRole.superAdmin || role == UserRole.universityAdmin;
  }
}
