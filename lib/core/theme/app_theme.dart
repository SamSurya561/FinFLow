// lib/core/theme/app_theme.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// iOS-like theme, frosted card helpers and small UI helpers for FinFlow.

class AppTheme {
  // Primary colours
  static const Color _primary = Color(0xFF0A84FF);
  static const Color _accent = Color(0xFF34C759);
  static const Color _danger = Color(0xFFFF3B30);

  // Background / surfaces
  static const Color _scaffoldLight = Color(0xFFF8F8F8);
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _scaffoldDark = Color(0xFF0B0C0D);
  static const Color _cardDark = Color(0xFF111214);

  // Radii
  static const double _radiusCard = 14.0;
  static const double _radiusButton = 12.0;

  // Animation constants
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 450);
  static const Curve ease = Curves.easeOutCubic;
  static const Curve easeIn = Curves.easeInCubic;

  // Page transitions: use Cupertino page transitions for native iOS feel.
  static final PageTransitionsTheme _iosPageTransitions = PageTransitionsTheme(
    builders: {
      for (final target in TargetPlatform.values)
        target: const CupertinoPageTransitionsBuilder(),
    },
  );

  /// Small convenience to create an [CardTheme] configured for iOS style.
  static CardTheme cardThemeFor(Color color) {
    return CardTheme(
      color: color,
      elevation: 6,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusCard),
      ),
    );
  }

  /// Soft frosted BoxDecoration (use for containers/cards).
  /// Use opacity tweaks to achieve frosted glass effect for both dark and light.
  static BoxDecoration elevatedFrostedDecoration({
    required BuildContext context,
    Color? color,
    double radius = _radiusCard,
    double elevation = 6,
  }) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color base = color ?? (dark ? _cardDark : _cardLight);
    return BoxDecoration(
      color: dark ? base.withOpacity(0.95) : base.withOpacity(0.98),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: dark ? Colors.black54 : Colors.grey.withOpacity(0.12),
          blurRadius: elevation,
          offset: Offset(0, elevation * 0.6),
        ),
      ],
    );
  }

  /// Animated wrapper for list items — provides small fade + translate with
  /// optional index-based stagger.
  static Widget animatedFrostedCard({
    required BuildContext context,
    required Widget child,
    int index = 0,
    double radius = _radiusCard,
    double elevation = 6,
    Duration duration = normal,
    Curve curve = AppTheme.ease,
    Duration? additionalDelay,
  }) {
    final totalDelay = Duration(milliseconds: index * 50) + (additionalDelay ?? Duration.zero);
    // We return a TweenAnimationBuilder that starts with opacity 0 and offset down.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      // start with a slight delay using a Future micro delay inside an AnimatedBuilder
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: Container(
              decoration: elevatedFrostedDecoration(
                context: context,
                radius: radius,
                elevation: elevation,
              ),
              child: child,
            ),
          ),
        );
      },
      // We trigger the animation with a small delayed call to ensure stagger works.
      onEnd: () {},
    );
  }

  // Simple iOS-style action button to re-use in several places
  static Widget iosActionButton({
    required VoidCallback onPressed,
    required Widget child,
    Color? background,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: background ?? _primary,
            borderRadius: BorderRadius.circular(_radiusButton),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: DefaultTextStyle(style: const TextStyle(color: Colors.white), child: child),
        ),
      ),
    );
  }

  // Light theme (iOS-like)
  static final ThemeData iosLight = ThemeData(
    brightness: Brightness.light,
    primaryColor: _primary,
    scaffoldBackgroundColor: _scaffoldLight,
    canvasColor: _scaffoldLight,
    colorScheme: ColorScheme.fromSeed(seedColor: _primary, brightness: Brightness.light),
    cardColor: _cardLight,
    // explicit CardTheme - avoids helper/type ambiguity
    cardTheme: CardThemeData(
      color: _cardLight,
      elevation: 6,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusCard),
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 2,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w600),
      iconTheme: IconThemeData(color: Colors.black54),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _cardLight,
      elevation: 8,
      selectedItemColor: _primary,
      unselectedItemColor: Colors.black45,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    popupMenuTheme: const PopupMenuThemeData(color: Colors.white, elevation: 4),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      labelStyle: TextStyle(color: Colors.black54),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusButton)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusButton)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: _primary)),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: _primary),
    pageTransitionsTheme: _iosPageTransitions,
    splashFactory: NoSplash.splashFactory,
    textTheme: Typography.material2018(platform: TargetPlatform.iOS).black.apply(bodyColor: Colors.black87),
    iconTheme: const IconThemeData(color: Colors.black54),
    shadowColor: Colors.black54,
  );

  // Dark theme (iOS-like)
  static final ThemeData iosDark = ThemeData(
    brightness: Brightness.dark,
    primaryColor: _primary,
    scaffoldBackgroundColor: _scaffoldDark,
    canvasColor: _scaffoldDark,
    colorScheme: ColorScheme.fromSeed(seedColor: _primary, brightness: Brightness.dark),
    cardColor: _cardDark,
    // explicit CardTheme - avoids helper/type ambiguity
    cardTheme: CardThemeData(
      color: _cardDark,
      elevation: 6,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radiusCard),
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF141416),
      elevation: 4,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
      iconTheme: IconThemeData(color: Colors.white70),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _cardDark,
      elevation: 8,
      selectedItemColor: _primary,
      unselectedItemColor: Colors.white38,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    popupMenuTheme: PopupMenuThemeData(color: _cardDark, elevation: 6),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      labelStyle: TextStyle(color: Colors.white70),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusButton)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: BorderSide(color: Colors.grey.shade800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radiusButton)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: _primary)),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: _primary),
    pageTransitionsTheme: _iosPageTransitions,
    splashFactory: NoSplash.splashFactory,
    textTheme: Typography.material2018(platform: TargetPlatform.iOS).white.apply(bodyColor: Colors.white70),
    iconTheme: const IconThemeData(color: Colors.white70),
    shadowColor: Colors.black87,
  );
}
