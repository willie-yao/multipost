import 'dart:convert';
import 'dart:io';

import 'package:cross_posting_app/app/app_configuration.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/accounts/bluesky_oauth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppConfiguration config({
    String client = 'public-fixture-id',
    String xRedirect = 'com.example.caption:/x',
    String metadata = 'https://app.example.com/oauth/client.json',
    String scheme = 'com.example.app',
  }) => AppConfiguration(
    xClientId: client,
    xRedirectUri: Uri.parse(xRedirect),
    blueskyMetadataUri: Uri.parse(metadata),
    blueskyCallbackScheme: scheme,
  );

  test('missing X setup does not invalidate Bluesky or Instagram setup', () {
    final value = config(client: '');
    expect(value.connection(Destination.x).configured, isFalse);
    expect(value.connection(Destination.x).reason, contains('X'));
    expect(value.connection(Destination.bluesky).configured, isTrue);
    expect(value.connection(Destination.instagram).available, isTrue);
  });

  test('missing Bluesky metadata affects only its connection', () {
    final value = config(metadata: '');
    expect(value.connection(Destination.x).configured, isTrue);
    expect(value.connection(Destination.bluesky).configured, isFalse);
    expect(value.connection(Destination.bluesky).reason, contains('Bluesky'));
    expect(value.connection(Destination.instagram).available, isTrue);
  });

  test('malformed X client and callback configurations stay disabled', () {
    for (final client in [
      ' ',
      'client with spaces',
      'secret\nvalue',
      'client\u0000id',
    ]) {
      expect(
        config(client: client).connection(Destination.x).configured,
        isFalse,
      );
    }
    for (final redirect in [
      '',
      '/callback',
      'http://example.com/callback',
      'javascript:alert(1)',
      'com.example.caption:/x?token=unsafe',
      'com.example.caption:/x#fragment',
      'https://user:pass@example.com/callback',
    ]) {
      expect(
        config(xRedirect: redirect).connection(Destination.x).configured,
        isFalse,
        reason: redirect,
      );
    }
    expect(
      config(xRedirect: 'https://app.example.com/x')
          .connection(Destination.x)
          .configured,
      isTrue,
    );
  });

  test(
    'release Bluesky metadata requires public HTTPS and reverse domain scheme',
    () {
      for (final metadata in [
        '',
        'http://app.example.com/client.json',
        'https://localhost/client.json',
        'https://127.0.0.1/client.json',
        'https://app.example.com:8443/client.json',
        'https://user:pass@app.example.com/client.json',
        'https://app.example.com/client.json?q=1',
        'https://app.example.com/client.json#f',
      ]) {
        expect(
          config(metadata: metadata).connection(Destination.bluesky).configured,
          isFalse,
          reason: metadata,
        );
      }
      for (final scheme in [
        '',
        'caption',
        'com.example.app://',
        'com.example.other',
      ]) {
        expect(
          config(scheme: scheme).connection(Destination.bluesky).configured,
          isFalse,
          reason: scheme,
        );
      }
    },
  );

  test(
    'syntactically valid public setup does not assert SDK or live acceptance',
    () {
      final value = config();
      for (final destination in [Destination.x, Destination.bluesky]) {
        final gate = value.connection(destination);
        expect(gate.configured, isTrue);
        expect(gate.available, isFalse);
        expect(gate.reason, contains('verification'));
        expect(gate.reason, isNot(contains('public-fixture-id')));
      }
      expect(value.blueskyRedirectUri, Uri.parse('com.example.app:/callback'));
    },
  );

  test('build configuration defaults fail closed without blocking drafts', () {
    final value = AppConfiguration.fromEnvironment();
    expect(value.connection(Destination.x).available, isFalse);
    expect(value.connection(Destination.bluesky).available, isFalse);
    expect(value.connection(Destination.instagram).available, isTrue);
  });

  test('Bluesky sign-in opens only for a dev build with valid owned setup', () {
    const metadata =
        'https://willie-yao.github.io/multipost/client-metadata.json';
    AppConfiguration build({
      required bool dev,
      String scheme = 'io.github.willie-yao',
    }) => AppConfiguration(
      xClientId: '',
      xRedirectUri: Uri(),
      blueskyMetadataUri: Uri.parse(metadata),
      blueskyCallbackScheme: scheme,
      blueskyDevConnect: dev,
    );
    expect(
      build(dev: false).connection(Destination.bluesky).available,
      isFalse,
    );
    final dev = build(dev: true).connection(Destination.bluesky);
    expect(dev.configured, isTrue);
    expect(dev.available, isTrue);
    expect(dev.reason, contains('Posting to Bluesky stays off'));
    // The switch never overrides a mismatched callback scheme.
    expect(
      build(
        dev: true,
        scheme: 'io.github.someone-else',
      ).connection(Destination.bluesky).available,
      isFalse,
    );
    // X is unaffected by the Bluesky switch.
    expect(build(dev: true).connection(Destination.x).available, isFalse);
    expect(
      build(dev: true).blueskyRedirectUri.toString(),
      'io.github.willie-yao:/callback',
    );
  });

  test('published Bluesky metadata file matches what the app requires', () {
    // docs/bluesky/pages is what gets hosted; drift here breaks sign-in.
    final json = jsonDecode(
      File('../docs/bluesky/pages/client-metadata.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final value = AppConfiguration(
      xClientId: '',
      xRedirectUri: Uri(),
      blueskyMetadataUri: Uri.parse(json['client_id'] as String),
      blueskyCallbackScheme: 'io.github.willie-yao',
      blueskyDevConnect: true,
    );
    expect(value.connection(Destination.bluesky).available, isTrue);
    expect(json['client_id'], value.blueskyMetadataUri.toString());
    expect(json['redirect_uris'], [value.blueskyRedirectUri.toString()]);
    expect(json['application_type'], 'native');
    expect(json['token_endpoint_auth_method'], 'none');
    expect(json['dpop_bound_access_tokens'], isTrue);
    expect(json['response_types'], ['code']);
    expect((json['grant_types'] as List).toSet(), {
      'authorization_code',
      'refresh_token',
    });
    expect(json['scope'], blueskyWriteScope);
  });
}
