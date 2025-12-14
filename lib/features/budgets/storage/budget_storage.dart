// lib/features/budgets/storage/budget_storage.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget_model.dart';

// NEW imports for profile summary updates
import '/core/storage/profile_storage.dart';
import '/core/storage/local_storage.dart';

class BudgetStorage {
  static const String _key = 'budgets';

  /// Return the saved budgets (empty list if none)
  static Future<List<Budget>> getBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.map((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return Budget.fromJson(m);
      } catch (_) {
        // ignore malformed entry, skip it
        return null;
      }
    }).whereType<Budget>().toList();
  }

  /// Overwrite all budgets
  static Future<bool> saveBudgets(List<Budget> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = budgets.map((b) => jsonEncode(b.toJson())).toList();
    final ok = await prefs.setStringList(_key, encoded);

    // === NEW: update profile summary after budgets change ===
    try {
      await _updateProfileSummary();
    } catch (_) {}

    return ok;
  }

  /// Add or update a single budget by id. Returns true if saved successfully.
  static Future<bool> saveBudget(Budget budget) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    // decode existing into budgets
    final budgets = existing.map((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return Budget.fromJson(m);
      } catch (_) {
        return null;
      }
    }).whereType<Budget>().toList();

    final idx = budgets.indexWhere((b) => b.id == budget.id);
    if (idx >= 0) {
      budgets[idx] = budget;
    } else {
      budgets.add(budget);
    }
    final encoded = budgets.map((b) => jsonEncode(b.toJson())).toList();
    final ok = await prefs.setStringList(_key, encoded);

    // === NEW: update profile summary after single budget save ===
    try {
      await _updateProfileSummary();
    } catch (_) {}

    return ok;
  }

  /// Delete by index
  static Future<bool> deleteBudgetAt(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    if (index < 0 || index >= existing.length) return false;
    existing.removeAt(index);
    final ok = await prefs.setStringList(_key, existing);

    // === NEW: update profile summary after delete ===
    try {
      await _updateProfileSummary();
    } catch (_) {}

    return ok;
  }

  /// Delete by id
  static Future<bool> deleteBudgetById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    final budgets = existing.map((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return Budget.fromJson(m);
      } catch (_) {
        return null;
      }
    }).whereType<Budget>().toList();
    final filtered = budgets.where((b) => b.id != id).map((b) => jsonEncode(b.toJson())).toList();
    final ok = await prefs.setStringList(_key, filtered);

    // === NEW: update profile summary after delete by id ===
    try {
      await _updateProfileSummary();
    } catch (_) {}

    return ok;
  }

  /// Compute and persist profile summary using budgets and current-month expenses.
  static Future<void> _updateProfileSummary() async {
    try {
      final budgets = await getBudgets();
      final expenses = await LocalStorage.getExpenses();
      final now = DateTime.now();

      final spentThisMonth = expenses
          .where((e) => e.date.year == now.year && e.date.month == now.month)
          .fold<double>(0.0, (p, c) => p + c.amount);

      final totalBudgetLimits = budgets.fold<double>(0.0, (p, b) {
        try {
          return p + (b.limit ?? 0.0);
        } catch (_) {
          return p;
        }
      });

      final safeToSpendEstimate = (totalBudgetLimits - spentThisMonth) < 0 ? 0.0 : (totalBudgetLimits - spentThisMonth);

      await Profile.updateBudgetSummary(
        budgetsCount: budgets.length,
        spentThisMonth: spentThisMonth,
        safeToSpendEstimate: safeToSpendEstimate,
      );
    } catch (_) {
      // Swallow errors: do not break callers if something goes wrong here.
    }
  }
}
