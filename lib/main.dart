// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/notifiers/theme_notifier.dart';

// --- Features & Core Imports ---
import 'core/theme/app_theme.dart';
import 'core/notifiers/bottom_nav_notifier.dart';
import 'features/splash/splash_screen.dart'; // <--- The New Entry Point

// --- Screens for the Bottom Nav ---
import 'features/dashboard/dashboard_screen.dart';
import 'features/transactions/transactions_screen.dart';
import 'features/budgets/budgets_screen.dart';
import 'features/profile/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ThemeNotifier.init(); // Initialize Theme
  // We no longer check LocalStorage here.
  // The SplashScreen handles the decision logic now.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeNotifier.themeMode,
        builder: (context, mode, child) {
          return MaterialApp(
            title: 'FinFlow',

            // Theme Configuration
            theme: AppTheme.iosLight,
            darkTheme: AppTheme.iosDark,
            themeMode: ThemeMode.system,
            // Starts with system default

            debugShowCheckedModeBanner: false,

            // Start with the Animated Splash Screen
            home: const SplashScreen(),
          );
        },
    );
  }
}

// --- Main App Shell (Bottom Navigation) ---
// This is called by AuthGate when the user is logged in.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  int _selectedIndex = 0;

  // Listen to the notifier to allow other screens to switch tabs programmatically
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
    setState(() {
      _selectedIndex = idx;
    });
  }

  Widget _buildBody() {
    // Pass payload to TransactionsScreen if needed (e.g., from "Add Expense" logic)
    if (_selectedIndex == 1) {
      final payload = bottomNavNotifier.value['payload'] as Map<String, dynamic>?;
      final initialCategory = payload != null ? payload['category'] as String? : null;
      return TransactionsScreen(initialCategory: initialCategory);
    }

    switch (_selectedIndex) {
      case 0:
        return const DashboardScreen();
      case 1:
      // Transactions (Handled above, but kept for safety)
        return const TransactionsScreen();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: Theme(
        // Override theme to ensure bottom nav looks consistent
        data: Theme.of(context).copyWith(
          canvasColor: isDark ? const Color(0xFF000000) : Colors.white,
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) {
            setState(() => _selectedIndex = i);
            // Clear payload on manual tap so it doesn't persist
            bottomNavNotifier.value = {'index': i, 'payload': null};
          },
          type: BottomNavigationBarType.fixed, // Ensures labels always show if you want
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          elevation: 8,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded),
                label: 'Dashboard'
            ),
            BottomNavigationBarItem(
                icon: Icon(Icons.list_alt_rounded),
                label: 'Transactions'
            ),
            BottomNavigationBarItem(
                icon: Icon(Icons.pie_chart_outline_rounded),
                label: 'Budgets'
            ),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                label: 'Profile'
            ),
          ],
        ),
      ),
    );
  }
}