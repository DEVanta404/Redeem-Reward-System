import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/password_policy.dart';
import '../widgets/password_policy_panel.dart';

class PasswordUpdateForm extends StatefulWidget {
  final String email;
  final String displayName;
  final bool requireCurrentPassword;
  final Future<void> Function() onSuccess;

  const PasswordUpdateForm({
    super.key,
    required this.email,
    required this.displayName,
    required this.requireCurrentPassword,
    required this.onSuccess,
  });

  @override
  State<PasswordUpdateForm> createState() => _PasswordUpdateFormState();
}

class _PasswordUpdateFormState extends State<PasswordUpdateForm> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _suggested = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _suggestPassword() {
    final password = PasswordPolicy.suggest(
      email: widget.email,
      displayName: widget.displayName,
    );
    setState(() {
      _newController.text = password;
      _confirmController.clear();
      _suggested = true;
    });
  }

  Future<void> _copySuggestedPassword() async {
    await Clipboard.setData(ClipboardData(text: _newController.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Suggested password copied.')),
    );
  }

  Future<void> _submit() async {
    final current = _currentController.text;
    final password = _newController.text;
    final confirmation = _confirmController.text;
    final messenger = ScaffoldMessenger.of(context);

    if (widget.requireCurrentPassword && current.isEmpty) {
      _showMessage('Enter your current password.');
      return;
    }
    if (password != confirmation) {
      _showMessage('The new passwords do not match.');
      return;
    }
    if (current.isNotEmpty && password == current) {
      _showMessage('Choose a password different from your current password.');
      return;
    }
    if (!PasswordPolicy.evaluate(
      password,
      email: widget.email,
      displayName: widget.displayName,
    ).isValid) {
      _showMessage('Please meet every password requirement.');
      return;
    }

    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      if (widget.requireCurrentPassword) {
        final response = await client.auth.signInWithPassword(
          email: widget.email,
          password: current,
        );
        if (response.session == null ||
            response.user?.id != client.auth.currentUser?.id) {
          _showMessage('Your current password could not be verified.');
          return;
        }
      }
      await client.auth.updateUser(UserAttributes(password: password));
      if (!mounted) return;
      await widget.onSuccess();
    } on AuthException catch (error) {
      if (!mounted) return;
      final text = error.message.toLowerCase().contains('password')
          ? 'Supabase rejected that password. Please choose another one that meets the password rules.'
          : error.message.toLowerCase().contains('invalid') ||
                error.message.toLowerCase().contains('credentials')
          ? 'Your current password is incorrect.'
          : 'We could not update your password. Please try again.';
      messenger.showSnackBar(SnackBar(content: Text(text)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('We could not update your password. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.requireCurrentPassword) ...[
            PasswordTextField(
              controller: _currentController,
              label: 'Current Password',
            ),
            const SizedBox(height: 12),
          ],
          PasswordTextField(
            controller: _newController,
            label: 'New Password',
            onChanged: (_) {
              if (_suggested) setState(() => _suggested = false);
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _suggestPassword,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Suggest a strong password'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3E2723),
                  padding: EdgeInsets.zero,
                ),
              ),
              if (_suggested)
                IconButton(
                  tooltip: 'Copy suggested password',
                  onPressed: _copySuggestedPassword,
                  icon: const Icon(Icons.copy, color: Color(0xFF3E2723)),
                ),
            ],
          ),
          PasswordPolicyPanel(
            password: _newController.text,
            email: widget.email,
            displayName: widget.displayName,
          ),
          const SizedBox(height: 12),
          PasswordTextField(
            controller: _confirmController,
            label: 'Confirm New Password',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3E2723),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Update Password'),
          ),
        ],
      ),
    );
  }
}

class ForcedPasswordUpdateScreen extends StatelessWidget {
  final String email;
  final String displayName;
  final Future<void> Function() onPasswordUpdated;
  final Future<void> Function() onSignOut;

  const ForcedPasswordUpdateScreen({
    super.key,
    required this.email,
    required this.displayName,
    required this.onPasswordUpdated,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_reset,
                        size: 48,
                        color: Color(0xFF3E2723),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Update your password',
                        style: TextStyle(
                          color: Color(0xFF3E2723),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your account needs a new password before you can continue.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF795548)),
                      ),
                      const SizedBox(height: 20),
                      PasswordUpdateForm(
                        email: email,
                        displayName: displayName,
                        requireCurrentPassword: true,
                        onSuccess: onPasswordUpdated,
                      ),
                      TextButton(
                        onPressed: onSignOut,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
