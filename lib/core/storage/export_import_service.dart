// lib/core/storage/export_import_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import 'local_storage.dart';
import '../../features/budgets/models/budget_model.dart';
import '../../features/budgets/storage/budget_storage.dart';
import '../../features/transactions/models/expense_model.dart';

class ExportImportService {
  // CSV filenames
  static const String budgetsFileName = 'budgets.csv';
  static const String expensesFileName = 'expenses.csv';

  // --- Export helpers -----------------------------------------------------

  /// Export budgets and expenses as two CSV files and open the share sheet.
  /// Returns true on success.
  static Future<bool> exportAllCsv(BuildContext context) async {
    try {
      final dir = await _getAppDocsDir();

      // budgets
      final budgets = await BudgetStorage.getBudgets() ?? <Budget>[];
      final budgetsCsv = _budgetsToCsv(budgets);
      final budgetsFile = File('${dir.path}/$budgetsFileName');
      await budgetsFile.writeAsString(budgetsCsv, flush: true);

      // expenses
      final expenses = await LocalStorage.getExpenses() ?? <Expense>[];
      final expensesCsv = _expensesToCsv(expenses);
      final expensesFile = File('${dir.path}/$expensesFileName');
      await expensesFile.writeAsString(expensesCsv, flush: true);

      // Share both files via share_plus
      await Share.shareXFiles([
        XFile(budgetsFile.path),
        XFile(expensesFile.path),
      ], text: 'FinFlow export: budgets and expenses CSV');

      return true;
    } catch (e, st) {
      debugPrint('Export failed: $e\n$st');
      await _showMessage(context, 'Export failed: ${e.toString()}');
      return false;
    }
  }

  // Convert budgets to CSV (header + rows)
  static String _budgetsToCsv(List<Budget> budgets) {
    final rows = <List<dynamic>>[];
    rows.add(['id', 'category', 'limit', 'rollover']);
    for (final b in budgets) {
      rows.add([b.id, b.category, b.limit.toString(), b.rollover ? 'true' : 'false']);
    }
    return const ListToCsvConverter().convert(rows);
  }

  // Convert expenses to CSV. Use ISO 8601 for date column.
  static String _expensesToCsv(List<Expense> expenses) {
    final rows = <List<dynamic>>[];
    rows.add(['id', 'amount', 'category', 'date_iso', 'note', 'type']);
    for (final e in expenses) {
      rows.add([
        e.id,
        e.amount.toString(),
        e.category,
        e.date.toIso8601String(),
        e.note ?? '',
        //e.type ?? '' // if you have types, else empty
      ]);
    }
    return const ListToCsvConverter().convert(rows);
  }

  // --- Import helpers -----------------------------------------------------

  /// Ask the user to pick either budgets.csv or expenses.csv (or any csv).
  /// After file is selected, asks the user whether to Replace or Merge.
  static Future<void> importCsvFlow(BuildContext context) async {
    try {
      // 1) pick file (use file_picker; fallback to paste)
      String? picked;
      try {
        final result = await FilePicker.platform.pickFiles(
          dialogTitle: 'Select CSV file (budgets.csv or expenses.csv)',
          type: FileType.custom,
          allowedExtensions: ['csv', 'txt'],
        );

        if (result != null && result.files.single.path != null) {
          final path = result.files.single.path!;
          picked = await File(path).readAsString();
        }
      } catch (e) {
        // file_picker not available or failed — we'll fall back to paste.
        debugPrint('File picker failed: $e');
      }

      // if user didn't pick a file, prompt to paste CSV text
      if (picked == null) {
        picked = await _pasteCsvFallback(context);
        if (picked == null) return; // user cancelled
      }

      // Parse CSV
      final csvRows = const CsvToListConverter(eol: '\n').convert(picked);
      if (csvRows.isEmpty) {
        await _showMessage(context, 'CSV appears to be empty.');
        return;
      }

      // Determine file type from header row
      final header = csvRows.first.map((e) => e.toString().trim().toLowerCase()).toList();

      if (_isBudgetHeader(header)) {
        await _askReplaceOrMergeAndImportBudgets(context, csvRows);
      } else if (_isExpenseHeader(header)) {
        await _askReplaceOrMergeAndImportExpenses(context, csvRows);
      } else {
        await _showMessage(context, 'CSV header not recognized. Expected budgets or expenses format.');
      }
    } catch (e, st) {
      debugPrint('Import failed: $e\n$st');
      await _showMessage(context, 'Import failed: ${e.toString()}');
    }
  }

  // Determine headers
  static bool _isBudgetHeader(List<String> header) {
    return header.contains('id') && header.contains('category') && header.contains('limit');
  }

  static bool _isExpenseHeader(List<String> header) {
    return header.contains('id') && header.contains('amount') && header.contains('date_iso');
  }

  // Ask user Replace or Merge for budgets
  static Future<void> _askReplaceOrMergeAndImportBudgets(BuildContext context, List<List<dynamic>> csvRows) async {
    final action = await showDialog<_ImportAction?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import budgets'),
        content: const Text('Do you want to replace existing budgets or merge?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, _ImportAction.cancel), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, _ImportAction.merge), child: const Text('Merge')),
          TextButton(onPressed: () => Navigator.pop(ctx, _ImportAction.replace), child: const Text('Replace')),
        ],
      ),
    );

    if (action == null || action == _ImportAction.cancel) return;

    // parse budgets (skip header)
    final parsed = _parseBudgetsFromCsv(csvRows);
    if (parsed.isEmpty) {
      await _showMessage(context, 'No valid budget rows found.');
      return;
    }

    final existing = await BudgetStorage.getBudgets() ?? [];

    if (action == _ImportAction.replace) {
      await BudgetStorage.saveBudgets(parsed);
      await _showMessage(context, 'Budgets replaced (${parsed.length} items).');
    } else {
      // merge: add only those with unique id or unique category
      final Map<String, Budget> mapById = { for (var b in existing) b.id : b };
      final Set<String> categories = existing.map((e) => e.category.toLowerCase()).toSet();

      for (final b in parsed) {
        if (mapById.containsKey(b.id)) {
          // update by id
          mapById[b.id] = b;
        } else if (categories.contains(b.category.toLowerCase())) {
          // skip duplicate category
          continue;
        } else {
          mapById[b.id] = b;
          categories.add(b.category.toLowerCase());
        }
      }

      final merged = mapById.values.toList();
      await BudgetStorage.saveBudgets(merged);
      await _showMessage(context, 'Budgets merged (now ${merged.length} items).');
    }
  }

  // Ask user Replace or Merge for expenses
  static Future<void> _askReplaceOrMergeAndImportExpenses(BuildContext context, List<List<dynamic>> csvRows) async {
    final action = await showDialog<_ImportAction?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import expenses'),
        content: const Text('Do you want to replace existing expenses or merge?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, _ImportAction.cancel), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, _ImportAction.merge), child: const Text('Merge')),
          TextButton(onPressed: () => Navigator.pop(ctx, _ImportAction.replace), child: const Text('Replace')),
        ],
      ),
    );

    if (action == null || action == _ImportAction.cancel) return;

    final parsed = _parseExpensesFromCsv(csvRows);
    if (parsed.isEmpty) {
      await _showMessage(context, 'No valid expense rows found.');
      return;
    }

    final existing = await LocalStorage.getExpenses() ?? [];

    if (action == _ImportAction.replace) {
      await LocalStorage.saveExpenses(parsed);
      await _showMessage(context, 'Expenses replaced (${parsed.length} items).');
    } else {
      // merge by id (if id present), else add unique entries
      final Map<String, Expense> mapById = { for (var e in existing) e.id : e };
      for (final e in parsed) {
        if (e.id.isNotEmpty && mapById.containsKey(e.id)) {
          mapById[e.id] = e;
        } else {
          // add new
          mapById[e.id.isNotEmpty ? e.id : DateTime.now().millisecondsSinceEpoch.toString()] = e;
        }
      }
      final merged = mapById.values.toList();
      await LocalStorage.saveExpenses(merged);
      await _showMessage(context, 'Expenses merged (now ${merged.length} items).');
    }
  }

  // --- CSV parsing into domain models -----------------------------------

  static List<Budget> _parseBudgetsFromCsv(List<List<dynamic>> rows) {
    if (rows.length < 2) return [];
    final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();

    final idIdx = header.indexOf('id');
    final catIdx = header.indexOf('category');
    final limitIdx = header.indexOf('limit');
    final rollIdx = header.indexOf('rollover');

    final List<Budget> parsed = [];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 3) continue;
      try {
        final id = idIdx >= 0 && idIdx < row.length ? row[idIdx].toString() : DateTime.now().millisecondsSinceEpoch.toString();
        final cat = catIdx >= 0 && catIdx < row.length ? row[catIdx].toString() : '';
        final limit = limitIdx >= 0 && limitIdx < row.length ? double.tryParse(row[limitIdx].toString()) ?? 0.0 : 0.0;
        final rollover = rollIdx >= 0 && rollIdx < row.length ? row[rollIdx].toString().toLowerCase() == 'true' : false;
        if (cat.trim().isEmpty) continue;
        parsed.add(Budget(id: id.toString(), category: cat.toString(), limit: limit, rollover: rollover));
      } catch (_) {
        // ignore single malformed rows
        continue;
      }
    }
    return parsed;
  }

  static List<Expense> _parseExpensesFromCsv(List<List<dynamic>> rows) {
    if (rows.length < 2) return [];
    final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();

    final idIdx = header.indexOf('id');
    final amountIdx = header.indexOf('amount');
    final catIdx = header.indexOf('category');
    final dateIdx = header.indexOf('date_iso');
    final noteIdx = header.indexOf('note');
    final typeIdx = header.indexOf('type');

    final List<Expense> parsed = [];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 3) continue;
      try {
        final id = idIdx >= 0 && idIdx < row.length ? row[idIdx].toString() : DateTime.now().millisecondsSinceEpoch.toString();
        final amount = amountIdx >= 0 && amountIdx < row.length ? double.tryParse(row[amountIdx].toString()) ?? 0.0 : 0.0;
        final cat = catIdx >= 0 && catIdx < row.length ? row[catIdx].toString() : 'Unknown';
        final dateStr = dateIdx >= 0 && dateIdx < row.length ? row[dateIdx].toString() : DateTime.now().toIso8601String();
        DateTime date;
        try {
          date = DateTime.parse(dateStr);
        } catch (_) {
          date = DateTime.now();
        }
        final note = noteIdx >= 0 && noteIdx < row.length ? row[noteIdx].toString() : '';
// If your Expense model DOES NOT have `type`, don't parse or pass it.
        parsed.add(Expense(
          id: id.toString(),
          amount: amount,
          category: cat,
          date: date,
          note: note,
        ));

      } catch (_) {
        continue;
      }
    }
    return parsed;
  }

  // --- fallback paste dialog (if file picker fails) ---------------------

  static Future<String?> _pasteCsvFallback(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste CSV contents'),
        content: SizedBox(
          height: 260,
          child: Column(
            children: [
              const Text('If the app cannot open the file picker, paste the CSV file content here.'),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste CSV text...'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Use text')),
        ],
      ),
    );
    return result;
  }

  // --- small helpers -----------------------------------------------------

  static Future<Directory> _getAppDocsDir() async {
    return await getApplicationDocumentsDirectory();
  }

  static Future<void> _showMessage(BuildContext ctx, String msg) async {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

enum _ImportAction { replace, merge, cancel }
