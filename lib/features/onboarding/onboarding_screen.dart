// lib/features/onboarding/onboarding_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'dart:math' as math;
import '../../core/storage/local_storage.dart';
import '../../core/auth/auth_gate.dart'; // To navigate after finishing

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _content = [
    {
      'title': 'Master Your\nMoney',
      'desc': 'Take total control of your finances. Track every rupee with precision and ease.',
    },
    {
      'title': 'Smart\nAnalytics',
      'desc': 'Visualize your spending habits. Set smart budgets and never overspend again.',
    },
    {
      'title': 'Private &\nSecure',
      'desc': 'Your data stays on your device. Offline-first, secure, and strictly yours.',
    },
  ];

  Future<void> _finishOnboarding() async {
    HapticFeedback.heavyImpact();
    await LocalStorage.setSeenOnboarding();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AuthGate(),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. Scrollable Page View
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (idx) {
              HapticFeedback.selectionClick();
              setState(() => _currentPage = idx);
            },
            itemCount: _content.length,
            itemBuilder: (ctx, idx) {
              return _OnboardingPage(
                title: _content[idx]['title']!,
                desc: _content[idx]['desc']!,
                index: idx,
                isDark: isDark,
              );
            },
          ),

          // 2. Bottom Controls
          Positioned(
            bottom: 50,
            left: 24,
            right: 24,
            child: Column(
              children: [
                // Page Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) => _buildDot(i, isDark)),
                ),
                const SizedBox(height: 32),

                // Animated Button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.fastOutSlowIn,
                  width: _currentPage == 2 ? 200 : 70,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage == 2) {
                        _finishOnboarding();
                      } else {
                        _pageCtrl.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 8,
                      shadowColor: Theme.of(context).primaryColor.withOpacity(0.5),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeInBack,
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.6, end: 1.0).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: _currentPage == 2
                          ? const Text(
                        'Get Started',
                        key: ValueKey('text'),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      )
                          : const Icon(
                        Icons.arrow_forward_rounded,
                        key: ValueKey('icon'),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Skip Button (Top Right)
          Positioned(
            top: 60,
            right: 24,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _currentPage < 2 ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: _currentPage == 2,
                child: TextButton(
                  onPressed: _finishOnboarding,
                  child: Text(
                      'Skip',
                      style: TextStyle(
                        color: textColor.withOpacity(0.5),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      )
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index, bool isDark) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 32 : 8,
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).primaryColor
            : (isDark ? Colors.white24 : Colors.black12),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// --- Content Page Structure ---

class _OnboardingPage extends StatelessWidget {
  final String title;
  final String desc;
  final int index;
  final bool isDark;

  const _OnboardingPage({
    required this.title,
    required this.desc,
    required this.index,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Visual Container
          SizedBox(
            height: 300,
            child: Center(child: _buildVisual(index)),
          ),

          const Spacer(flex: 1),

          // Text Content
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, val, child) {
              return Opacity(
                opacity: val,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - val)),
                  child: child,
                ),
              );
            },
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 36,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  desc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildVisual(int idx) {
    if (idx == 0) return const _PiggyBankVisual();
    if (idx == 1) return const _AnalyticsVisual();
    return const _SecureShieldVisual();
  }
}

// --- Custom Animated Visuals ---

// 1. Piggy Bank Visual (UPDATED: Added Top Bar & Fade-In Coins)
class _PiggyBankVisual extends StatefulWidget {
  const _PiggyBankVisual();
  @override
  State<_PiggyBankVisual> createState() => _PiggyBankVisualState();
}

class _PiggyBankVisualState extends State<_PiggyBankVisual> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return SizedBox(
      width: 300, height: 300,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, child) {
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // --- NEW: Top Decorative Bar ---
              Positioned(
                top: 0,
                child: Container(
                  width: 100, height: 4,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Piggy Body
              Positioned(
                bottom: 30,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 180, height: 150,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(80), topRight: Radius.circular(80),
                          bottomLeft: Radius.circular(50), bottomRight: Radius.circular(50),
                        ),
                        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                    ),
                    Positioned(top: 60, child: Container(width: 50, height: 36, decoration: BoxDecoration(color: primaryColor.withOpacity(0.3), borderRadius: BorderRadius.circular(18)))),
                    // Coin Slot (Existing)
                    Positioned(top: 15, child: Container(width: 60, height: 8, decoration: BoxDecoration(color: primaryColor.withOpacity(0.5), borderRadius: BorderRadius.circular(4)))),
                  ],
                ),
              ),
              // Falling Coins
              _coin(left: 128, startTop: -20, endTop: 160, color: Colors.orange, delay: 0.0),
              _coin(left: 190, startTop: 10, endTop: 180, color: Colors.amber, delay: 0.35),
              _coin(left: 66, startTop: 0, endTop: 170, color: Colors.deepOrangeAccent, delay: 0.7),
            ],
          );
        },
      ),
    );
  }

  Widget _coin({required double left, required double startTop, required double endTop, required Color color, required double delay}) {
    final relativeValue = (_ctrl.value - delay) % 1.0;
    if ((_ctrl.value - delay) < 0) return const SizedBox.shrink();

    // --- UPDATED: Fade In AND Fade Out Logic ---
    double opacity = 1.0;
    if (relativeValue < 0.2) {
      // Fade in over the first 20%
      opacity = relativeValue * 5;
    } else if (relativeValue > 0.8) {
      // Fade out over the last 20%
      opacity = (1.0 - relativeValue) * 5;
    }

    final top = startTop + ((endTop - startTop) * relativeValue);

    return Positioned(
      left: left, top: top,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: relativeValue * 2 * math.pi,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]),
            child: const Icon(Icons.currency_rupee, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

// 2. Analytics Visual (Bar + Pie)
class _AnalyticsVisual extends StatelessWidget {
  const _AnalyticsVisual();
  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _BarChartVisual(),
        SizedBox(height: 30),
        _PieChartVisual(),
      ],
    );
  }
}

class _BarChartVisual extends StatefulWidget {
  const _BarChartVisual();
  @override
  State<_BarChartVisual> createState() => _BarChartVisualState();
}
class _BarChartVisualState extends State<_BarChartVisual> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(80 * _ctrl.value, Colors.blueAccent),
            const SizedBox(width: 16),
            _bar(140 * _ctrl.value, Colors.purpleAccent),
            const SizedBox(width: 16),
            _bar(110 * _ctrl.value, Colors.greenAccent),
          ],
        );
      },
    );
  }
  Widget _bar(double h, Color c) => Container(width: 30, height: h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: c.withOpacity(0.4), blurRadius: 8)]));
}

class _PieChartVisual extends StatefulWidget {
  const _PieChartVisual();
  @override
  State<_PieChartVisual> createState() => _PieChartVisualState();
}
class _PieChartVisualState extends State<_PieChartVisual> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) => SizedBox(width: 100, height: 100, child: CustomPaint(painter: _PieChartPainter(animationValue: _ctrl.value))),
    );
  }
}
class _PieChartPainter extends CustomPainter {
  final double animationValue;
  _PieChartPainter({required this.animationValue});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = Colors.orangeAccent;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * 0.4 * animationValue, true, paint);

    paint.color = Colors.redAccent;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2 + 2 * math.pi * 0.4 * animationValue, 2 * math.pi * 0.3 * animationValue, true, paint);

    paint.color = Colors.tealAccent;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2 + 2 * math.pi * 0.7 * animationValue, 2 * math.pi * 0.3 * animationValue, true, paint);
  }
  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) => oldDelegate.animationValue != animationValue;
}

// 3. Secure Shield Visual
class _SecureShieldVisual extends StatefulWidget {
  const _SecureShieldVisual();
  @override
  State<_SecureShieldVisual> createState() => _SecureShieldVisualState();
}
class _SecureShieldVisualState extends State<_SecureShieldVisual> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF30D158);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            _ripple(color, _ctrl.value),
            _ripple(color, (_ctrl.value + 0.5) % 1.0),
            Transform.scale(
              scale: 1.0 + (0.05 * math.sin(_ctrl.value * 2 * math.pi)),
              child: Container(
                width: 130, height: 130,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(40), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))]),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 64),
              ),
            ),
          ],
        );
      },
    );
  }
  Widget _ripple(Color color, double value) {
    return Opacity(
      opacity: (1.0 - value).clamp(0.0, 1.0),
      child: Container(
        width: 130 + (140 * value), height: 130 + (140 * value),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.5), width: 4 * (1-value))),
      ),
    );
  }
}