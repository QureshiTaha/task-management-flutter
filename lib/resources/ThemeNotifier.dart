import 'package:flutter/material.dart';
import 'package:task_management/pages/SettingsScreen.dart';
import 'package:task_management/resources/local_storage.dart';

class ThemeNotifier extends ChangeNotifier {
  late ThemeData _currentTheme;
  ThemeMode themeMode = ThemeMode.system;
  AppThemeMode _mode = AppThemeMode.system;
  Color _primaryColor = Colors.blue;
  Color _secondaryColor = Colors.green;

  ThemeNotifier() {
    _loadThemeSettings();
  }

  ThemeData get currentTheme => _currentTheme;
  AppThemeMode get mode => _mode;
  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;

  /// Sets the theme mode and rebuilds the theme
  void setThemeMode(AppThemeMode mode) async {
    _mode = mode;
    await localStorage.putString('themeMode', mode.toString().split('.').last);
    _updateTheme();
    notifyListeners();
  }

  /// Set primary color and rebuild theme
  void setPrimaryColor(Color color) {
    _primaryColor = color;
    localStorage.putInt('primaryColor', color.value);
    _updateTheme();
    notifyListeners();
  }

  /// Set secondary color and rebuild theme
  void setSecondaryColor(Color color) {
    _secondaryColor = color;
    localStorage.putInt('secondaryColor', color.value);
    _updateTheme();
    notifyListeners();
  }

  /// Builds theme based on current mode and custom colors
  void _updateTheme() {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        secondary: _secondaryColor,
        brightness:
            _mode == AppThemeMode.dark ? Brightness.dark : Brightness.light,
      ),
      useMaterial3: true,
    );

    _currentTheme = baseTheme;
    themeMode =
        _mode == AppThemeMode.system
            ? ThemeMode.system
            : _mode == AppThemeMode.light
            ? ThemeMode.light
            : ThemeMode.dark;
  }

  /// Loads saved theme mode and colors
  Future<void> _loadThemeSettings() async {
    final modeStr = await localStorage.getString('themeMode');
    final primary = await localStorage.getInt('primaryColor');
    final secondary = await localStorage.getInt('secondaryColor');

    switch (modeStr) {
      case 'light':
        _mode = AppThemeMode.light;
        break;
      case 'dark':
        _mode = AppThemeMode.dark;
        break;
      default:
        _mode = AppThemeMode.system;
    }

    if (primary != null) _primaryColor = Color(primary);
    if (secondary != null) _secondaryColor = Color(secondary);

    _updateTheme();
    notifyListeners();
  }
}
