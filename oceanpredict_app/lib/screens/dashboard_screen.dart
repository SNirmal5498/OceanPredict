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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  // ---- Existing real-data state (untouched logic) ----
  String _totalRecords = '...';
  String _activeFloats = '...';
  String _avgTemp = '...';
  double? _avgTempValue;
  String _avgSalinity = '...';
  double? _avgSalinityValue;

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

  Future<void> _loadStats() async {
    final result = await ApiService.getDashboardStats();
    if (!mounted) return;

    if (result['statusCode'] == 200) {
      final data = result['body'];
      setState(() {
        _totalRecords = '${data['total_records']}';
        _activeFloats = '${data['active_floats']}';
        _avgTempValue = (data['avg_temperature'] as num?)?.toDouble();
        _avgSalinityValue = (data['avg_salinity'] as num?)?.toDouble();
        _avgTemp = '${data['avg_temperature']}°C';
        _avgSalinity = '${data['avg_salinity']}';
      });
    }
  }

  // Simple client-side heuristic since there's no backend health-score field.
  // Swap this for a real API value if one is ever added.
  ({int score, String status, Color color}) _computeOceanHealth() {
    if (_avgTempValue == null || _avgSalinityValue == null) {
      return (score: 0, status: 'Loading', color: Colors.grey);
    }
    final tempPenalty = (_avgTempValue! - 20).abs() * 2.2;
    final salPenalty = (_avgSalinityValue! - 35).abs() * 6;
    int score = (100 - tempPenalty - salPenalty).clamp(0, 100).round();

    String status;
    Color color;
    if (score >= 80) {
      status = 'Excellent';
      color = const Color(0xFF2E7D32);
    } else if (score >= 60) {
      status = 'Good';
      color = Colors.cyan.shade700;
    } else if (score >= 40) {
      status = 'Moderate';
      color = Colors.orange.shade700;
    } else {
      status = 'Critical';
      color = Colors.red.shade700;
    }
    return (score: score, status: status, color: color);
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
    final health = _computeOceanHealth();
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
              const SizedBox(height: 24),
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
                  score: health.score,
                  status: health.status,
                  color: health.color,
                ),
              ),
              const SizedBox(height: 20),
              _fadeSlide(
                start: 0.25,
                end: 0.75,
                child: _LatestDatasetCard(totalRecords: _totalRecords),
              ),
              const SizedBox(height: 20),
              _fadeSlide(
                start: 0.3,
                end: 0.8,
                child: const _RecentActivityCard(),
              ),
              const SizedBox(height: 20),
              _fadeSlide(
                start: 0.35,
                end: 0.85,
                child: _QuickActionsSection(isTablet: isTablet),
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
            'Welcome back, Nirmal',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ocean Monitoring Dashboard',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Stat grid + redesigned cards
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

class _StatCard extends StatefulWidget {
  final _StatCardData data;
  const _StatCard({required this.data});

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  double _scale = 1.0;

  void _setScale(double s) => setState(() => _scale = s);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setScale(1.03),
      onExit: (_) => _setScale(1.0),
      child: GestureDetector(
        onTapDown: (_) => _setScale(0.96),
        onTapUp: (_) => _setScale(1.0),
        onTapCancel: () => _setScale(1.0),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.all(16),
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.data.gradient,
                    ),
                  ),
                  child: Icon(widget.data.icon, color: Colors.white, size: 22),
                ),
                const Spacer(),
                Text(
                  widget.data.value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B3C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.data.label,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Ocean Health Score (circular gauge)
// ============================================================
class _OceanHealthCard extends StatelessWidget {
  final int score;
  final String status;
  final Color color;

  const _OceanHealthCard({
    required this.score,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
            width: 84,
            height: 84,
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
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ocean Health',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$score/100',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B3C),
                  ),
                ),
                const SizedBox(height: 4),
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
                      fontSize: 12.5,
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
  final String totalRecords;
  const _LatestDatasetCard({required this.totalRecords});

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
                  'Latest Dataset',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'argo_ocean_data.nc',
                  style: TextStyle(color: Color(0xFF1A2B3C), fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalRecords records  •  2.4 MB',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Text(
            'Today',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Recent Activity
// ============================================================
class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  @override
  Widget build(BuildContext context) {
    final activities = [
      ('Dataset uploaded', Icons.check_circle, Colors.green),
      ('Prediction completed', Icons.check_circle, Colors.green),
      ('Report generated', Icons.check_circle, Colors.green),
    ];

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
            'Recent Activity',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          ...activities.map(
            (a) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(a.$2, color: a.$3, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(a.$1, style: const TextStyle(fontSize: 13.5)),
                  ),
                ],
              ),
            ),
          ),
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
  const _QuickActionsSection({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        'Upload Dataset',
        Icons.upload_file_rounded,
        () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UploadScreen()),
            ),
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