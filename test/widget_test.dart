// Basic Flutter widget test to verify app loads without errors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cbrn4/main.dart';

void main() {
  testWidgets('App loads without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const CbrnDashboardApp());

    // Verify the app title is rendered
    expect(find.text('CBRN Response System'), findsOneWidget);

    // Verify sidebar items are rendered
    expect(find.text('OVERVIEW'), findsOneWidget);
    expect(find.text('LIVE MAP'), findsOneWidget);
    expect(find.text('ANALYSIS'), findsOneWidget);
    expect(find.text('SUBSTANCES'), findsOneWidget);
    expect(find.text('INTELLIGENCE'), findsOneWidget);
    expect(find.text('PLANNING'), findsOneWidget);
    expect(find.text('EVACUATION'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
  });
}
