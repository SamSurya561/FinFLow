// lib/core/notifiers/bottom_nav_notifier.dart
import 'package:flutter/material.dart';

/// A simple global notifier holding the current tab index and an optional payload.
/// Usage example:
/// bottomNavNotifier.value = {'index': 1, 'payload': {'category': 'Bills'}};
final ValueNotifier<Map<String, dynamic>> bottomNavNotifier =
ValueNotifier<Map<String, dynamic>>({'index': 0, 'payload': null});
