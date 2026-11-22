-- ============================================================
-- نظام دوامي (DAWAMI) - تصميم الجدول الموحد الوحيد لقاعدة البيانات (Single-Table Design)
-- جدول واحد فقط لحفظ كافة البيانات (الطلاب، الحضور، الإعدادات) والمزامنة المباشرة مع Hive
-- ============================================================

-- 1. تفعيل امتداد توليد UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. إنشاء الجدول الموحد الوحيد لكافة بيانات تطبيق دوامي
CREATE TABLE IF NOT EXISTS public.dawami_records (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    record_type VARCHAR(50) NOT NULL,            -- نوع السجل: 'student' أو 'attendance' أو 'setting'
    record_key VARCHAR(100) NOT NULL,           -- المفتاح الفريد (الرقم الجامعي للطالب أو معرّف سجل الحضور)
    student_number VARCHAR(50),                 -- الرقم الجامعي المفهرس للبحث السريع
    full_name VARCHAR(255),                     -- اسم الطالب كاملاً
    barcode_id VARCHAR(100),                    -- معرّف الباركود / QR الخاص بالطالب
    record_date DATE DEFAULT CURRENT_DATE,      -- تاريخ الحضور (YYYY-MM-DD)
    record_time TIME DEFAULT CURRENT_TIME,      -- وقت الحضور (HH:mm)
    method VARCHAR(50),                         -- طريقة التحقق: 'fingerprint' أو 'barcode' أو 'manual'
    status VARCHAR(50) NOT NULL DEFAULT 'نشط',   -- حالة السجل: 'نشط' / 'حاضر' / 'منصرف'
    sync_status VARCHAR(50) NOT NULL DEFAULT 'مزامنة',
    data JSONB NOT NULL DEFAULT '{}'::jsonb,    -- كائن JSON يحتوي على كافة التفاصيل الإضافية للكيان
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT dawami_records_pkey PRIMARY KEY (id),
    CONSTRAINT dawami_records_type_key UNIQUE (record_type, record_key)
);

-- 3. منح الصلاحيات العامة لكافة الأدوار لتمكين المزامنة دون مشاكل
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;

-- 4. إيقاف Row Level Security (RLS) للجدول الموحد لتفادي أخطاء 42501
ALTER TABLE IF EXISTS public.dawami_records DISABLE ROW LEVEL SECURITY;

-- 5. فهارس سريعة للاستعلامات اليومية وعمليات المزامنة
CREATE INDEX IF NOT EXISTS idx_dawami_records_type ON public.dawami_records(record_type);
CREATE INDEX IF NOT EXISTS idx_dawami_records_key ON public.dawami_records(record_key);
CREATE INDEX IF NOT EXISTS idx_dawami_records_student_number ON public.dawami_records(student_number);
CREATE INDEX IF NOT EXISTS idx_dawami_records_barcode_id ON public.dawami_records(barcode_id);
CREATE INDEX IF NOT EXISTS idx_dawami_records_date ON public.dawami_records(record_date);
CREATE INDEX IF NOT EXISTS idx_dawami_records_sync_status ON public.dawami_records(sync_status);
