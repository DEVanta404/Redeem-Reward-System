import 'dart:io';

import 'package:flutter/material.dart';
import '../app_state.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback onProfileUpdated;
  final VoidCallback onLoggedOut;

  const ProfileScreen(
      {super.key,
      required this.state,
      required this.onProfileUpdated,
      required this.onLoggedOut});

  Color get _membershipColor {
    switch (state.membership) {
      case 'Gold':
        return const Color(0xFFFFA000);
      case 'Silver':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF795548);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('Profile',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF3E2723))),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          children: [
            // ── Avatar card ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: const Color(0xFF3E2723),
                    backgroundImage: state.user.avatarUrl.trim().isNotEmpty
                        ? NetworkImage(state.user.avatarUrl)
                        : (state.user.avatarPath.trim().isNotEmpty
                            ? FileImage(File(state.user.avatarPath))
                            : null),
                    child: (state.user.avatarUrl.trim().isEmpty &&
                            state.user.avatarPath.trim().isEmpty)
                        ? Text(
                            state.user.name.isNotEmpty
                                ? state.user.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(state.user.name,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E2723))),
                  const SizedBox(height: 4),
                  Text(state.user.email,
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 14)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _membershipColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium,
                            color: _membershipColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${state.membership} Member · ${state.points} pts',
                          style: TextStyle(
                              color: _membershipColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Personal info ────────────────────────────────────────
            _InfoSection(items: [
              _InfoItem(
                  icon: Icons.person_outline,
                  label: 'Username',
                  value: state.user.name),
              _InfoItem(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: state.user.email),
              _InfoItem(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: state.user.phone),
              _InfoItem(
                  icon: Icons.cake_outlined,
                  label: 'Birthday',
                  value: state.user.birthday),
            ]),
            const SizedBox(height: 20),

            // ── Action buttons ───────────────────────────────────────
            _ActionButton(
              icon: Icons.edit_outlined,
              label: 'Edit Profile',
              color: const Color(0xFF3E2723),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                      state: state, onSaved: onProfileUpdated),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.lock_outline,
              label: 'Change Password',
              color: const Color(0xFF5D4037),
              onTap: () => _showChangePasswordDialog(context),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              icon: Icons.logout,
              label: 'Logout',
              color: const Color(0xFFC62828),
              onTap: () => _showLogoutDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Password',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PasswordField(controller: currentCtrl, label: 'Current Password'),
            const SizedBox(height: 12),
            _PasswordField(controller: newCtrl, label: 'New Password'),
            const SizedBox(height: 12),
            _PasswordField(
                controller: confirmCtrl, label: 'Confirm New Password'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3E2723),
                foregroundColor: Colors.white),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onLoggedOut();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem(
      {required this.icon, required this.label, required this.value});
}

class _InfoSection extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Personal Information',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF3E2723))),
          const SizedBox(height: 4),
          const Divider(),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(item.icon, size: 18, color: const Color(0xFF795548)),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                      Text(item.value,
                          style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF3E2723),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color)),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;

  const _PasswordField({required this.controller, required this.label});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
