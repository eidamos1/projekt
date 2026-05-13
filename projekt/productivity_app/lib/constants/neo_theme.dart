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

  // Spacing scale
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  // Typography scale — font is inherited from textTheme (Space Grotesk).
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.1,
  );
  static const TextStyle headline = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );
  static const TextStyle subhead = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
  );

  // Aspect ratio for photo proof (uniform task-card layout regardless of
  // the user's actual photo orientation; cover-fit crops to fill).
  static const double photoAspectRatio = 4 / 3;

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
