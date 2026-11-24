import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory StatusBadge.fromStatus(String status) {
    switch (status) {
      case 'نشط':
      case 'حاضر':
      case 'تمت':
      case 'متزامن':
        return StatusBadge(
          label: status,
          backgroundColor: AppColors.success.withAlpha(25),
          textColor: AppColors.success,
          icon: Icons.check_circle_rounded,
        );
      case 'انصراف':
      case 'تم الانصراف':
        return StatusBadge(
          label: status,
          backgroundColor: AppColors.primaryBlue.withAlpha(25),
          textColor: AppColors.primaryBlue,
          icon: Icons.logout_rounded,
        );
      case 'متأخر':
      case 'انتظار':
      case 'بانتظار المزامنة':
        return StatusBadge(
          label: status,
          backgroundColor: AppColors.warning.withAlpha(30),
          textColor: AppColors.warning,
          icon: Icons.access_time_filled_rounded,
        );
      case 'غائب':
      case 'متوقف':
      case 'فشل':
      case 'فشل المزامنة':
        return StatusBadge(
          label: status,
          backgroundColor: AppColors.danger.withAlpha(25),
          textColor: AppColors.danger,
          icon: Icons.cancel_rounded,
        );
      case 'متخرج':
        return StatusBadge(
          label: status,
          backgroundColor: AppColors.primaryBlue.withAlpha(25),
          textColor: AppColors.primaryBlue,
          icon: Icons.school_rounded,
        );
      default:
        return StatusBadge(
          label: status,
          backgroundColor: Colors.grey.withAlpha(30),
          textColor: Colors.grey.shade700,
        );
    }
  }

  factory StatusBadge.fromFingerprintStatus(bool hasFingerprint) {
    if (hasFingerprint) {
      return const StatusBadge(
        label: 'مسجلة',
        backgroundColor: Color(0x2210B981),
        textColor: Color(0xFF059669),
        icon: Icons.fingerprint_rounded,
      );
    } else {
      return const StatusBadge(
        label: 'غير مسجلة',
        backgroundColor: Color(0x22F59E0B),
        textColor: Color(0xFFD97706),
        icon: Icons.fingerprint_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

