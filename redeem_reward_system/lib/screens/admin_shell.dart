import 'package:flutter/material.dart';

import '../app_state.dart';
import 'admin_dashboard_screen.dart';

class AdminShell extends StatelessWidget {
  final AppState state;
  final Future<void> Function() onLoggedOut;
  final VoidCallback onUnauthorized;

  const AdminShell({
    super.key,
    required this.state,
    required this.onLoggedOut,
    required this.onUnauthorized,
  });

  @override
  Widget build(BuildContext context) {
    if (!state.user.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) onUnauthorized();
      });
      return const Scaffold(
        backgroundColor: Color(0xFFF5F0E8),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF3E2723)),
        ),
      );
    }

    return AdminDashboardScreen(
      state: state,
      onLoggedOut: onLoggedOut,
      onUnauthorized: onUnauthorized,
    );
  }
}
