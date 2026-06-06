// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_era/screens/setup_screen.dart';
import 'package:offline_era/providers/user_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Setup screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => UserProvider(),
        child: const MaterialApp(home: SetupScreen()),
      ),
    );

    expect(find.text('offline\nera.'), findsOneWidget);
  });
}
