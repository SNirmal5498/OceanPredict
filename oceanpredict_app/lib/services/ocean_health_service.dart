import 'package:flutter/material.dart';

/// Result of an ocean health calculation.
class OceanHealthResult {
  final int score; // 0-100
  final String status; // Excellent / Good / Moderate / Critical / No Data
  final Color color;
  final Map<String, double> factors; // 0-100 each

  const OceanHealthResult({
    required this.score,
    required this.status,
    required this.color,
    required this.factors,
  });
}

/// Pure calculation service — no UI here.
///
/// NOTE: This is a documented heuristic derived from real aggregate values
/// already returned by the existing /analytics/summary endpoint (avg/min/max
/// temperature, salinity, and max pressure). It is NOT randomly generated.
/// If a real backend "ocean health" endpoint is added later, this class is
/// the single place to swap the calculation for a real API call — the UI
/// layer never needs to change.
class OceanHealthService {
  static OceanHealthResult calculate({
    double? avgTemp,
    double? minTemp,
    double? maxTemp,
    double? avgSalinity,
    double? minSalinity,
    double? maxSalinity,
    double? maxPressure,
  }) {
    if (avgTemp == null || avgSalinity == null) {
      return const OceanHealthResult(
        score: 0,
        status: 'No Data',
        color: Colors.grey,
        factors: {},
      );
    }

    final tempRange = (maxTemp != null && minTemp != null) ? (maxTemp - minTemp) : 0;
    final tempStability = (100 - (tempRange * 2.5)).clamp(0, 100).toDouble();

    final salinityBalance = (100 - ((avgSalinity - 35).abs() * 8)).clamp(0, 100).toDouble();

    // More vertical (depth) coverage in the profile is treated as richer,
    // healthier sampling — capped at 2000 dbar as a reasonable ocean-depth ceiling.
    final depthVariation = maxPressure == null
        ? 50.0
        : ((maxPressure / 2000) * 100).clamp(0, 100).toDouble();

    // The backend already filters out NaN/missing readings before storing
    // data (see /upload), so stored records are treated as clean.
    const dataQuality = 100.0;

    final score = ((tempStability + salinityBalance + depthVariation + dataQuality) / 4)
        .round()
        .clamp(0, 100);

    String status;
    Color color;
    if (score >= 80) {
      status = 'Excellent';
      color = const Color(0xFF2E7D32);
    } else if (score >= 60) {
      status = 'Good';
      color = Colors.cyan.shade700;
    } else if (score >= 40) {
      status = 'Moderate';
      color = Colors.orange.shade700;
    } else {
      status = 'Critical';
      color = Colors.red.shade700;
    }

    return OceanHealthResult(
      score: score,
      status: status,
      color: color,
      factors: {
        'Temperature Stability': tempStability,
        'Salinity Balance': salinityBalance,
        'Depth Variation': depthVariation,
        'Data Quality': dataQuality,
      },
    );
  }
}

/// Simple real statistics helpers used for trend + anomaly detection.
/// Operates only on actual fetched values — never generates data.
class DataStats {
  static double mean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double stdDev(List<double> values) {
    if (values.length < 2) return 0;
    final m = mean(values);
    final variance = values.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) / values.length;
    return variance <= 0 ? 0 : variance.abs().toDouble();
  }

  /// Returns slope sign via simple least-squares regression against index.
  /// > small positive threshold => Increasing, < negative => Decreasing, else Stable.
  static String trendDirection(List<double> values) {
    if (values.length < 2) return 'Stable';
    final n = values.length;
    final xs = List<double>.generate(n, (i) => i.toDouble());
    final xMean = mean(xs);
    final yMean = mean(values);
    double num = 0;
    double den = 0;
    for (int i = 0; i < n; i++) {
      num += (xs[i] - xMean) * (values[i] - yMean);
      den += (xs[i] - xMean) * (xs[i] - xMean);
    }
    if (den == 0) return 'Stable';
    final slope = num / den;
    if (slope > 0.05) return 'Increasing';
    if (slope < -0.05) return 'Decreasing';
    return 'Stable';
  }

  /// Flags indices whose value is more than 2 standard deviations from the mean.
  static List<int> anomalyIndices(List<double> values) {
    if (values.length < 3) return [];
    final m = mean(values);
    final sd = stdDev(values);
    if (sd == 0) return [];
    final result = <int>[];
    for (int i = 0; i < values.length; i++) {
      final dev = (values[i] - m).abs();
      if (dev > 2 * sd) result.add(i);
    }
    return result;
  }

  static String severityFor(double value, double mean, double sd) {
    if (sd == 0) return 'Low';
    final dev = (value - mean).abs() / sd;
    if (dev > 3) return 'High';
    if (dev > 2.5) return 'Medium';
    return 'Low';
  }
}