import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/widgets/xp_bar.dart';

void main() {
  group('XPBar widget', () {
    testWidgets('displays level and XP text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: XPBar(xp: 42, level: 3)),
        ),
      );

      expect(find.text('Úroveň 3 (XP: 42/100)'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows correct progress value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: XPBar(xp: 75, level: 5)),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.75, 0.01));
    });

    testWidgets('shows 0 progress for 0 XP', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: XPBar(xp: 0, level: 1)),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.0);
    });
  });
}
