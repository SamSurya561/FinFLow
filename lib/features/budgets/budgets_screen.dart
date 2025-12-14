// lib/features/budgets/budgets_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/storage/local_storage.dart';
import '../../core/theme/app_theme.dart';
import '../transactions/models/expense_model.dart';
import '../transactions/transactions_screen.dart';
import 'models/budget_model.dart';
import 'storage/budget_storage.dart';

/// Helper: normalize category -> Title case single word.
String _normalizeCategory(String s) {
  final t = s.trim();
  if (t.isEmpty) return t;
  return '${t[0].toUpperCase()}${t.substring(1).toLowerCase()}';
}

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  List<Budget> _budgets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final list = await BudgetStorage.getBudgets();
    setState(() {
      _budgets = list ?? [];
      _loading = false;
    });
  }

  double _spentForBudget(Budget b, List<Expense> allExpenses) {
    final month = DateTime.now();
    return allExpenses
        .where((e) =>
    e.category == b.category &&
        e.date.year == month.year &&
        e.date.month == month.month)
        .fold(0.0, (p, e) => p + e.amount);
  }

  Future<void> _showBudgetExpensesSheet(Budget b) async {
    final expenses = await LocalStorage.getExpenses() ?? [];
    final month = DateTime.now();
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final List<Expense> filtered = expenses
        .where((e) =>
    e.category == b.category && !e.date.isBefore(start) && e.date.isBefore(end))
        .toList();

    final total = filtered.fold(0.0, (p, e) => p + e.amount);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.78,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.category,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text('Total: ₹ ${total.toStringAsFixed(0)}',
                              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey)),
                        ],
                      ),
                      const Spacer(),
                      Text('Limit: ₹ ${b.limit.toStringAsFixed(0)}',
                          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                      child: Text('No transactions for ${b.category} this month',
                          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey)))
                      : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final e = filtered[i];
                      final time =
                          '${e.date.day.toString().padLeft(2, '0')}-${e.date.month.toString().padLeft(2, '0')}-${e.date.year} ${e.date.hour.toString().padLeft(2, '0')}:${e.date.minute.toString().padLeft(2, '0')}';
                      final color = _categoryColor(e.category);
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: color, child: const Text('₹', style: TextStyle(color: Colors.white))),
                        title: Text('₹ ${e.amount.toStringAsFixed(0)} • ${e.category}'),
                        subtitle: e.note.isNotEmpty ? Text('${e.note}\n$time') : Text(time),
                        isThreeLine: e.note.isNotEmpty,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => TransactionsScreen(initialCategory: b.category)),
                            );
                          },
                          child: const Text('View in Transactions'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Food':
        return Colors.orange;
      case 'Travel':
        return Colors.blue;
      case 'Shopping':
        return Colors.purple;
      case 'Bills':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showAddEditDialog({Budget? budget}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return _BudgetFormSheet(budget: budget);
      },
    );

    if (result == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            onPressed: () => _showAddEditDialog(budget: null),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: FutureBuilder<List<Expense>>(
        future: LocalStorage.getExpenses(),
        builder: (context, snap) {
          final allExpenses = snap.data ?? [];
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: _budgets.length,
            itemBuilder: (context, i) {
              final b = _budgets[i];
              final spent = _spentForBudget(b, allExpenses);
              final percent = b.limit > 0 ? (spent / b.limit).clamp(0.0, 1.0) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: AppTheme.animatedFrostedCard(
                  context: context,
                  index: i,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _showBudgetExpensesSheet(b),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(b.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                              Text('₹ ${b.limit.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: percent,
                            minHeight: 8,
                            backgroundColor: Colors.grey[800],
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('Spent: ₹ ${spent.toStringAsFixed(0)}', style: const TextStyle(color: Colors.grey)),
                              const Spacer(),
                              Text('${(percent * 100).toStringAsFixed(0)}%'),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: () async {
                                  await _showAddEditDialog(budget: b);
                                  await _refresh();
                                },
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete budget?'),
                                      content: Text('Delete budget for "${b.category}"?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    final list = await BudgetStorage.getBudgets() ?? [];
                                    list.removeWhere((x) => x.id == b.id);
                                    await BudgetStorage.saveBudgets(list);
                                    await _refresh();
                                  }
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Bottom sheet widget for add/edit budget.
/// Lifecycle-managed controllers to avoid the runtime crash you saw earlier.
class _BudgetFormSheet extends StatefulWidget {
  final Budget? budget;

  const _BudgetFormSheet({this.budget});

  @override
  State<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<_BudgetFormSheet> {
  late TextEditingController _limitController;
  late String _category;
  late bool _rollover;
  final _formKey = GlobalKey<FormState>();

  // prevent double saves & show spinner
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _limitController = TextEditingController(text: widget.budget?.limit.toString() ?? '');
    _category = widget.budget?.category ?? 'Food';
    _rollover = widget.budget?.rollover ?? false;
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _showDuplicateAlert(BuildContext ctx, String category) async {
    await showDialog<void>(
      context: ctx,
      builder: (dctx) {
        return AlertDialog(
          title: const Text('Duplicate budget'),
          content: Text('A budget for "$category" already exists.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('OK')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.budget == null ? 'Add Budget' : 'Edit Budget', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _limitController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Limit (₹)'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter a number';
                        final parsed = double.tryParse(v.trim());
                        if (parsed == null) return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _category,
                      items: const [
                        DropdownMenuItem(value: 'Food', child: Text('Food')),
                        DropdownMenuItem(value: 'Travel', child: Text('Travel')),
                        DropdownMenuItem(value: 'Shopping', child: Text('Shopping')),
                        DropdownMenuItem(value: 'Bills', child: Text('Bills')),
                      ],
                      onChanged: (v) => setState(() => _category = v ?? _category),
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Rollover'),
                        const Spacer(),
                        Switch(value: _rollover, onChanged: (v) => setState(() => _rollover = v)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving
                                ? null
                                : () async {
                              if (_formKey.currentState?.validate() != true) return;

                              setState(() => _saving = true);
                              try {
                                final parsedLimit = double.parse(_limitController.text.trim());
                                final list = await BudgetStorage.getBudgets() ?? [];
                                final normalizedCategory = _category.trim().toLowerCase();

                                // Duplicate check (case-insensitive), allow editing the same id.
                                final bool wouldDuplicate = list.any((bItem) =>
                                bItem.category.trim().toLowerCase() == normalizedCategory &&
                                    (widget.budget == null || bItem.id != widget.budget!.id));

                                if (wouldDuplicate) {
                                  if (mounted) await _showDuplicateAlert(context, _category);
                                  return;
                                }

                                // Save new or update existing
                                if (widget.budget != null) {
                                  final idx = list.indexWhere((x) => x.id == widget.budget!.id);
                                  if (idx != -1) {
                                    final updated = widget.budget!.copyWith(
                                      limit: parsedLimit,
                                      category: _normalizeCategory(_category),
                                      rollover: _rollover,
                                    );
                                    list[idx] = updated;
                                    await BudgetStorage.saveBudgets(list);
                                  }
                                } else {
                                  final newB = Budget(
                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                    category: _normalizeCategory(_category),
                                    limit: parsedLimit,
                                    rollover: _rollover,
                                  );
                                  list.add(newB);
                                  await BudgetStorage.saveBudgets(list);
                                }

                                if (mounted) Navigator.pop(context, true);
                              } finally {
                                if (mounted) setState(() => _saving = false);
                              }
                            },
                            child: _saving
                                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
