import 'package:flutter/material.dart';

class SettingsService {
  // Global Theme Mode State
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

  // Notification Preferences State
  static bool notificationsEnabled = true;
  static Map<String, bool> notificationTypes = {
    'Temperature Alerts': true,
    'Salinity Alerts': true,
    'Sensor Anomaly Alerts': true,
    'Prediction Alerts': false,
  };

  // Toggle Theme
  static void toggleTheme(bool isDark) {
    themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // Ocean-inspired Dark Theme
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      primaryColor: Colors.cyan,
      scaffoldBackgroundColor: const Color(0xFF0D1B2A),
      cardColor: const Color(0xFF1B263B),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1B263B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      colorScheme: const ColorScheme.dark(
        primary: Colors.cyan,
        secondary: Colors.cyanAccent,
        surface: Color(0xFF1B263B),
      ),
      dialogBackgroundColor: const Color(0xFF1B263B),
      dividerColor: Colors.white12,
    );
  }

  // Ocean-inspired Light Theme
  static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      primaryColor: Colors.cyan.shade700,
      scaffoldBackgroundColor: const Color(0xFFF3FAFC),
      cardColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      colorScheme: ColorScheme.light(
        primary: Colors.cyan.shade700,
        surface: Colors.white,
      ),
    );
  }
}
