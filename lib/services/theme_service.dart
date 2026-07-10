import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  bool _isDark = true;
  int _defaultDeliveryDays = 25;

  bool get isDark => _isDark;
  int get defaultDeliveryDays => _defaultDeliveryDays;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('isDarkMode') ?? true;
    _defaultDeliveryDays = prefs.getInt('defaultDeliveryDays') ?? 25;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDark = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    notifyListeners();
  }

  Future<void> setDefaultDeliveryDays(int value) async {
    _defaultDeliveryDays = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('defaultDeliveryDays', value);
    notifyListeners();
  }

  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFEEF2FF),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF0F3460),
      secondary: Color(0xFF4FC3F7),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF1A1A2E),
      onPrimary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F3460),
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0F3460),
      indicatorColor: const Color(0xFF4FC3F7).withOpacity(0.3),
      iconTheme: WidgetStateProperty.all(const IconThemeData(color: Colors.white54)),
    ),
    cardColor: Colors.white,
    dividerColor: const Color(0xFFDBEAFE),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0F3460),
        foregroundColor: Colors.white,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(const Color(0xFF4FC3F7)),
      trackColor: WidgetStateProperty.all(const Color(0xFF4FC3F7).withOpacity(0.3)),
    ),
  );

  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF1A1A2E),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF4FC3F7),
      secondary: Color(0xFF4FC3F7),
      surface: Color(0xFF16213E),
      onSurface: Colors.white,
      onPrimary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF16213E),
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF16213E),
      indicatorColor: const Color(0xFF0F3460),
    ),
    cardColor: const Color(0xFF16213E),
    dividerColor: Colors.white12,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0F3460),
        foregroundColor: Colors.white,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(const Color(0xFF4FC3F7)),
      trackColor: WidgetStateProperty.all(const Color(0xFF4FC3F7).withOpacity(0.3)),
    ),
  );
}

// Helper extension for easy theme color access
extension AppTheme on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get cardBg => isDark ? const Color(0xFF16213E) : Colors.white;
  Color get pageBg => isDark ? const Color(0xFF1A1A2E) : const Color(0xFFEEF2FF);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF1A1A2E);
  Color get textSecondary => isDark ? Colors.white54 : const Color(0xFF4A5568);
  Color get textHint => isDark ? Colors.white38 : const Color(0xFF9CA3AF);
  Color get borderColor => isDark ? Colors.white24 : const Color(0xFFDBEAFE);
  Color get accent => const Color(0xFF4FC3F7);
  Color get primaryBtn => const Color(0xFF0F3460);
  Color get divider => isDark ? Colors.white12 : const Color(0xFFE2E8F0);
}
