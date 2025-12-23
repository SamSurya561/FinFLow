// lib/core/notifiers/theme_notifier.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode');
    if (saved == 'light') themeMode.value = ThemeMode.light;
    else if (saved == 'dark') themeMode.value = ThemeMode.dark;
    else themeMode.value = ThemeMode.system;
  }

  static Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.light) await prefs.setString('theme_mode', 'light');
    else if (mode == ThemeMode.dark) await prefs.setString('theme_mode', 'dark');
    else await prefs.remove('theme_mode'); // System default
  }
}