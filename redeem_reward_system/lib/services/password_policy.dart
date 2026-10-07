import 'dart:math';

class PasswordRule {
  final String label;
  final bool passed;

  const PasswordRule(this.label, this.passed);
}

class PasswordPolicyResult {
  final List<PasswordRule> rules;

  const PasswordPolicyResult(this.rules);

  bool get isValid => rules.take(8).every((rule) => rule.passed);

  String get strength {
    final passedCount = rules.where((rule) => rule.passed).length;
    if (passedCount <= 4) return 'Weak';
    if (passedCount <= 6) return 'Fair';
    if (!isValid) return 'Good';
    return rules.last.passed ? 'Strong' : 'Good';
  }
}

class PasswordPolicy {
  static const _blockedPasswords = [
    'qwerty',
    'password',
    '12345678',
    '123456',
    '111111',
    'letmein',
    'welcome',
    'iloveyou',
    'admin',
    'abc123',
  ];
  static const _lowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _digits = '0123456789';
  static const _symbols = r'!@#$%^&*()-_=+[]{};:,.?/|~';

  static PasswordPolicyResult evaluate(
    String password, {
    String email = '',
    String displayName = '',
  }) {
    final lower = password.toLowerCase();
    final normalizedPassword = lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final personalWords = <String>{
      ...email
          .split('@')
          .first
          .toLowerCase()
          .split(RegExp(r'[^a-z0-9]+')),
      ...displayName.toLowerCase().split(RegExp(r'[^a-z0-9]+')),
    }
        .map((word) => word.replaceAll(RegExp(r'[^a-z0-9]'), ''))
        .where((word) => word.length >= 3)
        .toSet();
    final containsPersonalWord = personalWords.any(
      (word) => normalizedPassword.contains(word),
    );

    return PasswordPolicyResult([
      PasswordRule('At least 8 characters (12 recommended)', password.length >= 8),
      PasswordRule('An uppercase letter', RegExp(r'[A-Z]').hasMatch(password)),
      PasswordRule('A lowercase letter', RegExp(r'[a-z]').hasMatch(password)),
      PasswordRule('A number', RegExp(r'[0-9]').hasMatch(password)),
      PasswordRule('A symbol', RegExp(r'[^A-Za-z0-9\s]').hasMatch(password)),
      PasswordRule(
        'Not a common password',
        !_blockedPasswords.any((blocked) => lower.contains(blocked)),
      ),
      PasswordRule('Does not contain your name or email', !containsPersonalWord),
      PasswordRule(
        'No long sequences or repeated characters',
        !_hasSequence(password) && !RegExp(r'(.)\1{3,}', caseSensitive: false)
            .hasMatch(password),
      ),
      PasswordRule('12 or more characters recommended', password.length >= 12),
    ]);
  }

  static String suggest({
    String email = '',
    String displayName = '',
  }) {
    final random = Random.secure();
    const all = 'abcdefghijklmnopqrstuvwxyz'
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        '0123456789'
        r'!@#$%^&*()-_=+[]{};:,.?/|~';
    final required = [
      _lowercase,
      _uppercase,
      _digits,
      _symbols,
    ];

    for (var attempt = 0; attempt < 100; attempt++) {
      final chars = <String>[
        for (final alphabet in required)
          alphabet[random.nextInt(alphabet.length)],
        for (var i = 4; i < 14; i++) all[random.nextInt(all.length)],
      ];
      chars.shuffle(random);
      final candidate = chars.join();
      if (evaluate(
        candidate,
        email: email,
        displayName: displayName,
      ).isValid) {
        return candidate;
      }
    }
    throw StateError('Could not generate a password for this account.');
  }

  static bool _hasSequence(String password) {
    final value = password.toLowerCase();
    for (var start = 0; start <= value.length - 6; start++) {
      var ascending = true;
      var descending = true;
      for (var offset = 1; offset < 6; offset++) {
        final previous = value.codeUnitAt(start + offset - 1);
        final current = value.codeUnitAt(start + offset);
        ascending = ascending && current == previous + 1;
        descending = descending && current == previous - 1;
      }
      if (ascending || descending) return true;
    }
    return false;
  }
}
