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
  test('known receipt survives gallery filename and folder changes', () async {
    const savedUri = 'content://media/external_primary/images/media/42';
    final renamedRow = <String, String>{
      'uri': savedUri,
      'displayName': 'A user renamed this photo.png',
      'relativePath': 'Pictures/A different album/',
    };
    final savedJob = PhotoExportJob(
      id: job.id,
      packageId: package.id,
      ordinal: 1,
      uri: savedUri,
      completed: true,
    );
    messenger.setMockMethodCallHandler(MethodChannelAndroidTransfer.channel, (
      call,
    ) async {
      final args = call.arguments as Map;
      if (args['uri'] == renamedRow['uri']) return {'uri': savedUri};
      // Original generated metadata no longer identifies this still-valid row.
      if (args['displayName'] != renamedRow['displayName']) {
        return <String, String>{};
      }
      throw StateError('Unexpected fixture lookup');
    });
    final result = (await transfer.reconcilePhotos(package, [savedJob])).single;
    expect(result.succeeded, isTrue);
    expect(result.uri, savedUri);
  });
  test(
    'launch maps absent plugin and malformed outcomes conservatively',
    () async {
      expect(await transfer.openInstagram(), LaunchResult.unavailable);
      for (final entry in {
        'opened': LaunchResult.opened,
        'unavailable': LaunchResult.unavailable,
        'unknown': LaunchResult.failed,
      }.entries) {
        messenger.setMockMethodCallHandler(
          MethodChannelAndroidTransfer.channel,
          (call) async => entry.key,
        );
        expect(await transfer.openInstagram(), entry.value);
      }
    },
  );
  test('share cannot use a capability for the wrong photo count', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(MethodChannelAndroidTransfer.channel, (
      _,
    ) async {
      calls++;
      return {
        'status': 'dispatchedToInstagram',
        'targetPackage': 'com.instagram.android',
      };
    });
    final carouselOnly = MethodChannelAndroidTransfer(
      Directory('/private/instagram-packages'),
      shareCapability: InstagramShareCapability(
        carousel: true,
        checkedAt: DateTime.utc(2026),
        device: 'fixture',
        instagramVersion: 'fixture',
      ),
    );
    expect(await carouselOnly.sharePhotos(package), ShareDispatch.unavailable);
    expect(await transfer.sharePhotos(package), ShareDispatch.unavailable);
    expect(calls, 0);
  });
  test('targeted dispatch requires the exact Instagram target', () async {
    final enabled = MethodChannelAndroidTransfer(
      Directory('/private/instagram-packages'),
      shareCapability: InstagramShareCapability(
        singlePhoto: true,
        carousel: true,
        checkedAt: DateTime.utc(2026),
        device: 'fixture',
        instagramVersion: 'fixture',
      ),
    );
    for (final target in [null, 'other.app', 'com.instagram.android']) {
      messenger.setMockMethodCallHandler(
        MethodChannelAndroidTransfer.channel,
        (_) async => {
          'status': 'dispatchedToInstagram',
          'targetPackage': target,
        },
      );
      expect(
        await enabled.sharePhotos(package),
        target == 'com.instagram.android'
            ? ShareDispatch.dispatchedToInstagram
            : ShareDispatch.failed,
      );
    }
    for (final status in [
      'chooserOpened',
      'cancelled',
      'unavailable',
      'failed',
      'unknown',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannelAndroidTransfer.channel,
        (_) async => {'status': status},
      );
      final expected = switch (status) {
        'chooserOpened' => ShareDispatch.chooserOpened,
        'cancelled' => ShareDispatch.cancelled,
        'unavailable' => ShareDispatch.unavailable,
        _ => ShareDispatch.failed,
      };
      expect(await enabled.sharePhotos(package), expected);
    }
  });
  test(
    'photo handoff sends every ordered frozen file and no caption',
    () async {
      final enabled = MethodChannelAndroidTransfer(
        Directory('/private/instagram-packages'),
        shareCapability: InstagramShareCapability(
          carousel: true,
          checkedAt: DateTime.utc(2026),
          device: 'fixture',
          instagramVersion: 'fixture',
        ),
      );
      final multiple = package.copyWith(
        photos: [
          package.photos.single,
          package.photos.single.copyWith(
            ordinal: 2,
            relativePath: '${package.id}/02.jpg',
          ),
        ],
      );
      MethodCall? sent;
      messenger.setMockMethodCallHandler(MethodChannelAndroidTransfer.channel, (
        call,
      ) async {
        sent = call;
        return {
          'status': 'dispatchedToInstagram',
          'targetPackage': 'com.instagram.android',
        };
      });
      expect(
        await enabled.sharePhotos(multiple),
        ShareDispatch.dispatchedToInstagram,
      );
      expect(sent!.method, 'sharePhotos');
      final arguments = sent!.arguments as Map;
      final photos = arguments['photos'] as List;
      expect(photos.length, 2);
      expect((photos[0] as Map)['mimeType'], 'image/png');
      expect((photos[1] as Map)['mimeType'], 'image/jpeg');
      expect((photos[1] as Map)['sourcePath'], endsWith('02.jpg'));
      expect(arguments.containsKey('caption'), isFalse);
      expect(arguments.containsKey('text'), isFalse);
    },
  );
  test(
    'revoked photo URI or Android error is never a successful dispatch',
    () async {
      final enabled = MethodChannelAndroidTransfer(
        Directory('/private/instagram-packages'),
        shareCapability: InstagramShareCapability(
          singlePhoto: true,
          checkedAt: DateTime.utc(2026),
          device: 'fixture',
          instagramVersion: 'fixture',
        ),
      );
      messenger.setMockMethodCallHandler(
        MethodChannelAndroidTransfer.channel,
        (_) async => throw PlatformException(code: 'access-revoked'),
      );
      expect(await enabled.sharePhotos(package), ShareDispatch.failed);
      expect(await enabled.openInstagram(), LaunchResult.failed);
    },
  );
}
