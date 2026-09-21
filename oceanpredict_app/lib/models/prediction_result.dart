class ForecastPoint {
  final int step;
  final int cycle;
  final double predictedValue;

  ForecastPoint({required this.step, required this.cycle, required this.predictedValue});

  factory ForecastPoint.fromJson(Map<String, dynamic> json) => ForecastPoint(
        step: json['step'] as int,
        cycle: json['cycle'] as int,
        predictedValue: (json['predicted_value'] as num).toDouble(),
      );
}

class PredictionMetrics {
  final int trainSamples;
  final int testSamples;
  final double? mae;
  final double? rmse;
  final double? r2;

  PredictionMetrics({
    required this.trainSamples,
    required this.testSamples,
    this.mae,
    this.rmse,
    this.r2,
  });

  factory PredictionMetrics.fromJson(Map<String, dynamic> json) => PredictionMetrics(
        trainSamples: json['train_samples'] as int,
        testSamples: json['test_samples'] as int,
        mae: (json['mae'] as num?)?.toDouble(),
        rmse: (json['rmse'] as num?)?.toDouble(),
        r2: (json['r2'] as num?)?.toDouble(),
      );
}

class HistoricalPoint {
  final int cycle;
  final double value;

  HistoricalPoint({required this.cycle, required this.value});

  factory HistoricalPoint.fromJson(Map<String, dynamic> json) => HistoricalPoint(
        cycle: json['cycle'] as int,
        value: (json['value'] as num).toDouble(),
      );
}

class PredictionResult {
  final String model;
  final String target;
  final String floatId;
  final int horizon;
  final double latestActualValue;
  final List<HistoricalPoint> historicalSeries;
  final List<ForecastPoint> forecast;
  final PredictionMetrics metrics;
  final Map<String, double>? featureImportance;
  final List<String> featuresUsed;

  PredictionResult({
    required this.model,
    required this.target,
    required this.floatId,
    required this.horizon,
    required this.latestActualValue,
    required this.historicalSeries,
    required this.forecast,
    required this.metrics,
    required this.featureImportance,
    required this.featuresUsed,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) => PredictionResult(
        model: json['model'] as String,
        target: json['target'] as String,
        floatId: '${json['float_id']}',
        horizon: json['horizon'] as int,
        latestActualValue: (json['latest_actual_value'] as num).toDouble(),
        historicalSeries: (json['historical_series'] as List? ?? [])
            .map((h) => HistoricalPoint.fromJson(h as Map<String, dynamic>))
            .toList(),
        forecast: (json['forecast'] as List)
            .map((f) => ForecastPoint.fromJson(f as Map<String, dynamic>))
            .toList(),
        metrics: PredictionMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
        featureImportance: json['feature_importance'] == null
            ? null
            : Map<String, double>.from(
                (json['feature_importance'] as Map).map((k, v) => MapEntry('$k', (v as num).toDouble())),
              ),
        featuresUsed: List<String>.from(json['features_used'] ?? []),
      );

  double get expectedChange => forecast.isEmpty ? 0 : (forecast.last.predictedValue - latestActualValue);

  /// Real interpretation computed from the actual expected change and forecast sequence trend — never hardcoded.
  String get trendInterpretation {
    final label = target == 'temperature' ? 'Temperature' : 'Salinity';
    final unit = target == 'temperature' ? '°C' : ' PSU';
    final overallDelta = expectedChange;
    final absOverallDelta = overallDelta.abs();

    String mainMessage;
    bool isOverallIncrease = false;
    bool isOverallDecrease = false;

    if (absOverallDelta < 0.05) {
      mainMessage = '$label is predicted to remain relatively stable';
    } else if (overallDelta > 0) {
      isOverallIncrease = true;
      mainMessage = '$label is predicted to increase by ${absOverallDelta.toStringAsFixed(2)}$unit overall';
    } else {
      isOverallDecrease = true;
      mainMessage = '$label is predicted to decrease by ${absOverallDelta.toStringAsFixed(2)}$unit overall';
    }

    String suffix = '';
    if (forecast.length >= 2) {
      final firstForecast = forecast.first.predictedValue;
      final finalForecast = forecast.last.predictedValue;
      final intraDelta = finalForecast - firstForecast;

      if (isOverallIncrease && intraDelta <= -0.05) {
        suffix = ', with a gradual decline across the forecast cycles.';
      } else if (isOverallDecrease && intraDelta >= 0.05) {
        suffix = ', with a gradual increase across the forecast cycles.';
      } else if (!isOverallIncrease && !isOverallDecrease) {
        if (intraDelta <= -0.05) {
          suffix = ', with a gradual decline across the forecast cycles.';
        } else if (intraDelta >= 0.05) {
          suffix = ', with a gradual increase across the forecast cycles.';
        }
      }
    }

    if (suffix.isEmpty) {
      return '$mainMessage.';
    }
    return '$mainMessage$suffix';
  }
}

/// Session-only prediction history entry (real, generated from actual results).
class PredictionHistoryEntry {
  final PredictionResult result;
  final DateTime generatedAt;

  PredictionHistoryEntry({required this.result, required this.generatedAt});
}
