import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // IMPORTANT: this must match your PC's hotspot IP + Flask port
  static const String baseUrl = 'http://127.0.0.1:5000';

  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );
    return {
      'statusCode': response.statusCode,
      'body': jsonDecode(response.body),
    };
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    return {
      'statusCode': response.statusCode,
      'body': jsonDecode(response.body),
    };
  }
  static Future<Map<String, dynamic>> getDashboardStats() async {
  final response = await http.get(
    Uri.parse('$baseUrl/dashboard/stats'),
  );
  return {
    'statusCode': response.statusCode,
    'body': jsonDecode(response.body),
  };
}
static Future<Map<String, dynamic>> uploadFile(String filePath, String fileName) async {
  var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
  request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));

  var streamedResponse = await request.send();
  var response = await http.Response.fromStream(streamedResponse);

  return {
    'statusCode': response.statusCode,
    'body': jsonDecode(response.body),
  };
}
}