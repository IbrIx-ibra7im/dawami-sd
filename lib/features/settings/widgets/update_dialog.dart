import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/update_service.dart';
import '../../../data/models/update_info.dart';

/// نافذة منبثقة تفاعلية باللغة العربية لعرض تفاصيل التحديث الجديد وتنزيله
class UpdateDialog extends StatelessWidget {
  final String currentVersion;
  final AppReleaseInfo releaseInfo;

  const UpdateDialog({
    super.key,
    required this.currentVersion,
    required this.releaseInfo,
  });

  /// عرض النافذة المنبثقة بسهولة من أي مكان
  static Future<void> show(
    BuildContext context, {
    required String currentVersion,
    required AppReleaseInfo releaseInfo,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => UpdateDialog(
        currentVersion: currentVersion,
        releaseInfo: releaseInfo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 650),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue,
                    AppColors.turquoise.withAlpha(220),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🚀 إصدار جديد متوفر!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          releaseInfo.name.isNotEmpty ? releaseInfo.name : 'تحديث جديد لتطبيق دوامي',
                          style: TextStyle(
                            color: Colors.white.withAlpha(220),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 2. Version Comparison Badge
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'الإصدار الحالي',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            currentVersion,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: AppColors.primaryBlue),
                    Column(
                      children: [
                        const Text(
                          'الإصدار الجديد',
                          style: TextStyle(fontSize: 11, color: AppColors.success),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.success.withAlpha(80)),
                          ),
                          child: Text(
                            releaseInfo.cleanVersion,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 3. Release Notes / Changelog
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notes_rounded, size: 16, color: AppColors.primaryBlue),
                      SizedBox(width: 6),
                      Text(
                        'ما الجديد في هذا الإصدار:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 180),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : AppColors.lightBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        releaseInfo.body.isNotEmpty
                            ? releaseInfo.body
                            : 'يتضمن هذا الإصدار تحسينات برمجية وإصلاحات لزيادة سرعة وكفاءة تسجيل الحضور بالبصمة والباركود.',
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                  ),
                  // Assets Available Badges
                  if (releaseInfo.hasExe || releaseInfo.hasApk)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (releaseInfo.hasExe)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primaryBlue.withAlpha(80)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.desktop_windows_rounded, size: 15, color: AppColors.primaryBlue),
                                  const SizedBox(width: 5),
                                  Text(
                                    'مثبت ويندوز (.exe): ${releaseInfo.exeSizeFormatted.isNotEmpty ? releaseInfo.exeSizeFormatted : "متوفر"}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                                  ),
                                ],
                              ),
                            ),
                          if (releaseInfo.hasApk)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.success.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.success.withAlpha(80)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.android_rounded, size: 15, color: AppColors.success),
                                  const SizedBox(width: 5),
                                  Text(
                                    'تطبيق أندرويد (.apk): ${releaseInfo.apkSizeFormatted.isNotEmpty ? releaseInfo.apkSizeFormatted : "متوفر"}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 10),

                  // Download Link Card
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      UpdateService.instance.openUpdateUrl(releaseInfo.htmlUrl);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link_rounded, size: 16, color: AppColors.primaryBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              releaseInfo.htmlUrl,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryBlue,
                                decoration: TextDecoration.underline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.primaryBlue),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // 4. Action Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('لاحقاً', style: TextStyle(color: Colors.grey)),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text(
                      'الانتقال إلى موقع التحميل',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await UpdateService.instance.openUpdateUrl(releaseInfo.htmlUrl);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
