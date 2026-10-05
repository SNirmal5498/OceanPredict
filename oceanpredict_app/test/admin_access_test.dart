import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oceanpredict_app/services/auth_service.dart';
import 'package:oceanpredict_app/widgets/app_drawer.dart';
import 'package:oceanpredict_app/screens/admin_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.logout();
  });

  group('Admin Panel Access Control and Drawer Visibility', () {
    testWidgets('Normal User (role: user) - Admin Panel MUST NOT appear in drawer', (tester) async {
      await AuthService.saveSession('mock_token', {
        'id': 1,
        'name': 'Normal User',
        'email': 'user@example.com',
        'role': 'user',
      });

      expect(AuthService.currentUser?.role, 'user');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            drawer: AppDrawer(),
            body: Text('Test Body'),
          ),
        ),
      );

      // Open drawer
      final ScaffoldState state = tester.firstState(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();

      // Admin Panel tile MUST NOT appear
      expect(find.text('Admin Panel'), findsNothing);
    });

    testWidgets('Normal User (role: user) - Direct access to AdminScreen displays Access Denied', (tester) async {
      await AuthService.saveSession('mock_token', {
        'id': 1,
        'name': 'Normal User',
        'email': 'user@example.com',
        'role': 'user',
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Access must be denied
      expect(find.text('Access Denied'), findsWidgets);
      expect(find.text('You do not have permission to access the Admin Panel.'), findsOneWidget);
    });

    testWidgets('Admin User (role: admin) - Admin Panel SHOULD appear in drawer', (tester) async {
      await AuthService.saveSession('mock_token_admin', {
        'id': 2,
        'name': 'Admin User',
        'email': 'admin@example.com',
        'role': 'admin',
      });

      expect(AuthService.currentUser?.role, 'admin');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            drawer: AppDrawer(),
            body: Text('Test Body'),
          ),
        ),
      );

      // Open drawer
      final ScaffoldState state = tester.firstState(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();

      // Scroll down drawer to make bottom items visible
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Admin Panel tile SHOULD appear
      expect(find.text('Admin Panel'), findsOneWidget);
    });

    testWidgets('Admin User (role: admin) - Direct access to AdminScreen displays Admin Panel', (tester) async {
      await AuthService.saveSession('mock_token_admin', {
        'id': 2,
        'name': 'Admin User',
        'email': 'admin@example.com',
        'role': 'admin',
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Admin Panel header should be shown
      expect(find.text('Admin Panel'), findsWidgets);
      expect(find.text('You do not have permission to access the Admin Panel.'), findsNothing);
    });

    testWidgets('Logout clears session and role', (tester) async {
      await AuthService.saveSession('mock_token_admin', {
        'id': 2,
        'name': 'Admin User',
        'email': 'admin@example.com',
        'role': 'admin',
      });
      expect(AuthService.currentUser, isNotNull);

      await AuthService.logout();
      expect(AuthService.currentUser, isNull);
      final token = await AuthService.getToken();
      expect(token, isNull);
    });
  });
}
