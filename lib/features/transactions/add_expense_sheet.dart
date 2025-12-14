// lib/features/transactions/add_expense_sheet.dart
import 'package:flutter/material.dart';
import '../../core/storage/local_storage.dart';
import 'models/expense_model.dart';

// NEW imports for profile summary update
import '../../core/storage/profile_storage.dart';
import '../budgets/storage/budget_storage.dart';

/// Shows a modal bottom sheet that functions as Add / Edit expense UI.
/// Call like:
///   final saved = await showAddExpenseSheet(context, expense: maybeExpense);
/// Returns true when a change was saved, false/null otherwise.
Future<bool?> showAddExpenseSheet(BuildContext ctx, {Expense? expense}) {
  return showModalBottomSheet<bool>(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _AddExpenseSheetContent(expense: expense),
      );
    },
  );
}

class _AddExpenseSheetContent extends StatefulWidget {
  final Expense? expense;
  const _AddExpenseSheetContent({Key? key, this.expense}) : super(key: key);

  @override
  State<_AddExpenseSheetContent> createState() => _AddExpenseSheetContentState();
}

class _AddExpenseSheetContentState extends State<_AddExpenseSheetContent> {
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
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _fmt(DateTime dt) =>
      '${dt.day}-${dt.month}-${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final parsed = double.parse(_amountController.text.trim());
    final note = _noteController.text.trim();

    if (isEdit) {
      // update existing: fetch list, replace by id, save list
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

        // === NEW: update profile summary after saving the updated list ===
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

        if (mounted) Navigator.pop(context, true);
        return;
      }
      // fallback: append
      final created = Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: parsed,
        category: _category,
        note: note,
        date: _date,
      );
      await LocalStorage.saveExpense(created);

      // === NEW: update profile summary after saving a new expense ===
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

      if (mounted) Navigator.pop(context, true);
      return;
    } else {
      final created = Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: parsed,
        category: _category,
        note: note,
        date: _date,
      );
      await LocalStorage.saveExpense(created);

      // === NEW: update profile summary after saving a new expense ===
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

      if (mounted) Navigator.pop(context, true);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = isEdit ? 'Edit expense' : 'Add expense';
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
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
                          items: <String>['Food', 'Travel', 'Shopping', 'Bills'].map((c) {
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
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _save,
                                child: Text(isEdit ? 'Save' : 'Add'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
