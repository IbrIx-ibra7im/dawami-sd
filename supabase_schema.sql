-- ============================================================
-- نظام دوامي (DAWAMI) - تصميم قاعدة بيانات Supabase (PostgreSQL)
-- مواصفات المشروع: 16 جدولاً + سياسات الأمان RLS والفهارس والقيود
-- ============================================================

-- تفعيل امتداد توليد UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. جدول الكليات (colleges)
CREATE TABLE IF NOT EXISTS colleges (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. جدول الأقسام (departments)
CREATE TABLE IF NOT EXISTS departments (
    id SERIAL PRIMARY KEY,
    college_id INT NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. جدول المستويات الدراسية (academic_levels)
CREATE TABLE IF NOT EXISTS academic_levels (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    order_no INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. جدول الفصول الدراسية (semesters)
CREATE TABLE IF NOT EXISTS semesters (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. جدول المقررات (courses)
CREATE TABLE IF NOT EXISTS courses (
    id SERIAL PRIMARY KEY,
    department_id INT NOT NULL REFERENCES departments(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. جدول القاعات (classrooms)
CREATE TABLE IF NOT EXISTS classrooms (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    capacity INT NOT NULL DEFAULT 50,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. جدول المحاضرات (lectures)
CREATE TABLE IF NOT EXISTS lectures (
    id SERIAL PRIMARY KEY,
    course_id INT NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    classroom_id INT NOT NULL REFERENCES classrooms(id) ON DELETE CASCADE,
    instructor VARCHAR(255) NOT NULL,
    day VARCHAR(50) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    grace_minutes INT DEFAULT 15,
    late_after TIME NOT NULL,
    close_at TIME NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. جدول جلسات الحضور (attendance_sessions)
CREATE TABLE IF NOT EXISTS attendance_sessions (
    id SERIAL PRIMARY KEY,
    lecture_id INT NOT NULL REFERENCES lectures(id) ON DELETE CASCADE,
    session_date DATE NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'نشطة',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. جدول الطلاب (students) بمواصفات تطبيق دوامي المحدثة
CREATE TABLE IF NOT EXISTS students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_number VARCHAR(50) UNIQUE NOT NULL,
    university_id VARCHAR(50) UNIQUE, -- متوافق مع الحقل السابق
    full_name VARCHAR(255) NOT NULL,
    college VARCHAR(255) NOT NULL DEFAULT 'كلية علوم الحاسوب والتنمية البشرية',
    department VARCHAR(255) NOT NULL DEFAULT 'علوم الحاسوب',
    academic_level VARCHAR(100) NOT NULL DEFAULT 'المستوى الأول',
    college_id INT REFERENCES colleges(id),
    department_id INT REFERENCES departments(id),
    level_id INT REFERENCES academic_levels(id),
    semester_id INT REFERENCES semesters(id),
    phone VARCHAR(30) NOT NULL,
    email VARCHAR(255),
    photo_url TEXT,
    barcode_id VARCHAR(100) UNIQUE,
    qr_code TEXT, -- متوافق مع الحقل السابق
    fingerprint_id VARCHAR(100),
    fingerprint_registered BOOLEAN NOT NULL DEFAULT FALSE,
    fingerprint_status VARCHAR(50) NOT NULL DEFAULT 'غير مسجلة',
    fingerprint_quality INT,
    fingerprint_enrolled_at TIMESTAMPTZ,
    status VARCHAR(50) NOT NULL DEFAULT 'نشط', -- 'نشط', 'متوقف', 'متخرج'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- فهارس فريدة وسريعة للبحث والتحقق
CREATE INDEX IF NOT EXISTS idx_students_student_number ON students(student_number);
CREATE INDEX IF NOT EXISTS idx_students_barcode_id ON students(barcode_id);
CREATE INDEX IF NOT EXISTS idx_students_fingerprint_id ON students(fingerprint_id);
CREATE INDEX IF NOT EXISTS idx_students_full_name ON students(full_name);

-- 10. جدول الحضور (attendance) - مع منع التكرار Idempotent ومطابقة مواصفات المزامنة
CREATE TABLE IF NOT EXISTS attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_number VARCHAR(50),
    university_id VARCHAR(50), -- متوافق مع الحقل السابق
    student_name VARCHAR(255),
    student_id INT REFERENCES students(id) ON DELETE CASCADE,
    lecture_id INT REFERENCES lectures(id) ON DELETE CASCADE,
    session_id INT REFERENCES attendance_sessions(id) ON DELETE CASCADE,
    attendance_date DATE DEFAULT CURRENT_DATE,
    attendance_time TIME DEFAULT CURRENT_TIME,
    check_in TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    check_out TIMESTAMPTZ,
    method VARCHAR(50) NOT NULL, -- 'fingerprint', 'barcode', 'qr', 'manual'
    status VARCHAR(50) NOT NULL DEFAULT 'حاضر', -- 'حاضر', 'متأخر', 'غائب', 'انصراف'
    sync_status VARCHAR(50) NOT NULL DEFAULT 'مزامنة',
    device_id VARCHAR(100) NOT NULL DEFAULT 'ZK-F18',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_student_session UNIQUE (student_id, session_id)
);

CREATE INDEX IF NOT EXISTS idx_attendance_student_number ON attendance(student_number);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance(attendance_date);
CREATE INDEX IF NOT EXISTS idx_attendance_sync_status ON attendance(sync_status);

-- 11. جدول الملفات الشخصية والمستخدمين (profiles)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'viewer',
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. جدول المسؤولين والصلاحيات (admins)
CREATE TABLE IF NOT EXISTS admins (
    id SERIAL PRIMARY KEY,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    permissions TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 13. جدول الأجهزة (devices)
CREATE TABLE IF NOT EXISTS devices (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    type VARCHAR(100) NOT NULL,
    last_seen TIMESTAMPTZ DEFAULT NOW()
);

-- 14. جدول سجلات المزامنة (sync_logs)
CREATE TABLE IF NOT EXISTS sync_logs (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(100),
    result VARCHAR(50) NOT NULL,
    error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 15. جدول سجل التدقيق والتعديلات (audit_logs)
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    old_data JSONB,
    new_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 16. جدول إعدادات التطبيق (app_settings)
CREATE TABLE IF NOT EXISTS app_settings (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- الفهارس لتحسين الأداء (Indexes)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_students_university_id ON students(university_id);
CREATE INDEX IF NOT EXISTS idx_students_college_id ON students(college_id);
CREATE INDEX IF NOT EXISTS idx_attendance_student_session ON attendance(student_id, session_id);
CREATE INDEX IF NOT EXISTS idx_attendance_check_in ON attendance(check_in);
CREATE INDEX IF NOT EXISTS idx_sessions_lecture_date ON attendance_sessions(lecture_id, session_date);

-- ============================================================
-- سياسات الأمان على مستوى الصفوف (Row Level Security - RLS)
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE lectures ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- سياسة الملفات الشخصية: القراءة للجميع، والتعديل للمستخدم نفسه فقط
CREATE POLICY "Public profiles are readable" ON profiles
    FOR SELECT USING (true);

-- سياسة الحضور والغياب: القراءة للمصادق عليهم، والإضافة لموظفي التسجيل ومسؤولي الحضور
CREATE POLICY "Attendance read authenticated" ON attendance
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Attendance insert authorized" ON attendance
    FOR INSERT TO authenticated WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role IN ('super_admin', 'attendance_officer', 'registration_staff')
        )
    );

CREATE POLICY "Attendance update authorized" ON attendance
    FOR UPDATE TO authenticated USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role IN ('super_admin', 'attendance_officer')
        )
    );

CREATE POLICY "Attendance delete superadmin only" ON attendance
    FOR DELETE TO authenticated USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'super_admin'
        )
    );

