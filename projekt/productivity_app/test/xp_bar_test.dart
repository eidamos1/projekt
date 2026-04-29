import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/widgets/xp_bar.dart';

void main() {
  group('XPBar widget', () {
    testWidgets('renders level and XP text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: XPBar(xp: 42, level: 3)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('LEVEL'), findsOneWidget);
      expect(find.text('42 / 100 XP'), findsOneWidget);
    });

    testWidgets('animated bar settles to correct widthFactor', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: XPBar(xp: 75, level: 5)),
        ),
      );
      await tester.pumpAndSettle();

      final box = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(box.widthFactor, closeTo(0.75, 0.001));
    });

    testWidgets('clamps to floor 0.02 for 0 XP', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: XPBar(xp: 0, level: 1)),
        ),
      );
      await tester.pumpAndSettle();

      final box = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(box.widthFactor, closeTo(0.02, 0.001));
    });

    testWidgets('animates from 0 to target on first build', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: XPBar(xp: 50, level: 2)),
        ),
      );
      // Mid-animation: widthFactor should be between 0 and 0.5.
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(mid.widthFactor, lessThan(0.5));
      expect(mid.widthFactor, greaterThan(0.0));

      await tester.pumpAndSettle();
      final settled = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(settled.widthFactor, closeTo(0.5, 0.001));
    });
  });
}
