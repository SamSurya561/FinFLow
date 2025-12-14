// lib/features/transactions/transactions_screen.dart
import 'package:flutter/material.dart';
import 'models/expense_model.dart';
import '../../core/storage/local_storage.dart';
import 'add_expense_screen.dart';
import '../../core/storage/export_import_service.dart';

// NEW imports for profile update
import '../../core/storage/profile_storage.dart';
import '../budgets/storage/budget_storage.dart';

enum SortMode { newest, oldest, highest, lowest, categoryAZ }

class TransactionsScreen extends StatefulWidget {
  final String? initialCategory;

  const TransactionsScreen({Key? key, this.initialCategory}) : super(key: key);

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Expense> _expenses = [];
  bool _loading = true;

  // Prevent the bottom sheet from being opened multiple times for the same expense.
  static final Set<String> _openSheetExpenses = <String>{};

  // Small debounce to ignore very fast repeated taps.
  int _lastTapMs = 0;

  // UI filters / search / sort
  String _selectedCategory = 'All';
  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();
  SortMode _sortMode = SortMode.newest;

  String get _searchQuery => _searchController.text.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _selectedCategory = widget.initialCategory!;
    }
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await LocalStorage.getExpenses();
    setState(() {
      _expenses = list;
      _applySort();
      _loading = false;
    });
  }

  Future<void> _saveAll() async {
    await LocalStorage.saveExpenses(_expenses);

    // === NEW: update profile summary after persisting full list
    await _updateProfileSummary();
  }

  /// Computes and updates the lightweight profile budget summary:
  /// budgetsCount, spentThisMonth (this calendar month), safeToSpendEstimate
  Future<void> _updateProfileSummary() async {
    try {
      final budgets = await BudgetStorage.getBudgets();
      final expenses = await LocalStorage.getExpenses();
      final now = DateTime.now();

      final spent = expenses
          .where((x) => x.date.year == now.year && x.date.month == now.month)
          .fold<double>(0.0, (p, c) => p + c.amount);

      final totalBudget = budgets.fold<double>(0.0, (p, b) {
        // keep defensive in case limit is nullable or non-numeric
        double limit = 0.0;
        try {
          limit = b.limit ?? 0.0;
        } catch (_) {
          // if model shape differs, assume 0
        }
        return p + limit;
      });

      final safe = (totalBudget - spent) < 0 ? 0.0 : (totalBudget - spent);

      await Profile.updateBudgetSummary(
        budgetsCount: budgets.length,
        spentThisMonth: spent,
        safeToSpendEstimate: safe,
      );
    } catch (_) {
      // do not interrupt UI if update fails
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // debounce + guard + per-expense guard
  Future<void> _openExpenseSheet(Expense e) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapMs < 400) return;
    _lastTapMs = now;

    if (_openSheetExpenses.contains(e.id)) return;

    _openSheetExpenses.add(e.id);

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        builder: (ctx) {
          return Padding(
            padding: MediaQuery.of(ctx).viewInsets,
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
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: const Text('₹'),
                  ),
                  title: Text('₹ ${e.amount.toStringAsFixed(0)} • ${e.category}'),
                  subtitle: Text('${e.note}\n${_formatDate(e.date)}'),
                  isThreeLine: e.note.isNotEmpty,
                ),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditDialog(e);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _deleteExpense(e);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    } finally {
      _openSheetExpenses.remove(e.id);
    }
  }

  Future<void> _deleteExpense(Expense e) async {
    final index = _expenses.indexWhere((x) => x.id == e.id);
    if (index == -1) return;

    // Save for undo
    final deletedExpense = _expenses[index];
    final deletedIndex = index;

    // Remove from UI
    setState(() {
      _expenses.removeAt(index);
    });

    // Immediately persist the change (delete from storage)
    final ok = await LocalStorage.deleteExpenseAt(index);

    if (!mounted) return;

    if (!ok) {
      // failed to delete from storage: restore
      setState(() {
        _expenses.insert(deletedIndex, deletedExpense);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete expense')),
      );
      return;
    }

    // === NEW: update profile summary after delete ===
    await _updateProfileSummary();

    // Show undo snackbar
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Expense deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            // restore in UI
            setState(() {
              _expenses.insert(deletedIndex, deletedExpense);
              _applySort(); // reapply sorting ordering
            });
            // persist full list to storage (overwrite)
            await _saveAll();
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // EDIT: show a full form in bottom sheet to edit a single expense
  Future<void> _showEditDialog(Expense e) async {
    final index = _expenses.indexWhere((x) => x.id == e.id);
    if (index == -1) return;

    final formKey = GlobalKey<FormState>();
    double amount = e.amount;
    String category = e.category;
    String note = e.note;
    DateTime date = e.date;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 12,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Edit expense', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                Form(
                  key: formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: amount.toString(),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Amount (₹)'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter amount';
                          final parsed = double.tryParse(v);
                          if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                          return null;
                        },
                        onSaved: (v) => amount = double.parse(v!.trim()),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: category,
                        items: const [
                          DropdownMenuItem(value: 'Food', child: Text('Food')),
                          DropdownMenuItem(value: 'Travel', child: Text('Travel')),
                          DropdownMenuItem(value: 'Shopping', child: Text('Shopping')),
                          DropdownMenuItem(value: 'Bills', child: Text('Bills')),
                        ],
                        onChanged: (v) => category = v ?? category,
                        decoration: const InputDecoration(labelText: 'Category'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: note,
                        decoration: const InputDecoration(labelText: 'Note (optional)'),
                        onSaved: (v) => note = v ?? '',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text('Date: ${_formatDate(date)}'),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              final dt = await showDatePicker(
                                context: ctx,
                                initialDate: date,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (dt != null) {
                                final tm = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(date));
                                if (tm != null) {
                                  date = DateTime(dt.year, dt.month, dt.day, tm.hour, tm.minute);
                                }
                              }
                            },
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              formKey.currentState!.save();

                              final original = _expenses[index];

                              // Use copyWith to update the object
                              final updated = original.copyWith(
                                amount: amount,
                                category: category,
                                note: note,
                                date: date,
                              );

                              // replace in list (maintain same index to keep order)
                              setState(() {
                                _expenses[index] = updated;
                                _applySort();
                              });

                              // persist whole list
                              await _saveAll();

                              Navigator.pop(ctx); // close edit sheet
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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

  // FILTER predicate
  bool _passesFilter(Expense e) {
    if (_selectedCategory != 'All' && e.category != _selectedCategory) return false;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery;
      final inNote = e.note.toLowerCase().contains(q);
      final inCat = e.category.toLowerCase().contains(q);
      final inAmount = e.amount.toString().toLowerCase().contains(q);
      return inNote || inCat || inAmount;
    }
    return true;
  }

  // Sorting logic for _expenses list (modifies list in-place)
  void _applySort() {
    switch (_sortMode) {
      case SortMode.newest:
        _expenses.sort((a, b) => b.date.compareTo(a.date));
        break;
      case SortMode.oldest:
        _expenses.sort((a, b) => a.date.compareTo(b.date));
        break;
      case SortMode.highest:
        _expenses.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case SortMode.lowest:
        _expenses.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case SortMode.categoryAZ:
        _expenses.sort((a, b) => a.category.compareTo(b.category));
        break;
    }
  }

  // GROUPING + build visible widgets
  List<Widget> _buildGroupedList() {
    final Map<String, List<Expense>> groups = {};

    // iterate in display order
    final displayList = List<Expense>.from(_expenses);

    for (final e in displayList) {
      if (!_passesFilter(e)) continue;
      final key = _groupKey(e.date);
      groups.putIfAbsent(key, () => []).add(e);
    }

    final List<Widget> widgets = [];

    groups.forEach((group, list) {
      final total = list.fold(0.0, (p, e) => p + e.amount);

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            '$group — ₹ ${total.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );

      for (final e in list) {
        widgets.add(_buildDismissibleTile(e));
        widgets.add(const Divider(height: 1));
      }
    });

    if (widgets.isEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No transactions match your filters')),
        ),
      );
    }

    return widgets;
  }

  String _groupKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expenseDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(expenseDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${date.day}-${date.month}-${date.year}';
  }

  Widget _buildDismissibleTile(Expense e) {
    return Dismissible(
      key: Key(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        await _deleteExpense(e);
      },
      child: _expenseTile(e),
    );
  }

  Widget _expenseTile(Expense e) {
    final colorMap = {
      'Food': Colors.orange,
      'Travel': Colors.blue,
      'Shopping': Colors.purple,
      'Bills': Colors.red,
    };

    final color = colorMap[e.category] ?? Colors.grey;

    return ListTile(
      leading: CircleAvatar(backgroundColor: color, child: const Text('₹')),
      title: Text('₹ ${e.amount.toStringAsFixed(0)} • ${e.category}'),
      subtitle: Text('${e.note}\n${_formatDate(e.date)}'),
      isThreeLine: e.note.isNotEmpty,
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'edit') {
            _showEditDialog(e);
          } else if (value == 'delete') {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete expense?'),
                content: const Text('This will remove the expense permanently.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                ],
              ),
            );
            if (confirm == true) {
              await _deleteExpense(e);
            }
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'))),
          const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete), title: Text('Delete'))),
        ],
      ),
      onTap: () => _openExpenseSheet(e),
    );
  }

  Future<void> _openAddExpense() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
    );
    if (result == true) await _load();
  }

  void _toggleSearch() {
    setState(() {
      if (_searching) _searchController.clear();
      _searching = !_searching;
    });
  }

  void _changeSort(SortMode mode) {
    setState(() {
      _sortMode = mode;
      _applySort();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search transactions...',
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        )
            : const Text('Transactions'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          PopupMenuButton<SortMode>(
            icon: const Icon(Icons.more_vert),
            onSelected: (m) => _changeSort(m),
            itemBuilder: (ctx) => [
              CheckedPopupMenuItem(value: SortMode.newest, checked: _sortMode == SortMode.newest, child: const Text('Newest first')),
              CheckedPopupMenuItem(value: SortMode.oldest, checked: _sortMode == SortMode.oldest, child: const Text('Oldest first')),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(value: SortMode.highest, checked: _sortMode == SortMode.highest, child: const Text('Highest amount')),
              CheckedPopupMenuItem(value: SortMode.lowest, checked: _sortMode == SortMode.lowest, child: const Text('Lowest amount')),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(value: SortMode.categoryAZ, checked: _sortMode == SortMode.categoryAZ, child: const Text('Category A-Z')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAddExpense,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chipItem('All'),
                  const SizedBox(width: 8),
                  _chipItem('Food'),
                  const SizedBox(width: 8),
                  _chipItem('Bills'),
                  const SizedBox(width: 8),
                  _chipItem('Shopping'),
                  const SizedBox(width: 8),
                  _chipItem('Travel'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _expenses.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No expenses yet'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _openAddExpense,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Expense'),
                  ),
                ],
              ),
            )
                : ListView(
              children: _buildGroupedList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipItem(String title) {
    final selected = _selectedCategory == title;
    return ChoiceChip(
      label: Text(title),
      selected: selected,
      onSelected: (v) => setState(() {
        _selectedCategory = title;
      }),
      selectedColor: Colors.grey[700],
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.grey[300]),
      side: BorderSide(color: Colors.grey.shade700),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );
  }
}
