import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'upload_screen.dart';
import 'analytics_screen.dart';
import 'map_screen.dart';
import 'tracker_screen.dart';
import 'prediction_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'admin_screen.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _totalRecords = '...';
  String _activeFloats = '...';
  String _avgTemp = '...';
  String _avgSalinity = '...';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final result = await ApiService.getDashboardStats();
    if (!mounted) return;

    if (result['statusCode'] == 200) {
      final data = result['body'];
      setState(() {
        _totalRecords = '${data['total_records']}';
        _activeFloats = '${data['active_floats']}';
        _avgTemp = '${data['avg_temperature']}°C';
        _avgSalinity = '${data['avg_salinity']}';
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.cyan.shade700,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.cyan.shade700),
              child: const Row(
                children: [
                  Icon(Icons.water, color: Colors.white, size: 40),
                  SizedBox(width: 12),
                  Text(
                    'OceanPredict',
                    style: TextStyle(color: Colors.white, fontSize: 22),
                  ),
                ],
              ),
            ),
            ListTile(
  leading: const Icon(Icons.dashboard_outlined),
  title: const Text('Dashboard'),
  onTap: () => Navigator.pop(context),
),
ListTile(
  leading: const Icon(Icons.upload_file_outlined),
  title: const Text('Upload Dataset'),
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UploadScreen()),
    );
  },
),
ListTile(
  leading: const Icon(Icons.analytics_outlined),
  title: const Text('Analytics'),
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
    );
  },
),
ListTile(
  leading: const Icon(Icons.map_outlined),
  title: const Text('Ocean Map'),
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapScreen()),
    );
  },
),
ListTile(
  leading: const Icon(Icons.route_outlined),
  title: const Text('Float Tracker'),
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TrackerScreen()),
    );
  },
),
ListTile(
  leading: const Icon(Icons.auto_graph_outlined),
  title: const Text('AI Prediction'),
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PredictionScreen()),
    );
  },
),
ListTile(
  leading: const Icon(Icons.description_outlined),
  title: const Text('Reports'),
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReportsScreen()),
    );
  },
),
            const Divider(),
            ListTile(
  leading: const Icon(Icons.settings_outlined),
  title: const Text('Settings'),
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  },
),
ListTile(
  leading: const Icon(Icons.admin_panel_settings_outlined),
  title: const Text('Admin Panel'),
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminScreen()),
    );
  },
),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
body: GridView.count(
  padding: const EdgeInsets.all(16),
  crossAxisCount: 2,
  mainAxisSpacing: 16,
  crossAxisSpacing: 16,
  children: [
    _DashboardCard(
      icon: Icons.storage_outlined,
      label: 'Total Records',
      value: _totalRecords,
    ),
    _DashboardCard(
      icon: Icons.satellite_alt_outlined,
      label: 'Active Floats',
      value: _activeFloats,
    ),
    _DashboardCard(
      icon: Icons.thermostat_outlined,
      label: 'Avg Temperature',
      value: _avgTemp,
    ),
    _DashboardCard(
      icon: Icons.water_drop_outlined,
      label: 'Avg Salinity',
      value: _avgSalinity,
    ),
  ],
),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DashboardCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.cyan.shade700),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}