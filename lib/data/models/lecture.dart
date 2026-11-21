class Lecture {
  final int? id;
  final int courseId;
  final int classroomId;
  final String instructor;
  final String day; // 'الأحد', 'الإثنين', ...
  final String startTime; // '08:00'
  final String endTime; // '10:00'
  final int graceMinutes; // e.g. 15
  final String lateAfter; // '08:15'
  final String closeAt; // '08:30'
  final String? courseName;
  final String? courseCode;
  final String? classroomName;

  Lecture({
    this.id,
    required this.courseId,
    required this.classroomId,
    required this.instructor,
    required this.day,
    required this.startTime,
    required this.endTime,
    this.graceMinutes = 15,
    required this.lateAfter,
    required this.closeAt,
    this.courseName,
    this.courseCode,
    this.classroomName,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'course_id': courseId,
    'classroom_id': classroomId,
    'instructor': instructor,
    'day': day,
    'start_time': startTime,
    'end_time': endTime,
    'grace_minutes': graceMinutes,
    'late_after': lateAfter,
    'close_at': closeAt,
  };

  factory Lecture.fromMap(Map<String, dynamic> map) => Lecture(
    id: map['id'] as int?,
    courseId: (map['course_id'] as num).toInt(),
    classroomId: (map['classroom_id'] as num).toInt(),
    instructor: map['instructor'] as String? ?? '',
    day: map['day'] as String? ?? 'الأحد',
    startTime: map['start_time'] as String? ?? '08:00',
    endTime: map['end_time'] as String? ?? '10:00',
    graceMinutes: (map['grace_minutes'] as num?)?.toInt() ?? 15,
    lateAfter: map['late_after'] as String? ?? '08:15',
    closeAt: map['close_at'] as String? ?? '08:30',
    courseName: map['course_name'] as String?,
    courseCode: map['course_code'] as String?,
    classroomName: map['classroom_name'] as String?,
  );
}

class AttendanceSession {
  final int? id;
  final int lectureId;
  final String sessionDate; // '2026-11-20'
  final String status; // 'نشطة', 'مغلقة'
  final String? lectureName;
  final String? classroomName;
  final String? instructor;

  AttendanceSession({
    this.id,
    required this.lectureId,
    required this.sessionDate,
    this.status = 'نشطة',
    this.lectureName,
    this.classroomName,
    this.instructor,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'lecture_id': lectureId,
    'session_date': sessionDate,
    'status': status,
  };

  factory AttendanceSession.fromMap(Map<String, dynamic> map) => AttendanceSession(
    id: map['id'] as int?,
    lectureId: (map['lecture_id'] as num).toInt(),
    sessionDate: map['session_date'] as String? ?? '',
    status: map['status'] as String? ?? 'نشطة',
    lectureName: map['lecture_name'] as String?,
    classroomName: map['classroom_name'] as String?,
    instructor: map['instructor'] as String?,
  );
}

