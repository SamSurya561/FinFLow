// lib/core/data/repository.dart

// 1. Imports for Storage and Models
import '../storage/local_storage.dart';
import '../storage/profile_storage.dart';
import '../../features/budgets/storage/budget_storage.dart';
import '../../features/transactions/models/expense_model.dart';

class Repository {
  // Use this SINGLE method instead of calling LocalStorage + Profile separately
  static Future<void> addExpense(Expense expense) async {
    await LocalStorage.saveExpense(expense);
    await _syncProfileStats(); // Auto-updates the "Safe-to-Spend"
  }

  static Future<void> deleteExpense(int index) async {
    await LocalStorage.deleteExpenseAt(index);
    await _syncProfileStats();
  }

  // Helper: Updates the Profile summary (Safe-to-Spend) whenever data changes
  static Future<void> _syncProfileStats() async {
    try {
      final budgets = await BudgetStorage.getBudgets();
      final expenses = await LocalStorage.getExpenses();
      final now = DateTime.now();

      // Calculate spent this month
      final spent = expenses
          .where((x) => x.date.year == now.year && x.date.month == now.month)
          .fold<double>(0.0, (p, c) => p + c.amount);

      // Calculate total budget limit
      final totalBudget = budgets.fold<double>(0.0, (p, b) => p + (b.limit));

      // Calculate Safe-to-Spend
      final safe = (totalBudget - spent) < 0 ? 0.0 : (totalBudget - spent);

      // Save to Profile
      await Profile.updateBudgetSummary(
        budgetsCount: budgets.length,
        spentThisMonth: spent,
        safeToSpendEstimate: safe,
      );
    } catch (_) {
      // Fail silently if sync has issues (prevents app crash)
    }
  }
}