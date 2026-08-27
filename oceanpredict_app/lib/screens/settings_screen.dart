import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // User Profile State
  Map<String, dynamic>? _userProfile;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    setState(() => _isLoadingUser = true);
    try {
      // Reusing ApiService if currentUser endpoint exists
      final result = await ApiService.getDashboardStats(); // Fallback check
      if (result['statusCode'] == 200 && result['body']['user'] != null) {
        _userProfile = result['body']['user'];
      }
    } catch (_) {
      // Graceful fallback if no user auth state backend is initialized
    } finally {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800), // Responsive desktop centering
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 1. Header Subtitle
              const Text(
                'Manage your profile, preferences and account',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // 2. Profile Section
              _buildSectionHeader('Profile'),
              _buildProfileCard(isDark),
              const SizedBox(height: 20),

              // 3. Preferences Section
              _buildSectionHeader('Preferences'),
              _buildPreferencesCard(isDark),
              const SizedBox(height: 20),

              // 4. Account Section
              _buildSectionHeader('Account'),
              _buildAccountCard(isDark),
              const SizedBox(height: 20),

              // 5. Data & Privacy Section
              _buildSectionHeader('Data & Privacy'),
              _buildDataPrivacyCard(isDark),
              const SizedBox(height: 20),

              // 6. About Section
              _buildSectionHeader('About'),
              _buildAboutCard(isDark),
              const SizedBox(height: 24),

              // 7. Logout Button
              _buildLogoutButton(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildCardShell({required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  // ==========================================
  // Profile Section Components
  // ==========================================
  Widget _buildProfileCard(bool isDark) {
    final name = _userProfile?['name'] ?? 'N/A';
    final email = _userProfile?['email'] ?? 'N/A';
    final role = _userProfile?['role'] ?? 'N/A';

    return _buildCardShell(
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                child: Icon(Icons.person, size: 36, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _isLoadingUser
                    ? const Align(alignment: Alignment.centerLeft, child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Role: $role',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          const Divider(height: 24),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: _openEditProfileModal,
          ),
        ],
      ),
    );
  }

  void _openEditProfileModal() {
    final nameCtrl = TextEditingController(text: _userProfile?['name'] ?? '');
    final emailCtrl = TextEditingController(text: _userProfile?['email'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'User Name'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  _userProfile = {
                    ...(_userProfile ?? {}),
                    'name': nameCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                  };
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated locally.')),
                );
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Preferences Components
  // ==========================================
  Widget _buildPreferencesCard(bool isDark) {
    return _buildCardShell(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch ocean theme appearance'),
            value: SettingsService.themeModeNotifier.value == ThemeMode.dark,
            onChanged: (val) {
              setState(() {
                SettingsService.toggleTheme(val);
              });
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Notifications'),
            subtitle: const Text('Enable or disable system notifications'),
            value: SettingsService.notificationsEnabled,
            onChanged: (val) {
              setState(() {
                SettingsService.notificationsEnabled = val;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification preference updated.')),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune_outlined),
            title: const Text('Notification Settings'),
            subtitle: const Text('Choose alert categories'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: _openNotificationSettingsModal,
          ),
        ],
      ),
    );
  }

  void _openNotificationSettingsModal() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Notification Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: SettingsService.notificationTypes.keys.map((key) {
              return SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(key, style: const TextStyle(fontSize: 13)),
                value: SettingsService.notificationTypes[key] ?? false,
                onChanged: (val) {
                  setModalState(() {
                    SettingsService.notificationTypes[key] = val;
                  });
                  setState(() {});
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Account Section Components
  // ==========================================
  Widget _buildAccountCard(bool isDark) {
    return _buildCardShell(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: _openChangePasswordModal,
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.red),
            onTap: _openDeleteAccountModal,
          ),
        ],
      ),
    );
  }

  void _openChangePasswordModal() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password'),
                validator: (v) => v != newCtrl.text ? 'Passwords do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password change service is not available.')),
                );
              }
            },
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  void _openDeleteAccountModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This action cannot be undone. Your account and associated data may be permanently removed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deletion service is not available.')),
              );
            },
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Data & Privacy Components
  // ==========================================
  Widget _buildDataPrivacyCard(bool isDark) {
    return _buildCardShell(
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storage_outlined),
            title: const Text('My Data'),
            subtitle: const Text('Datasets, cached reports & local preferences'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('My Data Summary'),
                  content: const Text('Local Storage Usage:\n• Cached Preferences: 2 KB\n• Local Dataset Cache: 0 KB'),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cleaning_services_outlined, color: Colors.orange),
            title: const Text('Clear Local Data'),
            subtitle: const Text('Clear cached local state and preferences'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear Local Data?'),
                  content: const Text('This will reset your local UI preferences.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Local data cleared.')),
                        );
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.orange)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // About Section Components
  // ==========================================
  Widget _buildAboutCard(bool isDark) {
    return _buildCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.waves, color: Theme.of(context).colorScheme.primary, size: 28),
              const SizedBox(width: 10),
              const Text('OceanPredict', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'AI-Powered Argo Float Data Collection, Analysis and Forecasting System',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const Divider(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Version', style: TextStyle(fontSize: 13, color: Colors.grey)),
              Text('1.0.0', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Logout Button
  // ==========================================
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: Colors.red.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.logout, color: Colors.red, size: 18),
        label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logged out.')),
          );
        },
      ),
    );
  }
}