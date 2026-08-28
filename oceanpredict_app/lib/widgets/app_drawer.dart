import 'package:flutter/material.dart';
import '../services/auth_service.dart'; // Adjust path based on your existing code

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // Reuses existing user object from AuthService
    final user = AuthService.currentUser; 
    final bool isAdmin = user != null && user.role.toLowerCase() == 'admin';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user?.name ?? 'User'),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.cyan),
            ),
            decoration: BoxDecoration(color: Colors.cyan.shade700),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pushReplacementNamed(context, '/dashboard'),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Upload Dataset'),
            onTap: () => Navigator.pushReplacementNamed(context, '/upload'),
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Analytics'),
            onTap: () => Navigator.pushReplacementNamed(context, '/analytics'),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Ocean Map'),
            onTap: () => Navigator.pushReplacementNamed(context, '/map'),
          ),
          ListTile(
            leading: const Icon(Icons.directions_boat),
            title: const Text('Float Tracker'),
            onTap: () => Navigator.pushReplacementNamed(context, '/tracker'),
          ),
          ListTile(
            leading: const Icon(Icons.psychology),
            title: const Text('AI Prediction'),
            onTap: () => Navigator.pushReplacementNamed(context, '/prediction'),
          ),
          ListTile(
            leading: const Icon(Icons.assessment),
            title: const Text('Reports'),
            onTap: () => Navigator.pushReplacementNamed(context, '/reports'),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => Navigator.pushReplacementNamed(context, '/settings'),
          ),
          
          // STRICT CONDITION: Admin Panel appears ONLY if user.role == "admin"
          if (isAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Admin Panel'),
              onTap: () => Navigator.pushReplacementNamed(context, '/admin'),
            ),

          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await AuthService.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
  }
}