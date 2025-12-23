// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import '../../core/notifiers/bottom_nav_notifier.dart';
import '../../shared/widgets/bottom_nav.dart';
import '../dashboard/dashboard_screen.dart';
import '../transactions/transactions_screen.dart';
import '../budgets/budgets_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Listen to the global notifier for tab switching (e.g., from "View All" buttons)
  @override
  void initState() {
    super.initState();
    bottomNavNotifier.addListener(_handleNavNotifier);
  }

  @override
  void dispose() {
    bottomNavNotifier.removeListener(_handleNavNotifier);
    super.dispose();
  }

  void _handleNavNotifier() {
    final val = bottomNavNotifier.value;
    final idx = val['index'] as int? ?? 0;
    if (!mounted) return;
    if (_selectedIndex != idx) {
      setState(() {
        _selectedIndex = idx;
      });
    }
  }

  Widget _buildBody() {
    // If the Transactions tab is selected, check if we need to pass a category filter
    // (e.g., coming from the Budgets screen)
    if (_selectedIndex == 1) {
      final payload = bottomNavNotifier.value['payload'] as Map<String, dynamic>?;
      final initialCategory = payload != null ? payload['category'] as String? : null;

      // We use a ValueKey here to force the screen to rebuild/refresh if the category changes
      return TransactionsScreen(
        key: ValueKey(initialCategory ?? 'trans_screen'),
        initialCategory: initialCategory,
      );
    }

    switch (_selectedIndex) {
      case 0:
        return const DashboardScreen();
      case 2:
        return const BudgetsScreen();
      case 3:
        return const ProfileScreen();
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- CRITICAL: Allows content to scroll BEHIND the floating glass nav ---
      extendBody: true,
      resizeToAvoidBottomInset: false, // Prevents keyboard from pushing the nav bar up

      body: _buildBody(),

      bottomNavigationBar: FinFlowBottomNav(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          // Update global notifier state to match, clearing any old payloads
          bottomNavNotifier.value = {'index': index, 'payload': null};
        },
      ),
    );
  }
}