import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:quiz_management_mobile/data/models/study_group.dart';
import 'package:quiz_management_mobile/features/chat/voice_room_controller.dart';
import 'package:quiz_management_mobile/features/chat/voice_room_panel.dart';

import 'voice_room_test.dart' show FakeVoiceConnection, FakeDevices, FakePeer;

void main() {
  testWidgets('denying Android permission never starts native capture', (
    tester,
  ) async {
    const channel = MethodChannel('quizms/voice_permissions');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add('${call.method}:${call.arguments}');
          return false;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await expectLater(WebRtcVoiceDevices().capture('video'), throwsStateError);
    expect(calls, ['request:video']);
  });
  testWidgets(
    'listener joins with devices off and voice controls fit small screens with large text',
    (tester) async {
      final hub = FakeVoiceConnection();
      final call = VoiceRoomController(
        hub,
        devices: FakeDevices(),
        peerFactory: ({
          required localId,
          required remoteId,
          required configuration,
          required send,
          required onStream,
          required onState,
          required onError,
        }) => FakePeer(),
      );
      addTearDown(call.dispose);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await call.connect();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.8),
            ),
            child: Scaffold(
              body: VoiceRoomPanel(
                controller: call,
                channel: ChatChannel.fromJson({
                  'id': 2,
                  'groupId': 1,
                  'name': 'phong-hoc',
                  'isDefault': true,
                  'kind': 1,
                }),
                onChat: () {},
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Tham gia phòng'));
      await tester.tap(find.text('Tham gia phòng'));
      await tester.pumpAndSettle();
      expect(call.joined, isTrue, reason: '${call.error}; ${hub.calls}');
      expect(find.text('Bật mic'), findsOneWidget);
      expect(find.text('Bật camera'), findsOneWidget);
      expect(find.text('Đang nói'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Rời phòng'));
      await tester.pump();
      await tester.tap(find.text('Rời phòng'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(call.joined, isFalse);
      expect(find.text('Tham gia phòng'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
