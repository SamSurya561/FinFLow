// lib/features/budgets/models/budget_model.dart
class Budget {
  final String id;
  final String category;
  final double limit;
  final bool rollover; // <--- Added this missing field

  Budget({
    required this.id,
    required this.category,
    required this.limit,
    this.rollover = false, // Default to false
  });

  // Firestore Support
  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'limit': limit,
      'rollover': rollover,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map, String docId) {
    return Budget(
      id: docId,
      category: map['category'] ?? '',
      limit: (map['limit'] ?? 0).toDouble(),
      rollover: map['rollover'] ?? false,
    );
  }

  // JSON / LocalStorage Support
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'limit': limit,
      'rollover': rollover,
    };
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] ?? '',
      category: json['category'] ?? '',
      limit: (json['limit'] ?? 0).toDouble(),
      rollover: json['rollover'] ?? false,
    );
  }
}