import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/transaction_model.dart';
import 'add_expense_screen.dart';

class IncomesScreen extends StatelessWidget {
  const IncomesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Income History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        elevation: 0,
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: FirestoreService().getTransactionsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // Filter for Income Only
          final incomes = snapshot.data!.where((t) => t.type == TxnType.income).toList();

          if (incomes.isEmpty) {
            return Center(child: Text("No income records found", style: TextStyle(color: Colors.grey[500])));
          }

          final totalIncome = incomes.fold(0.0, (sum, item) => sum + item.amount);

          return Column(
            children: [
              // Total Card
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF30D158), Color(0xFF34C759)]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: const Color(0xFF30D158).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("TOTAL EARNINGS", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('₹ ${totalIncome.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const Icon(Icons.savings_rounded, color: Colors.white, size: 32),
                  ],
                ),
              ),

              // List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: incomes.length,
                  itemBuilder: (context, index) {
                    final income = incomes[index];
                    return Card(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFF30D158).withOpacity(0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.attach_money, color: Color(0xFF30D158)),
                        ),
                        title: Text(income.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(DateFormat('MMM d, yyyy').format(income.date)),
                        trailing: Text('+ ${income.amount.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF30D158), fontWeight: FontWeight.bold, fontSize: 16)),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddExpenseScreen(transaction: income))),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}