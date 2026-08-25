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

class PredictionResult {
  final String model;
  final String target;
  final String floatId;
  final int horizon;
  final double latestActualValue;
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

  /// Real interpretation computed from the actual forecast values — never hardcoded.
  String get trendInterpretation {
    if (forecast.length < 2) return 'Not enough forecast points to determine a trend.';
    final delta = forecast.last.predictedValue - forecast.first.predictedValue;
    final label = target == 'temperature' ? 'Temperature' : 'Salinity';
    if (delta.abs() < 0.05) return '$label is predicted to remain relatively stable.';
    if (delta > 0) return '$label is predicted to increase over the selected forecast period.';
    return '$label is predicted to decrease over the selected forecast period.';
  }
}

/// Session-only prediction history entry (real, generated from actual results).
class PredictionHistoryEntry {
  final PredictionResult result;
  final DateTime generatedAt;

  PredictionHistoryEntry({required this.result, required this.generatedAt});
}
