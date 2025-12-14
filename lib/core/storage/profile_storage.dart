// lib/core/storage/profile_storage.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Profile {
  final String name;
  final String email;
  /// base64-encoded image bytes (png/jpeg) or empty string
  final String imageBase64;

  /// Lightweight budget summary for profile screen
  final int budgetsCount;
  final double spentThisMonth;
  final double safeToSpendEstimate;

  Profile({
    required this.name,
    required this.email,
    this.imageBase64 = '',
    this.budgetsCount = 0,
    this.spentThisMonth = 0.0,
    this.safeToSpendEstimate = 0.0,
  });

  Profile copyWith({
    String? name,
    String? email,
    String? imageBase64,
    int? budgetsCount,
    double? spentThisMonth,
    double? safeToSpendEstimate,
  }) {
    return Profile(
      name: name ?? this.name,
      email: email ?? this.email,
      imageBase64: imageBase64 ?? this.imageBase64,
      budgetsCount: budgetsCount ?? this.budgetsCount,
      spentThisMonth: spentThisMonth ?? this.spentThisMonth,
      safeToSpendEstimate: safeToSpendEstimate ?? this.safeToSpendEstimate,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'imageBase64': imageBase64,
    'budgetsCount': budgetsCount,
    'spentThisMonth': spentThisMonth,
    'safeToSpendEstimate': safeToSpendEstimate,
  };

  factory Profile.fromJson(Map<String, dynamic> j) {
    return Profile(
      name: (j['name'] ?? '') as String,
      email: (j['email'] ?? '') as String,
      imageBase64: (j['imageBase64'] ?? '') as String,
      budgetsCount: (j['budgetsCount'] ?? 0) is int ? (j['budgetsCount'] as int) : int.tryParse('${j['budgetsCount']}') ?? 0,
      spentThisMonth: (j['spentThisMonth'] ?? 0.0) is double ? (j['spentThisMonth'] as double) : double.tryParse('${j['spentThisMonth']}') ?? 0.0,
      safeToSpendEstimate: (j['safeToSpendEstimate'] ?? 0.0) is double ? (j['safeToSpendEstimate'] as double) : double.tryParse('${j['safeToSpendEstimate']}') ?? 0.0,
    );
  }

  static const _key = 'finflow_profile_v2';

  /// Returns null if no profile saved.
  static Future<Profile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null) return null;
    try {
      final Map<String, dynamic> j = jsonDecode(s) as Map<String, dynamic>;
      return Profile.fromJson(j);
    } catch (e) {
      if (kDebugMode) print('Profile decode error: $e');
      return null;
    }
  }

  /// If no profile stored, returns a sensible default profile.
  static Future<Profile> getProfileOrDefault() async {
    final p = await getProfile();
    if (p != null) return p;
    return Profile(
      name: 'Your name',
      email: 'you@example.com',
      imageBase64: '',
      budgetsCount: 0,
      spentThisMonth: 0.0,
      safeToSpendEstimate: 0.0,
    );
  }

  static Future<bool> saveProfile(Profile p) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(p.toJson());
    return prefs.setString(_key, encoded);
  }

  static Future<bool> resetProfile() async {
    // kept for debugging / dev use, not exposed in UI
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(_key);
  }

  /// Convenience: update only budget summary and persist
  /// Call this from your budgets/transactions code whenever budgets or expenses change.
  static Future<bool> updateBudgetSummary({
    required int budgetsCount,
    required double spentThisMonth,
    required double safeToSpendEstimate,
  }) async {
    final current = await getProfileOrDefault();
    final updated = current.copyWith(
      budgetsCount: budgetsCount,
      spentThisMonth: spentThisMonth,
      safeToSpendEstimate: safeToSpendEstimate,
    );
    return saveProfile(updated);
  }
}
