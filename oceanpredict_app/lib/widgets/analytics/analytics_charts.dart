import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'analytics_widgets.dart';

class DepthReading {
  final double temperature;
  final double salinity;
  final double pressure;
  final int cycleNumber;
  final String floatId;
  final String? timestamp;

  DepthReading({
    required this.temperature,
    required this.salinity,
    required this.pressure,
    required this.cycleNumber,
    required this.floatId,
    this.timestamp,
  });
}

// ============================================================
// Axis padding helper
// ============================================================
class ChartAxisPadding {
  static (double minPadded, double maxPadded) padRange(
    double minVal,
    double maxVal, {
    double paddingFactor = 0.08,
    double minSpan = 1.0,
  }) {
    final span = maxVal - minVal;
    if (span.abs() < 1e-6) {
      final pad = (minVal.abs() * paddingFactor).clamp(minSpan, 100.0);
      return (minVal - pad, maxVal + pad);
    } else {
      final pad = span * paddingFactor;
      return (minVal - pad, maxVal + pad);
    }
  }
}

// ============================================================
// Layout wrapper for Fixed Left Y-Axis + Horizontal Scroll Plot
// ============================================================
class FixedYAxisChartLayout extends StatefulWidget {
  final Widget yAxisWidget;
  final Widget chartWidget;
  final double contentWidth;
  final double yAxisWidth;
  final double chartHeight;

  const FixedYAxisChartLayout({
    super.key,
    required this.yAxisWidget,
    required this.chartWidget,
    required this.contentWidth,
    this.yAxisWidth = 62.0,
    this.chartHeight = 250.0,
  });

  @override
  State<FixedYAxisChartLayout> createState() => _FixedYAxisChartLayoutState();
}

class _FixedYAxisChartLayoutState extends State<FixedYAxisChartLayout> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalAvailable = constraints.maxWidth;
        final availableForChart = (totalAvailable - widget.yAxisWidth).clamp(100.0, 10000.0);
        final targetWidth = widget.contentWidth > availableForChart
            ? widget.contentWidth
            : availableForChart;
        final isScrollable = targetWidth > availableForChart;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. FIXED LEFT Y-AXIS (Never scrolls horizontally)
                SizedBox(
                  width: widget.yAxisWidth,
                  height: widget.chartHeight,
                  child: widget.yAxisWidget,
                ),

                // 2. HORIZONTALLY SCROLLABLE PLOT AREA & X-AXIS
                Expanded(
                  child: SizedBox(
                    height: widget.chartHeight + 16.0,
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: isScrollable,
                      trackVisibility: isScrollable,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Container(
                          width: targetWidth,
                          height: widget.chartHeight + 16.0,
                          padding: const EdgeInsets.only(bottom: 16.0), // Keeps scrollbar below X-axis labels!
                          child: widget.chartWidget,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (isScrollable) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.swap_horiz_rounded, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Scroll horizontally to inspect graph',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

// ============================================================
// Temperature vs Depth
// ============================================================
class TemperatureDepthChart extends StatelessWidget {
  final List<DepthReading> readings;
  const TemperatureDepthChart({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const SoftCard(child: Text('No data available for profile analysis.'));
    }

    if (readings.length < 2) {
      final r = readings.first;
      return SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Temperature vs Depth', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.cyan.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.cyan.shade800, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Insufficient observations for profile chart analysis (1 reading: ${r.temperature}°C at ${r.pressure} dbar).',
                      style: TextStyle(color: Colors.cyan.shade900, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final temps = readings.map((r) => r.temperature).toList();
    final press = readings.map((r) => r.pressure).toList();

    final minTemp = temps.reduce((a, b) => a < b ? a : b);
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);

    final minPres = press.reduce((a, b) => a < b ? a : b);
    final maxPres = press.reduce((a, b) => a > b ? a : b);

    final (minX, maxX) = ChartAxisPadding.padRange(minTemp, maxTemp, paddingFactor: 0.08);
    final (minPaddedPres, maxPaddedPres) = ChartAxisPadding.padRange(minPres, maxPres, paddingFactor: 0.08, minSpan: 5.0);

    final minY = -maxPaddedPres;
    final maxY = -minPaddedPres;

    final spots = readings.map((r) => ScatterSpot(r.temperature, -r.pressure)).toList();
    final double contentWidth = (readings.length * 22.0).clamp(450.0, 15000.0);

    // Fixed Left Y-Axis
    final yAxisWidget = Column(
      children: [
        SizedBox(
          height: 206, // Matches plot height of right chart (250 total - 44 bottom titles)
          child: ScatterChart(
            ScatterChartData(
              minY: minY,
              maxY: maxY,
              minX: 0,
              maxX: 1,
              scatterSpots: const [],
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: const Text('Depth (dbar)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  axisNameSize: 18,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) {
                      final d = (-value).round();
                      if (d < 0) return const SizedBox();
                      return Text('$d', style: const TextStyle(fontSize: 10));
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
        const SizedBox(height: 44), // Spacer matching X-axis reserved size
      ],
    );

    // Scrollable Right Chart
    final chartWidget = ScatterChart(
      ScatterChartData(
        clipData: const FlClipData.none(),
        scatterSpots: spots,
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('Temperature (°C)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            axisNameSize: 18,
            sideTitles: SideTitles(showTitles: true, reservedSize: 26),
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
        scatterTouchData: ScatterTouchData(
          touchTooltipData: ScatterTouchTooltipData(
            getTooltipItems: (spot) {
              final idx = spots.indexOf(spot);
              final r = idx >= 0 && idx < readings.length ? readings[idx] : null;
              return ScatterTooltipItem(
                r != null
                    ? '${r.temperature.toStringAsFixed(1)}°C at ${(-spot.y).round()} dbar\n'
                        'Float ${r.floatId} • Cycle #${r.cycleNumber}'
                    : '${spot.x.toStringAsFixed(1)}°C at ${(-spot.y).round()} dbar',
                textStyle: const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
      ),
    );

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Temperature vs Depth', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          FixedYAxisChartLayout(
            yAxisWidget: yAxisWidget,
            chartWidget: chartWidget,
            contentWidth: contentWidth,
            chartHeight: 250.0,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Salinity vs Depth
// ============================================================
class SalinityDepthChart extends StatelessWidget {
  final List<DepthReading> readings;
  const SalinityDepthChart({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const SoftCard(child: Text('No data available for profile analysis.'));
    }

    if (readings.length < 2) {
      final r = readings.first;
      return SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Salinity vs Depth', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.cyan.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.cyan.shade800, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Insufficient observations for profile chart analysis (1 reading: ${r.salinity} PSU at ${r.pressure} dbar).',
                      style: TextStyle(color: Colors.cyan.shade900, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final sals = readings.map((r) => r.salinity).toList();
    final press = readings.map((r) => r.pressure).toList();

    final minSal = sals.reduce((a, b) => a < b ? a : b);
    final maxSal = sals.reduce((a, b) => a > b ? a : b);

    final minPres = press.reduce((a, b) => a < b ? a : b);
    final maxPres = press.reduce((a, b) => a > b ? a : b);

    final (minX, maxX) = ChartAxisPadding.padRange(minSal, maxSal, paddingFactor: 0.08);
    final (minPaddedPres, maxPaddedPres) = ChartAxisPadding.padRange(minPres, maxPres, paddingFactor: 0.08, minSpan: 5.0);

    final minY = -maxPaddedPres;
    final maxY = -minPaddedPres;

    final spots = readings.map((r) => ScatterSpot(r.salinity, -r.pressure)).toList();
    final double contentWidth = (readings.length * 22.0).clamp(450.0, 15000.0);

    // Fixed Left Y-Axis
    final yAxisWidget = Column(
      children: [
        SizedBox(
          height: 206,
          child: ScatterChart(
            ScatterChartData(
              minY: minY,
              maxY: maxY,
              minX: 0,
              maxX: 1,
              scatterSpots: const [],
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: const Text('Depth (dbar)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  axisNameSize: 18,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) {
                      final d = (-value).round();
                      if (d < 0) return const SizedBox();
                      return Text('$d', style: const TextStyle(fontSize: 10));
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
        const SizedBox(height: 44),
      ],
    );

    // Scrollable Right Chart
    final chartWidget = ScatterChart(
      ScatterChartData(
        clipData: const FlClipData.none(),
        scatterSpots: spots,
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('Salinity (PSU)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            axisNameSize: 18,
            sideTitles: SideTitles(showTitles: true, reservedSize: 26),
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
        scatterTouchData: ScatterTouchData(
          touchTooltipData: ScatterTouchTooltipData(
            getTooltipItems: (spot) {
              final idx = spots.indexOf(spot);
              final r = idx >= 0 && idx < readings.length ? readings[idx] : null;
              return ScatterTooltipItem(
                r != null
                    ? '${r.salinity.toStringAsFixed(2)} PSU at ${(-spot.y).round()} dbar\n'
                        'Float ${r.floatId} • Cycle #${r.cycleNumber}'
                    : '${spot.x.toStringAsFixed(2)} PSU at ${(-spot.y).round()} dbar',
                textStyle: const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
      ),
    );

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Salinity vs Depth', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          FixedYAxisChartLayout(
            yAxisWidget: yAxisWidget,
            chartWidget: chartWidget,
            contentWidth: contentWidth,
            chartHeight: 250.0,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Pressure vs Temperature
// ============================================================
class PressureTemperatureChart extends StatelessWidget {
  final List<DepthReading> readings;
  const PressureTemperatureChart({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const SoftCard(child: Text('No data available for profile analysis.'));
    }

    if (readings.length < 2) {
      final r = readings.first;
      return SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pressure vs Temperature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.cyan.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.cyan.shade800, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Insufficient observations for profile chart analysis (1 reading: ${r.pressure} dbar, ${r.temperature}°C).',
                      style: TextStyle(color: Colors.cyan.shade900, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final temps = readings.map((r) => r.temperature).toList();
    final press = readings.map((r) => r.pressure).toList();

    final minTemp = temps.reduce((a, b) => a < b ? a : b);
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);

    final minPres = press.reduce((a, b) => a < b ? a : b);
    final maxPres = press.reduce((a, b) => a > b ? a : b);

    final (minX, maxX) = ChartAxisPadding.padRange(minTemp, maxTemp, paddingFactor: 0.08);
    final (minY, maxY) = ChartAxisPadding.padRange(minPres, maxPres, paddingFactor: 0.08, minSpan: 5.0);

    final spots = readings.map((r) => ScatterSpot(r.temperature, r.pressure)).toList();
    final double contentWidth = (readings.length * 22.0).clamp(450.0, 15000.0);

    // Fixed Left Y-Axis
    final yAxisWidget = Column(
      children: [
        SizedBox(
          height: 206,
          child: ScatterChart(
            ScatterChartData(
              minY: minY,
              maxY: maxY,
              minX: 0,
              maxX: 1,
              scatterSpots: const [],
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: const Text('Pressure (dbar)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  axisNameSize: 18,
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
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
        const SizedBox(height: 44),
      ],
    );

    // Scrollable Right Chart
    final chartWidget = ScatterChart(
      ScatterChartData(
        clipData: const FlClipData.none(),
        scatterSpots: spots,
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('Temperature (°C)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            axisNameSize: 18,
            sideTitles: SideTitles(showTitles: true, reservedSize: 26),
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
        scatterTouchData: ScatterTouchData(
          touchTooltipData: ScatterTouchTooltipData(
            getTooltipItems: (spot) {
              final idx = spots.indexOf(spot);
              final r = idx >= 0 && idx < readings.length ? readings[idx] : null;
              return ScatterTooltipItem(
                r != null
                    ? '${r.temperature.toStringAsFixed(1)}°C, ${r.pressure.toStringAsFixed(0)} dbar\n'
                        'Float ${r.floatId} • Cycle #${r.cycleNumber}'
                    : '${spot.x.toStringAsFixed(1)}°C, ${spot.y.toStringAsFixed(0)} dbar',
                textStyle: const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
      ),
    );

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pressure vs Temperature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          FixedYAxisChartLayout(
            yAxisWidget: yAxisWidget,
            chartWidget: chartWidget,
            contentWidth: contentWidth,
            chartHeight: 250.0,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Trend charts
// ============================================================
class TrendChart extends StatelessWidget {
  final String title;
  final String yLabel;
  final List<double> values;
  final String direction;
  final Color color;
  final bool hasTimestamps;

  const TrendChart({
    super.key,
    required this.title,
    required this.yLabel,
    required this.values,
    required this.direction,
    required this.color,
    this.hasTimestamps = false,
  });

  IconData get _directionIcon {
    if (direction == 'Increasing') return Icons.trending_up;
    if (direction == 'Decreasing') return Icons.trending_down;
    if (direction == 'Stable') return Icons.trending_flat;
    return Icons.remove_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final bool isInsufficient = values.length < 2 || direction == 'Insufficient data';
    final double contentWidth = (values.length * 24.0).clamp(450.0, 15000.0);

    final minVal = values.isNotEmpty ? values.reduce((a, b) => a < b ? a : b) : 0.0;
    final maxVal = values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) : 1.0;
    final (minY, maxY) = ChartAxisPadding.padRange(minVal, maxVal, paddingFactor: 0.08);

    // Fixed Left Y-Axis
    final yAxisWidget = Column(
      children: [
        SizedBox(
          height: 178, // Matches plot height of right chart (220 total - 42 bottom titles)
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              minX: 0,
              maxX: 1,
              lineBarsData: [],
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: Text(yLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  axisNameSize: 18,
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
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
        const SizedBox(height: 42),
      ],
    );

    // Scrollable Right Chart
    final chartWidget = LineChart(
      LineChartData(
        clipData: const FlClipData.none(),
        minY: minY,
        maxY: maxY,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots
                .map((s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(2)} $yLabel (Point #${s.x.toInt() + 1})',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List<FlSpot>.generate(values.length, (i) => FlSpot(i.toDouble(), values[i])),
            isCurved: true,
            color: color,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Row(
                children: [
                  Icon(_directionIcon, size: 16, color: isInsufficient ? Colors.grey : color),
                  const SizedBox(width: 4),
                  Text(
                    isInsufficient ? 'Insufficient data' : direction,
                    style: TextStyle(
                      color: isInsufficient ? Colors.grey.shade700 : color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            !hasTimestamps
                ? 'Time trend unavailable — timestamp data is not available for this dataset.'
                : 'Timestamp timeline trend',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 10),
          if (isInsufficient)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Insufficient data for trend analysis (${values.length} observation available). Minimum 2 readings required.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            )
          else
            FixedYAxisChartLayout(
              yAxisWidget: yAxisWidget,
              chartWidget: chartWidget,
              contentWidth: contentWidth,
              chartHeight: 220.0,
            ),
        ],
      ),
    );
  }
}