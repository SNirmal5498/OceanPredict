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

  Map<String, dynamic>? _summary; // from existing /analytics/summary
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

    final idsResult = await ApiService.getFloatIds();
    final summaryResult = await ApiService.getAnalyticsSummary();
    if (!mounted) return;

    if (idsResult['statusCode'] != 200 || summaryResult['statusCode'] != 200) {
      setState(() => _state = _LoadState.error);
      return;
    }

    final ids = List<String>.from(idsResult['body']['float_ids']);
    if (ids.isEmpty) {
      setState(() => _state = _LoadState.empty);
      return;
    }

    setState(() {
      _floatIds = ids;
      _selectedFloatId = ids.first;
      _summary = summaryResult['body'];
    });

    await _loadFloatHistory(ids.first);
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

    final history = result['body']['history'] as List<dynamic>;
    final readings = history
        .where((h) => h['temperature'] != null && h['salinity'] != null && h['pressure'] != null)
        .map((h) => DepthReading(
              temperature: (h['temperature'] as num).toDouble(),
              salinity: (h['salinity'] as num).toDouble(),
              pressure: (h['pressure'] as num).toDouble(),
              cycleNumber: (h['cycle_number'] as num?)?.toInt() ?? 0,
              floatId: floatId,
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
    setState(() => _displayedReadings = _rawReadings);
  }

  List<AnomalyEntry> _computeAnomalies() {
    if (_displayedReadings.isEmpty) return [];
    final temps = _displayedReadings.map((r) => r.temperature).toList();
    final sals = _displayedReadings.map((r) => r.salinity).toList();

    final entries = <AnomalyEntry>[];
    final tempMean = DataStats.mean(temps);
    final tempSd = DataStats.stdDev(temps);
    for (final i in DataStats.anomalyIndices(temps)) {
      entries.add(AnomalyEntry(
        parameter: 'Temperature',
        floatId: _displayedReadings[i].floatId,
        value: temps[i],
        expectedRange: '${(tempMean - tempSd).toStringAsFixed(1)} - ${(tempMean + tempSd).toStringAsFixed(1)}°C',
        severity: DataStats.severityFor(temps[i], tempMean, tempSd),
      ));
    }

    final salMean = DataStats.mean(sals);
    final salSd = DataStats.stdDev(sals);
    for (final i in DataStats.anomalyIndices(sals)) {
      entries.add(AnomalyEntry(
        parameter: 'Salinity',
        floatId: _displayedReadings[i].floatId,
        value: sals[i],
        expectedRange: '${(salMean - salSd).toStringAsFixed(1)} - ${(salMean + salSd).toStringAsFixed(1)} PSU',
        severity: DataStats.severityFor(sals[i], salMean, salSd),
      ));
    }
    return entries;
  }

  List<String> _buildInsights() {
    if (_summary == null) return [];
    final temp = _summary!['temperature'];
    final sal = _summary!['salinity'];
    final pres = _summary!['pressure'];
    final anomalies = _computeAnomalies();

    return [
      'Average temperature is ${temp['avg']}°C.',
      'The highest recorded temperature is ${temp['max']}°C.',
      'Maximum observed pressure is ${pres['max_depth']} dbar.',
      'Salinity varies between ${sal['min']} and ${sal['max']} PSU.',
      anomalies.isEmpty ? 'No significant anomaly detected.' : 'Temperature or salinity anomaly detected.',
    ];
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
          const Center(child: Text('No dataset available', style: TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Upload an Argo Float dataset to begin analysis.',
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

    // ready
    final temp = _summary!['temperature'];
    final sal = _summary!['salinity'];
    final pres = _summary!['pressure'];

    final health = OceanHealthService.calculate(
      avgTemp: (temp['avg'] as num?)?.toDouble(),
      minTemp: (temp['min'] as num?)?.toDouble(),
      maxTemp: (temp['max'] as num?)?.toDouble(),
      avgSalinity: (sal['avg'] as num?)?.toDouble(),
      minSalinity: (sal['min'] as num?)?.toDouble(),
      maxSalinity: (sal['max'] as num?)?.toDouble(),
      maxPressure: (pres['max_depth'] as num?)?.toDouble(),
    );

    final anomalies = _computeAnomalies();
    final tempTrend = DataStats.trendDirection(_displayedReadings.map((r) => r.temperature).toList());
    final salTrend = DataStats.trendDirection(_displayedReadings.map((r) => r.salinity).toList());

    final statCards = [
      StatisticCard(
        title: 'Temperature',
        icon: Icons.thermostat_outlined,
        color: Colors.orange.shade700,
        avg: '${temp['avg']} °C',
        min: '${temp['min']} °C',
        max: '${temp['max']} °C',
      ),
      StatisticCard(
        title: 'Salinity',
        icon: Icons.water_drop_outlined,
        color: Colors.teal.shade700,
        avg: '${sal['avg']} PSU',
        min: '${sal['min']} PSU',
        max: '${sal['max']} PSU',
      ),
      StatisticCard(
        title: 'Pressure',
        icon: Icons.speed_outlined,
        color: Colors.blue.shade700,
        avg: '${pres['avg']} dbar',
        min: '',
        max: '${pres['max_depth']} dbar',
        showMinMax: false,
      ),
    ];

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 16, vertical: 16),
      children: [
        AnalyticsHeader(datasetName: _selectedFloatId, recordCount: _displayedReadings.length),
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
        ),
        const SizedBox(height: 16),
        TrendChart(
          title: 'Salinity Trend',
          yLabel: 'PSU',
          values: _displayedReadings.map((r) => r.salinity).toList(),
          direction: salTrend,
          color: Colors.teal.shade700,
        ),
        const SizedBox(height: 20),
        OceanHealthCard(result: health),
        const SizedBox(height: 16),
        AIInsightCard(insights: _buildInsights()),
        const SizedBox(height: 16),
        AnomalyCard(anomalies: anomalies),
        const SizedBox(height: 16),
        AnalysisSummaryCard(
          observations: _displayedReadings.length,
          floatCount: _floatIds.length,
          dateRange: 'Not available (no timestamp field yet)',
          avgTemp: '${temp['avg']} °C',
          avgSalinity: '${sal['avg']} PSU',
          maxDepth: '${pres['max_depth']} dbar',
          anomalyCount: anomalies.length,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}