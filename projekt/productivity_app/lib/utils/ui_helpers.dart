import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';

void showErrorSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.neonPink,
      behavior: SnackBarBehavior.fixed,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
        side: const BorderSide(color: Colors.white, width: NeoTheme.borderWidthThin),
      ),
    ),
  );
}

void showSuccessSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.neonGreen,
      behavior: SnackBarBehavior.fixed,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
        side: const BorderSide(color: Colors.white, width: NeoTheme.borderWidthThin),
      ),
    ),
  );
}

void showInfoSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.neonCyan,
      behavior: SnackBarBehavior.fixed,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeoTheme.radiusButton),
        side: const BorderSide(color: Colors.white, width: NeoTheme.borderWidthThin),
      ),
    ),
  );
}
