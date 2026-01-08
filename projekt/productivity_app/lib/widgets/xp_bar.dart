// widgets/xp_bar.dart
import 'package:flutter/material.dart';

class XPBar extends StatelessWidget {
  final int xp;
  final int level;
  XPBar({required this.xp, required this.level});

  @override
  Widget build(BuildContext context) {
    // Předpokládáme 100 XP na level
    int xpForNext = 100;
    double progress = (xp % xpForNext) / xpForNext;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Úroveň $level (XP: $xp/$xpForNext)'),
        SizedBox(height: 4),
        LinearProgressIndicator(value: progress),
      ],
    );
  }
}
