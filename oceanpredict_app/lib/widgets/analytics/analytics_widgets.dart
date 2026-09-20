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
  final int recordCount;
  final int floatCount;
  final String? fileSizeText;

  const AnalyticsHeader({
    super.key,
    required this.datasetName,
    required this.recordCount,
    required this.floatCount,
    this.fileSizeText,
  });

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
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.storage_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dataset: ${datasetName ?? 'Active Dataset'}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$recordCount record${recordCount == 1 ? '' : 's'}  •  $floatCount float${floatCount == 1 ? '' : 's'}${fileSizeText != null && fileSizeText!.isNotEmpty ? '  •  $fileSizeText' : ''}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

// ============================================================
// Filter panel
// ============================================================
class FilterPanel extends StatelessWidget {
  final List<String> floatIds;
  final String? selectedFloatId;
  final ValueChanged<String?> onFloatChanged;
  final TextEditingController minDepthController;
  final TextEditingController maxDepthController;
  final bool hasTimestamps;
  final String dateRangeText;
  final VoidCallback onApply;
  final VoidCallback onReset;

  const FilterPanel({
    super.key,
    required this.floatIds,
    required this.selectedFloatId,
    required this.onFloatChanged,
    required this.minDepthController,
    required this.maxDepthController,
    this.hasTimestamps = false,
    this.dateRangeText = 'Timestamp unavailable',
    required this.onApply,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('All Floats')),
      ...floatIds.map((id) => DropdownMenuItem(value: id, child: Text('Float $id', overflow: TextOverflow.ellipsis))),
    ];

    final effectiveValue = (selectedFloatId != null && (selectedFloatId == 'all' || floatIds.contains(selectedFloatId)))
        ? selectedFloatId
        : 'all';

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: effectiveValue,
            decoration: const InputDecoration(
              labelText: 'Float ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: items,
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
          Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: hasTimestamps ? 1.0 : 0.55,
                  child: IgnorePointer(
                    ignoring: !hasTimestamps,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date Range',
                        enabled: hasTimestamps,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        fillColor: hasTimestamps ? null : Colors.grey.shade100,
                        filled: !hasTimestamps,
                      ),
                      child: Text(
                        hasTimestamps ? dateRangeText : 'Date filtering unavailable',
                        style: TextStyle(fontSize: 12, color: hasTimestamps ? Colors.black87 : Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Opacity(
                  opacity: 0.55,
                  child: IgnorePointer(
                    ignoring: true,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Region',
                        enabled: false,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        fillColor: Colors.grey.shade100,
                        filled: true,
                      ),
                      child: Text(
                        'Region filtering unavailable',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!hasTimestamps)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(
                'Date filtering unavailable because this dataset has no timestamp field.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 10),
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
          Text('Average: $avg', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          if (showMinMax) ...[
            const SizedBox(height: 2),
            Text('Min: $min', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            Text('Max: $max', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          ] else ...[
            const SizedBox(height: 2),
            Text('Max Depth: $max', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// Ocean Health Card
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
              (e) {
                final val = e.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 140, child: Text(e.key, style: const TextStyle(fontSize: 12.5))),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: val == null ? 0 : (val / 100).clamp(0, 1),
                            minHeight: 7,
                            backgroundColor: Colors.grey.shade200,
                            color: val == null ? Colors.transparent : Colors.cyan.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 32,
                        child: Text(
                          val == null ? 'N/A' : '${val.round()}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: val == null ? FontWeight.bold : FontWeight.normal,
                            color: val == null ? Colors.grey.shade600 : Colors.black87,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                );
              },
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
            Text('Not enough data available to generate insights.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
          else
            ...insights.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
  final double depth;
  final String expectedRange;
  final String severity;

  AnomalyEntry({
    required this.parameter,
    required this.floatId,
    required this.value,
    required this.depth,
    required this.expectedRange,
    required this.severity,
  });
}

class AnomalyCard extends StatelessWidget {
  final List<AnomalyEntry> anomalies;
  final bool hasSufficientData;

  const AnomalyCard({
    super.key,
    required this.anomalies,
    this.hasSufficientData = true,
  });

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
          if (!hasSufficientData)
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Insufficient data for anomaly detection (minimum 3 observations required).',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                  ),
                ),
              ],
            )
          else if (anomalies.isEmpty)
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                SizedBox(width: 8),
                Text('No significant anomalies detected in active dataset.', style: TextStyle(fontSize: 13)),
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
                    Text(
                      'Float ${a.floatId.isEmpty || a.floatId == 'all' ? 'F001' : a.floatId}  •  Depth: ${a.depth.toStringAsFixed(1)} dbar  •  Value: ${a.value.toStringAsFixed(2)}${a.parameter == 'Temperature' ? '°C' : ' PSU'}  •  Expected range: ${a.expectedRange}',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
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
// Analysis Summary
// ============================================================
class AnalysisSummaryCard extends StatelessWidget {
  final int observations;
  final int floatCount;
  final String dateRange;
  final String avgTemp;
  final String avgSalinity;
  final String maxDepth;
  final String anomalyStatus;

  const AnalysisSummaryCard({
    super.key,
    required this.observations,
    required this.floatCount,
    required this.dateRange,
    required this.avgTemp,
    required this.avgSalinity,
    required this.maxDepth,
    required this.anomalyStatus,
  });

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
              ),
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
          row('Anomalies Detected', anomalyStatus),
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
