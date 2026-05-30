import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/utils/nickname_search.dart';

void main() {
  group('nicknameSearchKey', () {
    test('trims and lowercases', () {
      expect(nicknameSearchKey('  Adam Bažant  '), 'adam bažant');
    });

    test('is idempotent — applying twice equals applying once', () {
      final once = nicknameSearchKey('TralaLA');
      expect(nicknameSearchKey(once), once);
    });
  });

  group('nicknamePrefixUpperBound', () {
    test('is strictly greater than the key (range is non-empty)', () {
      // Guards the core invariant: if the bound ever collapsed to the key
      // itself, the range `>= key && < key` would be empty and every nickname
      // search would silently return nothing.
      const key = 'adam';
      final bound = nicknamePrefixUpperBound(key);
      expect(bound.compareTo(key) > 0, isTrue,
          reason: 'upper bound must exceed key or the prefix range is empty');
    });

    test('captures every string that starts with the prefix', () {
      const key = 'adam';
      final bound = nicknamePrefixUpperBound(key);
      for (final hit in ['adam', 'adam bažant', 'adamx']) {
        final inRange = key.compareTo(hit) <= 0 && hit.compareTo(bound) < 0;
        expect(inRange, isTrue, reason: '"$hit" should fall in [key, bound)');
      }
    });

    test('excludes strings that do not share the prefix', () {
      const key = 'adam';
      final bound = nicknamePrefixUpperBound(key);
      for (final miss in ['acab', 'beta', 'ad']) {
        final inRange = key.compareTo(miss) <= 0 && miss.compareTo(bound) < 0;
        expect(inRange, isFalse, reason: '"$miss" should be outside [key, bound)');
      }
    });
  });
}
