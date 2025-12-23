import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../home/home_screen.dart'; // Or your AuthGate/Dashboard import

class WelcomeScreen extends StatefulWidget {
  final String userName; // Optional: Pass name if available
  const WelcomeScreen({super.key, this.userName = 'User'});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late AnimationController _checkCtrl;

  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    // 1. Main Entrance Controller (Background, Text, Ripple)
    _mainCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

    // 2. Checkmark Drawing Controller
    _checkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    // Animations
    _scaleAnim = CurvedAnimation(parent: _mainCtrl, curve: Curves.elasticOut);
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic)),
    );

    // Sequence
    _playSequence();
  }

  Future<void> _playSequence() async {
    // A. Start Ripple & Text
    await _mainCtrl.forward();

    // B. Draw Checkmark
    HapticFeedback.mediumImpact();
    await _checkCtrl.forward();

    // C. Wait & Navigate
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(), // Or AuthGate()
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _checkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- Animated Visual ---
            Stack(
              alignment: Alignment.center,
              children: [
                // 1. Outer Glow/Ripple
                AnimatedBuilder(
                  animation: _mainCtrl,
                  builder: (ctx, child) {
                    return Opacity(
                      opacity: (1 - _mainCtrl.value).clamp(0.0, 1.0) * 0.5,
                      child: Transform.scale(
                        scale: 1.0 + (_mainCtrl.value * 0.5),
                        child: Container(
                          width: 150, height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withOpacity(0.3),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // 2. White/Black Circle Background
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                ),
                // 3. Drawing Checkmark
                SizedBox(
                  width: 40, height: 40,
                  child: CustomPaint(
                    painter: _CheckmarkPainter(progress: _checkCtrl),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // --- Animated Text ---
            FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Syncing your dashboard...',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Custom Painter for "Drawing" the Checkmark ---
class _CheckmarkPainter extends CustomPainter {
  final Animation<double> progress;
  _CheckmarkPainter({required this.progress}) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    // Checkmark shape coordinates (normalized)
    path.moveTo(size.width * 0.1, size.height * 0.5);
    path.lineTo(size.width * 0.4, size.height * 0.8);
    path.lineTo(size.width * 0.9, size.height * 0.2);

    // Animate the path drawing
    final pathMetrics = path.computeMetrics();
    for (var metric in pathMetrics) {
      final extractPath = metric.extractPath(
        0.0,
        metric.length * progress.value,
      );
      canvas.drawPath(extractPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) => true;
}