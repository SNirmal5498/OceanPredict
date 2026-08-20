import 'dart:math';
import 'map_service.dart'; // reused, not duplicated — MapFloatPoint comes from here

/// Pure business logic for the Float Tracker screen. No UI here.
class FloatTrackerService {
  /// Sorts observations chronologically using cycle_number, since the
  /// backend does not yet populate a real timestamp field. cycle_number is
  /// real data (increments each time an Argo float surfaces), so it's a
  /// legitimate chronological proxy — never arbitrary insertion order.
  /// Observations with a null cycle_number are pushed to the end.
  static List<MapFloatPoint> sortChronological(List<MapFloatPoint> points) {
    final sorted = List<MapFloatPoint>.from(points);
    sorted.sort((a, b) {
      if (a.cycleNumber == null && b.cycleNumber == null) return 0;
      if (a.cycleNumber == null) return 1;
      if (b.cycleNumber == null) return -1;
      return a.cycleNumber!.compareTo(b.cycleNumber!);
    });
    return sorted;
  }

  /// Haversine distance between two coordinates, in kilometers.
  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180);

  /// Total travel distance across a chronologically-sorted list.
  /// Returns null if fewer than 2 points exist (distance is meaningless).
  static double? totalDistanceKm(List<MapFloatPoint> sortedPoints) {
    if (sortedPoints.length < 2) return null;
    double total = 0;
    for (int i = 0; i < sortedPoints.length - 1; i++) {
      total += _haversineKm(
        sortedPoints[i].latitude,
        sortedPoints[i].longitude,
        sortedPoints[i + 1].latitude,
        sortedPoints[i + 1].longitude,
      );
    }
    return total;
  }

  /// Journey duration in days, if real timestamps exist on both ends.
  /// Currently always returns null since the backend doesn't populate
  /// FloatData.timestamp — written generically so it activates automatically
  /// once real timestamps are added, with no UI changes required.
  static int? journeyDurationDays(List<MapFloatPoint> sortedPoints) {
    if (sortedPoints.length < 2) return null;
    final first = sortedPoints.first.timestamp;
    final last = sortedPoints.last.timestamp;
    if (first == null || last == null) return null;
    try {
      final d1 = DateTime.parse(first);
      final d2 = DateTime.parse(last);
      return d2.difference(d1).inDays.abs();
    } catch (_) {
      return null;
    }
  }

  static double? average(List<double?> values) {
    final valid = values.whereType<double>().toList();
    if (valid.isEmpty) return null;
    return valid.reduce((a, b) => a + b) / valid.length;
  }

  static double? maxOf(List<double?> values) {
    final valid = values.whereType<double>().toList();
    if (valid.isEmpty) return null;
    return valid.reduce((a, b) => a > b ? a : b);
  }

  static int uniqueCycleCount(List<MapFloatPoint> points) {
    return points.map((p) => p.cycleNumber).whereType<int>().toSet().length;
  }
}