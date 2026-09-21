import 'dart:math';
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
  bool _detailsExpanded = true;

  _RunState _runState = _RunState.idle;
  String? _errorMessage;
  PredictionResult? _result;

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

    _runPrediction();
  }

  Future<void> _runPrediction({bool isManualRun = false}) async {
    if (_runState == _RunState.preparing || _runState == _RunState.training || _runState == _RunState.generating) {
      return; // no simultaneous requests
    }

    setState(() {
      _runState = _RunState.preparing;
      _errorMessage = null;
      _result = null;
    });

    setState(() => _runState = _RunState.training);
    await Future.delayed(const Duration(milliseconds: 200));
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
        if (isManualRun) {
          _history.insert(0, PredictionHistoryEntry(result: result, generatedAt: DateTime.now()));
        }
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
      onModelChanged: (v) {
        if (_model != v) {
          setState(() => _model = v);
          _runPrediction();
        }
      },
      onTargetChanged: (v) {
        if (_target != v) {
          setState(() => _target = v);
          _runPrediction();
        }
      },
      onFloatChanged: (v) {
        if (_selectedFloat != v) {
          setState(() => _selectedFloat = v);
          _runPrediction();
        }
      },
      onHorizonChanged: (v) {
        if (_horizon != v) {
          setState(() => _horizon = v);
          _runPrediction();
        }
      },
      inputsExpanded: _inputsExpanded,
      onToggleInputs: () => setState(() => _inputsExpanded = !_inputsExpanded),
    );
    final runButton = _RunButton(isBusy: _isBusy, statusText: _statusText, onPressed: () => _runPrediction(isManualRun: true));

    final resultSection = _runState == _RunState.failed
        ? _ErrorCard(message: _errorMessage ?? 'Prediction failed.', onRetry: _runPrediction)
        : _result != null
            ? _ResultSection(
                result: _result!,
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
  final bool detailsExpanded;
  final VoidCallback onToggleDetails;

  const _ResultSection({
    required this.result,
    required this.detailsExpanded,
    required this.onToggleDetails,
  });

  @override
  Widget build(BuildContext context) {
    final unit = result.target == 'temperature' ? '°C' : 'PSU';
    final modelLabel = result.model == 'linear_regression' ? 'Linear Regression' : 'Random Forest';

    final isAllFloats = result.floatId == 'all';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Forecast Result', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (isAllFloats)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.cyan.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Text('Aggregated (All Floats)',
                          style: TextStyle(color: Colors.cyan.shade900, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const Divider(height: 20),
              Text('Predicted ${result.target == 'temperature' ? 'Temperature' : 'Salinity'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
              Text('${result.forecast.last.predictedValue}$unit',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _row('Scope', isAllFloats ? 'Dataset-wide Aggregated Model' : 'Float ${result.floatId}'),
              _row('Model', modelLabel),
              _row('Forecast Horizon', isAllFloats ? '+${result.horizon} horizon steps' : 'Next ${result.horizon} cycles'),
              _row('Latest Observed Value', '${result.latestActualValue}$unit'),
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
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (isAllFloats)
          const _AllFloatsChartNotice()
        else if (result.historicalSeries.isNotEmpty)
          _ForecastChart(result: result, unit: unit),
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
                                  Text(
                                    isAllFloats ? 'Horizon Step +${f.step} (Aggregated)' : 'Cycle #${f.cycle}',
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                  Text('Predicted: ${f.predictedValue}$unit',
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
// All Floats Chart Notice
// ============================================================
class _AllFloatsChartNotice extends StatelessWidget {
  const _AllFloatsChartNotice();

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.cyan.shade700, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Select a specific float to view the historical and forecast timeline.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Forecast chart (Historical solid, Forecast dashed-style)
// ============================================================
class _ForecastChart extends StatelessWidget {
  final PredictionResult result;
  final String unit;

  const _ForecastChart({required this.result, required this.unit});

  @override
  Widget build(BuildContext context) {
    final targetName = result.target == 'temperature' ? 'Temperature' : 'Salinity';
    final title = '$targetName Forecast — ${result.floatId}';

    final histSpots = <FlSpot>[];
    for (final h in result.historicalSeries) {
      histSpots.add(FlSpot(h.cycle.toDouble(), h.value));
    }
    if (histSpots.isEmpty) return const SizedBox.shrink();

    final forecastSpots = <FlSpot>[histSpots.last];
    for (final f in result.forecast) {
      forecastSpots.add(FlSpot(f.cycle.toDouble(), f.predictedValue));
    }

    final allValues = [
      ...result.historicalSeries.map((h) => h.value),
      ...result.forecast.map((f) => f.predictedValue),
    ];
    final minVal = allValues.reduce(min);
    final maxVal = allValues.reduce(max);
    final delta = (maxVal - minVal).abs();
    final padding = delta == 0 ? 1.0 : delta * 0.15;
    final minY = minVal - padding;
    final maxY = maxVal + padding;

    final totalPoints = result.historicalSeries.length + result.forecast.length;
    final contentWidth = (totalPoints * 42.0).clamp(420.0, 10000.0);
    final lastActualCycle = histSpots.last.x;

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Row(
            children: [
              _legendDot(Colors.cyan.shade700, 'Actual', isFilled: true),
              const SizedBox(width: 16),
              _legendDot(Colors.orange.shade600, 'Forecast', isFilled: false),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fixed Left Y-Axis
                SizedBox(
                  width: 55,
                  child: Column(
                    children: [
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            minY: minY,
                            maxY: maxY,
                            minX: 0,
                            maxX: 1,
                            lineBarsData: [],
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                axisNameWidget: Text(
                                  result.target == 'temperature' ? 'Temp (°C)' : 'Sal (PSU)',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                axisNameSize: 16,
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 38,
                                  getTitlesWidget: (val, meta) {
                                    return Text(
                                      val.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 9.5, color: Colors.black87),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Horizontally Scrollable Plot Area
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: contentWidth,
                      child: LineChart(
                        LineChartData(
                          minY: minY,
                          maxY: maxY,
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              axisNameWidget: const Text(
                                'Cycle Number',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              axisNameSize: 16,
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                getTitlesWidget: (val, meta) {
                                  return Text('#${val.toInt()}', style: const TextStyle(fontSize: 9.5));
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: const FlGridData(show: true),
                          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                          extraLinesData: ExtraLinesData(
                            verticalLines: [
                              VerticalLine(
                                x: lastActualCycle,
                                color: Colors.orange.shade700,
                                strokeWidth: 1.5,
                                dashArray: [4, 4],
                                  label: VerticalLineLabel(
                                    show: true,
                                    alignment: Alignment.topRight,
                                    labelResolver: (line) => 'Forecast starts',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      backgroundColor: Colors.orange.shade50.withValues(alpha: 0.8),
                                    ),
                                  ),
                              ),
                            ],
                          ),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (touchedSpots) {
                                if (touchedSpots.isEmpty) return [];
                                final items = <LineTooltipItem?>[];
                                final seenCycles = <int>{};

                                for (final s in touchedSpots) {
                                  final cycleNum = s.x.round();
                                  final isForecast = s.barIndex == 1 && s.spotIndex > 0;

                                  if (seenCycles.contains(cycleNum)) {
                                    items.add(null);
                                    continue;
                                  }
                                  seenCycles.add(cycleNum);

                                  final statusLabel = isForecast ? 'Forecast' : 'Actual';
                                  final valTypeLabel = isForecast ? 'Predicted $targetName' : 'Actual $targetName';
                                  final valStr = '${s.y.toStringAsFixed(2)}$unit';

                                  items.add(
                                    LineTooltipItem(
                                      'Cycle #$cycleNum\n$valTypeLabel: $valStr\nStatus: $statusLabel',
                                      const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  );
                                }
                                return items;
                              },
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: histSpots,
                              isCurved: true,
                              color: Colors.cyan.shade700,
                              barWidth: 3.0,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(show: true, color: Colors.cyan.shade700.withValues(alpha: 0.08)),
                            ),
                            LineChartBarData(
                              spots: forecastSpots,
                              isCurved: true,
                              color: Colors.orange.shade600,
                              barWidth: 3.0,
                              dashArray: [6, 4],
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                  strokeColor: Colors.orange.shade600,
                                ),
                              ),
                              belowBarData: BarAreaData(show: true, color: Colors.orange.shade600.withValues(alpha: 0.08)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label, {required bool isFilled}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? c : Colors.white,
              border: Border.all(color: c, width: 2),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
            const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Forecast assumption: Future pressure, latitude, and longitude are held at their latest observed values because future measurements are unavailable.',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
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
              final modelName = r.model == 'linear_regression' ? 'Linear Regression' : 'Random Forest';
              final targetName = r.target == 'temperature' ? 'Temperature' : 'Salinity';
              final floatName = r.floatId == 'all' ? 'All Floats' : r.floatId;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(modelName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('$targetName • $floatName • ${r.horizon} cycles',
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