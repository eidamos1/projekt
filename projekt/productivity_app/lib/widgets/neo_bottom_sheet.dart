import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../utils/context_extensions.dart';

/// Shows a modal bottom sheet in the neobrutalism style — bordered top,
/// drag handle, shape-matched to the rest of the app.
///
/// Caller supplies `children` to render inside a SafeArea + Column.
Future<T?> showNeoBottomSheet<T>({
  required BuildContext context,
  required List<Widget> children,
}) {
  final isDark = context.isDark;
  return showModalBottomSheet<T>(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(
          top: Radius.circular(NeoTheme.radiusCard)),
      side: BorderSide(
        color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
        width: NeoTheme.borderWidth,
      ),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.borderSubtle : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ...children,
        ],
      ),
    ),
  );
}
