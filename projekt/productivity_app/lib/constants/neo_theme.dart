import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class NeoTheme {
  // Border widths
  static const borderWidth = 2.0;
  static const borderWidthThin = 1.5;

  // Border radii
  static const radiusCard = 8.0;
  static const radiusButton = 6.0;
  static const radiusSmall = 4.0;

  // Hard shadows (no blur)
  static const shadowOffset = Offset(3, 3);
  static const shadowOffsetSmall = Offset(2, 2);

  // Accent bar
  static const accentBarHeight = 6.0;

  static BoxDecoration cardDecoration({
    required bool isDark,
    Color? borderColor,
    Color? shadowColor,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radiusCard),
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      border: Border.all(
        color: borderColor ?? (isDark ? AppColors.borderSubtle : AppColors.borderBold),
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: shadowColor ?? (isDark
              ? Colors.black.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.12)),
          offset: shadowOffset,
          blurRadius: 0,
        ),
      ],
    );
  }

  static BoxDecoration buttonDecoration({
    required Color backgroundColor,
    Color? borderColor,
    Color? shadowColor,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radiusButton),
      color: backgroundColor,
      border: Border.all(
        color: borderColor ?? Colors.white,
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: shadowColor ?? Colors.black.withValues(alpha: 0.3),
          offset: shadowOffsetSmall,
          blurRadius: 0,
        ),
      ],
    );
  }
}
