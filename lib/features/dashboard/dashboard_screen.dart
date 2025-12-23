import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../core/storage/local_storage.dart';
import '../../core/services/firestore_service.dart';
import '../analytics/analytics_service.dart';
import '../../core/models/transaction_model.dart';
import '../budgets/models/budget_model.dart';
import '../transactions/add_expense_screen.dart';
import '../transactions/incomes_screen.dart';

enum Period { week, month }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  Period _period = Period.month;
  int _touchedIndex = -1;

  double _monthlyIncome = 0.0;
  double _monthlyExpense = 0.0;
  double _totalBudgetLimit = 0.0;
  double _safeToSpend = 0.0;

  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _recentTransactions = [];
  List<Budget> _budgets = [];

  late AnimationController _entranceController;
  StreamSubscription? _txnSubscription;
  StreamSubscription? _budgetSubscription;

  final GlobalKey _heroCardKey = GlobalKey();
  final GlobalKey _addExpenseKey = GlobalKey();
  final GlobalKey _chartKey = GlobalKey();
  final GlobalKey _goalKey = GlobalKey();
  final GlobalKey _addIncomeKey = GlobalKey();
  final GlobalKey _historyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _setupRealtimeSync();
    _checkTutorial();
  }

  @override
  void dispose() {
    _txnSubscription?.cancel();
    _budgetSubscription?.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  void _setupRealtimeSync() {
    setState(() => _loading = true);
    _txnSubscription = FirestoreService().getTransactionsStream().listen((transactions) {
      if (mounted) {
        _allTransactions = transactions;
        _recalculate();
      }
    });
    _budgetSubscription = FirestoreService().getBudgetsStream().listen((budgets) {
      if (mounted) {
        _budgets = budgets;
        _recalculate();
      }
    });
  }

  void _recalculate() {
    double income = 0;
    double expense = 0;
    double budgetSum = 0;
    final now = DateTime.now();

    for (var t in _allTransactions) {
      if (t.date.month == now.month && t.date.year == now.year) {
        if (t.type == TxnType.income) income += t.amount;
        else if (t.type == TxnType.expense) expense += t.amount;
      }
    }

    for (var b in _budgets) budgetSum += b.limit;

    // FORMULA: Safe to Spend = Income - Expenses
    double safe = income - expense;

    if (mounted) {
      setState(() {
        _recentTransactions = _allTransactions.take(5).toList();
        _monthlyIncome = income;
        _monthlyExpense = expense;
        _totalBudgetLimit = budgetSum;
        _safeToSpend = safe;
        _loading = false;
      });
      _entranceController.forward(from: 0);
    }
  }

  Future<void> _openAddExpense() async {
    HapticFeedback.mediumImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
  }

  Future<void> _openAddIncome() async {
    HapticFeedback.mediumImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
  }

  Future<void> _checkTutorial() async {
    await Future.delayed(const Duration(seconds: 1));
    final seen = await LocalStorage.hasSeenDashIntro();
    if (!seen && mounted) {
      _showTutorial();
      await LocalStorage.setSeenDashIntro();
    }
  }

  void _showTutorial() {
    TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black,
      opacityShadow: 0.85,
      imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      textSkip: "SKIP",
      paddingFocus: 0,
      pulseEnable: true,
      textStyleSkip: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.0),
    ).show(context: context);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(identify: "hero_card", keyTarget: _heroCardKey, shape: ShapeLightFocus.RRect, radius: 28, contents: [_buildTutorialContent("Safe to Spend", "Income - Expenses.\nYour monthly balance.", align: CrossAxisAlignment.center)]),
      TargetFocus(identify: "add_btn", keyTarget: _addExpenseKey, shape: ShapeLightFocus.RRect, radius: 20, contents: [_buildTutorialContent("Add Expense", "Log spending here.", align: CrossAxisAlignment.start, isBottom: false)]),
      TargetFocus(identify: "add_inc", keyTarget: _addIncomeKey, shape: ShapeLightFocus.RRect, radius: 20, contents: [_buildTutorialContent("Add Income", "Log earnings here.", align: CrossAxisAlignment.center, isBottom: false)]),
    ];
  }

  TargetContent _buildTutorialContent(String title, String desc, {CrossAxisAlignment align = CrossAxisAlignment.center, bool isBottom = true}) {
    return TargetContent(align: isBottom ? ContentAlign.bottom : ContentAlign.top, builder: (context, controller) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: align, children: [Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)), const SizedBox(height: 8), Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.4))]));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

    if (_loading) return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: bgColor, expandedHeight: 110, pinned: true, elevation: 0,
            flexibleSpace: FlexibleSpaceBar(titlePadding: const EdgeInsets.only(left: 20, bottom: 16), title: Text('Dashboard', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.5))),
            actions: [
              IconButton(key: _historyKey, icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), shape: BoxShape.circle), child: Icon(Icons.history, color: isDark ? Colors.white : Colors.black87, size: 20)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IncomesScreen()))),
              const SizedBox(width: 16),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AnimatedEntrance(delay: 0, controller: _entranceController, child: Container(key: _heroCardKey, child: _HeroCard(safeToSpend: _safeToSpend, monthlySpent: _monthlyExpense, totalBudget: _totalBudgetLimit, isDark: isDark))),
                  const SizedBox(height: 24),
                  _AnimatedEntrance(delay: 100, controller: _entranceController, child: Row(children: [Expanded(child: Container(key: _addExpenseKey, child: _ActionButton(label: 'Expense', icon: Icons.arrow_downward_rounded, color: const Color(0xFFFF453A), onTap: _openAddExpense, isDark: isDark))), const SizedBox(width: 12), Expanded(child: Container(key: _addIncomeKey, child: _ActionButton(label: 'Income', icon: Icons.arrow_upward_rounded, color: const Color(0xFF30D158), onTap: _openAddIncome, isDark: isDark)))])),
                  const SizedBox(height: 32),
                  _AnimatedEntrance(delay: 200, controller: _entranceController, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('OVERVIEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.0)), _SegmentControl(selected: _period, onChanged: (p) => setState(() => _period = p), isDark: isDark)])),
                  const SizedBox(height: 16),
                  _AnimatedEntrance(delay: 300, controller: _entranceController, child: Container(key: _chartKey, child: _ChartCard(isDark: isDark, child: _period == Period.week ? _WeekBarChart(transactions: _allTransactions, touchedIndex: _touchedIndex, onTouch: (i) => setState(() => _touchedIndex = i)) : _MonthPieChart(transactions: _allTransactions)))),
                  const SizedBox(height: 32),
                  _AnimatedEntrance(delay: 400, controller: _entranceController, child: Text('RECENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.0))),
                  const SizedBox(height: 16),
                  _AnimatedEntrance(delay: 500, controller: _entranceController, child: _RecentTransactionsList(transactions: _recentTransactions, isDark: isDark)),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reuse the Components (_HeroCard, _ActionButton, etc.) from the previous successful builds.
// They are unchanged and just need to be pasted here to compile.
class _HeroCard extends StatelessWidget { final double safeToSpend; final double monthlySpent; final double totalBudget; final bool isDark; const _HeroCard({required this.safeToSpend, required this.monthlySpent, required this.totalBudget, required this.isDark}); @override Widget build(BuildContext context) { List<Color> gradientColors = [const Color(0xFF0A84FF), const Color(0xFF5E5CE6)]; if (safeToSpend < 0) gradientColors = [const Color(0xFFFF453A), const Color(0xFFBF5AF2)]; return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradientColors), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: gradientColors[0].withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('SAFE TO SPEND', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.0)), Icon(Icons.shield_moon_rounded, color: Colors.white.withOpacity(0.8), size: 20)]), const SizedBox(height: 12), Text('₹ ${safeToSpend.toStringAsFixed(0)}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white, height: 1.0)), const SizedBox(height: 24), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_StatItem(label: 'Spent', value: monthlySpent, icon: Icons.trending_down_rounded), Container(width: 1, height: 24, color: Colors.white24), _StatItem(label: 'Budgets', value: totalBudget, icon: Icons.pie_chart_outline_rounded)]))])); } }
class _StatItem extends StatelessWidget { final String label; final double value; final IconData icon; const _StatItem({required this.label, required this.value, required this.icon}); @override Widget build(BuildContext context) { return Row(children: [Icon(icon, color: Colors.white70, size: 16), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)), Text('₹ ${value.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))])]); } }
class _ActionButton extends StatelessWidget { final String label; final IconData icon; final Color color; final VoidCallback onTap; final bool isDark; const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap, required this.isDark}); @override Widget build(BuildContext context) { return GestureDetector(onTap: onTap, child: Container(height: 70, decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 24), const SizedBox(height: 6), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87))]))); } }
class _ChartCard extends StatelessWidget { final Widget child; final bool isDark; const _ChartCard({required this.child, required this.isDark}); @override Widget build(BuildContext context) { return Container(height: 250, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]), child: child); } }
class _WeekBarChart extends StatelessWidget { final List<TransactionModel> transactions; final int touchedIndex; final Function(int) onTouch; const _WeekBarChart({required this.transactions, required this.touchedIndex, required this.onTouch}); @override Widget build(BuildContext context) { final expenseOnly = transactions.where((e) => e.type == TxnType.expense).toList(); final data = AnalyticsService.last7DaysTotalsModel(expenseOnly); final List<double> totals = List<double>.from(data['totals']); final List<String> labels = List<String>.from(data['labels']); final maxVal = totals.fold(0.0, (p, e) => p > e ? p : e) * 1.2; final yMax = maxVal == 0 ? 100.0 : maxVal; return BarChart(BarChartData(alignment: BarChartAlignment.spaceAround, maxY: yMax, barTouchData: BarTouchData(touchCallback: (e, r) { if (r?.spot != null) onTouch(r!.spot!.touchedBarGroupIndex); else onTouch(-1); }, touchTooltipData: BarTouchTooltipData(getTooltipColor: (_) => Colors.black87, getTooltipItem: (group, groupIndex, rod, rodIndex) { return BarTooltipItem('₹${rod.toY.toInt()}', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)); })), titlesData: FlTitlesData(show: true, bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) { if (val.toInt() < 0 || val.toInt() >= labels.length) return const SizedBox(); return Padding(padding: const EdgeInsets.only(top: 8), child: Text(labels[val.toInt()], style: const TextStyle(fontSize: 10, color: Colors.grey))); })), leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))), borderData: FlBorderData(show: false), gridData: const FlGridData(show: false), barGroups: List.generate(7, (i) { final isTouched = i == touchedIndex; return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: totals[i], color: isTouched ? const Color(0xFF0A84FF) : Colors.grey.shade300, width: 14, borderRadius: BorderRadius.circular(6), backDrawRodData: BackgroundBarChartRodData(show: true, toY: yMax, color: Colors.grey.withOpacity(0.05)))]); }))); } }
class _MonthPieChart extends StatelessWidget { final List<TransactionModel> transactions; const _MonthPieChart({required this.transactions}); @override Widget build(BuildContext context) { final expenseOnly = transactions.where((e) => e.type == TxnType.expense).toList(); final totals = AnalyticsService.categoryTotalsForMonthModel(expenseOnly, DateTime.now()); if (totals.isEmpty) return const Center(child: Text("No expenses this month")); final categoryColors = {'Food': const Color(0xFFFF9F0A), 'Travel': const Color(0xFF0A84FF), 'Shopping': const Color(0xFFBF5AF2), 'Bills': const Color(0xFFFF453A), 'Others': const Color(0xFF32D74B)}; return Row(children: [Expanded(child: PieChart(PieChartData(sectionsSpace: 4, centerSpaceRadius: 40, sections: totals.entries.map((e) { return PieChartSectionData(value: e.value, color: categoryColors[e.key] ?? Colors.grey, radius: 20, showTitle: false); }).toList()))), const SizedBox(width: 24), Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: totals.entries.take(4).map((e) { return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: categoryColors[e.key] ?? Colors.grey, shape: BoxShape.circle)), const SizedBox(width: 8), Text('${e.key}: ₹${e.value.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))])); }).toList())]); } }
class _RecentTransactionsList extends StatelessWidget { final List<TransactionModel> transactions; final bool isDark; const _RecentTransactionsList({required this.transactions, required this.isDark}); @override Widget build(BuildContext context) { if (transactions.isEmpty) return Center(child: Text("No recent transactions", style: TextStyle(color: Colors.grey[500]))); return Column(children: transactions.map((e) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _getCategoryColor(e.category, e.type == TxnType.income).withOpacity(0.15), shape: BoxShape.circle), child: Icon(_getCategoryIcon(e.category, e.type == TxnType.income), color: _getCategoryColor(e.category, e.type == TxnType.income), size: 20)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.category, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black)), if (e.note.isNotEmpty) Text(e.note, style: TextStyle(color: Colors.grey[500], fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)])), Text('${e.type == TxnType.income ? '+' : '-'}₹${e.amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: e.type == TxnType.income ? Colors.green : (isDark ? Colors.white : Colors.black)))]))).toList()); } Color _getCategoryColor(String cat, bool isIncome) { if (isIncome) return const Color(0xFF30D158); switch (cat) { case 'Food': return const Color(0xFFFF9F0A); case 'Travel': return const Color(0xFF0A84FF); case 'Shopping': return const Color(0xFFBF5AF2); case 'Bills': return const Color(0xFFFF453A); default: return const Color(0xFF32D74B); } } IconData _getCategoryIcon(String cat, bool isIncome) { if (isIncome) return Icons.attach_money_rounded; switch (cat) { case 'Food': return Icons.fastfood_rounded; case 'Travel': return Icons.flight_takeoff_rounded; case 'Shopping': return Icons.shopping_bag_rounded; case 'Bills': return Icons.receipt_long_rounded; default: return Icons.grid_view_rounded; } } }
class _AnimatedEntrance extends StatelessWidget { final Widget child; final int delay; final AnimationController controller; const _AnimatedEntrance({required this.child, required this.delay, required this.controller}); @override Widget build(BuildContext context) { return AnimatedBuilder(animation: controller, builder: (context, child) { final start = delay / 1000.0; final end = start + 0.4; final curve = CurvedAnimation(parent: controller, curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0), curve: Curves.easeOutCubic)); return Opacity(opacity: curve.value, child: Transform.translate(offset: Offset(0, 20 * (1 - curve.value)), child: child)); }, child: child); } }
class _SegmentControl extends StatelessWidget { final Period selected; final Function(Period) onChanged; final bool isDark; const _SegmentControl({required this.selected, required this.onChanged, required this.isDark}); @override Widget build(BuildContext context) { return Container(decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade200, borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(4), child: Row(children: [_SegBtn('Week', Period.week, selected == Period.week, onChanged, isDark), _SegBtn('Month', Period.month, selected == Period.month, onChanged, isDark)])); } }
class _SegBtn extends StatelessWidget { final String label; final Period val; final bool isSelected; final Function(Period) onTap; final bool isDark; const _SegBtn(this.label, this.val, this.isSelected, this.onTap, this.isDark); @override Widget build(BuildContext context) { return GestureDetector(onTap: () { HapticFeedback.selectionClick(); onTap(val); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: isSelected ? (isDark ? Colors.grey[800] : Colors.white) : Colors.transparent, borderRadius: BorderRadius.circular(8), boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : []), child: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isDark ? Colors.white : Colors.black)))); } }