import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'attendance_record.dart';
import 'student.dart';

/// حالات فحص ومطابقة الوجه في البث المباشر
enum FaceVerificationStatus {
  searching,          // بانتظار وقوف الطالب أمام الكاميرا
  noFaceDetected,     // لا يوجد وجه أمام الكاميرا
  multipleFaces,      // يوجد أكثر من وجه أمام الكاميرا
  blurryOrPoorLight,  // إضاءة منخفضة أو الوجه غير واضح
  unregisteredFace,   // وجه غير مسجل في قاعدة البيانات
  mismatchedFeatures, // لم يتم التعرف على الوجه، ملامح الوجه غير متطابقة مع بيانات الطالب المسجلة
  livenessFailed,     // فشل فحص الحيوية (محاولة استخدام صورة مطبوعة أو شاشة)
  recognizedSuccess,  // تم التعرف على الطالب وتسجيل الحضور بنجاح
  alreadyRecorded,    // تم تسجيل الحضور مسبقاً (ضمن فترة منع التكرار)
  technicalError,     // تعذر الكشف بسبب خطأ تقني
}

extension FaceVerificationStatusX on FaceVerificationStatus {
  String get arabicTitle {
    switch (this) {
      case FaceVerificationStatus.searching:
        return 'المسح البيومتري نشط';
      case FaceVerificationStatus.noFaceDetected:
        return 'لا يوجد وجه';
      case FaceVerificationStatus.multipleFaces:
        return 'تعدد وجوه';
      case FaceVerificationStatus.blurryOrPoorLight:
        return 'إضاءة غير كافية';
      case FaceVerificationStatus.unregisteredFace:
        return 'وجه غير مسجل';
      case FaceVerificationStatus.mismatchedFeatures:
        return 'ملامح غير متطابقة';
      case FaceVerificationStatus.livenessFailed:
        return 'فحص الحيوية مرفوض';
      case FaceVerificationStatus.recognizedSuccess:
        return 'طالب معتمد';
      case FaceVerificationStatus.alreadyRecorded:
        return 'مسجل مسبقاً';
      case FaceVerificationStatus.technicalError:
        return 'خطأ تقني';
    }
  }

  String get arabicMessage {
    switch (this) {
      case FaceVerificationStatus.searching:
        return 'قف في المنتصف أمام الكاميرا بوضوح، سيتم التعرف وتسجيل دوامك آلياً.';
      case FaceVerificationStatus.noFaceDetected:
        return 'لا يوجد وجه أمام الكاميرا. يرجى الوقوف بوضوح أمام العدسة.';
      case FaceVerificationStatus.multipleFaces:
        return 'يوجد أكثر من وجه أمام الكاميرا. يرجى الوقوف بشكل فردي في المسار.';
      case FaceVerificationStatus.blurryOrPoorLight:
        return 'الإضاءة منخفضة أو الوجه غير واضح. يرجى تحسين الإضاءة والاقتراب قليلاً.';
      case FaceVerificationStatus.unregisteredFace:
        return 'وجه غير مسجل في النظام. يرجى مراجعة إدارة الكلية لتسجيل بصمة وجهك.';
      case FaceVerificationStatus.mismatchedFeatures:
        return 'لم يتم التعرف على الوجه، ملامح الوجه غير متطابقة مع بيانات الطالب المسجلة.';
      case FaceVerificationStatus.livenessFailed:
        return 'فشل فحص الحيوية (Liveness): تم اكتشاف محاولة استخدام صورة مطبوعة أو شاشة هاتف.';
      case FaceVerificationStatus.recognizedSuccess:
        return 'تمت المطابقة بنجاح وتسجيل الحضور آلياً.';
      case FaceVerificationStatus.alreadyRecorded:
        return 'تم تسجيل حضور الطالب مسبقاً ضمن هذه الجلسة (فترة منع التكرار).';
      case FaceVerificationStatus.technicalError:
        return 'تعذر إتمام الكشف بسبب عارض تقني، يرجى إعادة المحاولة.';
    }
  }

  Color get statusColor {
    switch (this) {
      case FaceVerificationStatus.searching:
        return AppColors.turquoise;
      case FaceVerificationStatus.recognizedSuccess:
        return AppColors.success;
      case FaceVerificationStatus.alreadyRecorded:
        return AppColors.warning;
      case FaceVerificationStatus.blurryOrPoorLight:
      case FaceVerificationStatus.multipleFaces:
      case FaceVerificationStatus.noFaceDetected:
        return const Color(0xFFF59E0B); // Amber
      case FaceVerificationStatus.mismatchedFeatures:
      case FaceVerificationStatus.unregisteredFace:
      case FaceVerificationStatus.livenessFailed:
      case FaceVerificationStatus.technicalError:
        return const Color(0xFFEF4444); // Neon Red
    }
  }

  IconData get statusIcon {
    switch (this) {
      case FaceVerificationStatus.searching:
        return Icons.face_rounded;
      case FaceVerificationStatus.recognizedSuccess:
        return Icons.check_circle_rounded;
      case FaceVerificationStatus.alreadyRecorded:
        return Icons.access_time_rounded;
      case FaceVerificationStatus.noFaceDetected:
        return Icons.person_off_rounded;
      case FaceVerificationStatus.multipleFaces:
        return Icons.groups_rounded;
      case FaceVerificationStatus.blurryOrPoorLight:
        return Icons.wb_incandescent_rounded;
      case FaceVerificationStatus.mismatchedFeatures:
      case FaceVerificationStatus.unregisteredFace:
        return Icons.error_outline_rounded;
      case FaceVerificationStatus.livenessFailed:
        return Icons.security_rounded;
      case FaceVerificationStatus.technicalError:
        return Icons.warning_amber_rounded;
    }
  }
}

/// نتيجة عملية فحص وتدقيق وجه الطالب المباشر
class LiveFaceVerification {
  final Rect boundingBox;
  final Student? student;
  final FaceVerificationStatus status;
  final double confidence;
  final double livenessScore;
  final bool isCooldown;
  final String? actionType;
  final AttendanceRecord? attendanceRecord;
  final String customMessage;

  const LiveFaceVerification({
    required this.boundingBox,
    this.student,
    required this.status,
    required this.confidence,
    required this.livenessScore,
    this.isCooldown = false,
    this.actionType,
    this.attendanceRecord,
    this.customMessage = '',
  });

  bool get isSuccess => status == FaceVerificationStatus.recognizedSuccess;
  bool get isRecognized => student != null && confidence >= 0.80;

  String get displayMessage => customMessage.isNotEmpty ? customMessage : status.arabicMessage;
}
