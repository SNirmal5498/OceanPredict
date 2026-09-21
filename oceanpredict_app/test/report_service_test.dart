import 'package:flutter_test/flutter_test.dart';
import 'package:oceanpredict_app/services/report_service.dart';

void main() {
  group('ReportService Statistical Calculations', () {
    test('computeStats correctly calculates mean, min, max, std, range', () {
      final values = [10.0, 20.0, 30.0, 40.0, 50.0];
      final stats = ReportService.computeStats(values);

      expect(stats['count'], 5);
      expect(stats['avg'], 30.0);
      expect(stats['min'], 10.0);
      expect(stats['max'], 50.0);
      expect(stats['range'], 40.0);
      expect(stats['std'], closeTo(15.81, 0.05));
    });

    test('computeStats handles empty list gracefully', () {
      final stats = ReportService.computeStats([]);
      expect(stats['count'], 0);
      expect(stats['avg'], null);
      expect(stats['min'], null);
      expect(stats['max'], null);
      expect(stats['std'], null);
    });

    test('computeStats handles single element list', () {
      final stats = ReportService.computeStats([25.4]);
      expect(stats['count'], 1);
      expect(stats['avg'], 25.4);
      expect(stats['min'], 25.4);
      expect(stats['max'], 25.4);
      expect(stats['std'], 0.0);
    });
  });
}
