import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // IMPORTANT: Match this with your backend IP + Flask port
  static const String baseUrl = 'http://127.0.0.1:5000';

  // Helper method to build headers with Authorization token
  static Map<String, String> _headers([String? token]) {
    final map = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    return map;
  }

  // Helper method to safely decode JSON responses
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final decodedBody = jsonDecode(response.body);
      return {
        'statusCode': response.statusCode,
        'body': decodedBody,
      };
    } catch (e) {
      return {
        'statusCode': response.statusCode,
        'body': {
          'error': 'Failed to parse response body',
          'details': response.body
        },
      };
    }
  }

  // --- AUTH ENDPOINTS ---
  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: _headers(),
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: _headers(),
        body: jsonEncode({'email': email, 'password': password}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  // --- ADMIN ENDPOINTS (WITH BEARER TOKEN) ---
  static Future<Map<String, dynamic>> getAdminStats(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/stats'),
        headers: _headers(token),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  static Future<Map<String, dynamic>> getAdminUsers(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/users'),
        headers: _headers(token),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  static Future<Map<String, dynamic>> getAdminDatasets(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/datasets'),
        headers: _headers(token),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  static Future<Map<String, dynamic>> getAdminLogs(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/system/logs'),
        headers: _headers(token),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  static Future<Map<String, dynamic>> updateUserRole(
      String token, int userId, String role) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/admin/users/$userId/role'),
        headers: _headers(token),
        body: jsonEncode({'role': role}),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  // --- GENERAL ENDPOINTS ---
  static Future<Map<String, dynamic>> getAnalyticsSummary([String? token]) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/analytics/summary'),
        headers: _headers(token),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  static Future<Map<String, dynamic>> getFloatIds([String? token]) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/floats/ids'),
        headers: _headers(token),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  static Future<Map<String, dynamic>> getFloatHistory(String floatId, [String? token]) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/floats/$floatId/history'),
        headers: _headers(token),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  static Future<Map<String, dynamic>> getFloatLocations([String? token]) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/floats/locations'),
        headers: _headers(token),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  static Future<Map<String, dynamic>> getDashboardStats([String? token]) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/stats'),
        headers: _headers(token),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  static Future<Map<String, dynamic>> uploadFile(
      List<int> fileBytes, String fileName, [String? token]) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
          http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }
}