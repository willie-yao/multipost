import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../design/caption_scaffold.dart';
import '../../design/caption_text.dart';
import '../../design/caption_tokens.dart';
import 'instagram_package.dart';
import 'instagram_service.dart';

/// Frozen snapshot with explicit local copy/save actions; resume never exports.
class InstagramScreen extends StatefulWidget {
  const InstagramScreen({
    super.key,
    required this.package,
    required this.service,
  });
  final InstagramPackage package;
  final InstagramService service;

  @override
  State<InstagramScreen> createState() => _InstagramScreenState();
}

class _InstagramScreenState extends State<InstagramScreen>
    with WidgetsBindingObserver {
  Map<int, Future<File>> _files = {};
  InstagramProgress? _progress;
  String? _error;
  String? _copyMessage;
  bool _copyFailed = false;
  bool _busy = false;
  bool _checkFailed = false;
  bool _checkAfterWork = false;
  int _generation = 0;
  InstagramPackage get package => widget.package;
  InstagramService get service => widget.service;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reset();
  }

  @override
  void didUpdateWidget(InstagramScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.package != package || oldWidget.service != service) _reset();
  }

  void _cachePhotos() {
    _files = {
      for (final photo in package.photos)
        photo.ordinal: service.fileFor(package, photo),
    };
    // FutureBuilder attaches in build; handle an early error until then as well.
    for (final future in _files.values) {
      unawaited(
        future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
    }
  }

  void _reset() {
    _generation++;
    _progress = null;
    _copyMessage = null;
    _copyFailed = false;
    _busy = false;
    _cachePhotos();
    unawaited(_check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_busy) {
        _checkAfterWork = true;
      } else {
        _cachePhotos();
        unawaited(_check());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _check() async {
    if (_busy) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
      _checkFailed = false;
    });
    try {
      final progress = await service.recheckSavedPhotos(package.id);
      final events = await service.repository.activity(package.id);
      if (mounted && generation == _generation) {
        setState(() {
          _progress = progress;
          if (_copyMessage == null &&
              events.any((e) => e.kind == InstagramEventKind.captionCopied)) {
            _copyMessage = 'Caption copied previously on this device';
          }
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _progress = null;
          _checkFailed = true;
          _error = 'Saved photos could not be checked. Keep this package and retry checking.';
        });
      }
    } finally {
      _finish(generation);
    }
  }

  void _finish(int generation) {
    if (!mounted || generation != _generation) return;
    setState(() => _busy = false);
    if (_checkAfterWork) {
      _checkAfterWork = false;
      _cachePhotos();
      unawaited(_check());
    }
  }

  Future<void> _copy() async {
    if (_busy) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _copyMessage = null;
    });
    try {
      await service.copyCaption(package.id);
      if (mounted && generation == _generation) {
        setState(() {
          _copyMessage = 'Caption copied';
          _copyFailed = false;
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _copyFailed = true;
          _copyMessage = error is CaptionCopyException ? error.toString() : 'Caption could not be copied. Select the full caption below or retry copy.';
        });
      }
    } finally {
      _finish(generation);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await service.saveMissingPhotos(package.id);
      final progress = await service.repository.progress(package.id);
      if (mounted && generation == _generation) {
        setState(() {
          _progress = progress;
          if (results.any((r) => !r.succeeded)) _error = 'Some photos could not be saved. Check storage and retry the remaining photos. Your private copies are kept.';
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _progress = null;
          _checkFailed = true;
          _error = 'Photo save activity could not be verified. Keep this package and retry checking before saving again.';
        });
      }
    } finally {
      _finish(generation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = _progress?.savedUris.length ?? 0;
    final remaining = package.photos.length - saved;
    final saveLabel = _checkFailed
        ? 'Retry checking photos'
        : remaining == 0
        ? 'Photos saved'
        : saved == 0
        ? 'Save photos'
        : remaining == 1
        ? 'Retry remaining photo'
        : 'Retry remaining $remaining photos';
    final decodePixels = (220 * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(1, 1200);
    return CaptionScaffold(
      title: 'Finish in Instagram',
      primaryAction: FilledButton(
        onPressed:
            _busy || (!_checkFailed && (_progress == null || remaining == 0))
            ? null
            : _checkFailed
            ? _check
            : _save,
        child: Text(_busy ? 'Working…' : saveLabel),
      ),
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
          const SizedBox(height: 20),
          if (_progress != null)
            Semantics(
              liveRegion: true,
              child: Text(
                '$saved of ${package.photos.length} saved',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            )
          else if (!_checkFailed)
            const Text('Checking saved photos…'),
          const SizedBox(height: 8),
          const Text(
            'Gallery destination: Pictures/CrossPosting. Check the numbered photos below and select them in this order; your gallery may sort them differently.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(_error!)),
          ],
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
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _copy,
            child: Text(_copyFailed ? 'Retry copy' : 'Copy caption'),
          ),
          if (_copyMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(liveRegion: true, child: Text(_copyMessage!)),
            ),
          const SizedBox(height: 16),
          const Text(
            'Descriptions stay selectable here; enter them inside Instagram if needed. Saving photos does not transfer these descriptions.',
          ),
          for (final photo in package.photos) ...[
            const Divider(height: 40),
            Text(
              'Photo ${photo.ordinal} of ${package.photos.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FutureBuilder<File>(
              future: _files[photo.ordinal],
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${snapshot.error}'),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _files[photo.ordinal] = service.fileFor(
                                  package,
                                  photo,
                                );
                              }),
                        child: const Text('Retry photo check'),
                      ),
                    ],
                  );
                }
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
                return Image(
                  image: ResizeImage(
                    FileImage(snapshot.data!),
                    width: decodePixels,
                    height: decodePixels,
                    policy: ResizeImagePolicy.fit,
                  ),
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
}
