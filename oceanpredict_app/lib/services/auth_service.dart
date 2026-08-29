import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
      };
}

class AuthService {
  static const String _tokenKey = 'jwt_token';
  static const String _userKey = 'user_data';

  static UserModel? _currentUser;

  /// Returns the current logged-in user in memory
  static UserModel? get currentUser => _currentUser;

  /// Retrieves the saved JWT token from local storage trimmed of whitespace/quotes
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final rawToken = prefs.getString(_tokenKey);
    if (rawToken == null || rawToken.isEmpty) return null;

    // Clean any accidentally escaped or wrapped quotes
    return rawToken.replaceAll('"', '').trim();
  }

  /// Saves the session after successful login
  static Future<void> saveSession(
      String token, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();

    // Clean token string before storing
    final cleanToken = token.replaceAll('"', '').trim();

    await prefs.setString(_tokenKey, cleanToken);
    await prefs.setString(_userKey, jsonEncode(userData));
    _currentUser = UserModel.fromJson(userData);
  }

  /// Loads saved session on app initialization
  static Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString(_userKey);
    if (userString != null && userString.isNotEmpty) {
      try {
        _currentUser = UserModel.fromJson(jsonDecode(userString));
      } catch (_) {
        _currentUser = null;
      }
    }
  }

  /// Clears stored token and resets session state
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    _currentUser = null;
  }
}