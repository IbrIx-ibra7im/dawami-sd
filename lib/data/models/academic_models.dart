class College {
  final int id;
  final String name;
  final String createdAt;

  College({required this.id, required this.name, required this.createdAt});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'created_at': createdAt};

  factory College.fromMap(Map<String, dynamic> map) => College(
    id: map['id'] as int,
    name: map['name'] as String,
    createdAt: map['created_at'] as String? ?? '',
  );
}

class Department {
  final int id;
  final int collegeId;
  final String name;

  Department({required this.id, required this.collegeId, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'college_id': collegeId, 'name': name};

  factory Department.fromMap(Map<String, dynamic> map) => Department(
    id: map['id'] as int,
    collegeId: (map['college_id'] as num).toInt(),
    name: map['name'] as String,
  );
}

class AcademicLevel {
  final int id;
  final String name;
  final int orderNo;

  AcademicLevel({required this.id, required this.name, required this.orderNo});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'order_no': orderNo};

  factory AcademicLevel.fromMap(Map<String, dynamic> map) => AcademicLevel(
    id: map['id'] as int,
    name: map['name'] as String,
    orderNo: (map['order_no'] as num).toInt(),
  );
}

class Semester {
  final int id;
  final String name;
  final String startDate;
  final String endDate;

  Semester({required this.id, required this.name, required this.startDate, required this.endDate});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'start_date': startDate,
    'end_date': endDate,
  };

  factory Semester.fromMap(Map<String, dynamic> map) => Semester(
    id: map['id'] as int,
    name: map['name'] as String,
    startDate: map['start_date'] as String? ?? '',
    endDate: map['end_date'] as String? ?? '',
  );
}

class Course {
  final int id;
  final int departmentId;
  final String name;
  final String code;

  Course({required this.id, required this.departmentId, required this.name, required this.code});

  Map<String, dynamic> toMap() => {
    'id': id,
    'department_id': departmentId,
    'name': name,
    'code': code,
  };

  factory Course.fromMap(Map<String, dynamic> map) => Course(
    id: map['id'] as int,
    departmentId: (map['department_id'] as num).toInt(),
    name: map['name'] as String,
    code: map['code'] as String,
  );
}

class Classroom {
  final int id;
  final String name;
  final int capacity;

  Classroom({required this.id, required this.name, required this.capacity});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'capacity': capacity};

  factory Classroom.fromMap(Map<String, dynamic> map) => Classroom(
    id: map['id'] as int,
    name: map['name'] as String,
    capacity: (map['capacity'] as num).toInt(),
  );
}

