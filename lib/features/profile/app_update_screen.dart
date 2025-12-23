// lib/features/profile/app_update_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppUpdateScreen extends StatefulWidget {
  const AppUpdateScreen({super.key});

  @override
  State<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends State<AppUpdateScreen> {
  bool _checking = true;
  bool _updateAvailable = false; // Simulate response

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate network call
    // In real app: Fetch from FirestoreService().getLatestVersion()
    if (mounted) {
      setState(() {
        _checking = false;
        _updateAvailable = false; // Toggle this to true to see the "Update" UI
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Software Update"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: _checking
            ? const CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _updateAvailable ? Icons.system_update_rounded : Icons.check_circle_outline_rounded,
              size: 80,
              color: _updateAvailable ? Colors.blue : Colors.green,
            ),
            const SizedBox(height: 24),
            Text(
              _updateAvailable ? "New Version Available" : "FinFlow is up to date",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 8),
            Text(
              _updateAvailable ? "Version 1.1.0 is ready to install." : "Current Version: 1.0.0",
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
            if (_updateAvailable) ...[
              const SizedBox(height: 40),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("WHAT'S NEW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    _buildLogItem("- Added Dark Mode support"),
                    _buildLogItem("- Fixed transaction sync issues"),
                    _buildLogItem("- Improved charts performance"),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text("Update Now"),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 15)),
    );
  }
}