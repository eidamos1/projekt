import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_app/widgets/year_heatmap.dart';

void main() {
  group('YearHeatmap.intensityBucket', () {
    test('returns 0 for count 0', () {
      expect(YearHeatmap.intensityBucket(0), 0);
    });

    test('returns count for 1..3', () {
      expect(YearHeatmap.intensityBucket(1), 1);
      expect(YearHeatmap.intensityBucket(2), 2);
      expect(YearHeatmap.intensityBucket(3), 3);
    });

    test('returns 4 for 4+', () {
      expect(YearHeatmap.intensityBucket(4), 4);
      expect(YearHeatmap.intensityBucket(10), 4);
      expect(YearHeatmap.intensityBucket(100), 4);
    });
  });
}
