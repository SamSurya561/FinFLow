import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../core/services/firestore_service.dart';
import '../../core/models/transaction_model.dart';
import 'add_expense_screen.dart';

class TransactionsScreen extends StatefulWidget {
  final String? initialCategory;
  const TransactionsScreen({super.key, this.initialCategory});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  StreamSubscription? _subscription;
  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _filteredTransactions = [];
  bool _loading = true;
  String _searchQuery = '';

  double _totalIncome = 0;
  double _totalExpense = 0;

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  void _setupStream() {
    _subscription = FirestoreService().getTransactionsStream().listen((data) {
      if (mounted) {
        setState(() {
          _allTransactions = data;
          _filterData();
          _loading = false;
        });
      }
    });
  }

  void _filterData() {
    List<TransactionModel> temp = _allTransactions;

    if (widget.initialCategory != null) {
      temp = temp.where((e) => e.category == widget.initialCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      temp = temp.where((e) =>
      e.category.toLowerCase().contains(q) ||
          e.note.toLowerCase().contains(q)
      ).toList();
    }

    _filteredTransactions = temp;

    _totalIncome = 0;
    _totalExpense = 0;
    for (var t in _filteredTransactions) {
      if (t.type == TxnType.income) {
        _totalIncome += t.amount;
      } else if (t.type == TxnType.expense) {
        _totalExpense += t.amount;
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _deleteTransaction(TransactionModel e) async {
    HapticFeedback.heavyImpact();
    await FirestoreService().deleteTransaction(e);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

    final grouped = _groupTransactionsByDate(_filteredTransactions);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.initialCategory != null ? '${widget.initialCategory} History' : 'Transactions',
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 24),
        ),
      ),

      // --- FIX: Wrapped in Padding to lift it above the Nav Bar ---
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90), // Lifted up by 90 pixels
        child: FloatingActionButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.push(context, MaterialPageRoute(builder: (_) => AddExpenseScreen(initialCategory: widget.initialCategory)));
          },
          backgroundColor: const Color(0xFF0A84FF),
          shape: const CircleBorder(),
          elevation: 4,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      // -----------------------------------------------------------

      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() { _searchQuery = val; _filterData(); }),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: const InputDecoration(icon: Icon(Icons.search, color: Colors.grey), hintText: 'Search...', border: InputBorder.none),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _SummaryPill(label: 'Income', amount: _totalIncome, isIncome: true, isDark: isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _SummaryPill(label: 'Expense', amount: _totalExpense, isIncome: false, isDark: isDark)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : grouped.isEmpty
                ? Center(child: Text("No transactions", style: TextStyle(color: Colors.grey[500])))
                : AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 120), // Added extra padding at bottom of list so last item isn't hidden
                itemCount: grouped.keys.length,
                itemBuilder: (context, index) {
                  final dateKey = grouped.keys.elementAt(index);
                  final transactions = grouped[dateKey]!;
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: _DateSection(
                          dateStr: dateKey,
                          transactions: transactions,
                          isDark: isDark,
                          onDelete: _deleteTransaction,
                          onEdit: (e) => Navigator.push(context, MaterialPageRoute(builder: (_) => AddExpenseScreen(transaction: e))),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<TransactionModel>> _groupTransactionsByDate(List<TransactionModel> list) {
    final Map<String, List<TransactionModel>> groups = {};
    for (var t in list) {
      final key = _getDateLabel(t.date);
      if (!groups.containsKey(key)) groups[key] = [];
      groups[key]!.add(t);
    }
    return groups;
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) return 'Today';
    return DateFormat('MMM d, yyyy').format(date);
  }
}

class _SummaryPill extends StatelessWidget {
  final String label; final double amount; final bool isIncome; final bool isDark;
  const _SummaryPill({required this.label, required this.amount, required this.isIncome, required this.isDark});
  @override Widget build(BuildContext context) {
    final color = isIncome ? const Color(0xFF30D158) : const Color(0xFFFF453A);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w800, fontSize: 16)),
      ]),
    );
  }
}

class _DateSection extends StatelessWidget {
  final String dateStr; final List<TransactionModel> transactions; final bool isDark; final Function(TransactionModel) onDelete; final Function(TransactionModel) onEdit;
  const _DateSection({required this.dateStr, required this.transactions, required this.isDark, required this.onDelete, required this.onEdit});
  @override Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 8), child: Text(dateStr.toUpperCase(), style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
      ...transactions.map((t) => _TransactionTile(expense: t, isDark: isDark, onDelete: onDelete, onEdit: onEdit)),
    ]);
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionModel expense; final bool isDark; final Function(TransactionModel) onDelete; final Function(TransactionModel) onEdit;
  const _TransactionTile({required this.expense, required this.isDark, required this.onDelete, required this.onEdit});
  @override Widget build(BuildContext context) {
    final isIncome = expense.type == TxnType.income;
    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24), color: Colors.redAccent, child: const Icon(Icons.delete_outline_rounded, color: Colors.white)),
      onDismissed: (_) => onDelete(expense),
      child: InkWell(
        onTap: () { HapticFeedback.lightImpact(); onEdit(expense); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7), border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.05)))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (isIncome ? const Color(0xFF30D158) : const Color(0xFFFF9F0A)).withOpacity(0.15), shape: BoxShape.circle), child: Icon(isIncome ? Icons.attach_money : Icons.shopping_bag_outlined, color: isIncome ? const Color(0xFF30D158) : const Color(0xFFFF9F0A), size: 20)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(expense.category, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)), if (expense.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(expense.note, style: TextStyle(color: Colors.grey[500], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis))])),
            Text('${isIncome ? '+' : '-'} ₹${expense.amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isIncome ? const Color(0xFF30D158) : (isDark ? Colors.white : Colors.black))),
          ]),
        ),
      ),
    );
  }
}