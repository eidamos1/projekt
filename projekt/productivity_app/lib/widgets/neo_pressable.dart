import 'package:flutter/material.dart';
import '../constants/neo_theme.dart';

/// Pressable wrapper that translates the child by [pressOffset] while held,
/// giving a "presses into its own shadow" feel that fits the neobrutalism style.
/// Layout is unchanged (uses Transform.translate). Place inside a Container
/// that owns the shadow; the child moves to cover the shadow on press.
class NeoPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Offset pressOffset;
  final Duration duration;
  final HitTestBehavior behavior;

  const NeoPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressOffset = NeoTheme.shadowOffsetSmall,
    this.duration = const Duration(milliseconds: 120),
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<NeoPressable> createState() => _NeoPressableState();
}

class _NeoPressableState extends State<NeoPressable> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null && widget.onLongPress == null;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: disabled ? null : (_) => _set(true),
      onTapUp: disabled ? null : (_) => _set(false),
      onTapCancel: disabled ? null : () => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _pressed ? 1.0 : 0.0),
        duration: widget.duration,
        curve: Curves.easeOut,
        builder: (context, t, child) => Transform.translate(
          offset: widget.pressOffset * t,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
