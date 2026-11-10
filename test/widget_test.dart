import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_management_mobile/features/kahoot/kahoot_entry_screen.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('Home opens the Kahoot entry screen', (tester) async {
    await TestApp(token: 'stored').start(tester);

    await tester.ensureVisible(find.text('Kahoot Live'));
    await tester.tap(find.text('Kahoot Live'));
    await tester.pumpAndSettle();

    expect(find.byType(KahootEntryScreen), findsOneWidget);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const [
      Size(320, 568),
      Size(390, 780),
      Size(768, 1024),
      Size(844, 390),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpAndSettle();
      final join = find.widgetWithText(FilledButton, 'Vào phòng');
      if (size.height >= 568) {
        expect(join.hitTestable(), findsOneWidget, reason: '$size');
      } else {
        await tester.ensureVisible(join);
        await tester.pumpAndSettle();
        expect(join.hitTestable(), findsOneWidget, reason: '$size');
      }
      expect(tester.takeException(), isNull, reason: '$size');
    }
    await tester.tap(find.text('Vào phòng'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập mã PIN hoặc quét mã QR'), findsOneWidget);
  });
}
