import 'package:flutter/material.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Users'),
              Tab(text: 'Datasets'),
              Tab(text: 'System'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUsersTab(),
            _buildDatasetsTab(),
            _buildSystemTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _userTile('Rahul Sharma', 'rahul@example.com', 'User'),
        _userTile('Priya Singh', 'priya@example.com', 'Admin'),
        _userTile('Amit Kumar', 'amit@example.com', 'User'),
      ],
    );
  }

  Widget _userTile(String name, String email, String role) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(name),
        subtitle: Text(email),
        trailing: Chip(
          label: Text(role),
          backgroundColor: role == 'Admin' ? Colors.orange.shade100 : Colors.grey.shade200,
        ),
      ),
    );
  }

  Widget _buildDatasetsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('argo_pacific_2026.csv'),
            subtitle: const Text('Uploaded by Rahul Sharma • 12,400 records'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {},
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('argo_indian_ocean.csv'),
            subtitle: const Text('Uploaded by Priya Singh • 8,900 records'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {},
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('System Health', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(),
                _healthRow('Database Status', 'Online', Colors.green),
                _healthRow('API Server', 'Online', Colors.green),
                _healthRow('Storage Used', '2.4 GB / 10 GB', Colors.blue),
                _healthRow('Active Sessions', '14', Colors.blue),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _healthRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}