import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/utils/invite_code.dart';

void main() {
  group('generateInviteCode', () {
    test('returns a string of length 8', () {
      for (var i = 0; i < 20; i++) {
        expect(generateInviteCode().length, 8);
      }
    });

    test('only contains characters from the allowed charset', () {
      // Allowed: A-Z without I, L, O; digits 2-9 (no 0, no 1)
      final allowed = RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]+$');
      for (var i = 0; i < 100; i++) {
        final code = generateInviteCode();
        expect(allowed.hasMatch(code), isTrue, reason: 'code "$code" contains disallowed chars');
      }
    });

    test('never contains ambiguous chars (0, O, 1, I, L)', () {
      final ambiguous = RegExp(r'[0O1IL]');
      for (var i = 0; i < 200; i++) {
        final code = generateInviteCode();
        expect(ambiguous.hasMatch(code), isFalse, reason: 'code "$code" contains ambiguous char');
      }
    });

    test('100 generated codes have at least 95 unique values', () {
      final codes = <String>{};
      for (var i = 0; i < 100; i++) {
        codes.add(generateInviteCode());
      }
      expect(codes.length, greaterThanOrEqualTo(95));
    });
  });
}
