import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/admin_service.dart';
import '../widgets/app_drawer.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = true;
  bool _hasError = false;

  Map<String, dynamic> _stats = {};
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  List<dynamic> _datasets = [];
  Map<String, String> _systemStatus = {};
  List<dynamic> _logs = [];

  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final stats = await AdminService.fetchDashboardStats();
      final users = await AdminService.fetchUsers();
      final datasets = await AdminService.fetchDatasets();
      final systemStatus = await AdminService.fetchSystemStatus();
      final logs = await AdminService.fetchSystemLogs();

      if (mounted) {
        setState(() {
          _stats = stats;
          _users = users;
          _datasets = datasets;
          _systemStatus = systemStatus;
          _logs = logs;
          _applyUserFilters();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _applyUserFilters() {
    _filteredUsers = _users.where((user) {
      final name = (user['name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final role = (user['role'] ?? '').toString().toLowerCase();
      final status = (user['status'] ?? '').toString().toLowerCase();

      final matchesSearch = name.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());

      bool matchesFilter = true;
      if (_selectedFilter == 'Admins') matchesFilter = role == 'admin';
      if (_selectedFilter == 'Users') matchesFilter = role == 'user';
      if (_selectedFilter == 'Active') matchesFilter = status == 'active';
      if (_selectedFilter == 'Disabled') matchesFilter = status == 'disabled';

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Future<void> _changeUserRole(dynamic user) async {
    final currentRole = user['role'] ?? 'user';
    final newRole = currentRole.toString().toLowerCase() == 'admin' ? 'user' : 'admin';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change user role?'),
        content: Text('Are you sure you want to change ${user['name'] ?? 'this user'}\'s role to $newRole?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await AdminService.updateUserRole(user['id'].toString(), newRole);
      if (success) {
        _loadAdminData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update role. Server action not supported.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. ROUTE PROTECTION CHECK
    final currentUser = AuthService.currentUser;
    if (currentUser == null || currentUser.role.toLowerCase() != 'admin') {
      return _buildAccessDeniedScreen(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.cyan.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAdminData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? _buildErrorWidget()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return RefreshIndicator(
                      onRefresh: _loadAdminData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 16),
                            _buildOverviewCards(constraints.maxWidth > 600),
                            const SizedBox(height: 24),
                            TabBar(
                              controller: _tabController,
                              labelColor: Colors.cyan.shade700,
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: Colors.cyan.shade700,
                              tabs: const [
                                Tab(text: 'Users', icon: Icon(Icons.people)),
                                Tab(text: 'Datasets', icon: Icon(Icons.dataset)),
                                Tab(text: 'System', icon: Icon(Icons.settings_suggest)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 600,
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildUsersTab(),
                                  _buildDatasetsTab(),
                                  _buildSystemTab(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildAccessDeniedScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access Denied')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gpp_bad, size: 80, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                'Access Denied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'You do not have permission to access the Admin Panel.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                icon: const Icon(Icons.dashboard),
                label: const Text('Return to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'Unable to load admin data.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAdminData,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Admin Panel',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.cyan.shade900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage users, datasets and system activity',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildOverviewCards(bool isWide) {
    final cards = [
      _statCard('Total Users', _stats['totalUsers']?.toString() ?? 'N/A', Icons.people_outline),
      _statCard('Datasets', _stats['totalDatasets']?.toString() ?? 'N/A', Icons.folder_open),
      _statCard('Records', _stats['totalRecords']?.toString() ?? 'N/A', Icons.table_chart_outlined),
      _statCard('Active Users', _stats['activeUsers']?.toString() ?? 'N/A', Icons.person_pin_circle_outlined),
    ];

    return isWide
        ? Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: c))).toList())
        : Column(children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: c)).toList());
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.cyan.shade50,
              child: Icon(icon, color: Colors.cyan.shade700),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                    _applyUserFilters();
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _selectedFilter,
              items: ['All', 'Admins', 'Users', 'Active', 'Disabled']
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedFilter = val;
                    _applyUserFilters();
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _filteredUsers.isEmpty
              ? const Center(child: Text('No user data available.'))
              : ListView.builder(
                  itemCount: _filteredUsers.length,
                  itemBuilder: (ctx, i) {
                    final u = _filteredUsers[i];
                    final isAdmin = (u['role'] ?? '').toString().toLowerCase() == 'admin';
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isAdmin ? Colors.amber.shade100 : Colors.grey.shade200,
                          child: Icon(
                            isAdmin ? Icons.security : Icons.person,
                            color: isAdmin ? Colors.amber.shade900 : Colors.grey.shade700,
                          ),
                        ),
                        title: Text(u['name'] ?? 'Unknown User'),
                        subtitle: Text('${u['email'] ?? ''}\nRole: ${u['role'] ?? 'User'} | Status: ${u['status'] ?? 'Active'}'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'role') _changeUserRole(u);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'role', child: Text('Change Role')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDatasetsTab() {
    return _datasets.isEmpty
        ? const Center(child: Text('No datasets available.'))
        : ListView.builder(
            itemCount: _datasets.length,
            itemBuilder: (ctx, i) {
              final d = _datasets[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file, color: Colors.cyan),
                  title: Text(d['name'] ?? 'Dataset'),
                  subtitle: Text('Uploaded by: ${d['uploadedBy'] ?? 'N/A'}\nRecords: ${d['records'] ?? 'N/A'} | Status: ${d['status'] ?? 'N/A'}'),
                  isThreeLine: true,
                ),
              );
            },
          );
  }

  Widget _buildSystemTab() {
    return ListView(
      children: [
        const Text('System Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._systemStatus.entries.map((e) => Card(
              child: ListTile(
                title: Text(e.key),
                trailing: Text(
                  e.value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: e.value.toLowerCase() == 'online' || e.value.toLowerCase() == 'connected' || e.value.toLowerCase() == 'available'
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
              ),
            )),
        const SizedBox(height: 24),
        const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _logs.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('No activity logs available.', style: TextStyle(color: Colors.grey)),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _logs.length,
                itemBuilder: (ctx, i) {
                  final log = _logs[i];
                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(log['event'] ?? 'Event'),
                    subtitle: Text('${log['user'] ?? 'N/A'} - ${log['timestamp'] ?? ''}'),
                  );
                },
              ),
      ],
    );
  }
}
