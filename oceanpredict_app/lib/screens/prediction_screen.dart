import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../services/prediction_service.dart';
import '../models/prediction_result.dart';
import 'upload_screen.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

enum _DatasetState { loading, error, empty, ready }
enum _RunState { idle, preparing, training, generating, done, failed }

class _PredictionScreenState extends State<PredictionScreen> {
  _DatasetState _datasetState = _DatasetState.loading;
  Map<String, dynamic>? _summary;
  List<String> _floatIds = [];

  String _model = 'linear_regression';
  String _target = 'temperature';
  String _selectedFloat = 'all';
  int _horizon = 5;
  bool _inputsExpanded = false;
  bool _detailsExpanded = false;

  _RunState _runState = _RunState.idle;
  String? _errorMessage;
  PredictionResult? _result;
  List<Map<String, dynamic>> _historicalPoints = []; // for chart, single-float only

  final List<PredictionHistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadDatasetStatus();
  }

  Future<void> _loadDatasetStatus() async {
    setState(() => _datasetState = _DatasetState.loading);

    final idsResult = await ApiService.getFloatIds();
    final summaryResult = await ApiService.getAnalyticsSummary();
    if (!mounted) return;

    if (idsResult['statusCode'] != 200 || summaryResult['statusCode'] != 200) {
      setState(() => _datasetState = _DatasetState.error);
      return;
    }

    final ids = List<String>.from(idsResult['body']['float_ids']);
    if (ids.isEmpty) {
      setState(() => _datasetState = _DatasetState.empty);
      return;
    }

    setState(() {
      _floatIds = ids;
      _summary = summaryResult['body'];
      _datasetState = _DatasetState.ready;
    });
  }

  Future<void> _loadHistoricalForChart() async {
    _historicalPoints = [];
    if (_selectedFloat == 'all') return; // not scientifically coherent across floats — skip honestly

    final result = await ApiService.getFloatHistory(_selectedFloat);
    if (result['statusCode'] == 200) {
      final history = result['body']['history'] as List<dynamic>;
      final sorted = List<Map<String, dynamic>>.from(history)
        ..sort((a, b) => ((a['cycle_number'] ?? 0) as num).compareTo((b['cycle_number'] ?? 0) as num));
      _historicalPoints = sorted;
    }
  }

  Future<void> _runPrediction() async {
    if (_runState == _RunState.preparing || _runState == _RunState.training || _runState == _RunState.generating) {
      return; // no simultaneous requests
    }

    setState(() {
      _runState = _RunState.preparing;
      _errorMessage = null;
      _result = null;
    });

    await _loadHistoricalForChart();
    if (!mounted) return;

    setState(() => _runState = _RunState.training);
    await Future.delayed(const Duration(milliseconds: 300)); // reflects real request in flight
    if (!mounted) return;

    setState(() => _runState = _RunState.generating);

    try {
      final result = await PredictionService.predict(
        model: _model,
        target: _target,
        floatId: _selectedFloat,
        horizon: _horizon,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _runState = _RunState.done;
        _history.insert(0, PredictionHistoryEntry(result: result, generatedAt: DateTime.now()));
      });
    } on PredictionException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _runState = _RunState.failed;
      });
    }
  }

  String get _statusText {
    switch (_runState) {
      case _RunState.preparing:
        return 'Preparing data...';
      case _RunState.training:
        return 'Training model...';
      case _RunState.generating:
        return 'Generating forecast...';
      default:
        return '';
    }
  }

  bool get _isBusy =>
      _runState == _RunState.preparing || _runState == _RunState.training || _runState == _RunState.generating;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FAFC),
      appBar: AppBar(title: const Text('AI Prediction')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_datasetState == _DatasetState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_datasetState == _DatasetState.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('Unable to load dataset status', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadDatasetStatus, child: const Text('Try Again')),
          ],
        ),
      );
    }

    if (_datasetState == _DatasetState.empty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_graph_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Prediction Requires Data', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Upload an Argo Float dataset before generating predictions.',
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

    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    final header = _Header();
    final datasetStatus = _DatasetStatusCard(summary: _summary!, floatCount: _floatIds.length);
    final setup = _PredictionSetupCard(
      model: _model,
      target: _target,
      selectedFloat: _selectedFloat,
      floatIds: _floatIds,
      horizon: _horizon,
      onModelChanged: (v) => setState(() => _model = v),
      onTargetChanged: (v) => setState(() => _target = v),
      onFloatChanged: (v) => setState(() => _selectedFloat = v),
      onHorizonChanged: (v) => setState(() => _horizon = v),
      inputsExpanded: _inputsExpanded,
      onToggleInputs: () => setState(() => _inputsExpanded = !_inputsExpanded),
    );
    final runButton = _RunButton(isBusy: _isBusy, statusText: _statusText, onPressed: _runPrediction);

    final resultSection = _runState == _RunState.failed
        ? _ErrorCard(message: _errorMessage ?? 'Prediction failed.', onRetry: _runPrediction)
        : _result != null
            ? _ResultSection(
                result: _result!,
                historicalPoints: _historicalPoints,
                detailsExpanded: _detailsExpanded,
                onToggleDetails: () => setState(() => _detailsExpanded = !_detailsExpanded),
              )
            : const SizedBox.shrink();

    final historySection = _PredictionHistorySection(history: _history);

    if (isWide) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: setup),
                const SizedBox(width: 16),
                Expanded(child: datasetStatus),
              ],
            ),
            const SizedBox(height: 16),
            runButton,
            const SizedBox(height: 16),
            resultSection,
            const SizedBox(height: 16),
            historySection,
            const SizedBox(height: 20),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 16),
          datasetStatus,
          const SizedBox(height: 16),
          setup,
          const SizedBox(height: 16),
          runButton,
          const SizedBox(height: 16),
          resultSection,
          const SizedBox(height: 16),
          historySection,
          const SizedBox(height: 20),
        ],
      ),
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
          Text('AI Prediction', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Forecast future ocean conditions using machine learning',
              style: TextStyle(color: Colors.white70, fontSize: 12.5)),
        ],
      ),
    );
  }
}

// ============================================================
// Dataset status
// ============================================================
class _DatasetStatusCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  final int floatCount;

  const _DatasetStatusCard({required this.summary, required this.floatCount});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dataset Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(height: 20),
          _row('Floats', '$floatCount'),
          _row('Avg Temperature', '${summary['temperature']['avg']}°C'),
          _row('Avg Salinity', '${summary['salinity']['avg']} PSU'),
          _row('Max Depth', '${summary['pressure']['max_depth']} dbar'),
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
// Prediction setup card
// ============================================================
class _PredictionSetupCard extends StatelessWidget {
  final String model;
  final String target;
  final String selectedFloat;
  final List<String> floatIds;
  final int horizon;
  final ValueChanged<String> onModelChanged;
  final ValueChanged<String> onTargetChanged;
  final ValueChanged<String> onFloatChanged;
  final ValueChanged<int> onHorizonChanged;
  final bool inputsExpanded;
  final VoidCallback onToggleInputs;

  const _PredictionSetupCard({
    required this.model,
    required this.target,
    required this.selectedFloat,
    required this.floatIds,
    required this.horizon,
    required this.onModelChanged,
    required this.onTargetChanged,
    required this.onFloatChanged,
    required this.onHorizonChanged,
    required this.inputsExpanded,
    required this.onToggleInputs,
  });

  static const _modelDescriptions = {
    'linear_regression': 'Simple and interpretable model for identifying linear trends.',
    'random_forest': 'Ensemble model capable of learning more complex relationships.',
  };

  static const _features = ['Cycle Number', 'Pressure', 'Latitude', 'Longitude'];

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Prediction Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: model,
            decoration: const InputDecoration(labelText: 'Select Model', border: OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem(value: 'linear_regression', child: Text('Linear Regression')),
              DropdownMenuItem(value: 'random_forest', child: Text('Random Forest')),
            ],
            onChanged: (v) => v != null ? onModelChanged(v) : null,
          ),
          const SizedBox(height: 6),
          Text(_modelDescriptions[model] ?? '', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: target,
            decoration:
                const InputDecoration(labelText: 'Prediction Target', border: OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem(value: 'temperature', child: Text('Temperature')),
              DropdownMenuItem(value: 'salinity', child: Text('Salinity')),
            ],
            onChanged: (v) => v != null ? onTargetChanged(v) : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: selectedFloat,
            decoration: const InputDecoration(labelText: 'Select Float', border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All Floats')),
              ...floatIds.map((id) => DropdownMenuItem(value: id, child: Text(id))),
            ],
            onChanged: (v) => v != null ? onFloatChanged(v) : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: horizon,
            decoration:
                const InputDecoration(labelText: 'Forecast Horizon', border: OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Next 1 cycle')),
              DropdownMenuItem(value: 3, child: Text('Next 3 cycles')),
              DropdownMenuItem(value: 5, child: Text('Next 5 cycles')),
              DropdownMenuItem(value: 10, child: Text('Next 10 cycles')),
            ],
            onChanged: (v) => v != null ? onHorizonChanged(v) : null,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onToggleInputs,
            child: Row(
              children: [
                Icon(inputsExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.cyan.shade700),
                const SizedBox(width: 4),
                Text('Model Inputs', style: TextStyle(color: Colors.cyan.shade700, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          if (inputsExpanded)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _features
                    .map((f) => Chip(label: Text(f, style: const TextStyle(fontSize: 11.5)), backgroundColor: Colors.cyan.shade50))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// Run button + status
// ============================================================
class _RunButton extends StatelessWidget {
  final bool isBusy;
  final String statusText;
  final VoidCallback onPressed;

  const _RunButton({required this.isBusy, required this.statusText, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isBusy ? null : onPressed,
            icon: isBusy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_graph),
            label: Text(isBusy ? statusText : 'Run Prediction'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Error card
// ============================================================
class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text('Prediction Failed', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

// ============================================================
// Result section (summary + chart + details + performance)
// ============================================================
class _ResultSection extends StatelessWidget {
  final PredictionResult result;
  final List<Map<String, dynamic>> historicalPoints;
  final bool detailsExpanded;
  final VoidCallback onToggleDetails;

  const _ResultSection({
    required this.result,
    required this.historicalPoints,
    required this.detailsExpanded,
    required this.onToggleDetails,
  });

  @override
  Widget build(BuildContext context) {
    final unit = result.target == 'temperature' ? '°C' : 'PSU';
    final modelLabel = result.model == 'linear_regression' ? 'Linear Regression' : 'Random Forest';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Forecast Result', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(height: 20),
              Text('Predicted ${result.target == 'temperature' ? 'Temperature' : 'Salinity'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
              Text('${result.forecast.last.predictedValue}$unit',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _row('Model', modelLabel),
              _row('Forecast Horizon', 'Next ${result.horizon} cycles'),
              _row('Latest Actual Value', '${result.latestActualValue}$unit'),
              _row('Expected Change', '${result.expectedChange >= 0 ? '+' : ''}${result.expectedChange.toStringAsFixed(2)}$unit'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.cyan.shade50, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.insights, color: Colors.cyan.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(result.trendInterpretation, style: const TextStyle(fontSize: 12.5))),
                  ],
                ),
              ),
              if (result.floatId == 'all') ...[
                const SizedBox(height: 8),
                Text(
                  'Chart omitted: "All Floats" mixes multiple floats and cannot be shown as one coherent historical series.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        if (result.floatId != 'all' && historicalPoints.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ForecastChart(result: result, historicalPoints: historicalPoints, unit: unit),
        ],
        const SizedBox(height: 16),
        _SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onToggleDetails,
                child: Row(
                  children: [
                    Icon(detailsExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.cyan.shade700),
                    const SizedBox(width: 4),
                    const Text('Forecast Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
              if (detailsExpanded)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: result.forecast
                        .map((f) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Cycle #${f.cycle}', style: const TextStyle(fontSize: 12.5)),
                                  Text('${f.predictedValue}$unit',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ModelPerformanceCard(result: result),
      ],
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
// Forecast chart (historical solid, forecast dashed-style)
// ============================================================
class _ForecastChart extends StatelessWidget {
  final PredictionResult result;
  final List<Map<String, dynamic>> historicalPoints;
  final String unit;

  const _ForecastChart({required this.result, required this.historicalPoints, required this.unit});

  @override
  Widget build(BuildContext context) {
    final field = result.target;
    final histSpots = <FlSpot>[];
    for (int i = 0; i < historicalPoints.length; i++) {
      final v = historicalPoints[i][field];
      if (v != null) histSpots.add(FlSpot(i.toDouble(), (v as num).toDouble()));
    }
    if (histSpots.isEmpty) return const SizedBox.shrink();

    final lastX = histSpots.last.x;
    final forecastSpots = <FlSpot>[histSpots.last];
    for (int i = 0; i < result.forecast.length; i++) {
      forecastSpots.add(FlSpot(lastX + i + 1, result.forecast[i].predictedValue));
    }

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Forecast Chart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Row(
            children: [
              _legendDot(Colors.cyan.shade700, 'Historical'),
              const SizedBox(width: 14),
              _legendDot(Colors.orange.shade600, 'Forecast'),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem('${s.y.toStringAsFixed(2)}$unit', const TextStyle(color: Colors.white, fontSize: 11)))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: histSpots,
                    isCurved: true,
                    color: Colors.cyan.shade700,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: forecastSpots,
                    isCurved: true,
                    color: Colors.orange.shade600,
                    barWidth: 2.5,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 3, color: c),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );
}

// ============================================================
// Model performance
// ============================================================
class _ModelPerformanceCard extends StatelessWidget {
  final PredictionResult result;
  const _ModelPerformanceCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final m = result.metrics;
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Model Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(height: 20),
          _row('Training Samples', '${m.trainSamples}'),
          _row('Test Samples', '${m.testSamples}'),
          _row('MAE', m.mae != null ? '${m.mae}' : 'Not available'),
          _row('RMSE', m.rmse != null ? '${m.rmse}' : 'Not available'),
          _row('R² Score', m.r2 != null ? '${m.r2}' : 'Not available'),
          if (result.featureImportance != null) ...[
            const SizedBox(height: 10),
            const Text('Feature Importance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...result.featureImportance!.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(width: 120, child: Text(e.key, style: const TextStyle(fontSize: 12))),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (e.value / 100).clamp(0, 1),
                            minHeight: 7,
                            backgroundColor: Colors.grey.shade200,
                            color: Colors.cyan.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${e.value}%', style: const TextStyle(fontSize: 11.5)),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 10),
          Text(
            'Future pressure/latitude/longitude are unknown, so the forecast holds them at the last observed real values.',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
          ),
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
// Prediction history (session-only, real entries)
// ============================================================
class _PredictionHistorySection extends StatelessWidget {
  final List<PredictionHistoryEntry> history;
  const _PredictionHistorySection({required this.history});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Prediction History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          if (history.isEmpty)
            Text('No previous predictions.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
          else
            ...history.map((h) {
              final r = h.result;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.model == 'linear_regression' ? 'Linear Regression' : 'Random Forest',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${r.target == 'temperature' ? 'Temperature' : 'Salinity'} • ${r.floatId == 'all' ? 'All Floats' : r.floatId} • ${r.horizon} cycles',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                    Text('Generated: ${h.generatedAt.day}/${h.generatedAt.month}/${h.generatedAt.year} ${h.generatedAt.hour.toString().padLeft(2, '0')}:${h.generatedAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}