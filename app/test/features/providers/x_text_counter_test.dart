import 'dart:async';

import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/providers/capabilities.dart';
import 'package:cross_posting_app/features/providers/x_text_counter.dart';
import 'package:cross_posting_app/features/review/review_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/provider_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('crossposting/x-text');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'native adapter carries exact text and official validity in one crossing',
    () async {
      var calls = 0;
      const text = 'e\u0301 https://example.com/👨‍👩‍👧‍👦';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls++;
            expect(call.method, 'measure');
            expect(call.arguments, text);
            return {'units': 27, 'valid': false};
          });
      final measured = await const XTextCounter().measure(text);
      expect(measured.units, 27);
      expect(measured.valid, isFalse);
      expect(calls, 1);
    },
  );
  test(
    'invalidity and native errors remain blocking while validation awaits',
    () async {
      final barrier = Completer<TextMeasurement>();
      final counter = _AwaitedCounter(barrier.future);
      var completed = false;
      final result = CapabilityValidator(fixtureCapabilities(), counter)
          .validate(fixturePost())
          .then((value) {
            completed = true;
            return value;
          });
      await pumpEventQueue();
      expect(completed, isFalse);
      barrier.complete(const TextMeasurement(units: 1, valid: false));
      expect((await result).single.code, 'text-invalid');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'unavailable');
          });
      final profile = fixtureCapabilities(destination: Destination.x);
      expect(
        (await CapabilityValidator(
          profile,
          const XTextCounter(),
        ).validate(fixturePost(destination: Destination.x))).single.code,
        'requirements-unverified',
      );
    },
  );
  test(
    'one shared owner emits empty, mixed and multiple video rules',
    () async {
      final empty = fixturePost(text: '');
      expect(sharedContentIssues(empty).map((i) => i.code), ['empty-post']);
      expect(
        await CapabilityValidator(
          fixtureCapabilities(),
          FixtureTextCounter(),
        ).validate(empty),
        isEmpty,
      );
      final video = fixtureVideoPost(Destination.bluesky).assets.single;
      final mixed = fixturePost(assets: [video, fixtureAsset()]);
      expect(sharedContentIssues(mixed).map((i) => i.code), ['mixed-media']);
      expect(
        sharedContentIssues(
          fixturePost(
            assets: [
              video,
              video.copyWith(id: '2'),
            ],
          ),
        ).map((i) => i.code),
        ['multiple-videos'],
      );
    },
  );
}

class _AwaitedCounter implements TextCounter {
  _AwaitedCounter(this.value);
  final Future<TextMeasurement> value;
  @override
  Future<TextMeasurement> measure(String text) => value;
}
