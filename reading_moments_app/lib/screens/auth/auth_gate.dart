import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';
import 'login_screen.dart';
import 'profile_bootstrap_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;

    if (session == null) {
      return const LoginScreen();
    }

    return const ProfileBootstrapScreen();
  }
}