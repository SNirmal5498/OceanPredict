import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'analytics_widgets.dart';

class DepthReading {
  final double temperature;
  final double salinity;
  final double pressure;
  final int cycleNumber;
  final String floatId;

  DepthReading({
    required this.temperature,
    required this.salinity,
    required this.pressure,
    required this.cycleNumber,
    required this.floatId,
  });
}

// ============================================================
// Temperature vs Depth (scatter, depth axis reversed so deeper = lower)
// ============================================================
class TemperatureDepthChart extends StatelessWidget {
  final List<DepthReading> readings;
  const TemperatureDepthChart({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const SoftCard(child: Text('No readings available for this float.'));
    }
    final spots = readings.map((r) => ScatterSpot(r.temperature, -r.pressure)).toList();

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Temperature vs Depth', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: ScatterChart(
              ScatterChartData(
                scatterSpots: spots,
                minX: readings.map((r) => r.temperature).reduce((a, b) => a < b ? a : b) - 1,
                maxX: readings.map((r) => r.temperature).reduce((a, b) => a > b ? a : b) + 1,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text('Temperature (°C)', style: TextStyle(fontSize: 11)),
                    sideTitles: SideTitles(showTitles: true, reservedSize: 26),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text('Depth (dbar)', style: TextStyle(fontSize: 11)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) =>
                          Text('${(-value).round()}', style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                scatterTouchData: ScatterTouchData(
                  touchTooltipData: ScatterTouchTooltipData(
                    getTooltipItems: (spot) => ScatterTooltipItem(
                      '${spot.x.toStringAsFixed(1)}°C at ${(-spot.y).round()} dbar',
                      textStyle: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
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
      return const SoftCard(child: Text('No readings available for this float.'));
    }
    final spots = readings.map((r) => ScatterSpot(r.salinity, -r.pressure)).toList();

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Salinity vs Depth', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: ScatterChart(
              ScatterChartData(
                scatterSpots: spots,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text('Salinity (PSU)', style: TextStyle(fontSize: 11)),
                    sideTitles: SideTitles(showTitles: true, reservedSize: 26),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text('Depth (dbar)', style: TextStyle(fontSize: 11)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) =>
                          Text('${(-value).round()}', style: const TextStyle(fontSize: 10)),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                scatterTouchData: ScatterTouchData(
                  touchTooltipData: ScatterTouchTooltipData(
                    getTooltipItems: (spot) => ScatterTooltipItem(
                      '${spot.x.toStringAsFixed(2)} PSU at ${(-spot.y).round()} dbar',
                      textStyle: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
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
      return const SoftCard(child: Text('No readings available for this float.'));
    }
    final spots = readings.map((r) => ScatterSpot(r.temperature, r.pressure)).toList();

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pressure vs Temperature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: ScatterChart(
              ScatterChartData(
                scatterSpots: spots,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text('Temperature (°C)', style: TextStyle(fontSize: 11)),
                    sideTitles: SideTitles(showTitles: true, reservedSize: 26),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text('Pressure (dbar)', style: TextStyle(fontSize: 11)),
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                scatterTouchData: ScatterTouchData(
                  touchTooltipData: ScatterTouchTooltipData(
                    getTooltipItems: (spot) {
                      final r = readings[spots.indexOf(spot)];
                      return ScatterTooltipItem(
                        '${r.temperature.toStringAsFixed(1)}°C, ${r.pressure.toStringAsFixed(0)} dbar\n'
                        'Float ${r.floatId} • Cycle #${r.cycleNumber}',
                        textStyle: const TextStyle(color: Colors.white, fontSize: 11),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Trend charts (x-axis = reading order, since no real timestamp exists yet)
// ============================================================
class TrendChart extends StatelessWidget {
  final String title;
  final String yLabel;
  final List<double> values;
  final String direction;
  final Color color;

  const TrendChart({
    super.key,
    required this.title,
    required this.yLabel,
    required this.values,
    required this.direction,
    required this.color,
  });

  IconData get _directionIcon {
    if (direction == 'Increasing') return Icons.trending_up;
    if (direction == 'Decreasing') return Icons.trending_down;
    return Icons.trending_flat;
  }

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SoftCard(child: Text('No data available for $title.'));
    }
    final spots = List<FlSpot>.generate(values.length, (i) => FlSpot(i.toDouble(), values[i]));

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
                  Icon(_directionIcon, size: 16, color: color),
                  const SizedBox(width: 4),
                  Text(direction, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          Text(
            'X-axis: reading order (timestamps not yet stored by backend)',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24)),
                  leftTitles: AxisTitles(
                    axisNameWidget: Text(yLabel, style: const TextStyle(fontSize: 11)),
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) => touchedSpots
                        .map((s) => LineTooltipItem(
                              s.y.toStringAsFixed(2),
                              const TextStyle(color: Colors.white, fontSize: 11),
                            ))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.1)),
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