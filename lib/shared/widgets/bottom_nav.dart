import 'package:flutter/material.dart';

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
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long),
          label: 'Transactions',
        ),
        NavigationDestination(
          icon: Icon(Icons.pie_chart),
          label: 'Budgets',
        ),
        NavigationDestination(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
