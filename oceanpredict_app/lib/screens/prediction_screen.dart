import 'package:flutter/material.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  String _selectedModel = 'Linear Regression';
  String _selectedTarget = 'Temperature';
  String _selectedFloat = 'All Floats';
  String _selectedHorizon = 'Next 5 Cycles';

  bool _hasResult = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Prediction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ----------------------------------------------------------
            // HEADER
            // ----------------------------------------------------------

            const Text(
              'Forecast future ocean conditions using machine learning',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 20),

            // ----------------------------------------------------------
            // DATASET INFORMATION
            // ----------------------------------------------------------

            _sectionTitle(
              'Dataset Information',
              Icons.dataset,
            ),

            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _infoItem(
                        'Records',
                        'N/A',
                        Icons.table_rows,
                      ),
                    ),
                    Expanded(
                      child: _infoItem(
                        'Floats',
                        'N/A',
                        Icons.sensors,
                      ),
                    ),
                    Expanded(
                      child: _infoItem(
                        'Date Range',
                        'N/A',
                        Icons.calendar_month,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ----------------------------------------------------------
            // PREDICTION SETUP
            // ----------------------------------------------------------

            _sectionTitle(
              'Prediction Setup',
              Icons.settings_suggest,
            ),

            const SizedBox(height: 12),

            // MODEL
            const Text(
              'Select Model',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: _selectedModel,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.auto_graph),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Linear Regression',
                  child: Text('Linear Regression'),
                ),
                DropdownMenuItem(
                  value: 'Random Forest',
                  child: Text('Random Forest'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _selectedModel = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // TARGET
            const Text(
              'Prediction Target',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: _selectedTarget,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.thermostat),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Temperature',
                  child: Text('Temperature'),
                ),
                DropdownMenuItem(
                  value: 'Salinity',
                  child: Text('Salinity'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _selectedTarget = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // FLOAT
            const Text(
              'Select Float',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: _selectedFloat,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.sensors),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'All Floats',
                  child: Text('All Floats'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _selectedFloat = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // FORECAST HORIZON
            const Text(
              'Forecast Horizon',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: _selectedHorizon,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timeline),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Next 1 Cycle',
                  child: Text('Next 1 Cycle'),
                ),
                DropdownMenuItem(
                  value: 'Next 3 Cycles',
                  child: Text('Next 3 Cycles'),
                ),
                DropdownMenuItem(
                  value: 'Next 5 Cycles',
                  child: Text('Next 5 Cycles'),
                ),
                DropdownMenuItem(
                  value: 'Next 10 Cycles',
                  child: Text('Next 10 Cycles'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _selectedHorizon = value;
                });
              },
            ),

            const SizedBox(height: 24),

            // ----------------------------------------------------------
            // RUN PREDICTION
            // ----------------------------------------------------------

            ElevatedButton.icon(
              onPressed: _runPrediction,
              icon: const Icon(Icons.auto_graph),
              label: const Text('Run Prediction'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ----------------------------------------------------------
            // RESULT
            // ----------------------------------------------------------

            if (_hasResult) ...[
              _sectionTitle(
                'Prediction Result',
                Icons.analytics,
              ),

              const SizedBox(height: 10),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _resultRow(
                        'Model',
                        _selectedModel,
                      ),
                      _resultRow(
                        'Target',
                        _selectedTarget,
                      ),
                      _resultRow(
                        'Float',
                        _selectedFloat,
                      ),
                      _resultRow(
                        'Forecast',
                        _selectedHorizon,
                      ),

                      const Divider(),

                      const SizedBox(height: 8),

                      const Text(
                        'No prediction available yet.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        'The machine-learning backend will be connected in the next step.',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --------------------------------------------------------
              // FORECAST CHART
              // --------------------------------------------------------

              _sectionTitle(
                'Forecast',
                Icons.show_chart,
              ),

              const SizedBox(height: 10),

              Card(
                child: Container(
                  height: 220,
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.show_chart,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Forecast chart will appear here',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Waiting for a real ML prediction.',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --------------------------------------------------------
              // MODEL PERFORMANCE
              // --------------------------------------------------------

              _sectionTitle(
                'Model Performance',
                Icons.speed,
              ),

              const SizedBox(height: 10),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: const [
                      _PerformanceRow(
                        label: 'MAE',
                        value: 'N/A',
                      ),
                      _PerformanceRow(
                        label: 'RMSE',
                        value: 'N/A',
                      ),
                      _PerformanceRow(
                        label: 'R² Score',
                        value: 'N/A',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --------------------------------------------------------
              // TREND INTERPRETATION
              // --------------------------------------------------------

              _sectionTitle(
                'Trend Interpretation',
                Icons.insights,
              ),

              const SizedBox(height: 10),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No prediction is available yet. '
                          'Trend interpretation will be generated '
                          'from the real model output.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ================================================================
  // RUN PREDICTION
  // ================================================================

  void _runPrediction() {
    setState(() {
      _hasResult = true;
    });
  }

  // ================================================================
  // SECTION TITLE
  // ================================================================

  Widget _sectionTitle(
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.cyan.shade700,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ================================================================
  // INFORMATION ITEM
  // ================================================================

  Widget _infoItem(
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.cyan.shade700,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // ================================================================
  // RESULT ROW
  // ================================================================

  Widget _resultRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// MODEL PERFORMANCE ROW
// ==================================================================

class _PerformanceRow extends StatelessWidget {
  final String label;
  final String value;

  const _PerformanceRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}