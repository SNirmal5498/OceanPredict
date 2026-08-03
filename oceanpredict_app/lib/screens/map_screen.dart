import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _isLoading = true;
  List<dynamic> _floats = [];

  @override
  void initState() {
    super.initState();
    _loadFloats();
  }

  Future<void> _loadFloats() async {
    final result = await ApiService.getFloatLocations();
    if (!mounted) return;

    if (result['statusCode'] == 200) {
      setState(() {
        _floats = result['body']['floats'];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ocean Map')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _floats.isEmpty
              ? const Center(child: Text('No float data available yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _floats.length,
                  itemBuilder: (context, index) {
                    final f = _floats[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.cyan.shade100,
                          child: Icon(Icons.satellite_alt, color: Colors.cyan.shade700),
                        ),
                        title: Text('Float ${f['float_id']}'),
                        subtitle: Text(
                          'Lat: ${f['latitude'].toStringAsFixed(2)}, Long: ${f['longitude'].toStringAsFixed(2)}\n'
                          'Temp: ${f['temperature']}°C  •  Salinity: ${f['salinity']}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}