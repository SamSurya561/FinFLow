import 'package:intl/intl.dart';
import '../../core/models/transaction_model.dart'; // Ensure this import points to your new model

class AnalyticsService {

  /// Calculates daily totals for the last 7 days.
  /// Used for the Dashboard Bar Chart.
  static Map<String, dynamic> last7DaysTotalsModel(List<TransactionModel> transactions) {
    List<double> totals = [];
    List<String> labels = [];
    final now = DateTime.now();

    // Loop backwards from 6 days ago to today
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayLabel = DateFormat('E').format(day); // e.g., "Mon", "Tue"

      double dailySum = 0;
      for (var t in transactions) {
        // Check if transaction date matches the current loop day
        if (t.date.year == day.year && t.date.month == day.month && t.date.day == day.day) {
          dailySum += t.amount;
        }
      }
      totals.add(dailySum);
      labels.add(dayLabel);
    }

    return {'totals': totals, 'labels': labels};
  }

  /// Calculates total spent per category for a specific month.
  /// Used for the Dashboard Pie Chart.
  static Map<String, double> categoryTotalsForMonthModel(List<TransactionModel> transactions, DateTime month) {
    Map<String, double> categoryMap = {};

    for (var t in transactions) {
      // Filter by Month & Year
      if (t.date.year == month.year && t.date.month == month.month) {
        if (!categoryMap.containsKey(t.category)) {
          categoryMap[t.category] = 0;
        }
        categoryMap[t.category] = categoryMap[t.category]! + t.amount;
      }
    }

    return categoryMap;
  }

  /// Calculates total EXPENSES for a specific month.
  /// Used for the "Monthly Spent" stat on the Dashboard.
  static double monthlyTotal(List<TransactionModel> transactions, DateTime month) {
    double sum = 0;
    for (var t in transactions) {
      // Logic: Only sum up if it is an EXPENSE and matches the month
      if (t.type == TxnType.expense && t.date.year == month.year && t.date.month == month.month) {
        sum += t.amount;
      }
    }
    return sum;
  }
}