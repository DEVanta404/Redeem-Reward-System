import 'package:flutter_test/flutter_test.dart';
import 'package:kapetol_app/services/password_policy.dart';

void main() {
  group('PasswordPolicy', () {
    test('rejects common and weak passwords', () {
      expect(PasswordPolicy.evaluate('qwerty123').isValid, isFalse);
      expect(PasswordPolicy.evaluate('Password1').isValid, isFalse);
    });

    test('accepts a long password meeting all rules', () {
      final result = PasswordPolicy.evaluate('V4!coffee-Mug9x');

      expect(result.isValid, isTrue);
      expect(result.strength, 'Strong');
    });

    test('accepts the minimum policy length and marks 12 as recommended', () {
      final result = PasswordPolicy.evaluate('X7!Abc?Q');

      expect(result.isValid, isTrue);
      expect(result.strength, 'Good');
      expect(result.rules.last.passed, isFalse);
    });

    test('rejects passwords containing account identity', () {
      expect(
        PasswordPolicy.evaluate(
          'Alice2025!Strong',
          email: 'alice@example.com',
          displayName: 'Alice Smith',
        ).isValid,
        isFalse,
      );
    });

    test('rejects ascending sequences and repeated characters', () {
      expect(PasswordPolicy.evaluate('Aa123456!xYz').isValid, isFalse);
      expect(PasswordPolicy.evaluate('M4!aaaaB9xyzQ').isValid, isFalse);
    });

    test('suggestion is a secure 14-character policy-compliant password', () {
      final password = PasswordPolicy.suggest(
        email: 'customer@example.com',
        displayName: 'Kapetol Customer',
      );

      expect(password.length, 14);
      expect(
        PasswordPolicy.evaluate(
          password,
          email: 'customer@example.com',
          displayName: 'Kapetol Customer',
        ).isValid,
        isTrue,
      );
    });
  });
}
