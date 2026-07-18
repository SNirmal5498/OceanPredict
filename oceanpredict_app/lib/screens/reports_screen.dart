import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Generate New Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('CSV'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.grid_on_outlined),
                  label: const Text('Excel'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Report History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _reportTile('Ocean_Report_July2026.pdf', '14 Jul 2026'),
          _reportTile('Salinity_Analysis.xlsx', '10 Jul 2026'),
          _reportTile('Temperature_Data.csv', '05 Jul 2026'),
        ],
      ),
    );
  }

  Widget _reportTile(String name, String date) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(name),
        subtitle: Text('Generated on $date'),
        trailing: IconButton(
          icon: const Icon(Icons.download_outlined),
          onPressed: () {},
        ),
      ),
    );
  }
}