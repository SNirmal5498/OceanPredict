import 'package:flutter/material.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionCard('Temperature Analysis', Icons.thermostat_outlined,
              'Average: 18.4°C  •  Range: 2°C - 29°C'),
          _buildSectionCard('Salinity Analysis', Icons.water_drop_outlined,
              'Average: 35.1 PSU  •  Range: 33 - 37 PSU'),
          _buildSectionCard('Pressure Analysis', Icons.speed_outlined,
              'Average: 512 dbar  •  Max depth: 1998m'),
          _buildSectionCard('Ocean Health Score', Icons.eco_outlined,
              'Score: 78/100  •  Status: Good'),
          const SizedBox(height: 8),
          Card(
            color: Colors.cyan.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI Insight: Temperature trends show a gradual warming pattern over the last 30 days.',
                    ),
                  ),
                ],
              ),
            ),
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