import 'package:cloud_firestore/cloud_firestore.dart';

enum TxnType { income, expense, transfer }

class TransactionModel {
  final String id;
  final double amount;
  final String category; // "Food", "Salary", "Transfer"
  final String note;
  final DateTime date;
  final TxnType type;
  final String accountId; // "Wallet-ID-123" (B1)
  final String? toAccountId; // Only for transfers (B1)
  final bool isRecurring; // (A3)
  final List<String> attachments; // (A5) URLs to images

  TransactionModel({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    required this.accountId,
    this.note = '',
    this.type = TxnType.expense,
    this.toAccountId,
    this.isRecurring = false,
    this.attachments = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'note': note,
      'date': Timestamp.fromDate(date),
      'type': type.name, // stored as string "income"
      'accountId': accountId,
      'toAccountId': toAccountId,
      'isRecurring': isRecurring,
      'attachments': attachments,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      category: map['category'] ?? 'Uncategorized',
      note: map['note'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      type: TxnType.values.firstWhere(
              (e) => e.name == (map['type'] ?? 'expense'),
          orElse: () => TxnType.expense),
      accountId: map['accountId'] ?? '',
      toAccountId: map['toAccountId'],
      isRecurring: map['isRecurring'] ?? false,
      attachments: List<String>.from(map['attachments'] ?? []),
    );
  }
}