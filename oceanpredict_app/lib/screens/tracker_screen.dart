import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../services/map_service.dart'; // reused — MapFloatPoint, not duplicated
import '../services/float_tracker_service.dart';
import 'upload_screen.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

enum _LoadState { loading, error, empty, ready }

class _TrackerScreenState extends State<TrackerScreen> {
  _LoadState _state = _LoadState.loading;

  List<String> _floatIds = [];
  String? _selectedFloatId;

  List<MapFloatPoint> _sortedPoints = [];
  int _selectedIndex = 0;

  bool _isPlaying = false;
  Timer? _playTimer;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadFloatIds();
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFloatIds() async {
    setState(() => _state = _LoadState.loading);

    final result = await ApiService.getFloatIds();
    if (!mounted) return;

    if (result['statusCode'] != 200) {
      setState(() => _state = _LoadState.error);
      return;
    }

    final ids = List<String>.from(result['body']['float_ids']);
    if (ids.isEmpty) {
      setState(() => _state = _LoadState.empty);
      return;
    }

    setState(() {
      _floatIds = ids;
      _selectedFloatId = ids.first;
    });
    await _loadHistory(ids.first);
  }

  Future<void> _loadHistory(String floatId) async {
    _stopPlaying();
    setState(() => _state = _LoadState.loading);

    final result = await ApiService.getFloatHistory(floatId);
    if (!mounted) return;

    if (result['statusCode'] != 200) {
      setState(() => _state = _LoadState.error);
      return;
    }

    final history = result['body']['history'] as List<dynamic>;
    final points = history
        .where((h) => h['latitude'] != null && h['longitude'] != null)
        .map((h) => MapFloatPoint(
              floatId: floatId,
              latitude: (h['latitude'] as num).toDouble(),
              longitude: (h['longitude'] as num).toDouble(),
              temperature: (h['temperature'] as num?)?.toDouble(),
              salinity: (h['salinity'] as num?)?.toDouble(),
              pressure: (h['pressure'] as num?)?.toDouble(),
              cycleNumber: (h['cycle_number'] as num?)?.toInt(),
              timestamp: h['timestamp'] as String?,
            ))
        .toList();

    final sorted = FloatTrackerService.sortChronological(points);

    setState(() {
      _sortedPoints = sorted;
      _selectedIndex = sorted.isEmpty ? 0 : sorted.length - 1;
      _state = _LoadState.ready;
    });
  }

  void _onFloatChanged(String? id) {
    if (id == null) return;
    setState(() => _selectedFloatId = id);
    _loadHistory(id);
  }

  void _selectIndex(int i) {
    _stopPlaying();
    setState(() => _selectedIndex = i);
    final p = _sortedPoints[i];
    try {
      _mapController.move(LatLng(p.latitude, p.longitude), _mapController.camera.zoom);
    } catch (_) {}
  }

  void _play() {
    if (_sortedPoints.length < 2) return;
    setState(() => _isPlaying = true);
    _playTimer?.cancel();
    _playTimer = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (!mounted) return;
      if (_selectedIndex >= _sortedPoints.length - 1) {
        _stopPlaying();
        return;
      }
      setState(() => _selectedIndex++);
    });
  }

  void _pause() {
    _playTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  void _restart() {
    _stopPlaying();
    setState(() => _selectedIndex = 0);
    _play();
  }

  void _stopPlaying() {
    _playTimer?.cancel();
    _isPlaying = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Float Tracker'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_state == _LoadState.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading Float History...'),
          ],
        ),
      );
    }

    if (_state == _LoadState.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('Unable to load Float History', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadFloatIds, child: const Text('Try Again')),
          ],
        ),
      );
    }

    if (_state == _LoadState.empty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No Float Data Available', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Upload an Argo Float dataset to track float movement.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const UploadScreen())),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload Dataset'),
            ),
          ],
        ),
      );
    }

    if (_sortedPoints.isEmpty) {
      return const Center(child: Text('No valid location data for this float.'));
    }

    final isLimited = _sortedPoints.length < 2;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    final distance = FloatTrackerService.totalDistanceKm(_sortedPoints);
    final duration = FloatTrackerService.journeyDurationDays(_sortedPoints);
    final avgTemp = FloatTrackerService.average(_sortedPoints.map((p) => p.temperature).toList());
    final avgSal = FloatTrackerService.average(_sortedPoints.map((p) => p.salinity).toList());
    final maxPres = FloatTrackerService.maxOf(_sortedPoints.map((p) => p.pressure).toList());
    final cycles = FloatTrackerService.uniqueCycleCount(_sortedPoints);

    final header = _Header(floatId: _floatIds.isEmpty ? '-' : (_selectedFloatId ?? '-'));
    final selector = _FloatSelector(floatIds: _floatIds, selected: _selectedFloatId, onChanged: _onFloatChanged);
    final summary = _SummaryCard(
      points: _sortedPoints,
      distanceKm: distance,
      durationDays: duration,
      cycles: cycles,
    );
    final map = _JourneyMap(
      points: _sortedPoints,
      selectedIndex: _selectedIndex,
      controller: _mapController,
      onMarkerTap: _selectIndex,
    );
    final controls = _JourneyControls(
      isPlaying: _isPlaying,
      enabled: !isLimited,
      onPlay: _play,
      onPause: _pause,
      onRestart: _restart,
    );
    final timeline = isLimited
        ? const _LimitedDataNotice()
        : _Timeline(
            points: _sortedPoints,
            selectedIndex: _selectedIndex,
            onChanged: (i) {
              _stopPlaying();
              setState(() => _selectedIndex = i);
            },
          );
    final currentObs = _CurrentObservationCard(point: _sortedPoints[_selectedIndex]);
    final stats = _JourneyStatsGrid(
      isWide: isWide,
      cycles: cycles,
      readings: _sortedPoints.length,
      distanceKm: distance,
      durationDays: duration,
      avgTemp: avgTemp,
      avgSalinity: avgSal,
      maxPressure: maxPres,
    );
    final tempChart = _TrendMiniChart(
      title: 'Temperature Trend',
      unit: '°C',
      points: _sortedPoints,
      valueOf: (p) => p.temperature,
      color: Colors.orange.shade700,
    );
    final salChart = _TrendMiniChart(
      title: 'Salinity Trend',
      unit: 'PSU',
      points: _sortedPoints,
      valueOf: (p) => p.salinity,
      color: Colors.teal.shade700,
    );
    final presChart = _TrendMiniChart(
      title: 'Pressure / Depth Trend',
      unit: 'dbar',
      points: _sortedPoints,
      valueOf: (p) => p.pressure,
      color: Colors.blue.shade700,
    );
    final history = _ReadingHistoryList(
      points: _sortedPoints,
      selectedIndex: _selectedIndex,
      onSelect: _selectIndex,
    );

    final content = isWide
        ? ListView(
            padding: const EdgeInsets.all(20),
            children: [
              header,
              const SizedBox(height: 12),
              selector,
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: 16),
                  Expanded(child: stats),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(height: 380, child: map),
              const SizedBox(height: 12),
              controls,
              const SizedBox(height: 12),
              timeline,
              const SizedBox(height: 16),
              currentObs,
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: tempChart),
                  const SizedBox(width: 16),
                  Expanded(child: salChart),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: presChart),
                  const SizedBox(width: 16),
                  Expanded(child: history),
                ],
              ),
              const SizedBox(height: 20),
            ],
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              header,
              const SizedBox(height: 12),
              selector,
              const SizedBox(height: 16),
              summary,
              const SizedBox(height: 16),
              SizedBox(height: 280, child: map),
              const SizedBox(height: 12),
              controls,
              const SizedBox(height: 12),
              timeline,
              const SizedBox(height: 16),
              currentObs,
              const SizedBox(height: 16),
              stats,
              const SizedBox(height: 16),
              tempChart,
              const SizedBox(height: 16),
              salChart,
              const SizedBox(height: 16),
              presChart,
              const SizedBox(height: 16),
              history,
              const SizedBox(height: 20),
            ],
          );

    return RefreshIndicator(
      onRefresh: () => _loadHistory(_selectedFloatId!),
      child: content,
    );
  }
}

// ============================================================
// Shared card shell
// ============================================================
class _SoftCard extends StatelessWidget {
  final Widget child;
  const _SoftCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: child,
    );
  }
}

// ============================================================
// Header
// ============================================================
class _Header extends StatelessWidget {
  final String floatId;
  const _Header({required this.floatId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [Colors.cyan.shade700, Colors.cyan.shade900]),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Float Tracker', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Track float movement and ocean observations',
              style: TextStyle(color: Colors.white70, fontSize: 12.5)),
        ],
      ),
    );
  }
}

// ============================================================
// Float selector
// ============================================================
class _FloatSelector extends StatelessWidget {
  final List<String> floatIds;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _FloatSelector({required this.floatIds, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        decoration: const InputDecoration(labelText: 'Select Float', border: OutlineInputBorder(), isDense: true),
        items: floatIds.map((id) => DropdownMenuItem(value: id, child: Text(id))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ============================================================
// Summary card
// ============================================================
class _SummaryCard extends StatelessWidget {
  final List<MapFloatPoint> points;
  final double? distanceKm;
  final int? durationDays;
  final int cycles;

  const _SummaryCard({
    required this.points,
    required this.distanceKm,
    required this.durationDays,
    required this.cycles,
  });

  @override
  Widget build(BuildContext context) {
    final start = points.first;
    final current = points.last;
    final limited = points.length < 2;

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Float ${current.floatId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(height: 20),
          _row('Current Position', '${current.latitude.toStringAsFixed(2)}°, ${current.longitude.toStringAsFixed(2)}°'),
          _row('Starting Position', '${start.latitude.toStringAsFixed(2)}°, ${start.longitude.toStringAsFixed(2)}°'),
          _row('Total Readings', '${points.length}'),
          _row('Total Cycles', '$cycles'),
          _row('Distance Travelled', distanceKm != null ? '${distanceKm!.toStringAsFixed(1)} km' : 'N/A'),
          _row('Journey Duration', durationDays != null ? '$durationDays Days' : 'N/A'),
          _row('Latest Cycle', current.cycleNumber != null ? '#${current.cycleNumber}' : 'N/A'),
          if (limited) ...[
            const SizedBox(height: 8),
            Text('Limited journey data', style: TextStyle(color: Colors.orange.shade700, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
          ],
        ),
      );
}

// ============================================================
// Journey map
// ============================================================
class _JourneyMap extends StatelessWidget {
  final List<MapFloatPoint> points;
  final int selectedIndex;
  final MapController controller;
  final ValueChanged<int> onMarkerTap;

  const _JourneyMap({
    required this.points,
    required this.selectedIndex,
    required this.controller,
    required this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    final center = LatLng(points[selectedIndex].latitude, points[selectedIndex].longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: FlutterMap(
        mapController: controller,
        options: MapOptions(initialCenter: center, initialZoom: 5),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.oceanpredict_app',
          ),
          if (points.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
                  color: Colors.cyan.shade700,
                  strokeWidth: 3,
                ),
              ],
            ),
          MarkerLayer(
            markers: List.generate(points.length, (i) {
              final p = points[i];
              final isStart = i == 0;
              final isCurrent = i == points.length - 1;
              final isSelected = i == selectedIndex;

              Color color = Colors.cyan.shade600;
              IconData icon = Icons.circle;
              if (isStart) {
                color = Colors.green.shade600;
                icon = Icons.flag;
              }
              if (isCurrent) {
                color = Colors.red.shade600;
                icon = Icons.satellite_alt;
              }

              return Marker(
                point: LatLng(p.latitude, p.longitude),
                width: isSelected ? 42 : 30,
                height: isSelected ? 42 : 30,
                child: GestureDetector(
                  onTap: () => onMarkerTap(i),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Icon(icon, color: Colors.white, size: isSelected ? 20 : 14),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Journey controls
// ============================================================
class _JourneyControls extends StatelessWidget {
  final bool isPlaying;
  final bool enabled;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onRestart;

  const _JourneyControls({
    required this.isPlaying,
    required this.enabled,
    required this.onPlay,
    required this.onPause,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filled(
          onPressed: !enabled ? null : (isPlaying ? onPause : onPlay),
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          style: IconButton.styleFrom(backgroundColor: Colors.cyan.shade700, foregroundColor: Colors.white),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          onPressed: !enabled ? null : onRestart,
          icon: const Icon(Icons.restart_alt),
        ),
      ],
    );
  }
}

class _LimitedDataNotice extends StatelessWidget {
  const _LimitedDataNotice();

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Not enough historical data for journey animation.', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Timeline
// ============================================================
class _Timeline extends StatelessWidget {
  final List<MapFloatPoint> points;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _Timeline({required this.points, required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cycle = points[selectedIndex].cycleNumber;
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selected Cycle: ${cycle != null ? '#$cycle' : 'N/A'}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Slider(
            value: selectedIndex.toDouble(),
            min: 0,
            max: (points.length - 1).toDouble(),
            divisions: points.length > 1 ? points.length - 1 : 1,
            activeColor: Colors.cyan.shade700,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Current observation card
// ============================================================
class _CurrentObservationCard extends StatelessWidget {
  final MapFloatPoint point;
  const _CurrentObservationCard({required this.point});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Current Observation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(height: 20),
          _row('Temperature', point.temperature != null ? '${point.temperature}°C' : 'N/A'),
          _row('Salinity', point.salinity != null ? '${point.salinity} PSU' : 'N/A'),
          _row('Pressure', point.pressure != null ? '${point.pressure} dbar' : 'N/A'),
          _row('Cycle', point.cycleNumber != null ? '#${point.cycleNumber}' : 'N/A'),
          _row('Timestamp', point.timestamp ?? 'Not Available'),
          _row('Location', '${point.latitude.toStringAsFixed(2)}°, ${point.longitude.toStringAsFixed(2)}°'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
          ],
        ),
      );
}

// ============================================================
// Journey statistics grid
// ============================================================
class _JourneyStatsGrid extends StatelessWidget {
  final bool isWide;
  final int cycles;
  final int readings;
  final double? distanceKm;
  final int? durationDays;
  final double? avgTemp;
  final double? avgSalinity;
  final double? maxPressure;

  const _JourneyStatsGrid({
    required this.isWide,
    required this.cycles,
    required this.readings,
    required this.distanceKm,
    required this.durationDays,
    required this.avgTemp,
    required this.avgSalinity,
    required this.maxPressure,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Total Cycles', '$cycles'),
      ('Total Readings', '$readings'),
      ('Distance Travelled', distanceKm != null ? '${distanceKm!.toStringAsFixed(1)} km' : 'N/A'),
      ('Journey Duration', durationDays != null ? '$durationDays Days' : 'N/A'),
      ('Average Temperature', avgTemp != null ? '${avgTemp!.toStringAsFixed(2)}°C' : 'N/A'),
      ('Average Salinity', avgSalinity != null ? '${avgSalinity!.toStringAsFixed(2)} PSU' : 'N/A'),
      ('Maximum Pressure', maxPressure != null ? '${maxPressure!.toStringAsFixed(0)} dbar' : 'N/A'),
    ];

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Journey Statistics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: items
                .map((e) => SizedBox(
                      width: isWide ? 150 : 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(e.$1, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Trend mini chart
// ============================================================
class _TrendMiniChart extends StatelessWidget {
  final String title;
  final String unit;
  final List<MapFloatPoint> points;
  final double? Function(MapFloatPoint) valueOf;
  final Color color;

  const _TrendMiniChart({
    required this.title,
    required this.unit,
    required this.points,
    required this.valueOf,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      final v = valueOf(points[i]);
      if (v != null) spots.add(FlSpot(i.toDouble(), v));
    }

    if (spots.isEmpty) {
      return _SoftCard(child: Text('No $title data available.'));
    }

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= points.length) return const SizedBox.shrink();
                        final c = points[i].cycleNumber;
                        return Text(c != null ? '#$c' : '', style: const TextStyle(fontSize: 9));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) {
                      final i = s.x.round();
                      final c = (i >= 0 && i < points.length) ? points[i].cycleNumber : null;
                      return LineTooltipItem(
                        'Cycle ${c != null ? '#$c' : 'N/A'}\n${s.y.toStringAsFixed(2)} $unit',
                        const TextStyle(color: Colors.white, fontSize: 11),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Reading history list
// ============================================================
class _ReadingHistoryList extends StatelessWidget {
  final List<MapFloatPoint> points; // chronological ascending
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _ReadingHistoryList({required this.points, required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final reversedIndices = List<int>.generate(points.length, (i) => points.length - 1 - i);

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reading History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ...reversedIndices.map((i) {
            final p = points[i];
            final isSelected = i == selectedIndex;
            return InkWell(
              onTap: () => onSelect(i),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.cyan.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? Colors.cyan.shade300 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.cycleNumber != null ? 'Cycle #${p.cycleNumber}' : 'Cycle N/A',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(
                      '${p.temperature != null ? '${p.temperature}°C' : 'N/A'} • ${p.salinity != null ? '${p.salinity} PSU' : 'N/A'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    Text('Pressure: ${p.pressure != null ? '${p.pressure} dbar' : 'N/A'}',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                    Text('Date: ${p.timestamp ?? 'Not Available'}',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}