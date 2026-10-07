import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_profiles.dart';
import '../services/password_policy.dart';
import '../widgets/password_policy_panel.dart';

class AuthScreen extends StatelessWidget {
  final Future<void> Function() onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F0E8),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_cafe,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Kapetol App',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E2723),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Life happens, Coffee helps.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF795548)),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE0D3),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const TabBar(
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: Color(0xFF3E2723),
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: Color(0xFF3E2723),
                          tabs: [
                            Tab(text: 'Login'),
                            Tab(text: 'Register'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 620,
                        child: TabBarView(
                          children: [
                            _AuthForm(
                              title: 'Welcome back',
                              subtitle: 'Login to your Kapetol account',
                              buttonLabel: 'Login',
                              isRegister: false,
                              onAuthenticated: onAuthenticated,
                            ),
                            _AuthForm(
                              title: 'Create account',
                              subtitle: 'Register to start earning rewards',
                              buttonLabel: 'Register',
                              isRegister: true,
                              onAuthenticated: onAuthenticated,
                            ),
                          ],
                        ),
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

class _AuthForm extends StatefulWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool isRegister;
  final Future<void> Function() onAuthenticated;

  const _AuthForm({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.isRegister,
    required this.onAuthenticated,
  });

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _suggestedPassword = false;

  bool get _passwordValid => PasswordPolicy.evaluate(
    _passwordController.text,
    email: _emailController.text,
    displayName: _nameController.text,
  ).isValid;

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (widget.isRegister && name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name.')));
      return;
    }

    if (!widget.isRegister && name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your email.')));
      return;
    }

    if (widget.isRegister && email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your email.')));
      return;
    }

    if (password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password.')),
      );
      return;
    }

    if (widget.isRegister) {
      if (!_passwordValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please meet every password requirement.')),
        );
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The passwords do not match.')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      late final AuthResponse authResponse;
      final resolvedEmail = widget.isRegister ? email : name;

      if (!widget.isRegister) {
        authResponse = await Supabase.instance.client.auth.signInWithPassword(
          email: resolvedEmail,
          password: password,
        );
      } else {
        authResponse = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {'name': name.trim()},
        );
      }

      final user = authResponse.user;
      final session = authResponse.session;

      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.buttonLabel == 'Register'
                  ? 'Registration failed. Please try again.'
                  : 'Unable to sign in. Please check your credentials.',
            ),
          ),
        );
        return;
      }

      if (widget.buttonLabel == 'Login' && (session == null)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to sign in. Please check your credentials.'),
          ),
        );
        return;
      }

      if (widget.buttonLabel == 'Register') {
        if (session != null) {
          final success = await SupabaseProfilesService().createOrUpdateProfile(
            userId: user.id,
            email: email,
            fullName: name.trim(),
            username: name.trim(),
          );

          if (!success) throw Exception('Profile creation failed.');
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Registration successful! Please log in with your credentials.',
            ),
          ),
        );
        return;
      }

      final profiles = SupabaseProfilesService();
      final profile = await profiles.getProfile(user.id);
      if (profile == null) {
        final success = await profiles.createOrUpdateProfile(
          userId: user.id,
          email: resolvedEmail,
          fullName: resolvedEmail.split('@').first,
        );
        if (!success) throw Exception('Profile creation failed.');
      }

      if (!mounted) return;
      await widget.onAuthenticated();
    } on AuthException catch (error) {
      if (!mounted) return;

      final lowerMessage = error.message.toLowerCase();
      String displayMessage = 'We could not complete authentication. Please try again.';

      if (lowerMessage.contains('already registered') ||
          lowerMessage.contains('already exists')) {
        displayMessage =
            'This email is already registered. Please try logging in instead.';
      } else if (lowerMessage.contains('invalid') ||
          lowerMessage.contains('credentials')) {
        if (!widget.isRegister) {
          displayMessage = 'Invalid credentials. Please check and try again.';
        } else {
          displayMessage =
              'Registration failed. Please try again with different credentials.';
        }
      } else if (lowerMessage.contains('email not confirmed')) {
        displayMessage =
            'Please confirm your email address before logging in. Check your email for a confirmation link.';
      } else if (lowerMessage.contains('password')) {
        displayMessage =
            'Please choose a password that meets the password requirements.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(displayMessage)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E2723),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF795548)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            keyboardType: widget.isRegister
                ? TextInputType.name
                : TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: widget.isRegister ? 'Name' : 'Email',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (widget.isRegister) setState(() {});
            },
          ),
          const SizedBox(height: 12),
          if (widget.isRegister)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          PasswordTextField(
            controller: _passwordController,
            label: 'Password',
            onChanged: (_) {
              if (_suggestedPassword) _suggestedPassword = false;
              setState(() {});
            },
          ),
          if (widget.isRegister) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    final suggested = PasswordPolicy.suggest(
                      email: _emailController.text,
                      displayName: _nameController.text,
                    );
                    setState(() {
                      _passwordController.text = suggested;
                      _confirmPasswordController.clear();
                      _suggestedPassword = true;
                    });
                  },
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Suggest a strong password'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF3E2723),
                    padding: EdgeInsets.zero,
                  ),
                ),
                if (_suggestedPassword)
                  IconButton(
                    tooltip: 'Copy suggested password',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _passwordController.text),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Suggested password copied.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, color: Color(0xFF3E2723)),
                  ),
              ],
            ),
            PasswordPolicyPanel(
              password: _passwordController.text,
              email: _emailController.text,
              displayName: _nameController.text,
            ),
            const SizedBox(height: 12),
            PasswordTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ||
                      (widget.isRegister && !_passwordValid) ||
                      (widget.isRegister &&
                          _passwordController.text !=
                              _confirmPasswordController.text)
                  ? null
                  : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3E2723),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(widget.buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
