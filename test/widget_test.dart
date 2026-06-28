// Smoke test: the app boots and renders.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:morse/app.dart';

void main() {
  testWidgets('MorseApp builds and shows the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MorseApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
