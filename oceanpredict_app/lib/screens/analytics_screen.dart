import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/ocean_health_service.dart';
import '../widgets/analytics/analytics_widgets.dart';
import '../widgets/analytics/analytics_charts.dart';
import 'upload_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

enum _LoadState { loading, error, empty, ready }

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _LoadState _state = _LoadState.loading;

  Map<String, dynamic>? _activeDataset;
  List<String> _floatIds = [];
  String? _selectedFloatId;
  List<DepthReading> _rawReadings = [];
  List<DepthReading> _displayedReadings = [];

  final _minDepthController = TextEditingController();
  final _maxDepthController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _minDepthController.dispose();
    _maxDepthController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _state = _LoadState.loading);

    final activeResult = await ApiService.getActiveDataset();
    final summaryResult = await ApiService.getAnalyticsSummary();
    final idsResult = await ApiService.getFloatIds();
    if (!mounted) return;

    if (activeResult['statusCode'] != 200 ||
        summaryResult['statusCode'] != 200 ||
        idsResult['statusCode'] != 200) {
      setState(() => _state = _LoadState.error);
      return;
    }

    final activeBody = activeResult['body'];
    if (activeBody['active'] != true) {
      setState(() => _state = _LoadState.empty);
      return;
    }

    final ids = List<String>.from(idsResult['body']['float_ids'] ?? []);

    setState(() {
      _activeDataset = activeBody;
      _floatIds = ids;
      _selectedFloatId = 'all';
    });

    await _loadFloatHistory('all');
  }

  Future<void> _loadFloatHistory(String floatId) async {
    final result = await ApiService.getFloatHistory(floatId);
    if (!mounted) return;

    if (result['statusCode'] != 200) {
      setState(() {
        _rawReadings = [];
        _displayedReadings = [];
        _state = _LoadState.ready;
      });
      return;
    }

    final history = result['body']['history'] as List<dynamic>? ?? [];
    final readings = history
        .where((h) => h['temperature'] != null && h['salinity'] != null && h['pressure'] != null)
        .map((h) => DepthReading(
              temperature: (h['temperature'] as num).toDouble(),
              salinity: (h['salinity'] as num).toDouble(),
              pressure: (h['pressure'] as num).toDouble(),
              cycleNumber: (h['cycle_number'] as num?)?.toInt() ?? 0,
              floatId: (h['float_id'] as String?) ?? floatId,
              timestamp: h['timestamp'] as String?,
            ))
        .toList();

    setState(() {
      _rawReadings = readings;
      _displayedReadings = readings;
      _state = _LoadState.ready;
    });
  }

  void _applyFilters() {
    final minD = double.tryParse(_minDepthController.text);
    final maxD = double.tryParse(_maxDepthController.text);

    setState(() {
      _displayedReadings = _rawReadings.where((r) {
        if (minD != null && r.pressure < minD) return false;
        if (maxD != null && r.pressure > maxD) return false;
        return true;
      }).toList();
    });
  }

  void _resetFilters() {
    _minDepthController.clear();
    _maxDepthController.clear();
    setState(() {
      _selectedFloatId = 'all';
      _displayedReadings = _rawReadings;
    });
    _loadFloatHistory('all');
  }

  List<AnomalyEntry> _computeAnomalies() {
    if (_displayedReadings.length < 3) return [];

    final entries = <AnomalyEntry>[];

    // Depth bands for profile stratification (0-100, 100-300, 300-600, 600-1000, 1000+)
    int getDepthBand(double pressure) {
      if (pressure < 100) return 0;
      if (pressure < 300) return 1;
      if (pressure < 600) return 2;
      if (pressure < 1000) return 3;
      return 4;
    }

    void detectForParameter({
      required String parameter,
      required String unit,
      required double Function(DepthReading r) getValue,
    }) {
      final allValues = _displayedReadings.map(getValue).toList();
      final globalQ1 = DataStats.percentile(allValues, 0.25);
      final globalQ3 = DataStats.percentile(allValues, 0.75);
      final globalIqr = (globalQ3 - globalQ1).abs();
      final effectiveGlobalIqr = globalIqr < 0.05
          ? (DataStats.mean(allValues).abs() * 0.05).clamp(0.2, 5.0)
          : globalIqr;
      final globalLower = globalQ1 - 1.5 * effectiveGlobalIqr;
      final globalUpper = globalQ3 + 1.5 * effectiveGlobalIqr;

      // Group readings by depth band
      final bandReadings = <int, List<DepthReading>>{};
      for (final r in _displayedReadings) {
        final b = getDepthBand(r.pressure);
        bandReadings.putIfAbsent(b, () => []).add(r);
      }

      // Precalculate IQR bounds per depth band if band has >= 4 observations
      final bandBounds = <int, ({double lower, double upper, double iqr})>{};
      bandReadings.forEach((band, readingsInBand) {
        if (readingsInBand.length >= 4) {
          final bandVals = readingsInBand.map(getValue).toList();
          final q1 = DataStats.percentile(bandVals, 0.25);
          final q3 = DataStats.percentile(bandVals, 0.75);
          double iqr = (q3 - q1).abs();
          if (iqr < 0.05) {
            iqr = (DataStats.mean(bandVals).abs() * 0.05).clamp(0.2, 5.0);
          }
          bandBounds[band] = (
            lower: q1 - 1.5 * iqr,
            upper: q3 + 1.5 * iqr,
            iqr: iqr,
          );
        }
      });

      // Evaluate each reading against depth-band bounds or global bounds
      for (final r in _displayedReadings) {
        final val = getValue(r);
        final band = getDepthBand(r.pressure);
        final bounds = bandBounds[band] ??
            (lower: globalLower, upper: globalUpper, iqr: effectiveGlobalIqr);

        if (val < bounds.lower || val > bounds.upper) {
          final dev = val < bounds.lower ? (bounds.lower - val) : (val - bounds.upper);
          String severity;
          if (dev >= 2.0 * bounds.iqr) {
            severity = 'High';
          } else if (dev >= 1.0 * bounds.iqr) {
            severity = 'Medium';
          } else {
            severity = 'Low';
          }

          final floatLabel = (r.floatId.isNotEmpty && r.floatId != 'all') ? r.floatId : 'F001';

          entries.add(AnomalyEntry(
            parameter: parameter,
            floatId: floatLabel,
            value: val,
            depth: r.pressure,
            expectedRange: '${bounds.lower.toStringAsFixed(2)}–${bounds.upper.toStringAsFixed(2)} $unit',
            severity: severity,
          ));
        }
      }
    }

    detectForParameter(
      parameter: 'Temperature',
      unit: '°C',
      getValue: (r) => r.temperature,
    );

    detectForParameter(
      parameter: 'Salinity',
      unit: 'PSU',
      getValue: (r) => r.salinity,
    );

    return entries;
  }

  List<String> _buildInsights() {
    if (_displayedReadings.isEmpty) {
      return ['Not enough data available to generate insights.'];
    }

    if (_displayedReadings.length < 2) {
      final r = _displayedReadings.first;
      return [
        'Single observation recorded: ${r.temperature}°C, ${r.salinity} PSU at ${r.pressure} dbar.',
        'Insufficient observations for reliable anomaly analysis (minimum 3 required).',
        'Upload additional profiling float data to generate multi-point depth trends.',
      ];
    }

    final temps = _displayedReadings.map((r) => r.temperature).toList();
    final sals = _displayedReadings.map((r) => r.salinity).toList();
    final press = _displayedReadings.map((r) => r.pressure).toList();

    final avgTemp = (temps.reduce((a, b) => a + b) / temps.length).toStringAsFixed(2);
    final maxTemp = temps.reduce((a, b) => a > b ? a : b).toStringAsFixed(2);
    final maxPres = press.reduce((a, b) => a > b ? a : b).toStringAsFixed(1);
    final minSal = sals.reduce((a, b) => a < b ? a : b).toStringAsFixed(2);
    final maxSal = sals.reduce((a, b) => a > b ? a : b).toStringAsFixed(2);

    final anomalies = _computeAnomalies();

    return [
      'Average temperature is $avgTemp°C across ${_displayedReadings.length} observations.',
      'Highest recorded temperature is $maxTemp°C.',
      'Maximum observed pressure/depth is $maxPres dbar.',
      'Salinity ranges between $minSal and $maxSal PSU.',
      anomalies.isEmpty
          ? 'No significant anomalies detected in current active dataset.'
          : '${anomalies.length} oceanographic anomaly detected.',
    ];
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF3FAFC),
      appBar: AppBar(title: const Text('Analytics')),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: _buildBody(isTablet),
      ),
    );
  }

  Widget _buildBody(bool isTablet) {
    if (_state == _LoadState.loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SkeletonBlock(height: 130),
          SkeletonBlock(height: 160),
          SkeletonBlock(height: 220),
          SkeletonBlock(height: 220),
        ],
      );
    }

    if (_state == _LoadState.error) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          const Center(child: Text('Unable to load analytics', style: TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(onPressed: _loadInitial, child: const Text('Try Again')),
          ),
        ],
      );
    }

    if (_state == _LoadState.empty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.storage_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Center(child: Text('No active dataset available', style: TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Upload or select an active Argo Float dataset to begin analysis.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UploadScreen()),
              ),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload Dataset'),
            ),
          ),
        ],
      );
    }

    // Ready state
    final activeDatasetName = _activeDataset?['filename'] ?? 'Active Dataset';
    final activeTotalRecords = _activeDataset?['total_records'] as int? ?? _displayedReadings.length;
    final metaSummary = _activeDataset?['metadata']?['summary'] ?? {};
    final bool hasTimestamps = metaSummary['timestamp_available'] == true ||
        _displayedReadings.any((r) => r.timestamp != null && r.timestamp!.isNotEmpty);
    final String dateRange = metaSummary['date_range'] ?? 'Timestamp unavailable';

    final temps = _displayedReadings.map((r) => r.temperature).toList();
    final sals = _displayedReadings.map((r) => r.salinity).toList();
    final press = _displayedReadings.map((r) => r.pressure).toList();

    final double? avgT = temps.isNotEmpty ? temps.reduce((a, b) => a + b) / temps.length : null;
    final double? minT = temps.isNotEmpty ? temps.reduce((a, b) => a < b ? a : b) : null;
    final double? maxT = temps.isNotEmpty ? temps.reduce((a, b) => a > b ? a : b) : null;

    final double? avgS = sals.isNotEmpty ? sals.reduce((a, b) => a + b) / sals.length : null;
    final double? minS = sals.isNotEmpty ? sals.reduce((a, b) => a < b ? a : b) : null;
    final double? maxS = sals.isNotEmpty ? sals.reduce((a, b) => a > b ? a : b) : null;

    final double? maxP = press.isNotEmpty ? press.reduce((a, b) => a > b ? a : b) : null;
    final double? avgP = press.isNotEmpty ? press.reduce((a, b) => a + b) / press.length : null;

    final health = OceanHealthService.calculate(
      avgTemp: avgT,
      minTemp: minT,
      maxTemp: maxT,
      avgSalinity: avgS,
      minSalinity: minS,
      maxSalinity: maxS,
      maxPressure: maxP,
      observationCount: _displayedReadings.length,
    );

    final tempTrend = _displayedReadings.length < 2 ? 'Insufficient data' : DataStats.trendDirection(temps);
    final salTrend = _displayedReadings.length < 2 ? 'Insufficient data' : DataStats.trendDirection(sals);
    final anomalies = _computeAnomalies();
    final String anomalyStatus = _displayedReadings.length < 3 ? 'Not evaluated' : '${anomalies.length}';

    final statCards = [
      StatisticCard(
        title: 'Temperature',
        icon: Icons.thermostat_outlined,
        color: Colors.orange.shade700,
        avg: avgT != null ? '${avgT.toStringAsFixed(2)} °C' : 'N/A',
        min: minT != null ? '${minT.toStringAsFixed(2)} °C' : 'N/A',
        max: maxT != null ? '${maxT.toStringAsFixed(2)} °C' : 'N/A',
      ),
      StatisticCard(
        title: 'Salinity',
        icon: Icons.water_drop_outlined,
        color: Colors.teal.shade700,
        avg: avgS != null ? '${avgS.toStringAsFixed(2)} PSU' : 'N/A',
        min: minS != null ? '${minS.toStringAsFixed(2)} PSU' : 'N/A',
        max: maxS != null ? '${maxS.toStringAsFixed(2)} PSU' : 'N/A',
      ),
      StatisticCard(
        title: 'Pressure',
        icon: Icons.speed_outlined,
        color: Colors.blue.shade700,
        avg: avgP != null ? '${avgP.toStringAsFixed(1)} dbar' : 'N/A',
        min: '',
        max: maxP != null ? '${maxP.toStringAsFixed(1)} dbar' : 'N/A',
        showMinMax: false,
      ),
    ];

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 16, vertical: 16),
      children: [
        AnalyticsHeader(
          datasetName: activeDatasetName,
          recordCount: activeTotalRecords,
          floatCount: _floatIds.length,
          fileSizeText: _formatFileSize(_activeDataset?['file_size'] as int?),
        ),
        const SizedBox(height: 16),
        FilterPanel(
          floatIds: _floatIds,
          selectedFloatId: _selectedFloatId,
          onFloatChanged: (id) {
            if (id == null) return;
            setState(() => _selectedFloatId = id);
            _loadFloatHistory(id);
          },
          minDepthController: _minDepthController,
          maxDepthController: _maxDepthController,
          hasTimestamps: hasTimestamps,
          dateRangeText: dateRange,
          onApply: _applyFilters,
          onReset: _resetFilters,
        ),
        const SizedBox(height: 20),
        const SectionHeading(title: 'Key Statistics', icon: Icons.bar_chart_rounded),
        isTablet
            ? Row(
                children: statCards
                    .map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c)))
                    .toList(),
              )
            : Column(children: statCards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList()),
        const SizedBox(height: 10),
        const SectionHeading(title: 'Profile Charts', icon: Icons.show_chart_rounded),
        TemperatureDepthChart(readings: _displayedReadings),
        const SizedBox(height: 16),
        SalinityDepthChart(readings: _displayedReadings),
        const SizedBox(height: 16),
        PressureTemperatureChart(readings: _displayedReadings),
        const SizedBox(height: 20),
        const SectionHeading(title: 'Trends', icon: Icons.timeline_rounded),
        TrendChart(
          title: 'Temperature Trend',
          yLabel: '°C',
          values: _displayedReadings.map((r) => r.temperature).toList(),
          direction: tempTrend,
          color: Colors.orange.shade700,
          hasTimestamps: hasTimestamps,
        ),
        const SizedBox(height: 16),
        TrendChart(
          title: 'Salinity Trend',
          yLabel: 'PSU',
          values: _displayedReadings.map((r) => r.salinity).toList(),
          direction: salTrend,
          color: Colors.teal.shade700,
          hasTimestamps: hasTimestamps,
        ),
        const SizedBox(height: 20),
        OceanHealthCard(result: health),
        const SizedBox(height: 16),
        AIInsightCard(insights: _buildInsights()),
        const SizedBox(height: 16),
        AnomalyCard(
          anomalies: anomalies,
          hasSufficientData: _displayedReadings.length >= 3,
        ),
        const SizedBox(height: 16),
        AnalysisSummaryCard(
          observations: _displayedReadings.length,
          floatCount: _floatIds.length,
          dateRange: dateRange,
          avgTemp: avgT != null ? '${avgT.toStringAsFixed(2)} °C' : 'N/A',
          avgSalinity: avgS != null ? '${avgS.toStringAsFixed(2)} PSU' : 'N/A',
          maxDepth: maxP != null ? '${maxP.toStringAsFixed(1)} dbar' : 'N/A',
          anomalyStatus: anomalyStatus,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}