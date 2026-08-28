import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';

class AdminService {
  static const String baseUrl = 'http://127.0.0.1:5000/api/admin'; // Update base URL as needed

  static Future<Map<String, dynamic>> fetchDashboardStats() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Unauthorized');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}

    return {
      'totalUsers': null,
      'totalDatasets': null,
      'totalRecords': null,
      'activeUsers': null,
    };
  }

  static Future<List<dynamic>> fetchUsers() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Unauthorized');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}

    return [];
  }

  static Future<bool> updateUserRole(String userId, String newRole) async {
    final token = await AuthService.getToken();
    if (token == null) return false;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId/role'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'role': newRole}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<dynamic>> fetchDatasets() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Unauthorized');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/datasets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}

    return [];
  }

  static Future<Map<String, String>> fetchSystemStatus() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Unauthorized');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/system/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, String>.from(data);
      }
    } catch (_) {}

    return {
      'Backend': 'Unknown',
      'Database': 'Unknown',
      'API': 'Unknown',
      'ML Service': 'Unknown',
    };
  }

  static Future<List<dynamic>> fetchSystemLogs() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Unauthorized');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/system/logs'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}

    return [];
  }
}
