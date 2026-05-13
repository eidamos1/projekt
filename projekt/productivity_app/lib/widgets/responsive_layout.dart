import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../constants/layout.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final Widget? sidebar;

  const ResponsiveLayout({super.key, required this.child, this.sidebar});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Kompaktni = centered narrow content, no sidebar. Rozlozeny = use full
    // width with sidebar when there's room.
    if (themeProvider.isCompactMode) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Layout.maxContentWidth),
          child: child,
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= Layout.wideScreenThreshold;

    if (isWide && sidebar != null) {
      return Row(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Layout.maxContentWidth),
                child: child,
              ),
            ),
          ),
          SizedBox(
            width: Layout.sidebarWidth,
            child: sidebar!,
          ),
        ],
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Layout.maxContentWidth),
        child: child,
      ),
    );
  }
}
