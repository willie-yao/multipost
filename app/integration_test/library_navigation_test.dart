import 'dart:io';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/app/services.dart';
import 'package:cross_posting_app/core/clock.dart';
import 'package:cross_posting_app/core/ids.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/features/library/library_screen.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native local library creates a durable unconnected draft', (
    tester,
  ) async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'l5-native-test'));
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    await root.create(recursive: true);
    final database = await LocalDatabase.open(
      databaseFactory,
      p.join(root.path, 'test.db'),
    );
    final media = MediaFiles(
      database,
      Directory(p.join(root.path, 'media')),
      const Ids(),
    );
    final services = AppServices(
      database: database,
      media: media,
      drafts: SqliteDraftRepository(database, media: media),
      accounts: LocalAccountRepository(database),
      clock: const Clock(),
      ids: const Ids(),
    );
    try {
      await services.recoverPicker(ImagePicker());
      expect(services.pickerRecoveryReady, isTrue);
      await tester.pumpWidget(
        CaptionApp(home: LibraryScreen(services: services)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your next post starts here.'), findsOneWidget);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await File(p.join(support.path, 'l5-first-run.png'))
          .writeAsBytes(await binding.takeScreenshot('l5-first-run'));
      await tester.ensureVisible(find.text('Create a draft'));
      await tester.tap(find.text('Create a draft'));
      await tester.pumpAndSettle();
      expect(find.text('Where should this go?'), findsOneWidget);
      expect((await services.drafts.list()).single.selected, isEmpty);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Continue to writing'),
            )
            .onPressed,
        isNull,
      );
      await File(p.join(support.path, 'l5-choose.png'))
          .writeAsBytes(await binding.takeScreenshot('l5-choose'));
      await tester.ensureVisible(
        find.byKey(const ValueKey('choose-instagram')),
      );
      await tester.tap(find.byKey(const ValueKey('choose-instagram')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to writing'));
      await tester.pumpAndSettle();
      final draft = (await services.drafts.list()).single;
      expect(draft.stage, ComposeStage.write);
      expect(draft.selected, {Destination.instagram});
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      await services.close();
      await root.delete(recursive: true);
    }
  });
}
