// Opt in with dedicated test credentials via dart-defines. No permanent data is written.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:quiz_management_mobile/core/config/app_config.dart';
import 'package:quiz_management_mobile/core/theme/app_theme.dart';
import 'package:quiz_management_mobile/data/api/api_client.dart';
import 'package:quiz_management_mobile/data/api/token_storage.dart';
import 'package:quiz_management_mobile/data/repositories/auth_repository.dart';
import 'package:quiz_management_mobile/data/repositories/profile_repository.dart';
import 'package:quiz_management_mobile/data/repositories/groups_repository.dart';
import 'package:quiz_management_mobile/features/auth/auth_controller.dart';
import 'package:quiz_management_mobile/features/chat/chat_room_screen.dart';
import 'package:quiz_management_mobile/features/chat/voice_room_controller.dart';
import 'package:quiz_management_mobile/features/chat/voice_room_panel.dart';

void main() {
  // Native video textures must keep consuming frames while device/network futures are pending.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const email = String.fromEnvironment('VOICE_TEST_EMAIL');
  const password = String.fromEnvironment('VOICE_TEST_PASSWORD');
  testWidgets(
    'native voice exchanges audio/video with a web participant',
    (tester) async {
      AppConfig.baseUrl = AppConfig.defaultBaseUrl;
      final tokens = InMemoryTokenStorage();
      final api = ApiClient(tokens: tokens);
      final auth = AuthController(
        AuthRepository(api, tokens),
        ProfileRepository(api, tokens),
      );
      final groups = GroupsRepository(api);
      await auth.login(email, password);
      final group = (await groups.mine()).firstWhere(
        (g) =>
            g.id ==
            const int.fromEnvironment('VOICE_TEST_GROUP', defaultValue: 1),
      );
      final channels = await groups.voiceChannels(group.id);
      expect(channels, isNotEmpty);
      VoiceRoomController? call;
      Future<void> until(
        bool Function() condition,
        String label, {
        int seconds = 45,
      }) async {
        final deadline = DateTime.now().add(Duration(seconds: seconds));
        while (!condition()) {
          if (DateTime.now().isAfter(deadline)) {
            fail('Timed out: $label; ${call?.error}');
          }
          await tester.pump(const Duration(milliseconds: 200));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }

      Future<void> tap(String label) async {
        // Controller futures may finish before the next enabled-button frame.
        await tester.pump();
        await tester.ensureVisible(find.text(label).last);
        await tester.tap(find.text(label).last);
        await tester.pump();
      }

      Future<Map<String, dynamic>> stats() async {
        final reports = await Future.wait(
          call!.peers.values.map((peer) => peer.stats()),
        );
        return {
          'participants': call!.participants.length,
          'states': call!.states.values.toList(),
          'rtp': reports
              .expand((items) => items)
              .where(
                (s) =>
                    s.type == 'inbound-rtp' ||
                    s.type == 'outbound-rtp' ||
                    s.type == 'media-source',
              )
              .map(
                (s) => {
                  'type': s.type,
                  'kind': s.values['kind'] ?? s.values['mediaType'],
                  'packetsReceived': s.values['packetsReceived'],
                  'packetsSent': s.values['packetsSent'],
                  'framesDecoded': s.values['framesDecoded'],
                  'framesEncoded': s.values['framesEncoded'],
                  'audioLevel': s.values['audioLevel'],
                  'totalAudioEnergy': s.values['totalAudioEnergy'],
                },
              )
              .toList(),
        };
      }

      try {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              Provider.value(value: groups),
            ],
            child: MaterialApp(
              theme: AppTheme.dark(),
              home: ChatRoomScreen(group: group),
            ),
          ),
        );
        await until(
          () => find.byTooltip('Các kênh chat').evaluate().isNotEmpty,
          'group screen',
        );
        final groupState = tester.state(find.byType(ChatRoomScreen)) as dynamic;
        await until(
          () => groupState.loading == false,
          'group loaded',
          seconds: 90,
        );
        expect(groupState.error, isNull);
        expect((groupState.voiceChannels as List).isNotEmpty, isTrue);
        await tester.tap(find.byTooltip('Các kênh chat'));
        await tester.pumpAndSettle();
        await until(
          () => tester
              .state<ScaffoldState>(find.byType(Scaffold).first)
              .isDrawerOpen,
          'channel drawer',
        );
        await until(
          () => find.text(channels.first.name).evaluate().isNotEmpty,
          'voice channel',
        );
        await tap(channels.first.name);
        await tester.pumpAndSettle();
        call = tester
            .widget<VoiceRoomPanel>(find.byType(VoiceRoomPanel))
            .controller;
        await until(() => call!.connected, 'voice connection');
        await tap('Tham gia phòng');
        await until(() => call!.joined, 'join listener');
        debugPrint('VOICE_STAGE joined');
        expect(call.microphone, isFalse);
        expect(call.camera, isFalse);
        await tap('Bật mic');
        await until(() => call!.microphone && !call.mediaBusy, 'microphone');
        debugPrint('VOICE_STAGE microphone ready');
        await tap('Bật camera');
        debugPrint('VOICE_STAGE camera requested');
        await until(() => call!.camera && !call.mediaBusy, 'camera');
        debugPrint('VOICE_STAGE camera ready');
        await until(
          () => call!.states.values.contains('connected'),
          'web peer',
          seconds: 90,
        );
        Map<String, dynamic>? report;
        final deadline = DateTime.now().add(const Duration(seconds: 45));
        while (DateTime.now().isBefore(deadline)) {
          report = await stats();
          final rtp = (report['rtp'] as List).cast<Map<String, dynamic>>();
          if (['audio', 'video'].every(
            (kind) => ['inbound-rtp', 'outbound-rtp'].every(
              (type) => rtp.any(
                (s) =>
                    s['kind'] == kind &&
                    s['type'] == type &&
                    ((s[type == 'inbound-rtp'
                                    ? 'packetsReceived'
                                    : 'packetsSent']
                                as num?) ??
                            0) >
                        0,
              ),
            ),
          )) {
            break;
          }
          await tester.pump(const Duration(milliseconds: 300));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        // Sanitized statistics only: no SDP, candidates, IPs or credentials.
        debugPrint('VOICE_NATIVE_REPORT ${jsonEncode(report)}');
        if (const bool.fromEnvironment('VOICE_TEST_REMOTE_TOGGLE')) {
          await until(
            () => call!.participants.any(
              (p) => p.id != call!.participantId && !p.camera,
            ),
            'web camera off',
          );
          await until(
            () => call!.participants.any(
              (p) => p.id != call!.participantId && p.camera,
            ),
            'web camera on',
          );
          await until(
            () => tester
                .widgetList<RTCVideoView>(find.byType(RTCVideoView))
                .any(
                  (view) =>
                      call!.streams.values.any(
                        (stream) =>
                            stream.id == view.videoRenderer.srcObject?.id,
                      ) &&
                      view.videoRenderer.videoWidth > 0 &&
                      view.videoRenderer.videoHeight > 0,
                ),
            'web video rendered again',
          );
          debugPrint('VOICE_STAGE web camera toggled');
          await Future<void>.delayed(const Duration(seconds: 2));
        }
        for (final kind in ['audio', 'video']) {
          for (final type in ['inbound-rtp', 'outbound-rtp']) {
            expect(
              (report!['rtp'] as List).any(
                (s) =>
                    s['kind'] == kind &&
                    s['type'] == type &&
                    ((s[type == 'inbound-rtp'
                                    ? 'packetsReceived'
                                    : 'packetsSent']
                                as num?) ??
                            0) >
                        0,
              ),
              isTrue,
              reason: '$type $kind',
            );
          }
        }
        await tester.pump();
        await tester.tap(find.byTooltip('Đổi camera'));
        await until(() => !call!.mediaBusy, 'rear camera');
        expect(call.frontCamera, isFalse);
        await tester.pump();
        await tester.tap(find.byTooltip('Đổi camera'));
        await until(() => !call!.mediaBusy, 'front camera');
        expect(call.frontCamera, isTrue);
        await tester.pump();
        await tester.tap(find.byTooltip('Chuyển sang loa thoại'));
        await until(() => !call!.speakerEnabled, 'earpiece');
        await tester.pump();
        await tester.tap(find.byTooltip('Bật loa ngoài'));
        await until(() => call!.speakerEnabled, 'speaker');
        debugPrint('VOICE_STAGE camera and speaker switched');
        await tap('Tắt mic');
        await until(() => !call!.microphone && !call.mediaBusy, 'mute');
        await tap('Bật mic');
        await until(() => call!.microphone && !call.mediaBusy, 'unmute');
        await tap('Tắt camera');
        await until(() => !call!.camera && !call.mediaBusy, 'camera off');
        await tap('Bật camera');
        await until(() => call!.camera && !call.mediaBusy, 'camera on');
        debugPrint('VOICE_STAGE devices toggled');
        await tap('Về chat');
        await until(
          () => find.text('Đang trong phòng voice').evaluate().isNotEmpty,
          'voice dock',
        );
        expect(call.joined, isTrue);
        debugPrint('VOICE_STAGE chat dock');
        await tester.tap(find.text('Đang trong phòng voice'));
        await tester.pump();
        await tap('Rời phòng');
        await until(() => !call!.joined, 'leave');
        expect(call.peers, isEmpty);
        expect(call.camera, isFalse);
        expect(call.microphone, isFalse);
        debugPrint('VOICE_STAGE left');
        await tap('Tham gia phòng');
        await until(() => call!.joined, 'rejoin');
        expect(call.camera, isFalse);
        expect(call.microphone, isFalse);
        await call.leave();
        debugPrint('VOICE_STAGE rejoined and left');
      } finally {
        await call?.leave();
        await tester.pumpWidget(const SizedBox.shrink());
        auth.dispose();
      }
    },
    skip: email.isEmpty || password.isEmpty,
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
