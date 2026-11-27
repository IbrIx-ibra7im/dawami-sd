class UniversityLocation {
  final String id;
  final String locationName;
  final String campusName;
  final String college;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isActive;

  const UniversityLocation({
    required this.id,
    required this.locationName,
    this.campusName = 'المقر الرئيسي',
    this.college = 'كلية علوم الحاسوب والتنمية البشرية',
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 350.0,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'location_name': locationName,
      'campus_name': campusName,
      'college': college,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory UniversityLocation.fromMap(Map<dynamic, dynamic> map) {
    return UniversityLocation(
      id: map['id']?.toString() ?? '',
      locationName: map['location_name']?.toString() ?? 'الحرم الجامعي',
      campusName: map['campus_name']?.toString() ?? 'المقر الرئيسي',
      college: map['college']?.toString() ?? 'كلية علوم الحاسوب والتنمية البشرية',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 19.1678,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 30.4720,
      radiusMeters: (map['radius_meters'] as num?)?.toDouble() ?? 350.0,
      isActive: (map['is_active'] == 1 || map['is_active'] == true),
    );
  }
}
