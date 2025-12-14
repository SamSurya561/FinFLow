class Expense {
  final String id;
  final double amount;
  final String category;
  final String note;
  final DateTime date;

  Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
  });

  Expense copyWith({
    String? id,
    double? amount,
    String? category,
    String? note,
    DateTime? date,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
      amount: json['amount'],
      category: json['category'],
      note: json['note'],
      date: DateTime.parse(json['date']),
    );
  }
}
