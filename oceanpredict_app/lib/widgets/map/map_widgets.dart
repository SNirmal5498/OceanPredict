import 'package:flutter/material.dart';
import '../../services/map_service.dart';

// ============================================================
// Search bar
// ============================================================
class MapSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;

  const MapSearchBar({super.key, required this.controller, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      child: TextField(
        controller: controller,
        onSubmitted: (_) => onSearch(),
        decoration: InputDecoration(
          hintText: 'Search Float ID or Cycle Number',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: onSearch),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );
  }
}

// ============================================================
// Map controls (zoom / reset / fit)
// ============================================================
class MapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final VoidCallback onFitToData;

  const MapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.onFitToData,
  });

  Widget _button(IconData icon, VoidCallback onTap, {String? tooltip}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: IconButton(
          icon: Icon(icon, color: Colors.cyan.shade800),
          tooltip: tooltip,
          onPressed: onTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _button(Icons.add, onZoomIn, tooltip: 'Zoom In'),
        _button(Icons.remove, onZoomOut, tooltip: 'Zoom Out'),
        _button(Icons.my_location, onReset, tooltip: 'Reset View'),
        _button(Icons.fit_screen, onFitToData, tooltip: 'Fit to Data'),
      ],
    );
  }
}

// ============================================================
// Legend
// ============================================================
class MapLegend extends StatelessWidget {
  final bool showTemperatureMode;
  const MapLegend({super.key, required this.showTemperatureMode});

  Widget _dot(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (!showTemperatureMode) return const SizedBox.shrink();
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 14,
          children: [
            _dot(Colors.blue, 'Low (<${MapService.lowThreshold.toStringAsFixed(0)}°C)'),
            _dot(Colors.green, 'Normal'),
            _dot(Colors.red, 'High (>${MapService.highThreshold.toStringAsFixed(0)}°C)'),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Summary bar
// ============================================================
class FloatLocationSummary extends StatelessWidget {
  final int total;
  final int visible;
  final int invalid;

  const FloatLocationSummary({super.key, required this.total, required this.visible, required this.invalid});

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value) => Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
          ],
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          stat('Total Floats', '$total'),
          stat('Visible', '$visible'),
          stat('Invalid Locations', '$invalid'),
        ],
      ),
    );
  }
}

// ============================================================
// Filter panel (sheet content)
// ============================================================
class MapFilterPanel extends StatelessWidget {
  final TextEditingController floatIdController;
  final TextEditingController minTempController;
  final TextEditingController maxTempController;
  final TextEditingController minSalController;
  final TextEditingController maxSalController;
  final TextEditingController minPresController;
  final TextEditingController maxPresController;
  final VoidCallback onApply;
  final VoidCallback onReset;

  const MapFilterPanel({
    super.key,
    required this.floatIdController,
    required this.minTempController,
    required this.maxTempController,
    required this.minSalController,
    required this.maxSalController,
    required this.minPresController,
    required this.maxPresController,
    required this.onApply,
    required this.onReset,
  });

  Widget _pairField(String label, TextEditingController c) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: floatIdController,
            decoration: const InputDecoration(labelText: 'Float ID', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          Text('Temperature Range (°C)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Row(children: [_pairField('Min', minTempController), _pairField('Max', maxTempController)]),
          const SizedBox(height: 10),
          Text('Salinity Range (PSU)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Row(children: [_pairField('Min', minSalController), _pairField('Max', maxSalController)]),
          const SizedBox(height: 10),
          Text('Pressure / Depth Range (dbar)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Row(children: [_pairField('Min', minPresController), _pairField('Max', maxPresController)]),
          const SizedBox(height: 6),
          Opacity(
            opacity: 0.5,
            child: IgnorePointer(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Date Range (not available yet)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    onApply();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade700, foregroundColor: Colors.white),
                  child: const Text('Apply Filters'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    onReset();
                    Navigator.pop(context);
                  },
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
// Float info bottom sheet
// ============================================================
class FloatInfoSheet extends StatelessWidget {
  final MapFloatPoint point;
  final VoidCallback onViewHistory;
  final VoidCallback onTrackFloat;
  final VoidCallback onViewAnalytics;

  const FloatInfoSheet({
    super.key,
    required this.point,
    required this.onViewHistory,
    required this.onTrackFloat,
    required this.onViewAnalytics,
  });

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Colors.cyan.shade400, Colors.cyan.shade700]),
                ),
                child: const Icon(Icons.satellite_alt, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Float ${point.floatId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          const Divider(height: 24),
          _row('Latitude', '${point.latitude.toStringAsFixed(2)}°'),
          _row('Longitude', '${point.longitude.toStringAsFixed(2)}°'),
          _row('Temperature', point.temperature != null ? '${point.temperature}°C' : 'N/A'),
          _row('Salinity', point.salinity != null ? '${point.salinity} PSU' : 'N/A'),
          _row('Pressure', point.pressure != null ? '${point.pressure} dbar' : 'N/A'),
          _row('Cycle', point.cycleNumber != null ? '#${point.cycleNumber}' : 'N/A'),
          _row('Timestamp', point.timestamp ?? 'Not available'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: onViewHistory, child: const Text('View History')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(onPressed: onTrackFloat, child: const Text('Track Float')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onViewAnalytics,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade700, foregroundColor: Colors.white),
              child: const Text('View Analytics'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Data quality card
// ============================================================
class DataQualityCard extends StatelessWidget {
  final int valid;
  final int invalid;
  final int missing;

  const DataQualityCard({super.key, required this.valid, required this.invalid, required this.missing});

  @override
  Widget build(BuildContext context) {
    Widget row(String label, int value, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.circle, size: 8, color: color),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 12.5)),
              ]),
              Text('$value', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Data Quality', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          row('Valid Locations', valid, Colors.green),
          row('Invalid Locations', invalid, Colors.red),
          row('Missing Coordinates', missing, Colors.orange),
        ],
      ),
    );
  }
}