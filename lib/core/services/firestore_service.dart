import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Models
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../../features/budgets/models/budget_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");
    return user.uid;
  }

  // --- Refs ---
  DocumentReference<Map<String, dynamic>> get _userDoc => _db.collection('users').doc(_uid);
  CollectionReference<Map<String, dynamic>> get _txnCol => _userDoc.collection('transactions');
  CollectionReference<Map<String, dynamic>> get _accCol => _userDoc.collection('accounts');
  CollectionReference<Map<String, dynamic>> get _budCol => _userDoc.collection('budgets');
  CollectionReference<Map<String, dynamic>> get _statsCol => _userDoc.collection('monthly_stats');

  // ==============================================================================
  // 1. TRANSACTIONS (Add, Update, Delete)
  // ==============================================================================

  Stream<List<TransactionModel>> getTransactionsStream() {
    return _txnCol.orderBy('date', descending: true).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => TransactionModel.fromMap(doc.data())).toList());
  }

  /// Add New Transaction
  Future<void> addTransaction(TransactionModel txn) async {
    final batch = _db.batch();
    final String monthKey = DateFormat('yyyy_MM').format(txn.date);

    // 1. Save Transaction
    batch.set(_txnCol.doc(txn.id), txn.toMap());

    // 2. Update Wallet Balance
    final accRef = _accCol.doc(txn.accountId);
    if (txn.type == TxnType.income) {
      batch.update(accRef, {'balance': FieldValue.increment(txn.amount)});
    } else if (txn.type == TxnType.expense) {
      batch.update(accRef, {'balance': FieldValue.increment(-txn.amount)});
    }

    // 3. Update Stats
    final statsRef = _statsCol.doc(monthKey);
    batch.set(statsRef, {'month': monthKey}, SetOptions(merge: true));
    if (txn.type == TxnType.income) {
      batch.update(statsRef, {'totalIncome': FieldValue.increment(txn.amount)});
    } else if (txn.type == TxnType.expense) {
      batch.update(statsRef, {'totalExpense': FieldValue.increment(txn.amount)});
    }

    await batch.commit();
  }

  /// Update Existing Transaction (Reverses Old -> Applies New)
  Future<void> updateTransaction(TransactionModel newTxn) async {
    final docSnap = await _txnCol.doc(newTxn.id).get();
    if (!docSnap.exists) return;

    final oldTxn = TransactionModel.fromMap(docSnap.data()!);
    final batch = _db.batch();

    // 1. REVERSE Old Transaction Effect
    final oldAccRef = _accCol.doc(oldTxn.accountId);
    if (oldTxn.type == TxnType.income) {
      batch.update(oldAccRef, {'balance': FieldValue.increment(-oldTxn.amount)});
    } else if (oldTxn.type == TxnType.expense) {
      batch.update(oldAccRef, {'balance': FieldValue.increment(oldTxn.amount)});
    }

    // 2. APPLY New Transaction Effect
    final newAccRef = _accCol.doc(newTxn.accountId);
    if (newTxn.type == TxnType.income) {
      batch.update(newAccRef, {'balance': FieldValue.increment(newTxn.amount)});
    } else if (newTxn.type == TxnType.expense) {
      batch.update(newAccRef, {'balance': FieldValue.increment(-newTxn.amount)});
    }

    // 3. Update Doc
    batch.update(_txnCol.doc(newTxn.id), newTxn.toMap());

    await batch.commit();
  }

  /// Delete Transaction
  Future<void> deleteTransaction(TransactionModel txn) async {
    final batch = _db.batch();

    // 1. Delete Doc
    batch.delete(_txnCol.doc(txn.id));

    // 2. Reverse Balance
    final accRef = _accCol.doc(txn.accountId);
    if (txn.type == TxnType.income) {
      batch.update(accRef, {'balance': FieldValue.increment(-txn.amount)});
    } else if (txn.type == TxnType.expense) {
      batch.update(accRef, {'balance': FieldValue.increment(txn.amount)});
    }

    await batch.commit();
  }

  // ==============================================================================
  // 2. USER PROFILE & ACCOUNTS
  // ==============================================================================

  Future<void> saveUserProfile(Map<String, dynamic> data) async {
    await _userDoc.set(data, SetOptions(merge: true));
  }

  Stream<List<AccountModel>> getAccountsStream() {
    return _accCol.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => AccountModel.fromMap(doc.data())).toList());
  }

  Future<void> createAccount(AccountModel account) async {
    await _accCol.doc(account.id).set(account.toMap());
  }

  // ==============================================================================
  // 3. BUDGETS
  // ==============================================================================

  Stream<List<Budget>> getBudgetsStream() {
    return _budCol.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Budget.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> setBudget(Budget budget) async {
    await _budCol.doc(budget.category).set(budget.toMap());
  }

  Future<void> deleteBudget(String id) async {
    await _budCol.doc(id).delete();
  }
}