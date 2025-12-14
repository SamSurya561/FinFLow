import 'package:flutter/material.dart';
import 'theme/light_theme.dart';
import 'theme/dark_theme.dart';
import '../features/home/home_screen.dart';
import '../core/auth/auth_gate.dart';

class FinFlowApp extends StatelessWidget {
  const FinFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinFlow',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
