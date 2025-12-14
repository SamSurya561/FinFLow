// lib/features/budgets/models/budget_model.dart
class Budget {
  final String id;
  final String category;
  final double limit;
  final bool rollover;

  Budget({
    required this.id,
    required this.category,
    required this.limit,
    this.rollover = false,
  });

  factory Budget.fromJson(Map<String, dynamic> j) {
    return Budget(
      id: (j['id'] ?? '').toString(),
      category: (j['category'] ?? '').toString(),
      // defensive: parse numeric types to double
      limit: (j['limit'] is num) ? (j['limit'] as num).toDouble() : double.tryParse((j['limit'] ?? '0').toString()) ?? 0.0,
      rollover: (j['rollover'] is bool) ? j['rollover'] as bool : (j['rollover']?.toString().toLowerCase() == 'true'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'limit': limit,
      'rollover': rollover,
    };
  }

  Budget copyWith({String? id, String? category, double? limit, bool? rollover}) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      limit: limit ?? this.limit,
      rollover: rollover ?? this.rollover,
    );
  }
}
