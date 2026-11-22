import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/services/sync_service.dart';

/// بطاقة وشريط حالة المزامنة والإنترنت (SyncStatusCard)
/// يعرض:
/// 1. حالة الإنترنت (متصل / غير متصل - أوفلاين).
/// 2. حالة المزامنة (تمت المزامنة / جاري المزامنة / بانتظار المزامنة / فشل المزامنة).
/// 3. عدد سجلات الحضور التي تنتظر المزامنة في Hive.
/// 4. إظهار آخر وقت تمت فيه المزامنة بدقة.
/// 5. زر "مزامنة الآن" لتنفيذ المزامنة اليدوية وإظهار إشعار فوري بالنتيجة.
class SyncStatusCard extends StatelessWidget {
  final bool compact;
  final EdgeInsetsGeometry? margin;

  const SyncStatusCard({
    super.key,
    this.compact = false,
    this.margin,
  });

  Future<void> _handleSyncNow(BuildContext context, SyncService syncService) async {
    final success = await syncService.syncNow();
    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('تمت مزامنة جميع السجلات المحلية بنجاح مع Supabase!'),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      final msg = syncService.lastError ?? 'تعذر الاتصال بـ Supabase حالياً، السجلات محفوظة محلياً بأمان';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<SyncService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = syncService.isOnline;
    final isSyncing = syncService.isSyncing;
    final pendingCount = syncService.pendingRecordsCount;

    Color syncBadgeColor;
    IconData syncIcon;
    if (isSyncing) {
      syncBadgeColor = AppColors.primaryBlue;
      syncIcon = Icons.sync_rounded;
    } else if (syncService.status == SyncStatus.failed) {
      syncBadgeColor = AppColors.danger;
      syncIcon = Icons.sync_problem_rounded;
    } else if (pendingCount > 0) {
      syncBadgeColor = Colors.orange;
      syncIcon = Icons.schedule_rounded;
    } else {
      syncBadgeColor = AppColors.success;
      syncIcon = Icons.cloud_done_rounded;
    }

    if (compact) {
      return Container(
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOnline ? AppColors.success.withAlpha(50) : Colors.orange.withAlpha(80),
          ),
        ),
        child: Row(
          children: [
            // مؤشر الإنترنت
            Icon(
              isOnline ? Icons.wifi : Icons.wifi_off_rounded,
              size: 16,
              color: isOnline ? AppColors.success : Colors.orange,
            ),
            const SizedBox(width: 6),
            Text(
              isOnline ? 'متصل' : 'أوفلاين',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isOnline ? AppColors.success : Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 16, color: Colors.grey.withAlpha(50)),
            const SizedBox(width: 12),
            // حالة المزامنة
            Icon(syncIcon, size: 16, color: syncBadgeColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                syncService.syncStatusText,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: syncBadgeColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (pendingCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$pendingCount بالانتظار',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // زر مزامنة الآن
            InkWell(
              onTap: isSyncing ? null : () => _handleSyncNow(context, syncService),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSyncing)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                      )
                    else
                      const Icon(Icons.sync_rounded, size: 14, color: AppColors.primaryBlue),
                    const SizedBox(width: 4),
                    const Text(
                      'مزامنة الآن',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: margin ?? const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline ? AppColors.primaryBlue.withAlpha(40) : Colors.orange.withAlpha(60),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: العنوان والاتصال
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.cloud_sync_rounded, color: AppColors.primaryBlue, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'حالة المزامنة والاتصال السحابي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              // رقاقة حالة الإنترنت
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline ? AppColors.success.withAlpha(20) : Colors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isOnline ? AppColors.success : Colors.orange),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOnline ? Icons.wifi : Icons.wifi_off_rounded,
                      size: 14,
                      color: isOnline ? AppColors.success : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'الإنترنت: متصل' : 'الإنترنت: غير متصل (أوفلاين)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isOnline ? AppColors.success : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // تفاصيل المزامنة
          Row(
            children: [
              // حالة المزامنة
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('حالة المزامنة:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(syncIcon, size: 16, color: syncBadgeColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            syncService.syncStatusText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: syncBadgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // السجلات التي تنتظر المزامنة
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('بانتظار الرفع إلى Supabase:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      '$pendingCount سجل حضور محلي',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: pendingCount > 0 ? Colors.orange : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // آخر وقت مزامنة وزر المزامنة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'آخر مزامنة: ${syncService.formattedLastSyncTime}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              ElevatedButton.icon(
                icon: isSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(isSyncing ? 'جاري المزامنة...' : 'مزامنة الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSyncing ? null : () => _handleSyncNow(context, syncService),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
