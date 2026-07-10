// Basic smoke test for the Welhof app.
import 'package:flutter_test/flutter_test.dart';

import 'package:welhof_app/main.dart';

void main() {
  testWidgets('App boots to the registration screen', (WidgetTester tester) async {
    await tester.pumpWidget(const WelhofApp());
    await tester.pumpAndSettle();

    // The gate resolves to the registration screen when no phone is stored.
    expect(find.text('Welkom bij Welhof'), findsOneWidget);
    expect(find.text('Verstuur code'), findsOneWidget);
  });
}
