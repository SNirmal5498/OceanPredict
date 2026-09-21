import 'package:flutter_test/flutter_test.dart';
import 'package:oceanpredict_app/models/prediction_result.dart';

void main() {
  group('PredictionResult trendInterpretation', () {
    test('User exact scenario: overall increase with intra-forecast decline', () {
      final result = PredictionResult(
        model: 'random_forest',
        target: 'temperature',
        floatId: '6903244',
        horizon: 5,
        latestActualValue: 20.61,
        historicalSeries: [],
        forecast: [
          ForecastPoint(step: 1, cycle: 13, predictedValue: 22.34),
          ForecastPoint(step: 2, cycle: 14, predictedValue: 22.22),
          ForecastPoint(step: 3, cycle: 15, predictedValue: 22.10),
          ForecastPoint(step: 4, cycle: 16, predictedValue: 21.97),
          ForecastPoint(step: 5, cycle: 17, predictedValue: 21.85),
        ],
        metrics: PredictionMetrics(trainSamples: 100, testSamples: 20),
        featureImportance: null,
        featuresUsed: [],
      );

      expect(result.expectedChange, closeTo(1.24, 0.001));
      expect(
        result.trendInterpretation,
        'Temperature is predicted to increase by 1.24°C overall, with a gradual decline across the forecast cycles.',
      );
    });

    test('Overall decrease with intra-forecast increase', () {
      final result = PredictionResult(
        model: 'random_forest',
        target: 'temperature',
        floatId: '6903244',
        horizon: 3,
        latestActualValue: 25.00,
        historicalSeries: [],
        forecast: [
          ForecastPoint(step: 1, cycle: 1, predictedValue: 21.00),
          ForecastPoint(step: 2, cycle: 2, predictedValue: 22.00),
          ForecastPoint(step: 3, cycle: 3, predictedValue: 23.00),
        ],
        metrics: PredictionMetrics(trainSamples: 100, testSamples: 20),
        featureImportance: null,
        featuresUsed: [],
      );

      expect(result.expectedChange, closeTo(-2.00, 0.001));
      expect(
        result.trendInterpretation,
        'Temperature is predicted to decrease by 2.00°C overall, with a gradual increase across the forecast cycles.',
      );
    });

    test('Overall increase with intra-forecast increase (same direction)', () {
      final result = PredictionResult(
        model: 'linear_regression',
        target: 'temperature',
        floatId: '6903244',
        horizon: 2,
        latestActualValue: 20.00,
        historicalSeries: [],
        forecast: [
          ForecastPoint(step: 1, cycle: 1, predictedValue: 21.00),
          ForecastPoint(step: 2, cycle: 2, predictedValue: 22.00),
        ],
        metrics: PredictionMetrics(trainSamples: 100, testSamples: 20),
        featureImportance: null,
        featuresUsed: [],
      );

      expect(
        result.trendInterpretation,
        'Temperature is predicted to increase by 2.00°C overall.',
      );
    });

    test('Relatively stable overall change', () {
      final result = PredictionResult(
        model: 'random_forest',
        target: 'temperature',
        floatId: '6903244',
        horizon: 2,
        latestActualValue: 20.00,
        historicalSeries: [],
        forecast: [
          ForecastPoint(step: 1, cycle: 1, predictedValue: 20.01),
          ForecastPoint(step: 2, cycle: 2, predictedValue: 20.02),
        ],
        metrics: PredictionMetrics(trainSamples: 100, testSamples: 20),
        featureImportance: null,
        featuresUsed: [],
      );

      expect(
        result.trendInterpretation,
        'Temperature is predicted to remain relatively stable.',
      );
    });

    test('Salinity target with PSU units', () {
      final result = PredictionResult(
        model: 'random_forest',
        target: 'salinity',
        floatId: '6903244',
        horizon: 2,
        latestActualValue: 35.00,
        historicalSeries: [],
        forecast: [
          ForecastPoint(step: 1, cycle: 1, predictedValue: 36.50),
          ForecastPoint(step: 2, cycle: 2, predictedValue: 36.00),
        ],
        metrics: PredictionMetrics(trainSamples: 100, testSamples: 20),
        featureImportance: null,
        featuresUsed: [],
      );

      expect(
        result.trendInterpretation,
        'Salinity is predicted to increase by 1.00 PSU overall, with a gradual decline across the forecast cycles.',
      );
    });
  });
}
