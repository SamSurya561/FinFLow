// lib/features/transactions/models/expense_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final double amount;
  final String category;
  final String note;
  final DateTime date;
  final bool isIncome;

  Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.note = '',
    this.isIncome = false,
  });

  // Convert TO Firestore/JSON (Map)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'note': note,
      'date': Timestamp.fromDate(date), // Firestore uses Timestamp
      'isIncome': isIncome,
    };
  }

  // Create FROM Firestore (Map)
  factory Expense.fromMap(Map<String, dynamic> map, String docId) {
    return Expense(
      id: docId,
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? '',
      note: map['note'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      isIncome: map['isIncome'] ?? false,
    );
  }

  // --- JSON Support for LocalStorage ---
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'note': note,
      'date': date.toIso8601String(), // JSON uses String for dates
      'isIncome': isIncome,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      note: json['note'] ?? '',
      date: DateTime.parse(json['date']),
      isIncome: json['isIncome'] ?? false,
    );
  }
}