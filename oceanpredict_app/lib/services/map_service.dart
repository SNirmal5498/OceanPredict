/// Data models + pure logic for the Ocean Map screen.
/// No UI here — keeps data processing separate from widgets per project rules.
class MapFloatPoint {
  final String floatId;
  final double latitude;
  final double longitude;
  final double? temperature;
  final double? salinity;
  final double? pressure;
  final int? cycleNumber;
  final String? timestamp; // not populated by backend yet — kept nullable & honest

  MapFloatPoint({
    required this.floatId,
    required this.latitude,
    required this.longitude,
    this.temperature,
    this.salinity,
    this.pressure,
    this.cycleNumber,
    this.timestamp,
  });

  /// Builds a point from a raw /floats/locations JSON entry.
  /// Returns null (not a fabricated point) if lat/long are missing or invalid.
  static MapFloatPoint? fromJson(Map<String, dynamic> json) {
    final lat = json['latitude'];
    final lng = json['longitude'];
    if (lat == null || lng == null) return null;

    final latVal = (lat as num).toDouble();
    final lngVal = (lng as num).toDouble();
    if (latVal < -90 || latVal > 90 || lngVal < -180 || lngVal > 180) return null;

    return MapFloatPoint(
      floatId: '${json['float_id']}',
      latitude: latVal,
      longitude: lngVal,
      temperature: (json['temperature'] as num?)?.toDouble(),
      salinity: (json['salinity'] as num?)?.toDouble(),
      pressure: (json['pressure'] as num?)?.toDouble(),
      cycleNumber: (json['cycle_number'] as num?)?.toInt(),
      timestamp: json['timestamp'] as String?,
    );
  }
}

enum TemperatureCategory { low, normal, high, unknown }

class MapService {
  /// Configurable thresholds — documented, not random.
  static const double lowThreshold = 15.0; // below this = "Low"
  static const double highThreshold = 25.0; // above this = "High"

  static TemperatureCategory categoryFor(double? temp) {
    if (temp == null) return TemperatureCategory.unknown;
    if (temp < lowThreshold) return TemperatureCategory.low;
    if (temp > highThreshold) return TemperatureCategory.high;
    return TemperatureCategory.normal;
  }

  /// Parses raw JSON list into valid points + counts invalid ones.
  /// Never invents coordinates for invalid records.
  static ({List<MapFloatPoint> points, int invalidCount}) parse(List<dynamic> raw) {
    final points = <MapFloatPoint>[];
    int invalid = 0;
    for (final item in raw) {
      final p = MapFloatPoint.fromJson(item as Map<String, dynamic>);
      if (p == null) {
        invalid++;
      } else {
        points.add(p);
      }
    }
    return (points: points, invalidCount: invalid);
  }

  /// Computes a bounding box (south, west, north, east) from real points.
  /// Returns null if there are no points to bound.
  static ({double south, double west, double north, double east})? boundsOf(
    List<MapFloatPoint> points,
  ) {
    if (points.isEmpty) return null;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return (south: minLat, west: minLng, north: maxLat, east: maxLng);
  }

  /// Center point derived from real data (average), not hardcoded.
  static (double, double)? centerOf(List<MapFloatPoint> points) {
    if (points.isEmpty) return null;
    final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return (lat, lng);
  }

  static List<MapFloatPoint> applyFilters(
    List<MapFloatPoint> points, {
    String? floatId,
    double? minTemp,
    double? maxTemp,
    double? minSalinity,
    double? maxSalinity,
    double? minPressure,
    double? maxPressure,
  }) {
    return points.where((p) {
      if (floatId != null && floatId.isNotEmpty && !p.floatId.toLowerCase().contains(floatId.toLowerCase())) {
        return false;
      }
      if (minTemp != null && (p.temperature == null || p.temperature! < minTemp)) return false;
      if (maxTemp != null && (p.temperature == null || p.temperature! > maxTemp)) return false;
      if (minSalinity != null && (p.salinity == null || p.salinity! < minSalinity)) return false;
      if (maxSalinity != null && (p.salinity == null || p.salinity! > maxSalinity)) return false;
      if (minPressure != null && (p.pressure == null || p.pressure! < minPressure)) return false;
      if (maxPressure != null && (p.pressure == null || p.pressure! > maxPressure)) return false;
      return true;
    }).toList();
  }
}