import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../utils/context_extensions.dart';

/// Pulsing neo-bordered placeholder. Use during async loads instead of a
/// CircularProgressIndicator so the layout doesn't jump in once data arrives.
class NeoSkeleton extends StatefulWidget {
  final double height;
  final EdgeInsetsGeometry margin;
  final double? width;

  const NeoSkeleton({
    super.key,
    required this.height,
    this.margin = EdgeInsets.zero,
    this.width,
  });

  @override
  State<NeoSkeleton> createState() => _NeoSkeletonState();
}

class _NeoSkeletonState extends State<NeoSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final pulseAlpha = 0.04 + _controller.value * 0.06;
        return Container(
          height: widget.height,
          width: widget.width,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black)
                .withValues(alpha: pulseAlpha),
            borderRadius: BorderRadius.circular(NeoTheme.radiusCard),
            border: Border.all(
              color: isDark ? AppColors.borderSubtle : AppColors.borderBold,
              width: NeoTheme.borderWidthThin,
            ),
          ),
        );
      },
    );
  }
}

/// Convenience: a vertical stack of skeletons sized like task/habit/notif cards.
class NeoSkeletonList extends StatelessWidget {
  final int count;
  final double itemHeight;

  const NeoSkeletonList({
    super.key,
    this.count = 3,
    this.itemHeight = 88,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(NeoTheme.spaceMd),
      itemCount: count,
      itemBuilder: (_, _) => NeoSkeleton(
        height: itemHeight,
        margin: const EdgeInsets.only(bottom: NeoTheme.spaceSm),
      ),
    );
  }
}
