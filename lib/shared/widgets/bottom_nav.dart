// lib/shared/widgets/bottom_nav.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FinFlowBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const FinFlowBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Modern "Floating" Navbar Design
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        // Floating margin (lifted up from bottom)
        margin: const EdgeInsets.only(left: 24, right: 24, bottom: 30),
        height: 72,
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF1C1C1E) : Colors.white).withOpacity(0.55),
          borderRadius: BorderRadius.circular(40), // Pill shape
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        // Frosted Glass Effect
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Home',
                    isSelected: currentIndex == 0,
                    onTap: () => _handleTap(0),
                  ),
                  _NavItem(
                    icon: Icons.receipt_long_rounded,
                    label: 'Trans.',
                    isSelected: currentIndex == 1,
                    onTap: () => _handleTap(1),
                  ),
                  _NavItem(
                    icon: Icons.pie_chart_rounded,
                    label: 'Budgets',
                    isSelected: currentIndex == 2,
                    onTap: () => _handleTap(2),
                  ),
                  _NavItem(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    isSelected: currentIndex == 3,
                    onTap: () => _handleTap(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(int index) {
    HapticFeedback.lightImpact(); // Premium tactile feel
    onTap(index);
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Active Color: Use primary color. Inactive: Grey.
    final activeColor = theme.primaryColor;
    final inactiveColor = Colors.grey.withOpacity(0.5);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Icon Scale & Color
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: isSelected ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut, // Bouncy effect
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 1.0 + (value * 0.2), // Scale up to 1.2x when selected
                  child: Icon(
                    icon,
                    color: Color.lerp(inactiveColor, activeColor, value),
                    size: 28, // Slightly larger icons
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            // Animated Label (Fade In/Out & Slide Up)
            AnimatedSlide(
              offset: isSelected ? Offset.zero : const Offset(0, 0.5),
              duration: const Duration(milliseconds: 200),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isSelected ? 1.0 : 0.0,
                child: isSelected
                    ? Text(
                  label,
                  style: TextStyle(
                    color: activeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                )
                    : const SizedBox.shrink(), // Keeps layout stable
              ),
            ),
          ],
        ),
      ),
    );
  }
}