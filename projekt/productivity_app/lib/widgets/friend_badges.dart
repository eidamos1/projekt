import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/context_extensions.dart';

/// Small circular level badge — 18x18, just the number, primary-tint border
/// once the user has hit level 5, otherwise muted. Used next to friend
/// nicknames in /profile and the /stats leaderboard widget.
class LevelBadge extends StatelessWidget {
  final int level;
  final double size;
  const LevelBadge({super.key, required this.level, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final isHigh = level >= 5;
    final color = isHigh ? context.primaryColor : AppColors.textSecondary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        '$level',
        style: TextStyle(
          fontSize: size * 0.55,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Pulses Icons.local_fire_department once every ~1.1s when [streak] >= 7
/// (Curves.easeInOut, scale 1.0 -> 1.18 -> 1.0). For shorter streaks the
/// icon is rendered statically. One AnimationController per visible row;
/// fine up to a few dozen rows, which is the realistic worst case here.
class StreakFlame extends StatefulWidget {
  final int streak;
  final double size;
  const StreakFlame({super.key, required this.streak, this.size = 12});

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (widget.streak >= 7) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(StreakFlame old) {
    super.didUpdateWidget(old);
    final shouldRun = widget.streak >= 7;
    if (shouldRun && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!shouldRun && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, _) {
        final scale = 1.0 + 0.18 * _curve.value;
        return Transform.scale(
          scale: scale,
          child: Icon(
            Icons.local_fire_department,
            size: widget.size,
            color: AppColors.neonPink,
          ),
        );
      },
    );
  }
}
