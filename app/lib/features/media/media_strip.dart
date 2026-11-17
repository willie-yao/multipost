import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../design/caption_tokens.dart';
import '../../storage/media_files.dart';
import '../drafts/draft.dart';

/// Ordered owned-media previews, shared by the composer and destination editor.
class MediaStrip extends StatelessWidget {
  const MediaStrip({
    super.key,
    required this.items,
    required this.media,
    this.onEdit,
  });
  final List<Attachment> items;
  final MediaFiles media;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var index = 0; index < items.length; index++)
          Padding(
            padding: EdgeInsets.only(right: index == items.length - 1 ? 0 : 8),
            child: SizedBox(
              width: 174,
              height: 108,
              child: Semantics(
                label:
                    'Media ${index + 1}${items[index].altText.isEmpty ? ', no description' : ', ${items[index].altText}'}',
                button: onEdit != null,
                child: InkWell(
                  onTap: onEdit,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MediaPreview(
                        key: ValueKey(items[index].assetId),
                        attachment: items[index],
                        media: media,
                      ),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: ColoredBox(
                          color: CaptionTokens.stage,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class MediaPreview extends StatefulWidget {
  const MediaPreview({
    super.key,
    required this.attachment,
    required this.media,
  });
  final Attachment attachment;
  final MediaFiles media;
  @override
  State<MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<MediaPreview> {
  late Future<(MediaAsset, File)> _source;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.assetId != widget.attachment.assetId ||
        oldWidget.media != widget.media) {
      _load();
    }
  }

  void _load() {
    _source = () async {
      final asset = await widget.media.find(widget.attachment.assetId);
      if (asset == null) throw const MediaFileException('Media missing');
      return (asset, await widget.media.fileFor(asset.id));
    }();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(MediaAsset, File)>(
    future: _source,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const ColoredBox(
          color: CaptionTokens.raised,
          child: Center(child: Text('Media unavailable')),
        );
      }
      final source = snapshot.data;
      if (source == null) {
        return const ColoredBox(
          color: CaptionTokens.raised,
          child: Center(child: Icon(Icons.image_outlined)),
        );
      }
      if (!source.$1.mimeType.startsWith('image/')) {
        return const ColoredBox(
          color: CaptionTokens.raised,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.videocam_outlined), Text('Video')],
            ),
          ),
        );
      }
      return Image.file(
        source.$2,
        fit: BoxFit.cover,
        cacheWidth: 720,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) =>
            const Center(child: Text('Preview unavailable')),
      );
    },
  );
}
