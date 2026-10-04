import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/features/kahoot/kahoot_entry_screen.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('Home opens the Kahoot entry screen', (tester) async {
    await TestApp(token: 'stored').start(tester);

    await tester.tap(find.text('Kahoot Live'));
    await tester.pumpAndSettle();

    expect(find.byType(KahootEntryScreen), findsOneWidget);
  });
}
