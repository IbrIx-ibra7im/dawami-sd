import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/constants/api_constants.dart';
import 'package:my_app/data/remote/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseService & Constants Tests', () {
    test('ApiConstants.normalizeSupabaseUrl handles trailing slashes and rest/v1', () {
      expect(
        ApiConstants.normalizeSupabaseUrl('https://xyz.supabase.co/rest/v1/'),
        'https://xyz.supabase.co',
      );
      expect(
        ApiConstants.normalizeSupabaseUrl('https://xyz.supabase.co/'),
        'https://xyz.supabase.co',
      );
      expect(
        ApiConstants.normalizeSupabaseUrl('https://xyz.supabase.co'),
        'https://xyz.supabase.co',
      );
    });

    test('SupabaseService.sqlPermissionFixScript contains required SQL fixes', () {
      final sql = SupabaseService.sqlPermissionFixScript;
      expect(sql, contains('GRANT USAGE ON SCHEMA public TO anon'));
      expect(sql, contains('GRANT ALL ON ALL TABLES IN SCHEMA public'));
      expect(sql, contains('ALTER TABLE IF EXISTS public.dawami_records DISABLE ROW LEVEL SECURITY'));
      expect(sql, contains('CREATE TABLE IF NOT EXISTS public.dawami_records'));
    });

    test('SupabaseTestResult correctly holds permission error properties', () {
      const result = SupabaseTestResult(
        isConnected: false,
        isPermissionDenied: true,
        statusTitle: 'تم رفض الصلاحيات (كود 42501)',
        message: 'تم الاتصال بالخادم، لكن Supabase يرفض الوصول لجداول قاعدة البيانات',
        hint: 'كود SQL',
      );

      expect(result.isConnected, isFalse);
      expect(result.isPermissionDenied, isTrue);
      expect(result.statusTitle, contains('42501'));
      expect(result.hint, equals('كود SQL'));
    });
  });
}
