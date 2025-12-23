import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/storage/local_storage.dart';
import '../../core/auth/auth_gate.dart';
import '../../features/onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    // 1. Hide Status Bar for Fullscreen Immersion
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // 2. Setup Animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Total animation time
    );

    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic)),
    );

    _controller.forward();

    // 3. Navigate after animation
    _checkNextScreen();
  }

  Future<void> _checkNextScreen() async {
    // Wait for animation + a little extra hold time
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2500)),
      // You can load other critical data here if needed
    ]);

    // Check where to go
    final seenOnboarding = await LocalStorage.hasSeenOnboarding();

    if (mounted) {
      // Restore Status Bar
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => seenOnboarding ? const AuthGate() : const OnboardingScreen(),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the black background color from your logo image to blend it perfectly
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnim.value,
              child: Transform.scale(
                scale: _scaleAnim.value,
                child: child,
              ),
            );
          },
          child: Image.asset(
            'assets/images/splash_logo.jpg',
            width: 250, // Adjust size as needed
          ),
        ),
      ),
    );
  }
}