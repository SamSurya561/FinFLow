import 'package:flutter/material.dart';

class SafeToSpendCard extends StatelessWidget {
  final double balance;
  final double upcomingBills;
  final double savingsGoal;

  const SafeToSpendCard({
    super.key,
    required this.balance,
    required this.upcomingBills,
    required this.savingsGoal,
  });

  @override
  Widget build(BuildContext context) {
    final double safeToSpend = balance - upcomingBills - savingsGoal;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Safe to Spend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Text(
              '₹ ${safeToSpend.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _info('Balance', balance),
                _info('Bills', upcomingBills),
                _info('Savings', savingsGoal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          '₹ ${amount.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
