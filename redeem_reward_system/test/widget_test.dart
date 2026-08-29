import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapetol_app/app_state.dart';
import 'package:kapetol_app/main.dart';
import 'package:kapetol_app/screens/edit_profile_screen.dart';

void main() {
  testWidgets('shows the splash screen before the auth flow', (tester) async {
    await tester.pumpWidget(const RewardApp());

    expect(find.text('Kapetol App'), findsOneWidget);
    expect(find.text('Life happens, Coffee helps.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('Kapetol App'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
  });

  testWidgets('shows only one save button on the edit profile screen', (tester) async {
    final state = AppState();
    state.user = UserProfile(
      id: 'user-123',
      name: 'Dejavu',
      email: 'ativophilrod@gmail.com',
      phone: '09934301442',
      birthday: '05/31/05',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EditProfileScreen(state: state, onSaved: () {}),
      ),
    );

    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });
}
