import 'package:flutter_test/flutter_test.dart';
import 'package:sawit_detector/main.dart';
import 'package:sawit_detector/pages/home_page.dart';

void main() {
  testWidgets('Smoke test - PalmGuardApp load', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PalmGuardApp());

    // Verify that the HomePage is loaded.
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('PalmGuard AI'), findsOneWidget);
  });
}
