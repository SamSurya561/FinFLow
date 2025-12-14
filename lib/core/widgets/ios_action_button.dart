// lib/core/widgets/ios_action_button.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../theme/app_theme.dart';


class IOSActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color? background;

  const IOSActionButton({required this.onPressed, required this.child, this.background, super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
            backgroundColor: background ?? Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
        ),
        child: child
    );
  }
}
