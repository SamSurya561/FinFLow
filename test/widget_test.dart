import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finflow/app/finflow_app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FinFlowApp());
    await tester.pumpAndSettle();

    // Verify that the dashboard title is present.
    expect(find.text('FinFlow Dashboard'), findsOneWidget);

    // Verify that the bottom navigation is present.
    // NavigationBar might be nested, so we can look for it by type.
    // Alternatively, we can look for a known icon on the bar.
    expect(find.byIcon(Icons.dashboard), findsOneWidget);
  });
}
