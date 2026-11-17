import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../design/caption_scaffold.dart';
import '../../design/caption_text.dart';
import '../../design/caption_tokens.dart';
import 'instagram_package.dart';
import 'instagram_service.dart';

/// I1's real, read-only snapshot. I2/I4 add checked save/copy/activity controls.
class InstagramScreen extends StatelessWidget {
  const InstagramScreen({
    super.key,
    required this.package,
    required this.service,
  });
  final InstagramPackage package;
  final InstagramService service;

  @override
  Widget build(BuildContext context) => CaptionScaffold(
    title: 'Finish in Instagram',
    actions: [
      IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back),
      ),
    ],
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CaptionText('Prepared on this device'),
        const SizedBox(height: 12),
        const Text(
          'Your reviewed caption, photo order and descriptions are kept below. You select and check the photos, choose the account and finish in Instagram. This app cannot verify publication.',
        ),
        const SizedBox(height: 12),
        const Text(
          'This view is read-only. Gallery saving, caption copying and optional handoff are not available here yet.',
          style: TextStyle(color: CaptionTokens.secondary),
        ),
        const SizedBox(height: 24),
        Text(
          package.ownCaption ? 'Own caption' : 'Shared caption',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (package.caption.isEmpty)
          const Text('No caption')
        else
          ColoredBox(
            color: CaptionTokens.raised,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                package.caption,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: package.ownCaption
                      ? CaptionTokens.own
                      : CaptionTokens.text,
                  backgroundColor: CaptionTokens.stage,
                ),
              ),
            ),
          ),
        for (final photo in package.photos) ...[
          const Divider(height: 40),
          Text(
            'Photo ${photo.ordinal} of ${package.photos.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          FutureBuilder<File>(
            future: service.fileFor(package, photo),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('${snapshot.error}');
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 160,
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Checking prepared photo',
                    ),
                  ),
                );
              }
              return Image.file(
                snapshot.data!,
                height: 220,
                fit: BoxFit.contain,
                semanticLabel: photo.altText.isEmpty
                    ? 'Prepared photo ${photo.ordinal}'
                    : photo.altText,
                errorBuilder: (_, _, _) => Text(
                  'Prepared photo ${photo.ordinal} could not be displayed. Keep this package and check storage.',
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          SelectableText(
            photo.altText.isEmpty ? 'No description' : photo.altText,
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Prepared versions stay on this device independently of the source draft. Uninstalling the app removes them.',
          style: TextStyle(color: CaptionTokens.secondary),
        ),
      ],
    ),
  );
}
