import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../storage/local_storage.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<bool>? _guestCheck;

  @override
  void initState() {
    super.initState();
    _guestCheck = LocalStorage.isGuest();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Check Guest Mode first (Local preference)
    return FutureBuilder<bool>(
      future: _guestCheck,
      builder: (context, guestSnapshot) {
        if (guestSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final isGuest = guestSnapshot.data ?? false;
        if (isGuest) {
          return const HomeScreen();
        }

        // 2. If not guest, check Firebase Auth
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (authSnapshot.hasData) {
              return const HomeScreen();
            }

            // 3. Neither guest nor logged in -> Login Screen
            return const LoginScreen();
          },
        );
      },
    );
  }
}