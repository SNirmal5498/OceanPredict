import 'package:flutter/material.dart';
import '../../services/ocean_health_service.dart';

// ============================================================
// Shared soft card shell
// ============================================================
class SoftCard extends StatelessWidget {
  final Widget child;
  const SoftCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String title;
  final IconData? icon;
  const SectionHeading({super.key, required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.cyan.shade700),
            const SizedBox(width: 6),
          ],
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
        ],
      ),
    );
  }
}

// ============================================================
// Analytics header
// ============================================================
class AnalyticsHeader extends StatelessWidget {
  final String? datasetName;
  final int? recordCount;

  const AnalyticsHeader({super.key, this.datasetName, this.recordCount});

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
          colors: [Colors.cyan.shade700, Colors.cyan.shade900],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.shade900.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ocean Analytics',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Understand ocean conditions through data-driven insights',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
          ),
          if (datasetName != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.satellite_alt, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Float: $datasetName${recordCount != null ? '  •  $recordCount readings' : ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// Filter panel
// ============================================================
class FilterPanel extends StatelessWidget {
  final List<String> floatIds;
  final String? selectedFloatId;
  final ValueChanged<String?> onFloatChanged;
  final TextEditingController minDepthController;
  final TextEditingController maxDepthController;
  final VoidCallback onApply;
  final VoidCallback onReset;

  const FilterPanel({
    super.key,
    required this.floatIds,
    required this.selectedFloatId,
    required this.onFloatChanged,
    required this.minDepthController,
    required this.maxDepthController,
    required this.onApply,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedFloatId,
            decoration: const InputDecoration(
              labelText: 'Float ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: floatIds
                .map((id) => DropdownMenuItem(value: id, child: Text(id, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: onFloatChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: minDepthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Min Depth (dbar)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: maxDepthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max Depth (dbar)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: 0.5,
            child: IgnorePointer(
              child: Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date Range',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: const Text('Not available yet', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Region',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: const Text('Not available yet', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              'Date Range and Region filters need extra dataset fields not yet stored by the backend.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onReset,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Reset Filters'),
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
// Statistic card (Temperature / Salinity / Pressure)
// ============================================================
class StatisticCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String avg;
  final String min;
  final String max;
  final bool showMinMax;

  const StatisticCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.avg,
    required this.min,
    required this.max,
    this.showMinMax = true,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: color.withValues(alpha: 0.12)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
            ],
          ),
          const SizedBox(height: 10),
          Text('Average: $avg', style: const TextStyle(fontSize: 13)),
          if (showMinMax) ...[
            Text('Min: $min', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            Text('Max: $max', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          ] else
            Text('Max: $max', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// ============================================================
// Ocean Health Card (uses OceanHealthResult from the service file)
// ============================================================
class OceanHealthCard extends StatelessWidget {
  final OceanHealthResult result;
  const OceanHealthCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 78,
                height: 78,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 78,
                      height: 78,
                      child: CircularProgressIndicator(
                        value: result.score / 100,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey.shade200,
                        color: result.color,
                      ),
                    ),
                    Text('${result.score}',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: result.color)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ocean Health Score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('${result.score}/100', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: result.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Status: ${result.status}',
                          style: TextStyle(color: result.color, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (result.factors.isNotEmpty) ...[
            const Divider(height: 26),
            ...result.factors.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 140, child: Text(e.key, style: const TextStyle(fontSize: 12.5))),
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
                    Text('${e.value.round()}', style: const TextStyle(fontSize: 11.5)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// AI Insight Card
// ============================================================
class AIInsightCard extends StatelessWidget {
  final List<String> insights;
  const AIInsightCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.orange.shade600, size: 18),
              const SizedBox(width: 8),
              const Text('AI Ocean Insights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          if (insights.isEmpty)
            Text('Not enough data yet to generate insights.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
          else
            ...insights.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontSize: 13)),
                    Expanded(child: Text(s, style: const TextStyle(fontSize: 13))),
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
// Anomaly Card
// ============================================================
class AnomalyEntry {
  final String parameter;
  final String floatId;
  final double value;
  final String expectedRange;
  final String severity;

  AnomalyEntry({
    required this.parameter,
    required this.floatId,
    required this.value,
    required this.expectedRange,
    required this.severity,
  });
}

class AnomalyCard extends StatelessWidget {
  final List<AnomalyEntry> anomalies;
  const AnomalyCard({super.key, required this.anomalies});

  Color _severityColor(String s) {
    switch (s) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      default:
        return Colors.amber.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Detected Anomalies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          if (anomalies.isEmpty)
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                SizedBox(width: 8),
                Text('No significant anomalies detected.', style: TextStyle(fontSize: 13)),
              ],
            )
          else
            ...anomalies.map(
              (a) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _severityColor(a.severity).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _severityColor(a.severity).withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${a.parameter} anomaly', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _severityColor(a.severity),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(a.severity, style: const TextStyle(color: Colors.white, fontSize: 10.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Float ${a.floatId}  •  Value: ${a.value.toStringAsFixed(2)}  •  Expected: ${a.expectedRange}',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
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
// Analysis Summary
// ============================================================
class AnalysisSummaryCard extends StatelessWidget {
  final int observations;
  final int floatCount;
  final String dateRange;
  final String avgTemp;
  final String avgSalinity;
  final String maxDepth;
  final int anomalyCount;

  const AnalysisSummaryCard({
    super.key,
    required this.observations,
    required this.floatCount,
    required this.dateRange,
    required this.avgTemp,
    required this.avgSalinity,
    required this.maxDepth,
    required this.anomalyCount,
  });

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
            ],
          ),
        );

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Analysis Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          row('Observations Analyzed', '$observations'),
          row('Number of Floats', '$floatCount'),
          row('Date Range', dateRange),
          row('Average Temperature', avgTemp),
          row('Average Salinity', avgSalinity),
          row('Maximum Depth', maxDepth),
          row('Anomalies Detected', '$anomalyCount'),
        ],
      ),
    );
  }
}

// ============================================================
// Loading skeleton
// ============================================================
class SkeletonBlock extends StatelessWidget {
  final double height;
  const SkeletonBlock({super.key, this.height = 90});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}