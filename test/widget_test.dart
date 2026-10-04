import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/core/router/app_router.dart';
import 'package:quiz_management_mobile/features/kahoot/kahoot_entry_screen.dart';
import 'package:quiz_management_mobile/main.dart';

void main() {
  testWidgets('Home opens the Kahoot entry screen', (tester) async {
    await tester.pumpWidget(QuizManagementApp(router: createRouter()));
    await tester.pumpAndSettle();

    expect(find.text('Kahoot Live'), findsOneWidget);

    await tester.tap(find.text('Kahoot Live'));
    await tester.pumpAndSettle();

    expect(find.byType(KahootEntryScreen), findsOneWidget);
  });
}
