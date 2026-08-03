import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  bool _isLoadingIds = true;
  List<String> _floatIds = [];
  String? _selectedFloatId;

  bool _isLoadingHistory = false;
  Map<String, dynamic>? _historyData;

  @override
  void initState() {
    super.initState();
    _loadFloatIds();
  }

  Future<void> _loadFloatIds() async {
    final result = await ApiService.getFloatIds();
    if (!mounted) return;

    if (result['statusCode'] == 200) {
      final ids = List<String>.from(result['body']['float_ids']);
      setState(() {
        _floatIds = ids;
        _isLoadingIds = false;
        if (ids.isNotEmpty) {
          _selectedFloatId = ids.first;
        }
      });
      if (_selectedFloatId != null) {
        _loadHistory(_selectedFloatId!);
      }
    } else {
      setState(() => _isLoadingIds = false);
    }
  }

  Future<void> _loadHistory(String floatId) async {
    setState(() => _isLoadingHistory = true);

    final result = await ApiService.getFloatHistory(floatId);
    if (!mounted) return;

    setState(() {
      _isLoadingHistory = false;
      _historyData = result['statusCode'] == 200 ? result['body'] : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Float Tracker')),
      body: _isLoadingIds
          ? const Center(child: CircularProgressIndicator())
          : _floatIds.isEmpty
              ? const Center(child: Text('No floats available yet'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedFloatId,
                        decoration: const InputDecoration(
                          labelText: 'Select Float',
                          border: OutlineInputBorder(),
                        ),
                        items: _floatIds.map((id) {
                          return DropdownMenuItem(value: id, child: Text(id));
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedFloatId = value);
                          _loadHistory(value);
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _isLoadingHistory
                            ? const Center(child: CircularProgressIndicator())
                            : _historyData == null
                                ? const Center(child: Text('No data for this float'))
                                : _buildHistoryView(),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHistoryView() {
    final data = _historyData!;
    final latest = data['latest'];
    final history = data['history'] as List<dynamic>;

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Float ${data['float_id']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Chip(
                      label: Text('${data['total_readings']} readings'),
                      backgroundColor: Colors.green.shade100,
                    ),
                  ],
                ),
                const Divider(),
                Text('Latest Position: ${latest['latitude']}, ${latest['longitude']}'),
                Text('Latest Cycle: #${latest['cycle_number']}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Reading History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...history.map((h) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.water_drop_outlined),
                title: Text('Cycle #${h['cycle_number']}'),
                subtitle: Text(
                  'Temp: ${h['temperature']}°C  •  Salinity: ${h['salinity']}  •  Pressure: ${h['pressure']} dbar',
                ),
              ),
            )),
      ],
    );
  }
}