import 'package:flutter/material.dart';

import '../services/password_policy.dart';

class PasswordPolicyPanel extends StatelessWidget {
  final String password;
  final String email;
  final String displayName;

  const PasswordPolicyPanel({
    super.key,
    required this.password,
    required this.email,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final result = PasswordPolicy.evaluate(
      password,
      email: email,
      displayName: displayName,
    );
    final color = switch (result.strength) {
      'Strong' => const Color(0xFF2E7D32),
      'Good' => const Color(0xFF8D6E63),
      'Fair' => const Color(0xFFB7791F),
      _ => const Color(0xFFC62828),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Password strength',
                  style: TextStyle(
                    color: Color(0xFF3E2723),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                password.isEmpty ? '—' : result.strength,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...result.rules.map(
            (rule) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    rule.passed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: rule.passed ? const Color(0xFF2E7D32) : Colors.grey,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      rule.label,
                      style: const TextStyle(
                        color: Color(0xFF5D4037),
                        fontSize: 12,
                      ),
                    ),
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

class PasswordTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;

  const PasswordTextField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
  });

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
