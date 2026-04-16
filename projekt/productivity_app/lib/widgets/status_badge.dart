import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../utils/context_extensions.dart';

enum StatusType { completed, rejected, pending }

class StatusBadge extends StatelessWidget {
  final StatusType status;
  final String? rejectionReason;
  final VoidCallback? onRetry;
  final bool isProcessing;

  const StatusBadge({
    super.key,
    required this.status,
    this.rejectionReason,
    this.onRetry,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    switch (status) {
      case StatusType.completed:
        return _buildBadge(
          borderColor: AppColors.neonGreen,
          icon: Icons.verified_rounded,
          iconColor: AppColors.neonGreen,
          label: Strings.statusCompleted,
        );

      case StatusType.rejected:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBadge(
              borderColor: AppColors.neonPink,
              icon: Icons.cancel_rounded,
              iconColor: AppColors.neonPink,
              label: Strings.statusRejected,
            ),
            if (rejectionReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Text(
                  '${Strings.reasonPrefix}$rejectionReason',
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondary : Colors.black45,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isProcessing ? null : onRetry,
                icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.neonYellow, size: 18),
                label: const Text(Strings.statusResend,
                    style: TextStyle(
                        color: AppColors.neonYellow,
                        fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: AppColors.neonYellow,
                      width: NeoTheme.borderWidth),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(NeoTheme.radiusButton)),
                ),
              ),
            ),
          ],
        );

      case StatusType.pending:
        return _buildBadge(
          borderColor: AppColors.neonYellow,
          icon: Icons.hourglass_top_rounded,
          iconColor: AppColors.neonYellow,
          label: Strings.statusPending,
        );
    }
  }

  Widget _buildBadge({
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NeoTheme.radiusSmall),
        color: Colors.transparent,
        border: Border.all(
          color: borderColor,
          width: NeoTheme.borderWidthThin,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.2),
            offset: NeoTheme.shadowOffsetSmall,
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  fontSize: 12)),
        ],
      ),
    );
  }
}
