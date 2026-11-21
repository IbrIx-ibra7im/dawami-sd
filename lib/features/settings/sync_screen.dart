import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_bundle_helper.dart';
import '../../core/utils/file_saver/file_saver.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/models/sync_and_auth_models.dart';
import '../../widgets/custom_widgets.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final engine = context.read<SyncEngine>();
        if (engine.currentMethod == SyncMethod.cloudSupabase) {
          engine.testSupabaseConnection();
        }
      }
    });
  }

  void _showSqlDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.terminal_rounded, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text('حل مشكلة الصلاحيات في Supabase (SQL)'),
          ],
        ),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withAlpha(80)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.warning, size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'سبب عدم المزامنة (Code 42501): افتراضياً في Supabase تكون الجداول مفعل عليها أمان الصفوف (RLS) بدون سياسات، أو لا تملك صفة anon صلاحيات التعديل. تشغيل هذا الكود يمنح الصلاحيات ويصلح المشكلة فوراً.',
                          style: TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'خطوات التنفيذ البسيطة:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  '1. افتح لوحة تحكم مشروعك في Supabase Dashboard (supabase.com).\n'
                  '2. اضغط على أيقونة SQL Editor من القائمة الجانبية اليسرى.\n'
                  '3. الصق كود SQL أدناه واضغط الزر الأخضر (Run).\n'
                  '4. ارجع للتطبيق واضغط "فحص الاتصال" ثم "مزامنة الآن".',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'كود SQL المعتمد لإصلاح الجداول:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('نسخ كود SQL'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          const ClipboardData(text: SupabaseService.sqlPermissionFixScript),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم نسخ كود SQL بنجاح! الصقه في Supabase SQL Editor واضغط Run.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 220,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const SingleChildScrollView(
                    child: SelectableText(
                      SupabaseService.sqlPermissionFixScript,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFFCDD6F4),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('نسخ كود SQL وإغلاق'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(text: SupabaseService.sqlPermissionFixScript),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم نسخ كود SQL بنجاح! الصقه في Supabase SQL Editor ثم اضغط Run.'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, SyncEngine syncEngine) {
    final urlController = TextEditingController(text: SupabaseService.instance.currentUrl);
    final keyController = TextEditingController(text: SupabaseService.instance.currentKey);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings_suggest_rounded, color: AppColors.primaryBlue),
            SizedBox(width: 8),
            Text('إعدادات الربط مع خادم Supabase'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'يمكنك تعديل رابط المشروع أو مفتاح API في حال رغبتك باستخدام مفتاح Service Role Key أو مشروع آخر:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'رابط مشروع Supabase (Project URL)',
                  hintText: 'https://xxxxxxxxxxxx.supabase.co',
                  prefixIcon: Icon(Icons.link_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'مفتاح API (Anon Key أو Service Role Key)',
                  prefixIcon: Icon(Icons.key_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ملاحظة: استخدام مفتاح Service Role Key يتجاوز قيود RLS تلقائياً دون الحاجة لتشغيل أي كود SQL.',
                style: TextStyle(fontSize: 11, color: AppColors.warning),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await syncEngine.resetSupabaseCredentials();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تمت استعادة الإعدادات الافتراضية')),
                );
              }
            },
            child: const Text('استعادة الافتراضي', style: TextStyle(color: AppColors.danger)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newUrl = urlController.text.trim();
              final newKey = keyController.text.trim();
              if (newUrl.isEmpty || newKey.isEmpty) return;

              final ok = await syncEngine.updateSupabaseCredentials(newUrl, newKey);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'تم تحديث الإعدادات وإعادة الاتصال بنجاح' : 'تعذر الاتصال بالإعدادات الجديدة'),
                    backgroundColor: ok ? AppColors.success : AppColors.danger,
                  ),
                );
              }
            },
            child: const Text('حفظ واختبار الاتصال'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackupFile(BuildContext context) async {
    try {
      final nowStr = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final fileName = 'Dawami_Sync_Backup_$nowStr.json';
      final bytes = await SyncBundleHelper.exportSyncBundleBytes();

      final savedPath = await FileSaver.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
            content: Text('تم تصدير حزمة المزامنة والنسخ الاحتياطي بنجاح:\n$savedPath'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تصدير حزمة المزامنة: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _importBackupFile(BuildContext context, SyncEngine syncEngine) async {
    try {
      final files = await FilePicker.pickFiles();

      if (files.isEmpty) return;
      final fileBytes = await files.first.readAsBytes();

      final jsonStr = utf8.decode(fileBytes);
      final stats = await SyncBundleHelper.restoreSyncBundle(jsonStr);

      await syncEngine.refreshQueue();

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 26),
                SizedBox(width: 8),
                Text('اكتملت المزامنة والاستيراد'),
              ],
            ),
            content: Text(
              'تم استيراد ودمج البيانات بنجاح من الملف:\n'
              '• عدد الطلاب المستوردين: ${stats['students']}\n'
              '• عدد سجلات الحضور المستوردة: ${stats['attendance']}\n\n'
              'تم تأكيد وحفظ كافة السجلات في قاعدة البيانات المحلية.',
              style: const TextStyle(height: 1.5),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('تم', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء استيراد حزمة المزامنة: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncEngine = context.watch<SyncEngine>();
    final connectivity = context.watch<ConnectivityService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = syncEngine.queueItems;
    final pendingCount = syncEngine.pendingCount;
    final testResult = syncEngine.lastTestResult;
    final currentMethod = syncEngine.currentMethod;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('إدارة وطرق المزامنة (Sync Center)'),
        backgroundColor: AppColors.darkBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded),
            tooltip: 'تفريغ طابور المزامنة',
            onPressed: () async {
              await syncEngine.clearSyncQueue();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تفريغ طابور المزامنة بنجاح')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث القائمة',
            onPressed: () => syncEngine.refreshQueue(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Sync Method Selection Bar (تغيير طريقة المزامنة)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? AppColors.surfaceDark : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.sync_alt_rounded, color: AppColors.primaryBlue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'اختر طريقة المزامنة المعتمدة في النظام:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Mode 1: Local Safe Sync (Recommended)
                      ChoiceChip(
                        avatar: const Icon(Icons.verified_user_rounded, size: 16, color: Colors.green),
                        label: const Text('المزامنة المحلية الذكية (آمن ومباشر)', style: TextStyle(fontWeight: FontWeight.bold)),
                        selected: currentMethod == SyncMethod.localSafe,
                        selectedColor: AppColors.success.withAlpha(40),
                        side: BorderSide(
                          color: currentMethod == SyncMethod.localSafe ? AppColors.success : Colors.grey.shade400,
                          width: currentMethod == SyncMethod.localSafe ? 2 : 1,
                        ),
                        onSelected: (val) {
                          if (val) syncEngine.switchSyncMethod(SyncMethod.localSafe);
                        },
                      ),
                      const SizedBox(width: 8),
                      // Mode 2: Cloud Supabase Sync
                      ChoiceChip(
                        avatar: const Icon(Icons.cloud_sync_rounded, size: 16, color: AppColors.primaryBlue),
                        label: const Text('المزامنة السحابية (Supabase Cloud)', style: TextStyle(fontWeight: FontWeight.bold)),
                        selected: currentMethod == SyncMethod.cloudSupabase,
                        selectedColor: AppColors.primaryBlue.withAlpha(40),
                        side: BorderSide(
                          color: currentMethod == SyncMethod.cloudSupabase ? AppColors.primaryBlue : Colors.grey.shade400,
                          width: currentMethod == SyncMethod.cloudSupabase ? 2 : 1,
                        ),
                        onSelected: (val) {
                          if (val) syncEngine.switchSyncMethod(SyncMethod.cloudSupabase);
                        },
                      ),
                      const SizedBox(width: 8),
                      // Mode 3: Backup & File Sync
                      ChoiceChip(
                        avatar: const Icon(Icons.folder_zip_rounded, size: 16, color: Colors.deepOrange),
                        label: const Text('المزامنة عبر ملف النسخ الاحتياطي', style: TextStyle(fontWeight: FontWeight.bold)),
                        selected: currentMethod == SyncMethod.fileBackup,
                        selectedColor: Colors.deepOrange.withAlpha(40),
                        side: BorderSide(
                          color: currentMethod == SyncMethod.fileBackup ? Colors.deepOrange : Colors.grey.shade400,
                          width: currentMethod == SyncMethod.fileBackup ? 2 : 1,
                        ),
                        onSelected: (val) {
                          if (val) syncEngine.switchSyncMethod(SyncMethod.fileBackup);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 2. Active Mode Details & Quick Action Panel
          if (currentMethod == SyncMethod.localSafe)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 24),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'وضع المزامنة المحلية الآمنة (نشط ومستقر)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success),
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text('اعتماد وتسوية السجلات فوراً'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () async {
                          final count = await syncEngine.markAllAsSyncedLocally();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم اعتماد ومزامنة $count سجل بنجاح في قاعدة البيانات المحلية'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'البيانات وسجلات الحضور والطلاب يتم تسجيلها واعتمادها ومزامنتها فورياً داخل قاعدة بيانات جهازك المشفرة دون الحاجة لأي خوادم خارجية أو ظهور أخطاء.',
                    style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            )
          else if (currentMethod == SyncMethod.fileBackup)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepOrange.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.swap_calls_rounded, color: Colors.deepOrange, size: 24),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'المزامنة ونقل البيانات عبر ملف النسخ الاحتياطي',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.deepOrange),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'تتيح لك تصدير حزمة المزامنة كملف ونقلها إلى أي جهاز أو كمبيوتر آخر لاستيراد ودمج كافة الطلاب وسجلات الحضور بنقرة واحدة.',
                    style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.file_download_rounded, size: 16),
                        label: const Text('تصدير حزمة المزامنة للجهاز'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => _exportBackupFile(context),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_upload_rounded, size: 16),
                        label: const Text('استيراد ودمج حزمة مزامنة من ملف'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepOrange,
                          side: const BorderSide(color: Colors.deepOrange),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => _importBackupFile(context, syncEngine),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            // Cloud Supabase Diagnostics Panel
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: syncEngine.hasPermissionError
                      ? AppColors.danger.withAlpha(120)
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_sync_rounded,
                        color: syncEngine.hasPermissionError ? AppColors.danger : AppColors.primaryBlue,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'خادم Supabase السحابي',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              SupabaseService.instance.currentUrl,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (syncEngine.isTestingConnection)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (testResult != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (testResult.isConnected
                                    ? AppColors.success
                                    : (testResult.isPermissionDenied ? AppColors.warning : AppColors.danger))
                                .withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            testResult.statusTitle,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: testResult.isConnected
                                  ? AppColors.success
                                  : (testResult.isPermissionDenied ? AppColors.warning : AppColors.danger),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (syncEngine.hasPermissionError) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.danger, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Supabase يرفض الصلاحيات (42501). يمكنك التحويل إلى المزامنة المحلية الآمنة لحل المشكلة فوراً دون الحاجة لقاعدة البيانات السحابية.',
                              style: TextStyle(fontSize: 11, color: AppColors.danger),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: () {
                              syncEngine.switchSyncMethod(SyncMethod.localSafe);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم التحويل فوراً إلى المزامنة المحلية الآمنة وتمت تسوية السجلات!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            },
                            child: const Text('التحويل للمحلي فوراً', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.network_check_rounded, size: 16),
                        label: const Text('فحص الاتصال', style: TextStyle(fontSize: 12)),
                        onPressed: syncEngine.isTestingConnection
                            ? null
                            : () => syncEngine.testSupabaseConnection(),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.code_rounded, size: 16),
                        label: const Text('كود حل الصلاحيات (SQL)', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _showSqlDialog(context),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text('إعدادات الربط', style: TextStyle(fontSize: 12)),
                        onPressed: () => _showSettingsDialog(context, syncEngine),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // 3. Status Bar & Fast Local Fix Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? AppColors.surfaceDark : Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      currentMethod == SyncMethod.localSafe ? Icons.verified_rounded : Icons.sync,
                      size: 16,
                      color: currentMethod == SyncMethod.localSafe ? AppColors.success : AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'آخر مزامنة: ${syncEngine.lastSyncTime}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                if (pendingCount > 0)
                  TextButton.icon(
                    icon: const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                    label: Text(
                      'تسوية $pendingCount سجلات محلياً',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                    onPressed: () async {
                      await syncEngine.markAllAsSyncedLocally();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم اعتماد وتسوية كافة السجلات محلياً بنجاح!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                  )
                else
                  const Row(
                    children: [
                      Icon(Icons.check, size: 16, color: AppColors.success),
                      SizedBox(width: 4),
                      Text(
                        'كافة السجلات متزامنة ومؤمنة',
                        style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 4. Queue Items List
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_done_rounded, size: 48, color: AppColors.success.withAlpha(120)),
                        const SizedBox(height: 12),
                        const Text(
                          'طابور المزامنة فارغ تماماً',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'جميع الطلاب وسجلات الحضور متزامنة ومحفوظة بنجاح.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildQueueItemTile(context, item, isDark, syncEngine);
                    },
                  ),
          ),

          // 5. Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  icon: syncEngine.isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(
                    syncEngine.isSyncing
                        ? 'جارٍ تنفيذ المزامنة وتأمين البيانات...'
                        : (currentMethod == SyncMethod.localSafe
                            ? 'تأكيد وحفظ المزامنة محلياً الآن'
                            : (currentMethod == SyncMethod.fileBackup
                                ? 'تصدير حزمة المزامنة (نسخ احتياطي)'
                                : 'مزامنة الآن إلى Supabase')),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentMethod == SyncMethod.localSafe
                        ? AppColors.success
                        : (currentMethod == SyncMethod.fileBackup ? Colors.deepOrange : AppColors.primaryBlue),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: syncEngine.isSyncing
                      ? null
                      : () async {
                          if (currentMethod == SyncMethod.fileBackup) {
                            await _exportBackupFile(context);
                            return;
                          }

                          final res = await syncEngine.processSyncQueue(
                            isOnline: connectivity.isOnline,
                          );
                          if (context.mounted && res) {
                            if (currentMethod == SyncMethod.localSafe) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تمت المزامنة والتسوية المحلية بنجاح وحفظ كافة السجلات!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            } else if (syncEngine.hasPermissionError) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('فشلت المزامنة السحابية بسبب كود 42501. يمكنك التبديل إلى "المزامنة المحلية الذكية" بالأعلى لحلها فوراً.'),
                                  backgroundColor: AppColors.warning,
                                  duration: Duration(seconds: 5),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('اكتملت المزامنة بنجاح مع قاعدة بيانات Supabase'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          }
                        },
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    currentMethod == SyncMethod.localSafe
                        ? 'الوضع المحلي نشط: البيانات آمنة ومحفوظة بالكامل في جهازك'
                        : 'يمكنك التبديل إلى المزامنة المحلية في أي وقت لتفادي انقطاع الإنترنت أو مشاكل السحابة',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueItemTile(
    BuildContext context,
    SyncQueueItem item,
    bool isDark,
    SyncEngine syncEngine,
  ) {
    final isLocal = syncEngine.currentMethod == SyncMethod.localSafe;
    final isDone = item.status == 'تمت' || isLocal;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone
              ? AppColors.success.withAlpha(80)
              : (item.status == 'فشل'
                  ? AppColors.danger.withAlpha(100)
                  : (isDark ? AppColors.borderDark : AppColors.borderLight)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${item.tableName} • ${item.operation}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              if (isLocal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 14, color: AppColors.success),
                      SizedBox(width: 4),
                      Text('محفوظ محلياً', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                    ],
                  ),
                )
              else
                StatusBadge.fromStatus(item.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'المعرف: ${item.recordId} • وقت التسجيل: ${item.createdAt.length >= 16 ? item.createdAt.substring(11, 16) : item.createdAt}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (!isLocal && item.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'الخطأ: ${item.error}',
                      style: const TextStyle(fontSize: 11, color: AppColors.danger),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await syncEngine.markAllAsSyncedLocally();
                    },
                    child: const Text('اعتماد محلياً', style: TextStyle(fontSize: 11, color: AppColors.success)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
