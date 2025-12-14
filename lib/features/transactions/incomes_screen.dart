// lib/features/transactions/incomes_screen.dart
import 'package:flutter/material.dart';
import '../../core/storage/local_storage.dart';

class IncomesScreen extends StatefulWidget {
  const IncomesScreen({Key? key}) : super(key: key);

  @override
  State<IncomesScreen> createState() => _IncomesScreenState();
}

class _IncomesScreenState extends State<IncomesScreen> {
  List<Map<String, dynamic>> _incomes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await LocalStorage.getIncomes();
    // Reverse so newest appear at top for the UI
    setState(() {
      _incomes = List<Map<String, dynamic>>.from(list.reversed);
      _loading = false;
    });
  }

  Future<void> _deleteAt(int idx) async {
    // Stored order is chronological; convert UI index back to stored index
    final storedIndex = (_incomes.length - 1) - idx;
    final ok = await LocalStorage.deleteIncomeAt(storedIndex);
    if (!ok) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete income')));
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Income deleted')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incomes'),
      ),
      body: _incomes.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No incomes yet'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Income'),
            )
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _incomes.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (ctx, i) {
          final inc = _incomes[i];
          final amt = (inc['amount'] ?? 0).toString();
          final note = (inc['note'] ?? '').toString();
          final date = inc['date']?.toString() ?? '';
          return ListTile(
            leading: CircleAvatar(child: const Icon(Icons.trending_up)),
            title: Text('₹ $amt'),
            subtitle: note.isNotEmpty ? Text('$note\n$date') : Text(date),
            isThreeLine: note.isNotEmpty,
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Delete income?'),
                    content: const Text('This will remove the income record.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirm == true) await _deleteAt(i);
              },
            ),
          );
        },
      ),
    );
  }
}
