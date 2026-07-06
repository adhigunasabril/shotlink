// This is a basic Flutter widget test for Shotlink.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:open_photo_link/main.dart';

void main() {
  testWidgets('Dashboard smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our app bar contains the 'shotlink' logo text.
    expect(find.text('shotlink'), findsOneWidget);

    // Verify that we have a camera icon/button on the dashboard.
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    expect(find.text('Tap to Start Photo & Scan'), findsOneWidget);
  });
}
