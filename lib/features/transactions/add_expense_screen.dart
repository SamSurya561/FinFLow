// lib/features/transactions/add_expense_screen.dart
import 'package:flutter/material.dart';
import '../../core/storage/local_storage.dart';
import 'models/expense_model.dart';

// NEW imports for profile updates
import '../../core/storage/profile_storage.dart';
import '../budgets/storage/budget_storage.dart';

class AddExpenseScreen extends StatefulWidget {
  // optional expense => if provided, screen works in EDIT mode
  final Expense? expense;
  const AddExpenseScreen({Key? key, this.expense}) : super(key: key);

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  String _category = 'Food';
  late DateTime _date;

  bool get isEdit => widget.expense != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final e = widget.expense!;
      _amountController = TextEditingController(text: e.amount.toString());
      _noteController = TextEditingController(text: e.note);
      _category = e.category;
      _date = e.date;
    } else {
      _amountController = TextEditingController();
      _noteController = TextEditingController();
      _date = DateTime.now();
    }
  }

  @override
  void dispose() {
    // Correct disposal of controllers
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final parsed = double.parse(_amountController.text.trim());
    final note = _noteController.text.trim();

    if (isEdit) {
      // update existing: read full list, find by id and replace, then save full list
      final list = await LocalStorage.getExpenses();
      final idx = list.indexWhere((it) => it.id == widget.expense!.id);
      if (idx != -1) {
        list[idx] = Expense(
          id: widget.expense!.id,
          amount: parsed,
          category: _category,
          note: note,
          date: _date,
        );
        await LocalStorage.saveExpenses(list);

        // === NEW: update profile summary after saving full list ===
        try {
          final budgets = await BudgetStorage.getBudgets();
          final expenses = await LocalStorage.getExpenses();
          final now = DateTime.now();
          final spent = expenses
              .where((x) => x.date.year == now.year && x.date.month == now.month)
              .fold<double>(0.0, (p, c) => p + c.amount);
          final totalBudget = budgets.fold<double>(0.0, (p, b) => p + (b.limit ?? 0.0));
          final safe = (totalBudget - spent) < 0 ? 0.0 : (totalBudget - spent);
          await Profile.updateBudgetSummary(
            budgetsCount: budgets.length,
            spentThisMonth: spent,
            safeToSpendEstimate: safe,
          );
        } catch (_) {}
        Navigator.pop(context, true); // saved
        return;
      } else {
        // fallback: append as new (shouldn't happen)
        final newExpense = Expense(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          amount: parsed,
          category: _category,
          note: note,
          date: _date,
        );
        await LocalStorage.saveExpense(newExpense);

        // === NEW: update profile summary after saving a new expense (fallback) ===
        try {
          final budgets = await BudgetStorage.getBudgets();
          final expenses = await LocalStorage.getExpenses();
          final now = DateTime.now();
          final spent = expenses
              .where((x) => x.date.year == now.year && x.date.month == now.month)
              .fold<double>(0.0, (p, c) => p + c.amount);
          final totalBudget = budgets.fold<double>(0.0, (p, b) => p + (b.limit ?? 0.0));
          final safe = (totalBudget - spent) < 0 ? 0.0 : (totalBudget - spent);
          await Profile.updateBudgetSummary(
            budgetsCount: budgets.length,
            spentThisMonth: spent,
            safeToSpendEstimate: safe,
          );
        } catch (_) {}

        Navigator.pop(context, true);
        return;
      }
    } else {
      // create new and append
      final newExpense = Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: parsed,
        category: _category,
        note: note,
        date: _date,
      );
      await LocalStorage.saveExpense(newExpense);

      // === NEW: update profile summary after creating new expense ===
      try {
        final budgets = await BudgetStorage.getBudgets();
        final expenses = await LocalStorage.getExpenses();
        final now = DateTime.now();
        final spent = expenses
            .where((x) => x.date.year == now.year && x.date.month == now.month)
            .fold<double>(0.0, (p, c) => p + c.amount);
        final totalBudget = budgets.fold<double>(0.0, (p, b) => p + (b.limit ?? 0.0));
        final safe = (totalBudget - spent) < 0 ? 0.0 : (totalBudget - spent);
        await Profile.updateBudgetSummary(
          budgetsCount: budgets.length,
          spentThisMonth: spent,
          safeToSpendEstimate: safe,
        );
      } catch (_) {}

      Navigator.pop(context, true);
      return;
    }
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (t == null) return;
    setState(() {
      _date = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  String _fmt(DateTime dt) => '${dt.day}-${dt.month}-${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isEdit ? AppBar(title: const Text('Edit expense')) : AppBar(title: const Text('Add expense')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter amount';
                      final n = double.tryParse(v);
                      if (n == null) return 'Invalid number';
                      if (n <= 0) return 'Amount must be > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: <String>['Food', 'Travel', 'Shopping', 'Bills', 'General or Others'].map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _category = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: 'Note (optional)'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text('Date: ${_fmt(_date)}')),
                      TextButton(onPressed: _pickDateTime, child: const Text('Change')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(onPressed: _save, child: Text(isEdit ? 'Save' : 'Add'))),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
