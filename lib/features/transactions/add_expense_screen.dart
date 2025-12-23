import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/transaction_model.dart';
import '../../core/models/account_model.dart';
import '../../core/services/firestore_service.dart';

class AddExpenseScreen extends StatefulWidget {
  final TransactionModel? transaction;
  final String? initialCategory; // <--- ADD THIS PARAMETER

  const AddExpenseScreen({super.key, this.transaction, this.initialCategory});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now();
  TxnType _type = TxnType.expense;

  String _selectedAccountId = '';
  List<AccountModel> _accounts = [];
  bool _isLoading = false;

  final List<String> _expenseCategories = ['Food', 'Travel', 'Shopping', 'Bills', 'Entertainment', 'Health', 'Others'];
  final List<String> _incomeCategories = ['Salary', 'Freelance', 'Investment', 'Gift', 'Rental', 'Others'];

  @override
  void initState() {
    super.initState();

    // 1. Handle Initial Category (if passed)
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }

    // 2. Handle Edit Mode (Overrides initial category if editing)
    if (widget.transaction != null) {
      _initEditMode();
    }

    _loadAccounts();
  }

  void _initEditMode() {
    _amountCtrl.text = widget.transaction!.amount.toStringAsFixed(0);
    _noteCtrl.text = widget.transaction!.note;
    _selectedCategory = widget.transaction!.category;
    _selectedDate = widget.transaction!.date;
    _type = widget.transaction!.type;
    _selectedAccountId = widget.transaction!.accountId;
  }

  void _loadAccounts() {
    FirestoreService().getAccountsStream().listen((accs) async {
      if (accs.isEmpty) {
        final defaultAcc = AccountModel(id: const Uuid().v4(), name: 'Cash', type: 'Cash', balance: 0);
        await FirestoreService().createAccount(defaultAcc);
      } else {
        if (mounted) {
          setState(() {
            _accounts = accs;
            if (_selectedAccountId.isEmpty && widget.transaction == null) {
              _selectedAccountId = accs.first.id;
            }
          });
        }
      }
    });
  }

  Future<void> _save() async {
    if (_amountCtrl.text.isEmpty) return;
    if (_selectedAccountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a wallet")));
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final txn = TransactionModel(
      id: widget.transaction?.id ?? const Uuid().v4(),
      amount: double.parse(_amountCtrl.text),
      category: _selectedCategory,
      date: _selectedDate,
      note: _noteCtrl.text,
      type: _type,
      accountId: _selectedAccountId,
    );

    try {
      if (widget.transaction == null) {
        await FirestoreService().addTransaction(txn);
      } else {
        await FirestoreService().updateTransaction(txn);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final primaryColor = _type == TxnType.income ? const Color(0xFF30D158) : const Color(0xFFFF453A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black), onPressed: () => Navigator.pop(context)),
        title: Text(widget.transaction == null ? 'Add Transaction' : 'Edit Transaction', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(onPressed: _save, child: Text("Save", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)))
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [_buildTypeBtn("Expense", TxnType.expense, isDark), _buildTypeBtn("Income", TxnType.income, isDark)]),
          ),
          const SizedBox(height: 24),
          Text("AMOUNT", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
            child: TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(prefixText: '₹ ', prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: primaryColor), border: InputBorder.none, hintText: '0'),
            ),
          ),
          const SizedBox(height: 24),
          Text("CATEGORY", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: (_type == TxnType.income ? _incomeCategories : _expenseCategories).map((cat) {
            final isSelected = _selectedCategory == cat;
            return ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              selectedColor: primaryColor.withOpacity(0.2),
              labelStyle: TextStyle(color: isSelected ? primaryColor : (isDark ? Colors.white : Colors.black), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              backgroundColor: cardColor,
              onSelected: (_) => setState(() => _selectedCategory = cat),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? primaryColor : Colors.transparent)),
            );
          }).toList()),
          const SizedBox(height: 24),
          Text("DETAILS", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              ListTile(
                leading: Icon(Icons.account_balance_wallet, color: primaryColor),
                title: const Text("Wallet"),
                trailing: DropdownButtonHideUnderline(child: DropdownButton<String>(
                  value: _selectedAccountId.isNotEmpty ? _selectedAccountId : null,
                  dropdownColor: cardColor,
                  items: _accounts.map((acc) => DropdownMenuItem(value: acc.id, child: Text(acc.name, style: TextStyle(color: isDark ? Colors.white : Colors.black)))).toList(),
                  onChanged: (val) => setState(() => _selectedAccountId = val!),
                )),
              ),
              Divider(color: Colors.grey.withOpacity(0.1), height: 1),
              ListTile(
                leading: Icon(Icons.calendar_today, color: primaryColor),
                title: const Text("Date"),
                trailing: Text(DateFormat('MMM d').format(_selectedDate), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now(), builder: (context, child) => Theme(data: isDark ? ThemeData.dark() : ThemeData.light(), child: child!));
                  if (picked != null) setState(() => _selectedDate = picked);
                },
              ),
              Divider(color: Colors.grey.withOpacity(0.1), height: 1),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(controller: _noteCtrl, decoration: const InputDecoration(icon: Icon(Icons.notes, color: Colors.grey), hintText: "Add a note", border: InputBorder.none))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBtn(String label, TxnType type, bool isDark) {
    final isSelected = _type == type;
    final color = type == TxnType.income ? const Color(0xFF30D158) : const Color(0xFFFF453A);
    return Expanded(child: GestureDetector(onTap: () => setState(() => _type = type), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isSelected ? color : Colors.transparent, borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)))));
  }
}