import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // IMPORTANT: this must match your backend IP + Flask port
  static const String baseUrl = 'http://127.0.0.1:5000';

  // Helper method to safely decode JSON responses
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final decodedBody = jsonDecode(response.body);
      return {
        'statusCode': response.statusCode,
        'body': decodedBody,
      };
    } catch (e) {
      // Handles plain text, HTML errors (500s), or unparseable responses
      return {
        'statusCode': response.statusCode,
        'body': {'error': 'Failed to parse response body', 'details': response.body},
      };
    }
  }

  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
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
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  static Future<Map<String, dynamic>> getAnalyticsSummary() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/analytics/summary'),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  static Future<Map<String, dynamic>> getFloatIds() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/floats/ids'),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  static Future<Map<String, dynamic>> getFloatHistory(String floatId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/floats/$floatId/history'),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  static Future<Map<String, dynamic>> getFloatLocations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/floats/locations'),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/stats'),
      );
      return _handleResponse(response);
    } catch (e) {
      return {'statusCode': 500, 'body': {'error': 'Network failure: $e'}};
    }
  }

  static Future<Map<String, dynamic>> uploadFile(
      List<int> fileBytes, String fileName) async {
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
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