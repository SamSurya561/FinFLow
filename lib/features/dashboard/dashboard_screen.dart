// lib/features/dashboard/dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/storage/local_storage.dart';
import '../analytics/analytics_service.dart';
import '../transactions/models/expense_model.dart';
import '../transactions/add_expense_screen.dart';
import '../transactions/incomes_screen.dart';
import '../budgets/models/budget_model.dart';
import '../budgets/storage/budget_storage.dart';
import 'widgets/safe_to_spend_card.dart';

enum Period { week, month }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _dataFuture;
  Period _period = Period.month;
  int _touchedIndex = -1;
  Future<void>? _sheetFuture;
  int _lastTapMs = 0;

  final Map<String, Color> _categoryColors = {
    'Food': Colors.orange,
    'Travel': Colors.blue,
    'Shopping': Colors.purple,
    'Bills': Colors.red,
  };

  // incomes & saving goal state
  double _totalIncomes = 0.0;
  double _savingGoalAmount = 0.0;
  bool _savingGoalRollover = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _dataFuture = Future.wait([
      LocalStorage.getExpenses(),
      BudgetStorage.getBudgets(),
      LocalStorage.getIncomes(),
      LocalStorage.getSavingGoal(),
    ]).then((list) {
      final expenses = list[0] as List<Expense>;
      final budgets = list[1] as List<Budget>;
      final incomes = list[2] as List<Map<String, dynamic>>;
      final goal = list[3] as Map<String, dynamic>?;

      _totalIncomes = incomes.fold<double>(0.0, (p, inc) {
        try {
          return p + (inc['amount'] as num).toDouble();
        } catch (_) {
          return p;
        }
      });

      if (goal != null) {
        try {
          _savingGoalAmount = (goal['amount'] as num).toDouble();
          _savingGoalRollover = goal['rollover'] == true;
        } catch (_) {
          _savingGoalAmount = 0.0;
          _savingGoalRollover = false;
        }
      } else {
        _savingGoalAmount = 0.0;
        _savingGoalRollover = false;
      }

      return _DashboardData(expenses: expenses, budgets: budgets);
    });

    setState(() {});
  }

  Future<void> _openAddExpense() async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
    if (result == true) _refresh();
  }

  Future<void> _openAddIncomeSheet() async {
    if (_sheetFuture != null) return;

    // controllers/validators created once BEFORE building sheet (prevents keyboard focus bug)
    final _formKey = GlobalKey<FormState>();
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    _sheetFuture = showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) {
        bool saving = false;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(builder: (c, setC) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 12),
                  Text('Add income', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          autofocus: true,
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Amount (₹)'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter amount';
                            final n = double.tryParse(v);
                            if (n == null || n <= 0) return 'Enter valid amount';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(controller: noteController, decoration: const InputDecoration(labelText: 'Note (optional)')),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel'))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: saving
                                    ? null
                                    : () async {
                                  if (!_formKey.currentState!.validate()) return;
                                  setC(() => saving = true);
                                  final amt = double.parse(amountController.text.trim());
                                  final note = noteController.text.trim();
                                  final inc = {
                                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                    'amount': amt,
                                    'note': note,
                                    'date': DateTime.now().toIso8601String(),
                                  };
                                  await LocalStorage.saveIncome(inc);
                                  _refresh();
                                  if (mounted) {
                                    Navigator.pop(ctx, true);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Income saved')));
                                  }
                                },
                                child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  )
                ],
              ),
            );
          }),
        );
      },
    );

    await _sheetFuture;
    _sheetFuture = null;
  }

  Future<void> _openAddSavingGoalSheet() async {
    if (_sheetFuture != null) return;

    final _formKey = GlobalKey<FormState>();
    final TextEditingController amountController = TextEditingController(text: _savingGoalAmount > 0 ? _savingGoalAmount.toStringAsFixed(0) : '');
    bool rollover = _savingGoalRollover;

    _sheetFuture = showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) {
        bool saving = false;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(builder: (c, setC) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 12),
                  Text('Add / Update Saving Goal', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          autofocus: true,
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Goal amount (₹)'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter amount';
                            final n = double.tryParse(v);
                            if (n == null || n <= 0) return 'Enter valid amount';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Checkbox(
                            value: rollover,
                            onChanged: (v) => setC(() => rollover = v ?? false),
                          ),

                          const SizedBox(width: 6),
                          const Text('Rollover unused to next month'),
                        ]),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel'))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: saving
                                    ? null
                                    : () async {
                                  if (!_formKey.currentState!.validate()) return;
                                  setState(() => saving = true);
                                  final amt = double.parse(amountController.text.trim());
                                  final goal = {'amount': amt, 'rollover': rollover, 'updatedAt': DateTime.now().toIso8601String()};
                                  await LocalStorage.saveSavingGoal(goal);

                                  Future<void> _persistDashboardSummary({
                                    required double totalIncome,
                                    required double totalExpenses,
                                    required double balance,
                                    required double safeToSpend,
                                    required double savingsGoal,
                                  }) async {
                                    await LocalStorage.saveDashboardSummary(
                                      totalIncome: totalIncome,
                                      totalExpenses: totalExpenses,
                                      balance: balance,
                                      safeToSpend: safeToSpend,
                                      savingsGoal: savingsGoal,
                                    );
                                  }

                                  _refresh();
                                  if (mounted) {
                                    Navigator.pop(ctx, true);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saving goal saved')));
                                  }
                                },
                                child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Goal'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  )
                ],
              ),
            );
          }),
        );
      },
    );

    await _sheetFuture;
    _sheetFuture = null;
  }

  double _spentForCategory(List<Expense> expenses, String category) {
    final month = DateTime.now();
    return expenses.where((e) => e.category == category && AnalyticsService.isSameMonth(e.date, month)).fold(0.0, (p, e) => p + e.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FinFlow Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IncomesScreen())).then((_) => _refresh()),
            tooltip: 'Incomes',
          )
        ],
      ),
      body: FutureBuilder<_DashboardData>(
        future: _dataFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final data = snap.data ?? _DashboardData(expenses: [], budgets: []);
          final expenses = data.expenses;
          final budgets = data.budgets;

          final double monthlyTotal = AnalyticsService.monthlyTotal(expenses, DateTime.now());
          final Map<String, double> categoryTotals = AnalyticsService.categoryTotalsForMonth(expenses, DateTime.now());

          final weekMap = AnalyticsService.last7DaysTotals(expenses);
          final List<double> weekTotals = List<double>.from(weekMap['totals'] as List);
          final List<String> weekLabels = List<String>.from(weekMap['labels'] as List);

          final List<Budget> overspent = budgets.where((b) {
            final spent = _spentForCategory(expenses, b.category);
            return spent > (b.limit ?? 0.0);
          }).toList();

          final double upcomingBills = budgets.fold<double>(0.0, (p, b) => p + (b.limit ?? 0.0));
          final double baseBalance =
              _totalIncomes - monthlyTotal - upcomingBills - _savingGoalAmount;

          final double savingsGoal = _savingGoalAmount;

          return Column(
            children: [
              if (overspent.isNotEmpty)
                MaterialBanner(
                  content: Text(overspent.length == 1 ? '${overspent[0].category} budget exceeded' : 'You have ${overspent.length} budgets exceeded'),
                  actions: [TextButton(onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(), child: const Text('DISMISS'))],
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SafeToSpendCard(balance: baseBalance, upcomingBills: upcomingBills, savingsGoal: savingsGoal),
                    const SizedBox(height: 16),
                    const Text('This Month Spending', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Text('₹ ${monthlyTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      ChoiceChip(label: const Text('Week'), selected: _period == Period.week, onSelected: (s) => setState(() => _period = Period.week)),
                      const SizedBox(width: 12),
                      ChoiceChip(label: const Text('Month'), selected: _period == Period.month, onSelected: (s) => setState(() => _period = Period.month)),
                    ]),
                    const SizedBox(height: 12),
                    if (_period == Period.week)
                      SizedBox(height: 260, child: _buildWeekBarChart(expenses, weekTotals, weekLabels))
                    else
                      SizedBox(height: 200, child: Row(children: [
                        Expanded(flex: 2, child: PieChart(PieChartData(sections: _buildPieSections(categoryTotals), sectionsSpace: 2, centerSpaceRadius: 30))),
                        const SizedBox(width: 12),
                        Expanded(flex: 1, child: _buildLegend(categoryTotals)),
                      ])),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openAddExpense,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Expense'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openAddIncomeSheet,
                          icon: const Icon(Icons.trending_up),
                          label: const Text('Add Income'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openAddSavingGoalSheet,
                          icon: const Icon(Icons.flag),
                          label: const Text('Add / Update Saving Goal'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: Theme.of(context).dividerColor)),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              const Expanded(child: Center(child: Text('More charts & insights coming soon 📊'))),
            ],
          );
        },
      ),
    );
  }

  // PIE/legend/week chart helpers unchanged (same as earlier)
  List<PieChartSectionData> _buildPieSections(Map<String, double> totals) {
    final total = totals.values.fold(0.0, (p, e) => p + e);
    final entries = totals.entries.toList();
    final List<PieChartSectionData> sections = [];

    for (int i = 0; i < entries.length; i++) {
      final k = entries[i].key;
      final v = entries[i].value;
      final percent = total == 0 ? 0.0 : (v / total);
      final color = _categoryColors[k] ?? Colors.primaries[i % Colors.primaries.length];

      sections.add(PieChartSectionData(color: color, value: v, title: '${(percent * 100).toStringAsFixed(0)}%', radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)));
    }

    return sections;
  }

  Widget _buildLegend(Map<String, double> totals) {
    final entries = totals.entries.toList();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.map((e) {
          final color = _categoryColors[e.key] ?? Colors.primaries[entries.indexOf(e) % Colors.primaries.length];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 8), Expanded(child: Text(e.key)), Text('₹ ${e.value.toStringAsFixed(0)}')]),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeekBarChart(List<Expense> allExpenses, List<double> totals, List<String> labels) {
    final maxVal = totals.fold(0.0, (p, e) => p > e ? p : e);
    final double yMax = (maxVal <= 0) ? 10 : (maxVal * 1.2);

    final groups = List.generate(7, (i) {
      final isTouched = i == _touchedIndex;
      final value = totals[i];
      return BarChartGroupData(x: i, barsSpace: 4, barRods: [BarChartRodData(toY: value, width: isTouched ? 18 : 14, borderRadius: BorderRadius.circular(6), color: isTouched ? Colors.amber : Colors.deepPurpleAccent)]);
    });

    return Card(
      elevation: 0,
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: BarChart(BarChartData(
          maxY: yMax,
          minY: 0,
          groupsSpace: 12,
          barGroups: groups,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(getTooltipColor: (_) => Colors.black87, getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem('₹ ${rod.toY.toStringAsFixed(0)}', const TextStyle(color: Colors.white));
            }),
            touchCallback: (event, response) {
              if (response == null || response.spot == null) {
                setState(() => _touchedIndex = -1);
                return;
              }
              final now = DateTime.now().millisecondsSinceEpoch;
              if (now - _lastTapMs < 300) return;
              _lastTapMs = now;
              final idx = response.spot!.touchedBarGroupIndex;
              setState(() => _touchedIndex = idx);
              if (_sheetFuture != null) return;
              final day = _dateForBarIndex(idx);
              _sheetFuture = _showDayDetailsSheet(day, allExpenses);
              _sheetFuture!.whenComplete(() {
                _sheetFuture = null;
                if (mounted) setState(() => _touchedIndex = -1);
              });
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: yMax / 4, getTitlesWidget: (val, meta) {
              if (val == 0) return const SizedBox.shrink();
              return Text('₹ ${val.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Colors.grey));
            })),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) {
              final idx = val.toInt();
              if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
              return Text(labels[idx], style: const TextStyle(fontSize: 12));
            }, reservedSize: 24)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: yMax / 4),
          borderData: FlBorderData(show: false),
        )),
      ),
    );
  }

  DateTime _dateForBarIndex(int index) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - index));
    return day;
  }

  Future<void> _showDayDetailsSheet(DateTime day, List<Expense> allExpenses) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final dayExpenses = allExpenses.where((e) => !e.date.isBefore(start) && e.date.isBefore(end)).toList();
    final total = dayExpenses.fold(0.0, (p, e) => p + e.amount);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${_prettyDate(day)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text('Total: ₹ ${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, color: Colors.grey))]),
                      const Spacer(),
                      Text('${day.weekday == DateTime.now().weekday && day.day == DateTime.now().day ? "Today" : ""}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: dayExpenses.isEmpty ? Center(child: Text('No transactions on ${_prettyDate(day)}', style: const TextStyle(color: Colors.grey))) : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: dayExpenses.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final e = dayExpenses[i];
                      final time = '${e.date.hour.toString().padLeft(2, '0')}:${e.date.minute.toString().padLeft(2, '0')}';
                      final color = _categoryColors[e.category] ?? Colors.grey;
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: color, child: Text('₹', style: const TextStyle(color: Colors.white))),
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
                  child: Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))), const SizedBox(width: 12), Expanded(child: ElevatedButton(onPressed: () { Navigator.pop(ctx); }, child: const Text('Add Expense')))]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _prettyDate(DateTime d) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _DashboardData {
  final List<Expense> expenses;
  final List<Budget> budgets;
  _DashboardData({required this.expenses, required this.budgets});
}
