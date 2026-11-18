import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../design/caption_scaffold.dart';
import '../../design/caption_tokens.dart';
import '../../storage/media_files.dart';
import '../drafts/draft.dart';

/// A focused original/result preview; transforms create a new owned file only
/// after confirmation. Source files and their other attachment versions stay put.
class PhotoTransformScreen extends StatefulWidget {
  const PhotoTransformScreen({
    super.key,
    required this.attachment,
    required this.media,
    required this.crop,
  });
  final Attachment attachment;
  final MediaFiles media;
  final bool crop;
  @override
  State<PhotoTransformScreen> createState() => _PhotoTransformScreenState();
}

class _PhotoTransformScreenState extends State<PhotoTransformScreen> {
  MediaAsset? _asset;
  File? _file;
  String? _error;
  bool _busy = false;
  double _ratio = 1;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final asset = await widget.media.find(widget.attachment.assetId);
      if (asset == null || !asset.mimeType.startsWith('image/')) {
        throw const MediaFileException(
          'Video crop and rotation are unsupported. Keep the original video or replace it.',
        );
      }
      final file = await widget.media.fileFor(asset.id);
      if (mounted) {
        setState(() {
          _asset = asset;
          _file = file;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error) {
            MediaFileException(:final message) => message,
            _ => 'The photo edit could not finish. Your original photo is unchanged. Try again.',
          },
        );
      }
    }
  }

  Rect _crop(MediaAsset asset) {
    final width = math.max(
      1,
      math.min(asset.width, (asset.height * _ratio).floor()),
    );
    final height = math.max(
      1,
      math.min(asset.height, (width / _ratio).floor()),
    );
    return Rect.fromLTWH(
      ((asset.width - width) / 2).floorToDouble(),
      ((asset.height - height) / 2).floorToDouble(),
      width.toDouble(),
      height.toDouble(),
    );
  }

  Future<void> _save() async {
    if (_busy || _asset == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.media.transform(
        widget.attachment.assetId,
        quarterTurns: widget.crop ? 0 : 1,
        cropPixels: widget.crop ? _crop(_asset!) : null,
      );
      await widget.media.fileFor(result.id);
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error) {
            MediaFileException(:final message) => message,
            _ => 'The photo edit could not finish. Your original photo is unchanged. Try again.',
          },
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: CaptionScaffold(
      title: widget.crop ? 'Crop photo' : 'Rotate photo',
      actions: [
        IconButton(
          tooltip: 'Cancel edit',
          onPressed: _busy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
      primaryAction: FilledButton(
        onPressed: _busy || _asset == null ? null : _save,
        child: Text(
          _busy
              ? 'Saving photo…'
              : widget.crop
              ? 'Save crop'
              : 'Save rotation',
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: CaptionTokens.of(context).error),
            ),
          if (_file != null) ...[
            const Text('Original'),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: Image.file(_file!, fit: BoxFit.contain, cacheWidth: 1080),
            ),
            const SizedBox(height: 24),
            const Text('Result preview'),
            const SizedBox(height: 8),
            if (widget.crop) ...[
              AspectRatio(
                aspectRatio: _crop(_asset!).width / _crop(_asset!).height,
                child: Image.file(_file!, fit: BoxFit.cover, cacheWidth: 1080),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in <String, double>{
                    'Square': 1,
                    'Portrait 4:5': 4 / 5,
                    'Landscape 16:9': 16 / 9,
                  }.entries)
                    ChoiceChip(
                      label: Text(option.key),
                      selected: _ratio == option.value,
                      onSelected: _busy
                          ? null
                          : (_) => setState(() => _ratio = option.value),
                    ),
                ],
              ),
              Text(
                'Centered crop · ${_crop(_asset!).width.toInt()} × ${_crop(_asset!).height.toInt()} pixels',
              ),
            ] else ...[
              SizedBox(
                height: 240,
                child: RotatedBox(
                  quarterTurns: 1,
                  child: Image.file(
                    _file!,
                    fit: BoxFit.contain,
                    cacheWidth: 1080,
                  ),
                ),
              ),
              const Text('Rotate 90° clockwise'),
            ],
            const SizedBox(height: 16),
            const Text(
              'Your original photo stays unchanged. This version gets a new copy.',
            ),
          ] else if (_error == null)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    ),
  );
}
