import 'dart:io';

import 'package:cross_posting_app/features/instagram/android_transfer.dart';
import 'package:cross_posting_app/features/instagram/instagram_package.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final package = InstagramPackage(
    id: '2b1cd2f7-b198-4f2f-845e-640098f3fdb7',
    operationId: 'p',
    draftId: 'd',
    revision: 0,
    caption: 'frozen',
    ownCaption: false,
    createdAt: DateTime.utc(2026),
    photos: [
      const PreparedPhoto(
        assetId: 'a',
        relativePath: '2b1cd2f7-b198-4f2f-845e-640098f3fdb7/01.png',
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ordinal: 1,
        altText: '',
      ),
    ],
  );
  final job = PhotoExportJob(
    id: 'baa94232-761d-4ad5-a810-36452ec3b52e',
    packageId: package.id,
    ordinal: 1,
  );
  final transfer = MethodChannelAndroidTransfer(
    Directory('/private/instagram-packages'),
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(
      MethodChannelAndroidTransfer.channel,
      null,
    );
  });
  test(
    'clipboard performs exactly one setData write and never reads',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      await transfer.copyCaption('full frozen caption');
      expect(calls.map((c) => c.method), ['Clipboard.setData']);
      expect(calls.single.arguments, {'text': 'full frozen caption'});
    },
  );
  test('port rejects duplicate or foreign photo jobs before channel', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(MethodChannelAndroidTransfer.channel, (
      call,
    ) async {
      calls++;
      return {'uri': 'content://media/1'};
    });
    await expectLater(
      transfer.savePhotos(package, [job, job]),
      throwsStateError,
    );
    expect(calls, 0);
    await expectLater(
      transfer.reconcilePhotos(package, [
        const PhotoExportJob(id: 'x', packageId: 'wrong', ordinal: 1),
      ]),
      throwsStateError,
    );
    expect(calls, 0);
  });
  test('native failed write or no-space result is not successful', () async {
    for (final code in ['write-failed', 'no-space']) {
      messenger.setMockMethodCallHandler(
        MethodChannelAndroidTransfer.channel,
        (call) async => throw PlatformException(code: code),
      );
      final result = (await transfer.savePhotos(package, [job])).single;
      expect(result.succeeded, isFalse);
      expect(result.errorCode, code);
    }
  });
}
