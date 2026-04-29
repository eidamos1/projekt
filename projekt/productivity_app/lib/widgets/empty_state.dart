import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../utils/context_extensions.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accentColor = context.primaryColor;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NeoTheme.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
                border: Border.all(
                  color: accentColor,
                  width: NeoTheme.borderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.25),
                    offset: NeoTheme.shadowOffset,
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Icon(icon, size: 40, color: accentColor),
            ),
            const SizedBox(height: NeoTheme.spaceLg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: NeoTheme.headline.copyWith(
                fontSize: 20,
                color: isDark ? AppColors.textPrimary : Colors.black87,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: NeoTheme.spaceXs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: NeoTheme.body.copyWith(
                  color:
                      isDark ? AppColors.textSecondary : Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
