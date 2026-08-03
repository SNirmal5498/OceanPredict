import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final result = await ApiService.getAnalyticsSummary();
    if (!mounted) return;

    if (result['statusCode'] == 200) {
      setState(() {
        _data = result['body'];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Failed to load analytics data'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSectionCard(
                      'Temperature Analysis',
                      Icons.thermostat_outlined,
                      'Average: ${_data!['temperature']['avg']}°C  •  Range: ${_data!['temperature']['min']}°C - ${_data!['temperature']['max']}°C',
                    ),
                    _buildSectionCard(
                      'Salinity Analysis',
                      Icons.water_drop_outlined,
                      'Average: ${_data!['salinity']['avg']} PSU  •  Range: ${_data!['salinity']['min']} - ${_data!['salinity']['max']} PSU',
                    ),
                    _buildSectionCard(
                      'Pressure Analysis',
                      Icons.speed_outlined,
                      'Average: ${_data!['pressure']['avg']} dbar  •  Max depth: ${_data!['pressure']['max_depth']} dbar',
                    ),
                  ],
                ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.cyan.shade700, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }
}