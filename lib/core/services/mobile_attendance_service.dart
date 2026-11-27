import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/local/hive_helper.dart';
import '../../data/models/mobile_device.dart';
import '../../data/models/university_location.dart';
import '../../data/models/student.dart';

class GeofenceVerificationResult {
  final bool isInsidePerimeter;
  final double distanceMeters;
  final UniversityLocation? nearestLocation;
  final bool isMockLocation;
  final bool isClockManipulated;
  final String message;

  const GeofenceVerificationResult({
    required this.isInsidePerimeter,
    required this.distanceMeters,
    this.nearestLocation,
    this.isMockLocation = false,
    this.isClockManipulated = false,
    required this.message,
  });
}

class MobileAttendanceService extends ChangeNotifier {
  static final MobileAttendanceService instance = MobileAttendanceService._init();
  final HiveHelper _hive = HiveHelper.instance;

  MobileAttendanceService._init();

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Meters
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) *
            cos(lat2 * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  Future<GeofenceVerificationResult> verifyStudentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const GeofenceVerificationResult(
        isInsidePerimeter: false,
        distanceMeters: -1,
        message: 'خدمة تحديد الموقع الجغرافي (GPS) غير مفعلة في الهاتف',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const GeofenceVerificationResult(
          isInsidePerimeter: false,
          distanceMeters: -1,
          message: 'تم رفض إذن الوصول إلى الموقع الجغرافي',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return const GeofenceVerificationResult(
        isInsidePerimeter: false,
        distanceMeters: -1,
        message: 'تم حظر إذن الموقع بشكل دائم من إعدادات الهاتف',
      );
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      return GeofenceVerificationResult(
        isInsidePerimeter: false,
        distanceMeters: -1,
        message: 'تعذر تحديد الموقع الجغرافي الحالي بدقة: $e',
      );
    }

    if (position.isMocked) {
      return const GeofenceVerificationResult(
        isInsidePerimeter: false,
        distanceMeters: -1,
        isMockLocation: true,
        message: 'تم اكتشاف تلاعب بالموقع الجغرافي (Fake GPS / Mock Location). تم رفض العملية لحماية النظام.',
      );
    }

    final locations = await _hive.getUniversityLocations();
    if (locations.isEmpty) {
      return const GeofenceVerificationResult(
        isInsidePerimeter: true,
        distanceMeters: 0,
        message: 'تم قبول الموقع (لم يتم تحديد نطاق جغرافي صارم)',
      );
    }

    double minDistance = double.infinity;
    UniversityLocation? closestLoc;

    for (final loc in locations) {
      if (!loc.isActive) continue;
      final dist = calculateDistance(position.latitude, position.longitude, loc.latitude, loc.longitude);
      if (dist < minDistance) {
        minDistance = dist;
        closestLoc = loc;
      }
    }

    if (closestLoc != null && minDistance <= closestLoc.radiusMeters) {
      return GeofenceVerificationResult(
        isInsidePerimeter: true,
        distanceMeters: minDistance,
        nearestLocation: closestLoc,
        message: 'الطالب داخل نطاق الحرم الجامعي (${closestLoc.locationName}) - المسافة: ${minDistance.round()} متر',
      );
    } else {
      final allowed = closestLoc?.radiusMeters.round() ?? 350;
      final actual = minDistance.round();
      return GeofenceVerificationResult(
        isInsidePerimeter: false,
        distanceMeters: minDistance,
        nearestLocation: closestLoc,
        message: 'الطالب خارج النطاق المسموح به للحرم الجامعي (المسافة: $actual متر، المسموح: $allowed متر)',
      );
    }
  }

  Future<void> bindMobileDevice({
    required Student student,
    required String deviceUuid,
    required String deviceModel,
    String osName = 'Android',
    String osVersion = '14',
  }) async {
    final existing = await _hive.getMobileDeviceByStudent(student.universityId);
    if (existing != null && existing.deviceUuid != deviceUuid) {
      throw Exception('هذا الحساب مقترن بهاتف آخر مسبقاً (${existing.deviceModel}). يرجى مراجعة شؤون الطلاب لإلغاء الربط القديم.');
    }

    final device = MobileDevice(
      id: 'MOB-${student.universityId}',
      studentId: student.id?.toString() ?? student.universityId,
      universityId: student.universityId,
      deviceUuid: deviceUuid,
      deviceModel: deviceModel,
      osName: osName,
      osVersion: osVersion,
      isApproved: true,
      boundAt: DateTime.now().toIso8601String(),
    );

    await _hive.saveMobileDevice(device);
    notifyListeners();
  }

  Future<bool> isDeviceAuthorized(String universityId, String deviceUuid) async {
    final device = await _hive.getMobileDeviceByStudent(universityId);
    if (device == null) return true; // First time binding
    return device.deviceUuid == deviceUuid && device.isApproved;
  }
}
