import 'dart:io';

import 'package:cross_posting_app/features/instagram/android_transfer.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native I3 absence and prepared-file boundary (synthetic only)', (
    _,
  ) async {
    final support = await getApplicationSupportDirectory();
    final transfer = MethodChannelAndroidTransfer(
      Directory(p.join(support.path, 'instagram-packages')),
    );
    expect(await transfer.openInstagram(), LaunchResult.unavailable);
    const id = '0b5669cf-6fdd-4b53-a2bc-425ac50c4fbd';
    final root = Directory(p.join(support.path, 'instagram-packages', id));
    await root.create(recursive: true);
    final photo = File(p.join(root.path, '01.png'));
    await photo.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10], flush: true);
    final hash = sha256.convert(await photo.readAsBytes()).toString();
    final arguments = <String, Object>{
      'packageId': id,
      'supported': true,
      'photos': [
        {
          'sourcePath': photo.path,
          'mimeType': 'image/png',
          'expectedHash': hash,
        },
      ],
    };
    final result = await MethodChannelAndroidTransfer.channel
        .invokeMapMethod<String, dynamic>('sharePhotos', arguments);
    expect(result?['status'], 'unavailable');
    final second = File(p.join(root.path, '02.jpg'));
    await second.writeAsBytes([255, 216, 255, 217], flush: true);
    final secondHash = sha256.convert(await second.readAsBytes()).toString();
    final multiple = <String, Object>{
      ...arguments,
      'photos': [
        {
          'sourcePath': photo.path,
          'mimeType': 'image/png',
          'expectedHash': hash,
        },
        {
          'sourcePath': second.path,
          'mimeType': 'image/jpeg',
          'expectedHash': secondHash,
        },
      ],
    };
    expect(
      (await MethodChannelAndroidTransfer.channel
          .invokeMapMethod<String, dynamic>(
            'sharePhotos',
            multiple,
          ))?['status'],
      'unavailable',
    );
    await expectLater(
      MethodChannelAndroidTransfer.channel.invokeMethod<Object>('sharePhotos', {
        ...arguments,
        'photos': [
          {
            'sourcePath': photo.path,
            'mimeType': 'image/png',
            'expectedHash': hash,
          },
          {
            'sourcePath': second.path,
            'mimeType': 'image/jpeg',
            'expectedHash': '0' * 64,
          },
        ],
      }),
      throwsA(
        isA<PlatformException>().having((e) => e.code, 'code', 'invalid-share'),
      ),
    );
    await second.delete();
    for (final invalid in [
      <String, Object>{
        'sourcePath': p.join(support.path, 'outside.png'),
        'mimeType': 'image/png',
        'expectedHash': hash,
      },
      <String, Object>{
        'sourcePath': p.join(root.path, '..', id, '01.png'),
        'mimeType': 'image/png',
        'expectedHash': hash,
      },
      <String, Object>{
        'sourcePath': photo.path,
        'mimeType': 'image/jpeg',
        'expectedHash': hash,
      },
      <String, Object>{
        'sourcePath': photo.path,
        'mimeType': 'image/png',
        'expectedHash': '0' * 64,
      },
    ]) {
      await expectLater(
        MethodChannelAndroidTransfer.channel.invokeMethod<Object>(
          'sharePhotos',
          {
            ...arguments,
            'photos': [invalid],
          },
        ),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'invalid-share',
          ),
        ),
      );
    }
    await expectLater(
      MethodChannelAndroidTransfer.channel.invokeMethod<Object>('sharePhotos', {
        ...arguments,
        'packageId': 'other-package',
      }),
      throwsA(isA<PlatformException>()),
    );
    final disabled = await MethodChannelAndroidTransfer.channel
        .invokeMapMethod<String, dynamic>('sharePhotos', {
          ...arguments,
          'supported': false,
        });
    expect(disabled?['status'], 'unavailable');
    // The channel still owns export and rejects an out-of-root source before MediaStore.
    await expectLater(
      MethodChannelAndroidTransfer.channel.invokeMethod<Object>('savePhoto', {
        'jobId': '052837ef-6417-4419-8c76-04baf99d9458',
        'sourcePath': p.join(support.path, 'outside.png'),
        'displayName': 'caption-052837ef-6417-4419-8c76-04baf99d9458-01.png',
        'mimeType': 'image/png',
        'expectedHash': hash,
      }),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'invalid-export',
        ),
      ),
    );
    await photo.delete();
    await root.delete();
    debugPrint(
      'I3 NATIVE Instagram absent; share disabled; canonical boundary rejected escape/mime/hash/package errors; exporter handler retained.',
    );
  });
}
