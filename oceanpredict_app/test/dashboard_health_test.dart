import 'package:flutter_test/flutter_test.dart';
import 'package:oceanpredict_app/services/ocean_health_service.dart';

void main() {
  group('OceanHealthService Calculation Tests', () {
    test('Calculates valid Ocean Health score when observations exist', () {
      final result = OceanHealthService.calculate(
        avgTemp: 23.14,
        minTemp: 14.52,
        maxTemp: 31.2,
        avgSalinity: 34.84,
        minSalinity: 34.27,
        maxSalinity: 37.1,
        maxPressure: 1000.0,
        observationCount: 288,
      );

      expect(result.score, greaterThan(0));
      expect(result.score, lessThanOrEqualTo(100));
      expect(result.status, isIn(['Excellent', 'Good', 'Moderate', 'Critical']));
      expect(result.factors['Salinity Balance'], isNotNull);
      expect(result.factors['Temperature Stability'], isNotNull);
    });

    test('Returns No Data status when observationCount is 0', () {
      final result = OceanHealthService.calculate(
        avgTemp: 23.14,
        avgSalinity: 34.84,
        observationCount: 0,
      );

      expect(result.score, 0);
      expect(result.status, 'No Data');
    });

    test('Returns No Data status when temperature or salinity is missing', () {
      final result = OceanHealthService.calculate(
        avgTemp: null,
        avgSalinity: 34.84,
        observationCount: 288,
      );

      expect(result.score, 0);
      expect(result.status, 'No Data');
    });
  });
}
