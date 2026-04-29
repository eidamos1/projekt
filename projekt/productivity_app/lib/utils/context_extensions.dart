import 'package:flutter/material.dart';

extension BuildContextX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  // Returns the user-selected theme color exactly (set on ThemeData.primaryColor
  // in main.dart). colorScheme.primary would return a Material3-tonal variant
  // which desaturates the chosen neon, so we read primaryColor directly.
  Color get primaryColor => Theme.of(this).primaryColor;
}
