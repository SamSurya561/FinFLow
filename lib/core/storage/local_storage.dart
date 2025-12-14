// lib/core/storage/local_storage.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/transactions/models/expense_model.dart';

class LocalStorage {
  // ---------------------------------------------------------------------------
  // EXPENSES (existing – unchanged)
  // ---------------------------------------------------------------------------
  static const String _expensesKey = 'finflow_expenses';

  static Future<List<Expense>> getExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_expensesKey) ?? [];
    return list
        .map((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return Expense.fromJson(m);
      } catch (_) {
        return null;
      }
    })
        .whereType<Expense>()
        .toList();
  }

  static Future<bool> saveExpenses(List<Expense> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = expenses.map((e) => jsonEncode(e.toJson())).toList();
    return prefs.setStringList(_expensesKey, encoded);
  }

  static Future<bool> saveExpense(Expense expense) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_expensesKey) ?? [];
    existing.add(jsonEncode(expense.toJson()));
    return prefs.setStringList(_expensesKey, existing);
  }

  static Future<bool> deleteExpenseAt(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_expensesKey) ?? [];
    if (index < 0 || index >= existing.length) return false;
    existing.removeAt(index);
    return prefs.setStringList(_expensesKey, existing);
  }

  // ---------------------------------------------------------------------------
  // INCOMES (existing – unchanged)
  // ---------------------------------------------------------------------------
  static const String _incomesKey = 'finflow_incomes';

  static Future<List<Map<String, dynamic>>> getIncomes() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_incomesKey) ?? [];
    final out = <Map<String, dynamic>>[];
    for (final s in list) {
      try {
        out.add(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {}
    }
    return out;
  }

  static Future<bool> saveIncomes(List<Map<String, dynamic>> incomes) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = incomes.map((m) => jsonEncode(m)).toList();
    return prefs.setStringList(_incomesKey, encoded);
  }

  static Future<bool> saveIncome(Map<String, dynamic> income) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_incomesKey) ?? [];
    existing.add(jsonEncode(income));
    return prefs.setStringList(_incomesKey, existing);
  }

  static Future<bool> deleteIncomeAt(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_incomesKey) ?? [];
    if (index < 0 || index >= existing.length) return false;
    existing.removeAt(index);
    return prefs.setStringList(_incomesKey, existing);
  }

  // ---------------------------------------------------------------------------
  // SAVING GOAL (existing – unchanged)
  // ---------------------------------------------------------------------------
  static const String _savingGoalKey = 'finflow_saving_goal';

  static Future<bool> saveSavingGoal(Map<String, dynamic> goal) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_savingGoalKey, jsonEncode(goal));
  }

  static Future<Map<String, dynamic>?> getSavingGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_savingGoalKey);
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> deleteSavingGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(_savingGoalKey);
  }

  // ---------------------------------------------------------------------------
  // 🔥 NEW: DASHBOARD SUMMARY (single source of truth)
  // ---------------------------------------------------------------------------
  static const String _dashboardSummaryKey = 'finflow_dashboard_summary';

  /// Save computed dashboard values (called ONLY from Dashboard)
  static Future<bool> saveDashboardSummary({
    required double totalIncome,
    required double totalExpenses,
    required double balance,
    required double safeToSpend,
    required double savingsGoal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final map = {
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'balance': balance,
      'safeToSpend': safeToSpend,
      'savingsGoal': savingsGoal,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    return prefs.setString(_dashboardSummaryKey, jsonEncode(map));
  }

  /// Read dashboard summary (used by Profile screen)
  static Future<Map<String, dynamic>?> getDashboardSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_dashboardSummaryKey);
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
