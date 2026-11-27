-- ==============================================================================
-- نظام دوامي المطور (DAWAMI University Smart Attendance & Departure System)
-- قاعدة بيانات Supabase الشاملة مع دعم كامل للبيومتركس، الهواتف، الكاميرات، الـ QR
-- متوافقة 100% مع الجدول الموحد الحالي ومع الجداول العلائقية الجديدة
-- ==============================================================================

-- 1. تفعيل امتدادات UUID والتشفير
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 2. المحافظة على الجدول الموحد الأصلي (dawami_records) لضمان عدم انقطاع أي خدمة
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.dawami_records (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    record_type VARCHAR(50) NOT NULL,
    record_key VARCHAR(100) NOT NULL,
    student_number VARCHAR(50),
    full_name VARCHAR(255),
    barcode_id VARCHAR(100),
    record_date DATE DEFAULT CURRENT_DATE,
    record_time TIME DEFAULT CURRENT_TIME,
    method VARCHAR(50),
    status VARCHAR(50) NOT NULL DEFAULT 'نشط',
    sync_status VARCHAR(50) NOT NULL DEFAULT 'مزامنة',
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT dawami_records_pkey PRIMARY KEY (id),
    CONSTRAINT dawami_records_type_key UNIQUE (record_type, record_key)
);

CREATE INDEX IF NOT EXISTS idx_dawami_records_type ON public.dawami_records(record_type);
CREATE INDEX IF NOT EXISTS idx_dawami_records_key ON public.dawami_records(record_key);
CREATE INDEX IF NOT EXISTS idx_dawami_records_student_number ON public.dawami_records(student_number);
CREATE INDEX IF NOT EXISTS idx_dawami_records_barcode_id ON public.dawami_records(barcode_id);
CREATE INDEX IF NOT EXISTS idx_dawami_records_date ON public.dawami_records(record_date);
CREATE INDEX IF NOT EXISTS idx_dawami_records_sync_status ON public.dawami_records(sync_status);

-- ==============================================================================
-- 3. الجداول العلائقية الجديدة المحددة في المواصفات
-- ==============================================================================

-- 3.1 جدول النطاقات الجغرافية للحرم الجامعي (Geofencing Locations)
CREATE TABLE IF NOT EXISTS public.university_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    location_name VARCHAR(150) NOT NULL,
    campus_name VARCHAR(150) DEFAULT 'المقر الرئيسي',
    college VARCHAR(150),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    radius_meters DOUBLE PRECISION NOT NULL DEFAULT 350.0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3.2 جدول طرق تسجيل الحضور والانصراف (Attendance Methods)
CREATE TABLE IF NOT EXISTS public.attendance_methods (
    code VARCHAR(50) PRIMARY KEY,
    name_ar VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    description TEXT,
    is_active BOOLEAN DEFAULT true
);

INSERT INTO public.attendance_methods (code, name_ar, name_en, description)
VALUES 
    ('fingerprint', 'بصمة الإصبع', 'Biometric Fingerprint', 'أجهزة وقارئات البصمة الحيوية'),
    ('face', 'التعرف على الوجه', 'Face Recognition', 'كاميرا الهاتف والكمبيوتر مع كشف الحيوية'),
    ('mobile', 'تطبيق الهاتف مع GPS', 'Mobile GPS Check-in', 'تسجيل الحضور عبر هاتف الطالب المقترن والنطاق الجغرافي'),
    ('barcode_qr', 'الباركود وQR', 'Barcode & Dynamic QR', 'مسح رموز QR الثابتة والديناميكية بكاميرا أو قارئ USB'),
    ('manual', 'تسجيل إداري استثنائي', 'Manual Administrative', 'تسجيل بواسطة المشرف أو مدير النظام مع التوثيق')
ON CONFLICT (code) DO UPDATE SET name_ar = EXCLUDED.name_ar;

-- 3.3 جدول الطلاب (Students Table)
CREATE TABLE IF NOT EXISTS public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    university_id VARCHAR(50) NOT NULL UNIQUE,
    full_name VARCHAR(255) NOT NULL,
    college VARCHAR(150) NOT NULL DEFAULT 'كلية علوم الحاسوب والتنمية البشرية',
    department VARCHAR(150) NOT NULL DEFAULT 'علوم الحاسوب',
    academic_level VARCHAR(50) NOT NULL DEFAULT 'المستوى الأول',
    phone VARCHAR(30) NOT NULL,
    email VARCHAR(150),
    photo_url TEXT,
    qr_code VARCHAR(150) NOT NULL UNIQUE,
    fingerprint_id VARCHAR(100),
    fingerprint_status VARCHAR(50) DEFAULT 'غير مسجلة',
    fingerprint_quality INT DEFAULT 0,
    fingerprint_enrolled_at TIMESTAMPTZ,
    face_registered BOOLEAN DEFAULT false,
    face_enrolled_at TIMESTAMPTZ,
    status VARCHAR(50) NOT NULL DEFAULT 'نشط', -- 'نشط', 'متوقف', 'متخرج'
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_students_university_id ON public.students(university_id);
CREATE INDEX IF NOT EXISTS idx_students_college_dept ON public.students(college, department);
CREATE INDEX IF NOT EXISTS idx_students_qr ON public.students(qr_code);

-- 3.4 جدول أجهزة البصمة (Biometric Devices Table)
CREATE TABLE IF NOT EXISTS public.biometric_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_name VARCHAR(150) NOT NULL,
    serial_number VARCHAR(100) NOT NULL UNIQUE,
    manufacturer VARCHAR(100) NOT NULL DEFAULT 'ZKTeco',
    model VARCHAR(100) NOT NULL DEFAULT 'ZK-F18',
    ip_address VARCHAR(45) NOT NULL,
    port INT NOT NULL DEFAULT 4370,
    protocol VARCHAR(20) DEFAULT 'TCP/IP',
    location_name VARCHAR(150) NOT NULL,
    college VARCHAR(150) DEFAULT 'كلية علوم الحاسوب والتنمية البشرية',
    department VARCHAR(150),
    status VARCHAR(50) NOT NULL DEFAULT 'غير متصل', -- 'متصل', 'غير متصل', 'قيد الاتصال'
    last_ping_at TIMESTAMPTZ,
    last_sync_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3.5 جدول تسجيلات قوالب البصمة (Biometric Enrollments)
CREATE TABLE IF NOT EXISTS public.biometric_enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
    university_id VARCHAR(50) NOT NULL,
    finger_index INT DEFAULT 1,
    template_hash TEXT NOT NULL,
    quality_score INT DEFAULT 90,
    device_model VARCHAR(100),
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_active BOOLEAN NOT NULL DEFAULT true
);

-- 3.6 جدول الهواتف المقترنة بحساب الطالب (Mobile Devices)
CREATE TABLE IF NOT EXISTS public.mobile_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
    university_id VARCHAR(50) NOT NULL,
    device_uuid VARCHAR(150) NOT NULL,
    device_model VARCHAR(100),
    os_name VARCHAR(50),
    os_version VARCHAR(50),
    is_approved BOOLEAN NOT NULL DEFAULT true,
    anti_spoofing_enabled BOOLEAN NOT NULL DEFAULT true,
    bound_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at TIMESTAMPTZ,
    CONSTRAINT unique_student_device UNIQUE (student_id, device_uuid)
);

-- 3.7 جدول أجهزة الكمبيوتر والمحطات (Computer Devices)
CREATE TABLE IF NOT EXISTS public.computer_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    machine_name VARCHAR(150) NOT NULL,
    machine_id VARCHAR(150) NOT NULL UNIQUE,
    ip_address VARCHAR(45),
    location_name VARCHAR(150) NOT NULL,
    college VARCHAR(150) DEFAULT 'كلية علوم الحاسوب والتنمية البشرية',
    department VARCHAR(150),
    camera_enabled BOOLEAN NOT NULL DEFAULT true,
    barcode_reader_enabled BOOLEAN NOT NULL DEFAULT true,
    biometric_reader_enabled BOOLEAN NOT NULL DEFAULT true,
    status VARCHAR(50) DEFAULT 'نشط',
    last_seen_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3.8 جدول ملفات التعرف على الوجه المشفرة (Face Profiles)
CREATE TABLE IF NOT EXISTS public.face_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
    university_id VARCHAR(50) NOT NULL UNIQUE,
    face_embedding JSONB DEFAULT '[]'::jsonb,
    face_embedding_hash TEXT NOT NULL,
    reference_photo_url TEXT,
    quality_score INT DEFAULT 95,
    liveness_verified BOOLEAN NOT NULL DEFAULT true,
    liveness_score NUMERIC(5, 4) DEFAULT 0.9800,
    sample_count INT DEFAULT 3,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_active BOOLEAN NOT NULL DEFAULT true
);

-- 3.8.1 جدول سجلات التعرف على الوجه وفحص الحيوية (Face Recognition Logs)
CREATE TABLE IF NOT EXISTS public.face_recognition_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.students(id) ON DELETE SET NULL,
    university_id VARCHAR(50),
    student_name VARCHAR(255),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    action_type VARCHAR(20) NOT NULL, -- 'حضور', 'انصراف'
    confidence NUMERIC(5, 4) NOT NULL DEFAULT 0.9500,
    liveness_score NUMERIC(5, 4) NOT NULL DEFAULT 0.9800,
    camera_device_id VARCHAR(100) DEFAULT 'FACE-CAM-LIVE',
    is_multi_face BOOLEAN NOT NULL DEFAULT false,
    status VARCHAR(30) NOT NULL DEFAULT 'success',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3.9 جدول ملفات QR والرموز المتغيرة المؤقتة (QR Profiles)
CREATE TABLE IF NOT EXISTS public.qr_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
    university_id VARCHAR(50) NOT NULL UNIQUE,
    qr_secret VARCHAR(100) NOT NULL,
    is_dynamic BOOLEAN NOT NULL DEFAULT true,
    token_interval_seconds INT NOT NULL DEFAULT 30,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3.10 جدول سجلات الحضور والانصراف اليومي للطلاب (Attendance & Departure Records)
CREATE TABLE IF NOT EXISTS public.attendance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
    student_number VARCHAR(50) NOT NULL,
    student_name VARCHAR(255) NOT NULL,
    record_date DATE NOT NULL DEFAULT CURRENT_DATE,
    check_in TIMESTAMPTZ NOT NULL DEFAULT now(),
    check_out TIMESTAMPTZ,
    method VARCHAR(50) NOT NULL, -- 'fingerprint', 'face', 'mobile', 'barcode_qr', 'manual'
    status VARCHAR(50) NOT NULL DEFAULT 'حاضر', -- 'حاضر', 'متأخر', 'غائب', 'منصرف'
    device_id VARCHAR(100),
    device_name VARCHAR(150),
    location_name VARCHAR(150),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    duration_minutes INT DEFAULT 0,
    delay_minutes INT DEFAULT 0,
    is_synced BOOLEAN NOT NULL DEFAULT true,
    sync_status VARCHAR(50) NOT NULL DEFAULT 'مزامنة',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_daily_student_attendance UNIQUE (student_number, record_date)
);

CREATE INDEX IF NOT EXISTS idx_attendance_date ON public.attendance_records(record_date);
CREATE INDEX IF NOT EXISTS idx_attendance_student_number ON public.attendance_records(student_number);
CREATE INDEX IF NOT EXISTS idx_attendance_method ON public.attendance_records(method);
CREATE INDEX IF NOT EXISTS idx_attendance_status ON public.attendance_records(status);

-- 3.11 جدول تعيينات الأجهزة (Device Assignments)
CREATE TABLE IF NOT EXISTS public.device_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID REFERENCES public.biometric_devices(id) ON DELETE CASCADE,
    assigned_location_id UUID REFERENCES public.university_locations(id) ON DELETE SET NULL,
    supervisor_name VARCHAR(150),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3.12 جدول سجل التدقيق الأمني والإداري (Audit Logs)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(100),
    user_name VARCHAR(150) NOT NULL,
    user_role VARCHAR(50) NOT NULL,
    action VARCHAR(100) NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE', 'OVERRIDE', 'ENROLL_BIOMETRIC'
    entity_type VARCHAR(50) NOT NULL, -- 'student', 'attendance', 'biometric_device', 'mobile_device'
    entity_id VARCHAR(100),
    details JSONB DEFAULT '{}'::jsonb,
    ip_address VARCHAR(45),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3.13 جدول سجل المزامنة (Sync Logs)
CREATE TABLE IF NOT EXISTS public.sync_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(50) NOT NULL,
    record_key VARCHAR(100) NOT NULL,
    operation VARCHAR(20) NOT NULL,
    status VARCHAR(50) NOT NULL, -- 'SUCCESS', 'FAILED', 'RETRY'
    error_message TEXT,
    sync_time TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==============================================================================
-- 4. إعداد الصلاحيات والأمان و Row Level Security (RLS)
-- ==============================================================================
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

-- تفعيل RLS مع سياسات مرنة ومحمية للجامعة
ALTER TABLE public.dawami_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biometric_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.biometric_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mobile_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.computer_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.face_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.university_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_logs ENABLE ROW LEVEL SECURITY;

-- سياسات عامة للوصول المقروء والمكتوب عبر مفتاح Supabase مع التحقق
DROP POLICY IF EXISTS "Public Read Students" ON public.students;
CREATE POLICY "Public Read Students" ON public.students FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Allow All Students" ON public.students;
CREATE POLICY "Allow All Students" ON public.students FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow All Attendance" ON public.attendance_records;
CREATE POLICY "Allow All Attendance" ON public.attendance_records FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow All Biometric Devices" ON public.biometric_devices;
CREATE POLICY "Allow All Biometric Devices" ON public.biometric_devices FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow All Enrollments" ON public.biometric_enrollments;
CREATE POLICY "Allow All Enrollments" ON public.biometric_enrollments FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow All Mobile Devices" ON public.mobile_devices;
CREATE POLICY "Allow All Mobile Devices" ON public.mobile_devices FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow All Computer Devices" ON public.computer_devices;
CREATE POLICY "Allow All Computer Devices" ON public.computer_devices FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow All Face Profiles" ON public.face_profiles;
CREATE POLICY "Allow All Face Profiles" ON public.face_profiles FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow All Face Logs" ON public.face_recognition_logs;
CREATE POLICY "Allow All Face Logs" ON public.face_recognition_logs FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow All QR Profiles" ON public.qr_profiles;
CREATE POLICY "Allow All QR Profiles" ON public.qr_profiles FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow All Locations" ON public.university_locations;
CREATE POLICY "Allow All Locations" ON public.university_locations FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow All Methods" ON public.attendance_methods;
CREATE POLICY "Allow All Methods" ON public.attendance_methods FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "Allow All Audit Logs" ON public.audit_logs;
CREATE POLICY "Allow All Audit Logs" ON public.audit_logs FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow All Sync Logs" ON public.sync_logs;
CREATE POLICY "Allow All Sync Logs" ON public.sync_logs FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- ==============================================================================
-- 5. التزامن التلقائي بين الجداول العلائقية وجدول dawami_records الموحد
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.sync_attendance_to_dawami_records()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.dawami_records (
        record_type,
        record_key,
        student_number,
        full_name,
        barcode_id,
        record_date,
        record_time,
        method,
        status,
        sync_status,
        data,
        updated_at
    ) VALUES (
        'attendance',
        NEW.id::text,
        NEW.student_number,
        NEW.student_name,
        NEW.student_number,
        NEW.record_date,
        NEW.check_in::time,
        NEW.method,
        NEW.status,
        'مزامنة',
        row_to_json(NEW)::jsonb,
        now()
    )
    ON CONFLICT (record_type, record_key) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        method = EXCLUDED.method,
        status = EXCLUDED.status,
        data = EXCLUDED.data,
        updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_sync_attendance ON public.attendance_records;
CREATE TRIGGER trigger_sync_attendance
AFTER INSERT OR UPDATE ON public.attendance_records
FOR EACH ROW EXECUTE FUNCTION public.sync_attendance_to_dawami_records();

-- إدخال موقع جامعي افتراضي (Dongola University Campus)
INSERT INTO public.university_locations (location_name, campus_name, college, latitude, longitude, radius_meters)
VALUES ('الحرم الجامعي الرئيسي', 'جامعة دنقلا', 'كلية علوم الحاسوب والتنمية البشرية', 19.1678, 30.4720, 600.0)
ON CONFLICT DO NOTHING;
