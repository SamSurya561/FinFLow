import '../transactions/models/expense_model.dart';
import '../../core/utils/date_utils.dart';

class AnalyticsService {
  // check if two dates fall in the same year + month
  static bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  // already existing methods (keep these if you added earlier)
  static double monthlyTotal(List expenses, DateTime month) {
    return expenses
        .where((e) => isSameMonth(e.date, month))
        .fold(0.0, (p, e) => p + e.amount);
  }

  static Map<String, double> categoryTotalsForMonth(
      List expenses, DateTime month) {
    final Map<String, double> map = {};
    for (final e in expenses) {
      if (isSameMonth(e.date, month)) {
        map[e.category] = (map[e.category] ?? 0) + e.amount;
      }
    }
    return map;
  }
  /// Returns list of 7 doubles: totals for [today -6] .. [today]
  /// and a list of labels (Mon/Tue/...).
  static Map<String, dynamic> last7DaysTotals(List expenses, [DateTime? from]) {
    final now = from ?? DateTime.now();
    final List<double> totals = List.filled(7, 0.0);
    final List<String> labels = List.filled(7, '');

    for (int i = 0; i < 7; i++) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
      labels[i] = _shortWeekday(day.weekday);
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      double sum = 0.0;
      for (final e in expenses) {
        if (!e.date.isBefore(dayStart) && e.date.isBefore(dayEnd)) {
          sum += e.amount;
        }
      }
      totals[i] = sum;
    }

    return {'totals': totals, 'labels': labels};
  }

  static String _shortWeekday(int weekday) {
    // 1 = Monday ... 7 = Sunday
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1) % 7];
  }
}

