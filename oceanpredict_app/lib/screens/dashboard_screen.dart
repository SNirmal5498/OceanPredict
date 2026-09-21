import 'dart:math';
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
import '../services/ocean_health_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  // ---- Active Dataset State ----
  bool _hasActiveDataset = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _datasets = [];
  int? _activeDatasetId;
  String _datasetName = 'No active dataset';
  int _fileSize = 0;
  String _uploadDate = '';
  
  String _totalRecords = '0';
  String _activeFloats = '0';
  String _avgTemp = 'N/A';
  String _avgSalinity = 'N/A';

  OceanHealthResult? _oceanHealth;
  List<Map<String, dynamic>> _recentActivities = [];

  // ---- Animation ----
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _controller.forward();
    _loadStats();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    final statsRes = await ApiService.getDashboardStats();
    final datasetsRes = await ApiService.getDatasets();
    final analyticsRes = await ApiService.getAnalyticsSummary();
    final logsRes = await ApiService.getAdminLogs('');

    if (!mounted) return;

    List<Map<String, dynamic>> loadedDatasets = [];
    if (datasetsRes['statusCode'] == 200 && datasetsRes['body'] is List) {
      loadedDatasets = List<Map<String, dynamic>>.from(datasetsRes['body']);
    }

    List<Map<String, dynamic>> loadedLogs = [];
    if (logsRes['statusCode'] == 200 && logsRes['body'] is List) {
      loadedLogs = List<Map<String, dynamic>>.from(logsRes['body']);
    }

    if (statsRes['statusCode'] == 200 && statsRes['body']?['active'] == true) {
      final data = statsRes['body'];
      final analyticsData = analyticsRes['statusCode'] == 200 ? analyticsRes['body'] : null;

      final temp = analyticsData?['temperature'];
      final sal = analyticsData?['salinity'];
      final pres = analyticsData?['pressure'];

      final tempAvg = (data['avg_temperature'] as num?)?.toDouble();
      final salAvg = (data['avg_salinity'] as num?)?.toDouble();
      final totalRecs = (data['total_records'] as num?)?.toInt() ?? 0;

      OceanHealthResult? health;
      if (tempAvg != null && salAvg != null && totalRecs > 0) {
        health = OceanHealthService.calculate(
          avgTemp: tempAvg,
          minTemp: (temp?['min'] as num?)?.toDouble(),
          maxTemp: (temp?['max'] as num?)?.toDouble(),
          avgSalinity: salAvg,
          minSalinity: (sal?['min'] as num?)?.toDouble(),
          maxSalinity: (sal?['max'] as num?)?.toDouble(),
          maxPressure: (pres?['max_depth'] as num?)?.toDouble(),
          observationCount: totalRecs,
        );
      }

      final activeId = (data['dataset_id'] as num?)?.toInt();
      final activeName = data['dataset_name'] as String? ?? 'Dataset';

      if (activeId != null && !loadedDatasets.any((d) => d['id'] == activeId)) {
        loadedDatasets.insert(0, {
          'id': activeId,
          'filename': activeName,
          'total_records': totalRecs,
        });
      }

      setState(() {
        _hasActiveDataset = true;
        _activeDatasetId = activeId;
        _datasetName = activeName;
        _fileSize = data['file_size'] ?? 0;
        _uploadDate = data['upload_date'] ?? '';
        _totalRecords = '${data['total_records'] ?? 0}';
        _activeFloats = '${data['active_floats'] ?? 0}';
        _avgTemp = tempAvg != null ? '${tempAvg.toStringAsFixed(2)}°C' : 'N/A';
        _avgSalinity = salAvg != null ? salAvg.toStringAsFixed(2) : 'N/A';
        _oceanHealth = health;
        _datasets = loadedDatasets;
        _recentActivities = loadedLogs;
        _isLoading = false;
      });
    } else {
      setState(() {
        _hasActiveDataset = false;
        _activeDatasetId = null;
        _datasetName = 'No active dataset';
        _fileSize = 0;
        _uploadDate = '';
        _totalRecords = '0';
        _activeFloats = '0';
        _avgTemp = 'N/A';
        _avgSalinity = 'N/A';
        _oceanHealth = null;
        _datasets = loadedDatasets;
        _recentActivities = loadedLogs;
        _isLoading = false;
      });
    }
  }

  Future<void> _switchDataset(int datasetId) async {
    final res = await ApiService.setActiveDataset(datasetId);
    if (res['statusCode'] == 200) {
      await _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Active dataset updated'),
            backgroundColor: Colors.cyan,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Animation<double> _stagger(double start, double end) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  Widget _fadeSlide({
    required Widget child,
    required double start,
    required double end,
  }) {
    final anim = _stagger(start, end);
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 700;

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
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UploadScreen()),
                );
                _loadStats();
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
      backgroundColor: const Color(0xFFF3FAFC),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : 16,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fadeSlide(
                start: 0.0,
                end: 0.5,
                child: _WelcomeHeader(greeting: _greeting()),
              ),
              const SizedBox(height: 16),
              if (_datasets.isNotEmpty) ...[
                _fadeSlide(
                  start: 0.05,
                  end: 0.55,
                  child: _DatasetSelectorCard(
                    datasets: _datasets,
                    activeDatasetId: _activeDatasetId,
                    onChanged: (id) => _switchDataset(id),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!_hasActiveDataset && !_isLoading) ...[
                _fadeSlide(
                  start: 0.1,
                  end: 0.6,
                  child: _NoActiveDatasetCard(
                    onUploadTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UploadScreen()),
                      );
                      _loadStats();
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _fadeSlide(
                start: 0.1,
                end: 0.6,
                child: _StatGrid(
                  isTablet: isTablet,
                  totalRecords: _totalRecords,
                  activeFloats: _activeFloats,
                  avgTemp: _avgTemp,
                  avgSalinity: _avgSalinity,
                ),
              ),
              const SizedBox(height: 20),
              _fadeSlide(
                start: 0.2,
                end: 0.7,
                child: _OceanHealthCard(
                  health: _oceanHealth,
                  hasActiveDataset: _hasActiveDataset,
                ),
              ),
              const SizedBox(height: 20),
              _fadeSlide(
                start: 0.25,
                end: 0.75,
                child: _LatestDatasetCard(
                  hasActive: _hasActiveDataset,
                  datasetName: _datasetName,
                  totalRecords: _totalRecords,
                  fileSizeLabel: _formatBytes(_fileSize),
                  uploadDate: _uploadDate,
                  onUploadTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const UploadScreen()),
                    );
                    _loadStats();
                  },
                ),
              ),
              const SizedBox(height: 20),
              _fadeSlide(
                start: 0.3,
                end: 0.8,
                child: _RecentActivityCard(activities: _recentActivities),
              ),
              const SizedBox(height: 20),
              _fadeSlide(
                start: 0.35,
                end: 0.85,
                child: _QuickActionsSection(
                  isTablet: isTablet,
                  onUploadReturn: _loadStats,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Welcome header
// ============================================================
class _WelcomeHeader extends StatelessWidget {
  final String greeting;
  const _WelcomeHeader({required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.cyan.shade700, const Color.fromARGB(255, 4, 158, 164)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 5, 177, 183).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'OceanPredict Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Real-Time Oceanographic Data & Floats Monitoring',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Dataset Selector Dropdown Card
// ============================================================
class _DatasetSelectorCard extends StatelessWidget {
  final List<Map<String, dynamic>> datasets;
  final int? activeDatasetId;
  final ValueChanged<int> onChanged;

  const _DatasetSelectorCard({
    required this.datasets,
    required this.activeDatasetId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.layers_rounded, color: Colors.cyan.shade700, size: 22),
          const SizedBox(width: 10),
          const Text(
            'Current Dataset:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: activeDatasetId,
                isExpanded: true,
                hint: const Text('Select dataset'),
                items: datasets.map((d) {
                  final id = d['id'] as int;
                  final name = d['filename'] as String? ?? 'Dataset #$id';
                  return DropdownMenuItem<int>(
                    value: id,
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) onChanged(val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// No Active Dataset Empty State Card
// ============================================================
class _NoActiveDatasetCard extends StatelessWidget {
  final VoidCallback onUploadTap;

  const _NoActiveDatasetCard({required this.onUploadTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active dataset',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Upload an oceanographic dataset to view live statistics and float analysis.',
                  style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onUploadTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upload Dataset'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Stat grid + cards
// ============================================================
class _StatGrid extends StatelessWidget {
  final bool isTablet;
  final String totalRecords;
  final String activeFloats;
  final String avgTemp;
  final String avgSalinity;

  const _StatGrid({
    required this.isTablet,
    required this.totalRecords,
    required this.activeFloats,
    required this.avgTemp,
    required this.avgSalinity,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatCardData(
        icon: Icons.storage_rounded,
        label: 'Total Records',
        value: totalRecords,
        gradient: [Colors.cyan.shade400, Colors.cyan.shade700],
      ),
      _StatCardData(
        icon: Icons.satellite_alt_rounded,
        label: 'Active Floats',
        value: activeFloats,
        gradient: [Colors.blue.shade400, Colors.blue.shade700],
      ),
      _StatCardData(
        icon: Icons.thermostat_rounded,
        label: 'Avg Temperature',
        value: avgTemp,
        gradient: [Colors.orange.shade400, Colors.deepOrange.shade400],
      ),
      _StatCardData(
        icon: Icons.water_drop_rounded,
        label: 'Avg Salinity',
        value: avgSalinity,
        gradient: [Colors.teal.shade400, Colors.teal.shade700],
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isTablet ? 4 : 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: isTablet ? 1.1 : 1.25,
      children: items.map((d) => _StatCard(data: d)).toList(),
    );
  }
}

class _StatCardData {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradient;

  _StatCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(colors: data.gradient),
            ),
            child: Icon(data.icon, color: Colors.white, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2B3C),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Ocean Health Card (Real service or Not available)
// ============================================================
class _OceanHealthCard extends StatelessWidget {
  final OceanHealthResult? health;
  final bool hasActiveDataset;

  const _OceanHealthCard({
    required this.health,
    required this.hasActiveDataset,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasActiveDataset) {
      return _buildCard(
        scoreText: 'No Data',
        statusText: 'No Dataset',
        color: Colors.grey.shade600,
      );
    }

    if (health == null || health!.status == 'No Data' || health!.status == 'Insufficient Data') {
      return _buildCard(
        scoreText: 'Not Evaluated',
        statusText: 'Insufficient Data',
        color: Colors.amber.shade700,
      );
    }

    if (health!.status == 'Error') {
      return _buildCard(
        scoreText: 'Error',
        statusText: 'Calculation Error',
        color: Colors.red.shade700,
      );
    }

    final score = health!.score;
    final status = health!.status;
    final color = health!.color;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _GaugePainter(
                percentage: score / 100,
                color: color,
              ),
              child: Center(
                child: Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ocean Health Index',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$score / 100',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B3C),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Status: $status',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            'View Details',
                            style: TextStyle(
                              color: Colors.cyan.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 18, color: Colors.cyan.shade700),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String scoreText,
    required String statusText,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.health_and_safety_outlined, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ocean Health Index',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  scoreText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Status: $statusText',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
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
}

class _GaugePainter extends CustomPainter {
  final double percentage; // 0.0 - 1.0
  final Color color;

  _GaugePainter({required this.percentage, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 7;

    final backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, backgroundPaint);

    final sweep = 2 * pi * percentage.clamp(0, 1);
    final foregroundPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + (sweep == 0 ? 0.001 : sweep),
        colors: [color.withValues(alpha: 0.45), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweep,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.color != color;
  }
}

// ============================================================
// Latest Dataset card
// ============================================================
class _LatestDatasetCard extends StatelessWidget {
  final bool hasActive;
  final String datasetName;
  final String totalRecords;
  final String fileSizeLabel;
  final String uploadDate;
  final VoidCallback onUploadTap;

  const _LatestDatasetCard({
    required this.hasActive,
    required this.datasetName,
    required this.totalRecords,
    required this.fileSizeLabel,
    required this.uploadDate,
    required this.onUploadTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [Colors.cyan.shade400, Colors.blue.shade600],
              ),
            ),
            child: const Icon(Icons.description_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Dataset',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  datasetName,
                  style: const TextStyle(
                    color: Color(0xFF1A2B3C),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  hasActive ? '$totalRecords records  •  $fileSizeLabel' : 'No dataset active',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          if (hasActive)
            Text(
              uploadDate.split(' ').first,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
            )
          else
            TextButton(
              onPressed: onUploadTap,
              child: const Text('Upload'),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// Recent Activity Card (Real activities, no invented names)
// ============================================================
class _RecentActivityCard extends StatelessWidget {
  final List<Map<String, dynamic>> activities;

  const _RecentActivityCard({required this.activities});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent System Activity',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No recent activities recorded.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            )
          else
            ...activities.take(5).map((a) {
              final event = a['event'] ?? 'System Event';
              final time = a['timestamp'] ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        event,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (time.isNotEmpty)
                      Text(
                        time.split(' ').first,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ============================================================
// Quick Actions
// ============================================================
class _QuickActionsSection extends StatelessWidget {
  final bool isTablet;
  final VoidCallback onUploadReturn;

  const _QuickActionsSection({
    required this.isTablet,
    required this.onUploadReturn,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        'Upload Dataset',
        Icons.upload_file_rounded,
        () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UploadScreen()),
          );
          onUploadReturn();
        },
      ),
      (
        'View Analytics',
        Icons.analytics_rounded,
        () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
            ),
      ),
      (
        'Open Ocean Map',
        Icons.map_rounded,
        () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MapScreen()),
            ),
      ),
      (
        'Generate Report',
        Icons.description_rounded,
        () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportsScreen()),
            ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Quick Actions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isTablet ? 4 : 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: actions
              .map((a) => _QuickActionButton(
                    label: a.$1,
                    icon: a.$2,
                    onTap: a.$3,
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.cyan.shade100),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.cyan.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}