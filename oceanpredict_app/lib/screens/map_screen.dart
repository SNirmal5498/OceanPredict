import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/map_service.dart';
import '../widgets/map/map_widgets.dart';
import 'upload_screen.dart';
import 'tracker_screen.dart';
import 'analytics_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum _LoadState { loading, error, empty, ready }

class _MapScreenState extends State<MapScreen> {
  _LoadState _state = _LoadState.loading;

  List<MapFloatPoint> _allPoints = [];
  List<MapFloatPoint> _visiblePoints = [];
  int _invalidCount = 0;

  bool _temperatureMode = false;

  final MapController _mapController = MapController();

  final _searchController = TextEditingController();
  final _floatIdController = TextEditingController();
  final _minTempController = TextEditingController();
  final _maxTempController = TextEditingController();
  final _minSalController = TextEditingController();
  final _maxSalController = TextEditingController();
  final _minPresController = TextEditingController();
  final _maxPresController = TextEditingController();

  static const LatLng _fallbackCenter = LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _floatIdController.dispose();
    _minTempController.dispose();
    _maxTempController.dispose();
    _minSalController.dispose();
    _maxSalController.dispose();
    _minPresController.dispose();
    _maxPresController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _state = _LoadState.loading);

    final result = await ApiService.getFloatLocations();
    if (!mounted) return;

    if (result['statusCode'] != 200) {
      setState(() => _state = _LoadState.error);
      return;
    }

    final raw = result['body']['floats'] as List<dynamic>;
    if (raw.isEmpty) {
      setState(() => _state = _LoadState.empty);
      return;
    }

    final parsed = MapService.parse(raw);
    if (parsed.points.isEmpty) {
      setState(() {
        _allPoints = [];
        _invalidCount = parsed.invalidCount;
        _state = _LoadState.empty;
      });
      return;
    }

    setState(() {
      _allPoints = parsed.points;
      _visiblePoints = parsed.points;
      _invalidCount = parsed.invalidCount;
      _state = _LoadState.ready;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToData());
  }

  void _fitToData() {
    final bounds = MapService.boundsOf(_visiblePoints);
    if (bounds == null) return;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(bounds.south, bounds.west),
            LatLng(bounds.north, bounds.east),
          ),
          padding: const EdgeInsets.all(40),
        ),
      );
    } catch (_) {
      // Map may not be attached yet — safe to ignore, user can tap Fit to Data manually.
    }
  }

  void _resetView() {
    final center = MapService.centerOf(_allPoints) ?? (0.0, 0.0);
    _mapController.move(LatLng(center.$1, center.$2), 4);
  }

  void _zoomIn() => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
  void _zoomOut() => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);

  void _applyFilters() {
    setState(() {
      _visiblePoints = MapService.applyFilters(
        _allPoints,
        floatId: _floatIdController.text,
        minTemp: double.tryParse(_minTempController.text),
        maxTemp: double.tryParse(_maxTempController.text),
        minSalinity: double.tryParse(_minSalController.text),
        maxSalinity: double.tryParse(_maxSalController.text),
        minPressure: double.tryParse(_minPresController.text),
        maxPressure: double.tryParse(_maxPresController.text),
      );
    });
  }

  void _resetFilters() {
    _floatIdController.clear();
    _minTempController.clear();
    _maxTempController.clear();
    _minSalController.clear();
    _maxSalController.clear();
    _minPresController.clear();
    _maxPresController.clear();
    setState(() => _visiblePoints = _allPoints);
  }

  void _search() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return;

    MapFloatPoint? match;
    for (final p in _visiblePoints) {
      if (p.floatId.toLowerCase().contains(query) || (p.cycleNumber?.toString() == query)) {
        match = p;
        break;
      }
    }

    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No matching float found.')),
      );
      return;
    }

    _mapController.move(LatLng(match.latitude, match.longitude), 8);
    _showFloatSheet(match);
  }

  Color _colorFor(MapFloatPoint p) {
    if (!_temperatureMode) return Colors.cyan.shade700;
    switch (MapService.categoryFor(p.temperature)) {
      case TemperatureCategory.low:
        return Colors.blue;
      case TemperatureCategory.high:
        return Colors.red;
      case TemperatureCategory.normal:
        return Colors.green;
      case TemperatureCategory.unknown:
        return Colors.grey;
    }
  }

  void _showFloatSheet(MapFloatPoint point) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => FloatInfoSheet(
        point: point,
        onViewHistory: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (context) => const TrackerScreen()));
        },
        onTrackFloat: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (context) => const TrackerScreen()));
        },
        onViewAnalytics: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalyticsScreen()));
        },
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => MapFilterPanel(
        floatIdController: _floatIdController,
        minTempController: _minTempController,
        maxTempController: _maxTempController,
        minSalController: _minSalController,
        maxSalController: _maxSalController,
        minPresController: _minPresController,
        maxPresController: _maxPresController,
        onApply: _applyFilters,
        onReset: _resetFilters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ocean Map'),
        actions: [
          IconButton(
            icon: Icon(_temperatureMode ? Icons.thermostat : Icons.thermostat_outlined),
            tooltip: 'Temperature visualization',
            onPressed: () => setState(() => _temperatureMode = !_temperatureMode),
          ),
          IconButton(icon: const Icon(Icons.filter_list), onPressed: _openFilterSheet),
        ],
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
            Text('Loading Argo Float locations...'),
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
            const Text('Unable to load map data', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Try Again')),
          ],
        ),
      );
    }

    if (_state == _LoadState.empty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No Argo Float data available', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Upload a dataset to visualize float locations on the map.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UploadScreen())),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload Dataset'),
            ),
          ],
        ),
      );
    }

    final center = MapService.centerOf(_visiblePoints);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    final mapWidget = Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center != null ? LatLng(center.$1, center.$2) : _fallbackCenter,
            initialZoom: 4,
          ),
          children: [
            TileLayer(
              // Tile provider kept separate/configurable — no hardcoded secrets.
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.oceanpredict_app',
            ),
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 60,
                size: const Size(44, 44),
                markers: _visiblePoints
                    .map((p) => Marker(
                          point: LatLng(p.latitude, p.longitude),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => _showFloatSheet(p),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _colorFor(p),
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: const Icon(Icons.satellite_alt, color: Colors.white, size: 18),
                            ),
                          ),
                        ))
                    .toList(),
                builder: (context, markers) => Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.cyan.shade800,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text('${markers.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: MapSearchBar(controller: _searchController, onSearch: _search),
        ),
        Positioned(
          right: 12,
          bottom: 90,
          child: MapControls(
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
            onReset: _resetView,
            onFitToData: _fitToData,
          ),
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: MapLegend(showTemperatureMode: _temperatureMode),
        ),
      ],
    );

    final sidePanel = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FloatLocationSummary(
            total: _allPoints.length,
            visible: _visiblePoints.length,
            invalid: _invalidCount,
          ),
          const SizedBox(height: 12),
          DataQualityCard(
            valid: _allPoints.length,
            invalid: _invalidCount,
            missing: _invalidCount,
          ),
        ],
      ),
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(flex: 3, child: mapWidget),
          SizedBox(width: 300, child: SingleChildScrollView(child: sidePanel)),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: mapWidget),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FloatLocationSummary(
            total: _allPoints.length,
            visible: _visiblePoints.length,
            invalid: _invalidCount,
          ),
        ),
      ],
    );
  }
}