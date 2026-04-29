import 'package:flutter/material.dart';

extension BuildContextX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  // Exact user-selected theme color. main.dart pins this via copyWith on
  // ColorScheme.fromSeed so the value matches the seed (no Material 3 tonal
  // desaturation of the neon).
  Color get primaryColor => Theme.of(this).colorScheme.primary;
}
