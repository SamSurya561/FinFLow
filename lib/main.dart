// lib/main.dart
import 'package:flutter/material.dart';
import 'core/notifiers/bottom_nav_notifier.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/transactions/transactions_screen.dart';
import 'features/budgets/budgets_screen.dart';
import 'core/theme/app_theme.dart';
import '../../features/profile/profile_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';




// Simple placeholder ProfileScreen in case file is missing in your project.
// You can remove this once you have your actual features/profile/profile_screen.dart.
//class ProfileScreen extends StatelessWidget {
//  const ProfileScreen({super.key});
//  @override
//  Widget build(BuildContext context) {
 //   return const Center(child: Text('Profile (placeholder)'));
 // }
//}

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinFlow',
      theme: AppTheme.iosLight,
      darkTheme: AppTheme.iosDark,
      themeMode: ThemeMode.system,
      home: const AppRoot(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  int _selectedIndex = 0;

  // We listen to bottomNavNotifier to allow other screens to request a tab switch.
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
    // When transactions tab is selected, pass optional initialCategory payload
    if (_selectedIndex == 1) {
      final payload = bottomNavNotifier.value['payload'] as Map<String, dynamic>?;
      final initialCategory = payload != null ? payload['category'] as String? : null;
      return TransactionsScreen(initialCategory: initialCategory);
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
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) {
          setState(() => _selectedIndex = i);
          // clear payload on manual tap
          bottomNavNotifier.value = {'index': i, 'payload': null};
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Transactions'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: 'Budgets'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
