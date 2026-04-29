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
  bool _hovered = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  void _setHovered(bool v) {
    if (_hovered != v) setState(() => _hovered = v);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null && widget.onLongPress == null;
    // t: -1 = lifted on hover, 0 = at rest, 1 = pressed in
    final double t = _pressed ? 1.0 : (_hovered ? -1.0 : 0.0);
    final hoverScale = _hovered && !_pressed ? 0.5 : 1.0;
    return MouseRegion(
      cursor: disabled ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: disabled ? null : (_) => _setHovered(true),
      onExit: disabled ? null : (_) => _setHovered(false),
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: disabled ? null : (_) => _setPressed(true),
        onTapUp: disabled ? null : (_) => _setPressed(false),
        onTapCancel: disabled ? null : () => _setPressed(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: t * hoverScale),
          duration: widget.duration,
          curve: Curves.easeOut,
          builder: (context, value, child) => Transform.translate(
            offset: widget.pressOffset * value,
            child: child,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
