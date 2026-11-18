import 'dart:async';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/clock.dart';
import '../core/ids.dart';
import '../features/accounts/account_repository.dart';
import '../features/accounts/account.dart';
import '../features/accounts/credential_vault.dart';
import '../features/accounts/x_connection.dart';
import '../features/accounts/bluesky_connection.dart';
import '../features/accounts/bluesky_oauth.dart';
import '../features/accounts/bluesky_browser.dart';
import '../features/drafts/draft.dart';
import '../features/drafts/draft_editor.dart';
import '../features/drafts/draft_repository.dart';
import '../features/instagram/instagram_repository.dart';
import '../features/instagram/instagram_service.dart';
import '../features/media/picker_imports.dart';
import '../features/providers/capabilities.dart';
import '../features/providers/provider.dart';
import '../features/providers/x_publisher.dart';
import '../features/providers/bluesky_publisher.dart';
import '../features/providers/x_text_counter.dart';
import '../features/publishing/publishing_boundary.dart';
import '../features/publishing/retry_edits.dart';
import '../features/publishing/attempt_repository.dart';
import '../features/publishing/publish_coordinator.dart';
import '../features/review/review_service.dart';
import '../storage/local_database.dart';
import '../storage/media_files.dart';
import 'app_configuration.dart';

class AppServices {
  AppServices({
    required this.database,
    required this.media,
    required this.drafts,
    required this.accounts,
    required this.clock,
    required this.ids,
    required this.instagramPackageRoot,
    this.onClose,
    this.connections = const {},
    Map<Destination, PublishProvider> publishProviders = const {},
    this.publishingOnline,
    this.blueskyDevAccepted = false,
  }) : publishProviders = Map.unmodifiable(publishProviders),
       pickerImports = PickerImports(media, ids);
  final LocalDatabase database;
  final MediaFiles media;
  final DraftRepository drafts;
  final AccountRepository accounts;
  final Map<Destination, AccountConnection> connections;
  final Map<Destination, PublishProvider> publishProviders;
  final FutureOr<bool?> Function()? publishingOnline;

  /// Development builds only: Bluesky text/photo posting is accepted.
  final bool blueskyDevAccepted;
  final Clock clock;
  final Ids ids;
  final PickerImports pickerImports;
  final Directory instagramPackageRoot;
  late final instagramPolicy = InstagramPhotoPolicy.localPreparation();
  late final instagramRepo = InstagramRepository(database);
  late final validators = CapabilityRegistry.production(
    instagram: instagramPolicy,
    blueskyDevAccepted: blueskyDevAccepted,
  );
  late final review = ReviewService(drafts, media, accounts, validators, clock);
  late final instagram = InstagramService(
    instagramRepo,
    media,
    instagramPackageRoot,
    instagramPolicy,
    ids,
    clock,
  );
  late final attempts = AttemptRepository(database, clock, ids);
  late final publishing = PublishCoordinator(
    attempts: attempts,
    review: review,
    instagram: instagram,
    providers: publishProviders,
    clock: clock,
    directOnline: publishingOnline,
  );
  late final retryEdits = RetryEdits(drafts, attempts, clock);
  final Future<void> Function()? onClose;
  bool pickerRecoveryReady = false;
  Object? pickerRecoveryError;
  PickerImportOperation? recoveredPicker;
  Future<void>? _recovery;

  static Future<AppServices> open() async {
    final support = await getApplicationSupportDirectory();
    final database = await LocalDatabase.open(
      databaseFactory,
      p.join(support.path, 'caption.db'),
    );
    final media = MediaFiles(
      database,
      Directory(p.join(support.path, 'media')),
      const Ids(),
    );
    final configuration = AppConfiguration.fromEnvironment();
    final accounts = LocalAccountRepository(
      database,
      configuration: configuration,
    );
    final client = http.Client();
    final bluesky = BlueskyConnection(
      configuration: configuration,
      vault: const SecureCredentialVault(),
      accounts: accounts,
      driverFactory: (stores) {
        if (!configuration.connection(Destination.bluesky).available) {
          throw const AccountConnectionUnavailable();
        }
        return HostedATProtoOAuthDriver(configuration, stores, client);
      },
      authorizeInBrowser: BlueskyBrowser(configuration).open,
    );
    final x = XConnection(
      configuration: configuration,
      driver: AppAuthXDriver(configuration),
      vault: const SecureCredentialVault(),
      accounts: accounts,
      client: client,
    );
    return AppServices(
      publishingOnline: const PublishingBoundary().online,
      blueskyDevAccepted: configuration.blueskyPostingAccepted,
      publishProviders: {
        Destination.x: XPublisher(
          connection: x,
          client: client,
          media: media,
          counter: const XTextCounter(),
          capabilities: ProviderCapabilities.documented(Destination.x),
        ),
        Destination.bluesky: BlueskyPublisher(
          connection: bluesky,
          media: media,
          capabilities: ProviderCapabilities.documented(
            Destination.bluesky,
            devAccepted: configuration.blueskyPostingAccepted,
          ),
        ),
      },
      connections: {Destination.x: x, Destination.bluesky: bluesky},
      onClose: () async => client.close(),
      // path_provider_android 2.3.1 getApplicationSupportPath returns filesDir.
      // I3 FileProvider must scope files-path to exactly instagram-packages/.
      instagramPackageRoot: Directory(
        p.join(support.path, 'instagram-packages'),
      ),
      database: database,
      media: media,
      drafts: SqliteDraftRepository(database, media: media),
      accounts: accounts,
      clock: const Clock(),
      ids: const Ids(),
    );
  }

  /// Bootstrap must await this; callers check pickerRecoveryReady before begin.
  /// A failed recovery keeps the journal and blocks launches for explicit repair.
  Future<void> recoverPicker(ImagePicker picker) =>
      _recovery ??= _recoverPicker(picker).whenComplete(() => _recovery = null);
  Future<void> _recoverPicker(ImagePicker picker) async {
    pickerRecoveryReady = false;
    pickerRecoveryError = null;
    try {
      recoveredPicker = await pickerImports.recoverLost(picker);
      pickerRecoveryReady = true;
    } catch (error) {
      pickerRecoveryError = error;
      try {
        recoveredPicker = await pickerImports.unresolved();
      } catch (_) {
        /* Keep the original error visible. */
      }
    }
  }

  Future<void> refreshPicker() async {
    recoveredPicker = await pickerImports.unresolved();
  }

  /// Explicit recovery applies only to the journal's saved draft and target.
  /// Unique operation asset IDs recognize save-before-ack restart without duplicates.
  Future<void> attachRecovered(PickerImportOperation requested) async {
    final operation = await pickerImports.unresolved();
    if (operation == null || operation.id != requested.id) {
      throw StateError(
        'This selection has already been resolved. Keep the current draft.',
      );
    }
    if (!operation.isComplete) {
      throw StateError(
        'This selection is incomplete. Discard it and choose again.',
      );
    }
    final draft = await drafts.get(operation.draftId);
    if (draft == null || draft.deletedAt != null) {
      throw StateError(
        'The original draft is unavailable. Keep or discard this selection.',
      );
    }
    final current = resolveContent(
      draft,
      operation.destination ?? Destination.x,
    ).media;
    final target = operation.destination == null ? draft.shared.media : current;
    final imported = operation.assets
        .map((a) => Attachment(assetId: a.id))
        .toList();
    final alreadyAttached =
        draft.revision == operation.draftRevision + 1 &&
        imported.isNotEmpty &&
        target.length >= imported.length &&
        List.generate(target.length - imported.length + 1, (i) => i).any(
          (i) => List.generate(
            imported.length,
            (j) => target[i + j].assetId == imported[j].assetId,
          ).every((v) => v),
        ) &&
        (operation.replacementAssetId == null ||
            !target.any((a) => a.assetId == operation.replacementAssetId));
    if (!alreadyAttached) {
      if (draft.revision != operation.draftRevision) {
        throw StateError(
          'The original draft changed. This selection was kept; discard it and choose again from that draft.',
        );
      }
      final nextMedia = [...target];
      if (operation.replacementAssetId case final replacement?) {
        final index = nextMedia.indexWhere((a) => a.assetId == replacement);
        if (index < 0) {
          throw StateError(
            'The original attachment changed. Keep or discard this selection.',
          );
        }
        nextMedia.replaceRange(index, index + 1, imported);
      } else {
        nextMedia.addAll(imported);
      }
      final next = operation.destination == null
          ? editSharedMedia(draft, nextMedia, clock.now())
          : editOwnMedia(draft, operation.destination!, nextMedia, clock.now());
      await drafts.save(next, expectedRevision: draft.revision);
    }
    await pickerImports.acknowledge(operation.id);
    await refreshPicker();
    pickerRecoveryError = null;
    pickerRecoveryReady = true;
  }

  Future<void> discardRecovered(PickerImportOperation requested) async {
    final operation = await pickerImports.unresolved();
    if (operation == null || operation.id != requested.id) {
      throw StateError('This selection has already been resolved.');
    }
    if (operation.isComplete) {
      await pickerImports.acknowledge(operation.id);
    } else {
      await pickerImports.cancel(operation.id);
    }
    await refreshPicker();
    pickerRecoveryError = null;
    pickerRecoveryReady = true;
  }

  Future<void> close() async {
    await database.close();
    await onClose?.call();
  }
}
