import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart'; // For the radial gauge
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/profile_storage.dart'; // To sync stats
import '../transactions/models/expense_model.dart';
import '../transactions/transactions_screen.dart'; // For navigation
import 'models/budget_model.dart';
import 'storage/budget_storage.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> with SingleTickerProviderStateMixin {
  List<Budget> _budgets = [];
  List<Expense> _expenses = [];
  bool _loading = true;

  // Animation
  late AnimationController _animController;

  // --- Tutorial Keys ---
  final GlobalKey _summaryKey = GlobalKey();
  final GlobalKey _addKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _loadData();
    _checkTutorial(); // <--- Check Tutorial
  }

  Future<void> _checkTutorial() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    final seen = await LocalStorage.hasSeenBudgetIntro();
    if (!seen && mounted) {
      _showTutorial();
      await LocalStorage.setSeenBudgetIntro();
    }
  }

  void _showTutorial() {
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: "summary_ring",
          keyTarget: _summaryKey,
          shape: ShapeLightFocus.RRect,
          radius: 20,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Budget Overview", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                    Padding(
                      padding: EdgeInsets.only(top: 10.0),
                      child: Text("This ring shows your TOTAL spending vs limits across all categories.", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        TargetFocus(
          identify: "add_budget",
          keyTarget: _addKey,
          alignSkip: Alignment.bottomLeft,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Create Budget", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                    Padding(
                      padding: EdgeInsets.only(top: 10.0),
                      child: Text("Tap here to set a monthly limit for Food, Travel, or Shopping.", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
      colorShadow: Colors.black,
      opacityShadow: 0.85,
      textSkip: "GOT IT",
      onFinish: () {},
    ).show(context: context);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final b = await BudgetStorage.getBudgets();
    final e = await LocalStorage.getExpenses();

    if (mounted) {
      setState(() {
        _budgets = b;
        _expenses = e;
        _loading = false;
      });
      _animController.forward(from: 0);
    }
  }

  double _calculateSpent(String category) {
    final now = DateTime.now();
    return _expenses
        .where((e) =>
    e.category == category &&
        e.date.year == now.year &&
        e.date.month == now.month)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  // --- Actions ---

  Future<void> _showAddEditSheet({Budget? budget}) async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BudgetEditSheet(
        budget: budget,
        onSave: (newBudget) async {
          if (budget == null) {
            // Add (check duplicates manually or just append)
            // Ideally we check if category exists, but for MVP we append
            // Better: update if exists
            final existingIdx = _budgets.indexWhere((b) => b.category == newBudget.category);
            if (existingIdx != -1) {
              _budgets[existingIdx] = newBudget; // Update existing logic
            } else {
              _budgets.add(newBudget);
            }
          } else {
            // Edit
            final idx = _budgets.indexWhere((b) => b.id == budget.id);
            if (idx != -1) _budgets[idx] = newBudget;
          }

          await BudgetStorage.saveBudgets(_budgets);
          _loadData(); // Refresh UI
        },
      ),
    );
  }

  Future<void> _deleteBudget(Budget b) async {
    HapticFeedback.heavyImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget?'),
        content: Text('Remove the budget for ${b.category}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await BudgetStorage.deleteBudgetById(b.id);
      _loadData();
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

    // Totals for the Header
    double totalLimit = 0;
    double totalSpent = 0;
    for (var b in _budgets) {
      totalLimit += b.limit;
      totalSpent += _calculateSpent(b.category);
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Large Header
          SliverAppBar(
            backgroundColor: bgColor,
            expandedHeight: 120,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Monthly Budgets',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                ),
              ),
            ),
            actions: [
              IconButton(
                key: _addKey, // <--- Key Attached
                icon: Icon(Icons.add_circle_outline_rounded, color: Theme.of(context).primaryColor, size: 28),
                onPressed: () => _showAddEditSheet(),
              ),
              const SizedBox(width: 16),
            ],
          ),

          // 2. Summary Circular Indicator
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                key: _summaryKey, // <--- Key Attached
                children: [
                  _BudgetSummaryRing(
                    totalLimit: totalLimit,
                    totalSpent: totalSpent,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // 3. Budget List
          if (_budgets.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 64, color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text('No budgets set', style: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 16)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _showAddEditSheet(),
                      child: const Text('Create your first budget'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final b = _budgets[index];
                  final spent = _calculateSpent(b.category);
                  // Staggered Animation
                  final animation = CurvedAnimation(
                    parent: _animController,
                    curve: Interval(
                      (index * 0.1).clamp(0.0, 1.0),
                      1.0,
                      curve: Curves.easeOutCubic,
                    ),
                  );

                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
                      child: _BudgetCard(
                        budget: b,
                        spent: spent,
                        isDark: isDark,
                        onTap: () => _showAddEditSheet(budget: b),
                        onLongPress: () => _deleteBudget(b),
                      ),
                    ),
                  );
                },
                childCount: _budgets.length,
              ),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }
}

// --- Components ---

class _BudgetSummaryRing extends StatelessWidget {
  final double totalLimit;
  final double totalSpent;
  final bool isDark;

  const _BudgetSummaryRing({required this.totalLimit, required this.totalSpent, required this.isDark});

  @override
  Widget build(BuildContext context) {
    double percent = totalLimit == 0 ? 0 : (totalSpent / totalLimit);
    if (percent > 1) percent = 1;

    // Color logic
    Color ringColor = const Color(0xFF30D158); // Green
    if (percent > 0.7) ringColor = const Color(0xFFFF9F0A); // Orange
    if (percent >= 1.0) ringColor = const Color(0xFFFF453A); // Red

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          // The Chart
          SizedBox(
            height: 80,
            width: 80,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: 270,
                    sectionsSpace: 0,
                    centerSpaceRadius: 30,
                    sections: [
                      PieChartSectionData(
                        color: ringColor,
                        value: totalSpent,
                        radius: 8,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        value: (totalLimit - totalSpent) < 0 ? 0 : (totalLimit - totalSpent),
                        radius: 8,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
                Center(
                  child: Text(
                    '${(percent * 100).toInt()}%',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // The Text Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOTAL SPENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text('₹${totalSpent.toStringAsFixed(0)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 4),
                Text(
                  'of ₹${totalLimit.toStringAsFixed(0)} limit',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final double spent;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BudgetCard({required this.budget, required this.spent, required this.isDark, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final double pct = budget.limit == 0 ? 0 : (spent / budget.limit);
    final double clampedPct = pct.clamp(0.0, 1.0);

    // Dynamic Status Color
    Color statusColor = const Color(0xFF30D158);
    if (pct > 0.75) statusColor = const Color(0xFFFF9F0A);
    if (pct >= 1.0) statusColor = const Color(0xFFFF453A);

    final remaining = budget.limit - spent;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(budget.category).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(budget.category),
                    color: _getCategoryColor(budget.category),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(budget.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        remaining < 0 ? 'Over by ₹${remaining.abs().toStringAsFixed(0)}' : '₹${remaining.toStringAsFixed(0)} left',
                        style: TextStyle(
                          color: remaining < 0 ? Colors.red : Colors.grey[500],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress Bar
            Stack(
              children: [
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutExpo,
                  widthFactor: clampedPct,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'food': return const Color(0xFFFF9F0A);
      case 'travel': return const Color(0xFF0A84FF);
      case 'shopping': return const Color(0xFFBF5AF2);
      case 'bills': return const Color(0xFFFF453A);
      default: return const Color(0xFF32D74B);
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'food': return Icons.fastfood_rounded;
      case 'travel': return Icons.flight_takeoff_rounded;
      case 'shopping': return Icons.shopping_bag_rounded;
      case 'bills': return Icons.receipt_long_rounded;
      default: return Icons.category_rounded;
    }
  }
}

class _BudgetEditSheet extends StatefulWidget {
  final Budget? budget;
  final Function(Budget) onSave;

  const _BudgetEditSheet({this.budget, required this.onSave});

  @override
  State<_BudgetEditSheet> createState() => _BudgetEditSheetState();
}

class _BudgetEditSheetState extends State<_BudgetEditSheet> {
  late TextEditingController _limitCtrl;
  String _category = 'Food';
  bool _rollover = false;

  final List<String> _categories = ['Food', 'Travel', 'Shopping', 'Bills', 'Others'];

  @override
  void initState() {
    super.initState();
    _limitCtrl = TextEditingController(text: widget.budget?.limit.toStringAsFixed(0) ?? '');
    if (widget.budget != null) {
      _category = widget.budget!.category;
      _rollover = widget.budget!.rollover;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1C1C1E) : Colors.white).withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.budget == null ? 'New Budget' : 'Edit Budget', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 24),
              // Category Selector
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final cat = _categories[i];
                    final isSel = _category == cat;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _category = cat);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSel ? Theme.of(context).primaryColor : (isDark ? Colors.grey[800] : Colors.grey[200]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(cat, style: TextStyle(color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black), fontWeight: FontWeight.w600)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              // Amount Input
              TextField(
                controller: _limitCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  labelText: 'Monthly Limit',
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              // Rollover Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_edu_rounded, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rollover Budget', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                          const Text('Unused amount adds to next month', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _rollover,
                      onChanged: (v) => setState(() => _rollover = v),
                      activeColor: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    final limit = double.tryParse(_limitCtrl.text);
                    if (limit != null && limit > 0) {
                      widget.onSave(Budget(
                        id: widget.budget?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        category: _category,
                        limit: limit,
                        rollover: _rollover,
                      ));
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Save Budget', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}