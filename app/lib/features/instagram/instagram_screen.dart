import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../design/caption_scaffold.dart';
import '../../design/caption_tokens.dart';
import '../../design/impression.dart';
import '../../design/post_sheet.dart';
import '../../core/safe_errors.dart';
import 'instagram_package.dart';
import 'android_transfer.dart';
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
  String? _transferMessage;
  bool _copyFailed = false;
  bool _busy = false;
  bool _checkFailed = false;
  bool _checkAfterWork = false;
  int _generation = 0;
  bool _returnQuestion = false;
  bool _chooserReturn = false;
  bool _resumePending = false;
  final _manualFocus = FocusNode(debugLabel: 'Manual Instagram confirmation');
  final _returnFocus = FocusNode(debugLabel: 'Return Instagram confirmation');
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
    _transferMessage = null;
    _copyFailed = false;
    _busy = false;
    _returnQuestion = false;
    _resumePending = false;
    _cachePhotos();
    unawaited(_check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (state == AppLifecycleState.paused) service.onExternalPause(package.id);
    if (state == AppLifecycleState.resumed) {
      _resumePending = true;
      if (_busy) {
        _checkAfterWork = true;
      } else {
        unawaited(_resumeAndCheck());
      }
    }
  }

  Future<void> _resumeAndCheck() async {
    if (_busy || !_resumePending) return;
    _resumePending = false;
    final generation = _generation;
    setState(() => _busy = true);
    try {
      if (await service.onResume(package.id)) {
        final events = await service.repository.events(package.id);
        final progress = await service.repository.progress(package.id);
        final launch = events.lastWhere(
          (e) =>
              e.launchId == progress.activeLaunchId &&
              e.kind != InstagramEventKind.returnAcknowledged,
        );
        // Commit acknowledgment before presenting the question. Relaunch must
        // never ask again for this trip, even if the answer is left undecided.
        await service.acknowledgeReturn(package.id);
        final acknowledged = await service.repository.progress(package.id);
        if (mounted &&
            generation == _generation &&
            acknowledged.activeLaunchId == launch.launchId &&
            acknowledged.promptedLaunchId == launch.launchId &&
            acknowledged.state != InstagramState.userMarked) {
          setState(() {
            _returnQuestion = true;
            _transferMessage = null;
            _chooserReturn = launch.kind == InstagramEventKind.chooserOpened;
          });
        }
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _transferMessage = 'The return question could not be recorded. You can still confirm explicitly below.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        _cachePhotos();
        await _check();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manualFocus.dispose();
    _returnFocus.dispose();
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
    InstagramProgress? recorded;
    try {
      recorded = await service.repository.progress(package.id);
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
          _progress = recorded;
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
      unawaited(_resumePending ? _resumeAndCheck() : _check());
    }
  }

  Future<void> _copy() async {
    if (_busy) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _copyMessage = null;
      _transferMessage = null;
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

  Future<void> _handoff({bool share = false}) async {
    if (_busy) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _transferMessage = null;
      _returnQuestion = false;
    });
    try {
      final message = share
          ? switch (await service.share(package.id)) {
              ShareDispatch.dispatchedToInstagram => 'Photo share requested. Check every photo arrived in order, then finish in Instagram. Publication is not verified.',
              ShareDispatch.chooserOpened => 'Share chooser opened. Selecting a target does not confirm that Instagram received your photos. You can still save photos below.',
              ShareDispatch.cancelled =>
                'Share cancelled. Your prepared photos and caption are kept.',
              ShareDispatch.unavailable => 'Photo sharing is unavailable. Save photos, copy your caption and select the photos inside Instagram.',
              ShareDispatch.failed => 'Photos could not be sent. Save photos and select them inside Instagram.',
            }
          : switch (await service.open(package.id)) {
              LaunchResult.opened => 'Instagram opened. Finish your post there. Publication is not verified.',
              LaunchResult.unavailable => 'Open Instagram yourself. Start it from your device, select the saved photos in order and paste your caption. Your prepared package is kept here.',
              LaunchResult.failed => 'Instagram could not be opened. Open it yourself from your device and use your saved photos and copied caption.',
            };
      final progress = await service.repository.progress(package.id);
      if (mounted && generation == _generation) {
        setState(() {
          _transferMessage = message;
          _progress = progress;
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _transferMessage = error is InstagramPreparationException
              ? error.toString()
              : 'Instagram activity could not be recorded. Check Instagram before trying again. Your prepared photos and caption are kept.';
        });
      }
    } finally {
      _finish(generation);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            generation == _generation &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          service.discardUnobservedTrip(package.id);
        }
      });
    }
  }

  Future<void> _confirm(FocusNode initiator) async {
    if (_busy) return;
    final generation = _generation;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Mark Instagram as posted?'),
          content: const Text(
            "This records your confirmation on this phone. The app can't verify that the post is live.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mark as posted'),
            ),
          ],
        ),
      );
      if (!mounted || generation != _generation) return;
      if (confirmed == true) {
        await service.markPosted(package.id);
        final progress = await service.repository.progress(package.id);
        if (!mounted || generation != _generation) return;
        setState(() {
          _progress = progress;
          _returnQuestion = false;
          _transferMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Instagram marked as posted.'),
            persist: false,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => unawaited(_undo()),
            ),
          ),
        );
      } else {
        // Re-enable the initiating button before requesting its focus.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && generation == _generation) initiator.requestFocus();
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _transferMessage = 'Your confirmation could not be recorded. Keep this package and try again.',
        );
      }
    } finally {
      _finish(generation);
    }
  }

  Future<void> _undo() async {
    if (_busy) return;
    final generation = _generation;
    setState(() => _busy = true);
    try {
      await service.undoMarked(package.id);
      final progress = await service.repository.progress(package.id);
      if (mounted && generation == _generation) {
        setState(() => _progress = progress);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Confirmation undone. Only this phone's record changed.",
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _transferMessage = 'Your confirmation could not be undone. Keep this package and try again.',
        );
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
    final marked = _progress?.state == InstagramState.userMarked;
    final handedOff = _progress?.state == InstagramState.handedOff;
    final returned =
        _returnQuestion ||
        (_progress?.activeLaunchId != null &&
            _progress?.activeLaunchId == _progress?.promptedLaunchId);
    final confirmedAt = _progress?.confirmedAt?.toLocal();
    final localTime = confirmedAt == null
        ? ''
        : MaterialLocalizations.of(context)
              .formatTimeOfDay(TimeOfDay.fromDateTime(confirmedAt));
    final decodePixels = (220 * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(1, 1200);
    return CaptionScaffold(
      title: marked ? 'Instagram record' : 'Finish in Instagram',
      bodyPadding: EdgeInsets.zero,
      primaryAction: FilledButton(
        focusNode: _returnQuestion ? _returnFocus : null,
        onPressed: _busy || (!_checkFailed && _progress == null)
            ? null
            : marked
            ? () => Navigator.maybePop(context)
            : _returnQuestion
            ? () => _confirm(_returnFocus)
            : _checkFailed
            ? _check
            : remaining == 0
            ? () => _handoff()
            : _save,
        child: Text(
          _busy
              ? 'Working…'
              : marked
              ? 'Done'
              : _returnQuestion
              ? "I've posted it"
              : remaining == 0 && !_checkFailed
              ? 'Open Instagram'
              : saveLabel,
        ),
      ),
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CaptionTokens.of(context).hairline),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // One ordered gallery, available by horizontal scroll at every count.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final photo in package.photos)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: SizedBox(
                              width: 170,
                              child: Stack(
                                children: [
                                  _photo(photo, decodePixels),
                                  Positioned(
                                    left: 8,
                                    bottom: 8,
                                    child: ExcludeSemantics(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: CaptionTokens.of(context)
                                              .sheet,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 3,
                                          ),
                                          child: Text(
                                            '${photo.ordinal}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ImpressionMark(
                      label: marked
                          ? 'Marked posted'
                          : handedOff
                          ? (returned
                                ? 'Status: still Handed off'
                                : 'Handed off')
                          : (returned
                                ? 'Status: still Ready to share'
                                : 'Ready to share'),
                      tone: marked
                          ? ImpressionTone.user
                          : ImpressionTone.waiting,
                      icon: handedOff && !marked ? Icons.arrow_forward : null,
                      time: marked && localTime.isNotEmpty ? localTime : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (marked) ...[
                    const Text(
                      "Your confirmation, not verified by the app. Undo changes only this phone's record.",
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: _busy ? null : _undo,
                        child: const Text('Undo my confirmation'),
                      ),
                    ),
                  ] else if (_returnQuestion) ...[
                    Text(
                      _chooserReturn
                          ? 'Back to your post'
                          : 'Back from Instagram. Did you finish posting?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "This app can't see Instagram. Your answer is the record.",
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _returnQuestion = false),
                      child: const Text('Not yet'),
                    ),
                  ],
                  if (_transferMessage != null) ...[
                    const SizedBox(height: 12),
                    Semantics(liveRegion: true, child: Text(_transferMessage!)),
                  ],
                ],
              ),
            ),
          ),
          _steps(
            marked,
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      '1  Save photos in order',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_checkFailed)
                    const Text('Saved photo check unavailable')
                  else if (_progress != null)
                    Text('$saved of ${package.photos.length} saved')
                  else if (!_checkFailed)
                    const Text('Checking saved photos…'),
                  const SizedBox(height: 8),
                  const Text(
                    'Saved to Pictures/CrossPosting. Pick them in this numbered order; your gallery may sort them differently.',
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(liveRegion: true, child: Text(_error!)),
                    ),
                  if (marked || _returnQuestion || remaining == 0) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : _checkFailed
                          ? _check
                          : remaining == 0
                          ? null
                          : _save,
                      child: Text(saveLabel),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(
                      '2  Copy the caption',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CaptionSourceLabel(own: package.ownCaption),
                  const SizedBox(height: 8),
                  if (package.caption.isEmpty)
                    const Text('No caption')
                  else
                    SelectableText(
                      package.caption,
                      style: TextStyle(
                        fontFamily: textFace,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                        color: package.ownCaption
                            ? CaptionTokens.of(context).own
                            : CaptionTokens.of(context).text,
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
                      child: Semantics(
                        liveRegion: true,
                        child: Text(_copyMessage!),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(
                      '3  Post it in Instagram',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'New feed post, photos in order, paste the caption, check the account, publish.',
                  ),
                  if (remaining > 0 ||
                      _checkFailed ||
                      marked ||
                      _returnQuestion) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _handoff(),
                      child: const Text('Open Instagram'),
                    ),
                  ],
                  if (service.shareCapability.supports(
                    package.photos.length,
                  )) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _handoff(share: true),
                      child: const Text('Send photos to Instagram'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Sending photos doesn't include the caption; copy it first.",
                    ),
                  ],
                  if (!marked && !_returnQuestion)
                    TextButton(
                      focusNode: _manualFocus,
                      onPressed: _busy || _progress == null
                          ? null
                          : () => _confirm(_manualFocus),
                      child: const Text("I've posted it"),
                    ),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(
                      'Photo descriptions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Saved photos don't carry descriptions; add them in Instagram.",
                  ),
                  for (final photo in package.photos) ...[
                    const SizedBox(height: 16),
                    Text('Photo ${photo.ordinal} description'),
                    SelectableText(
                      photo.altText.isEmpty ? 'No description' : photo.altText,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Once marked, the how-to steps fold under one disclosure: the record is
  /// the mark, the attribution and Undo. Save and copy stay inside.
  Widget _steps(bool marked, Widget steps) => marked
      ? Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: const Text('How this was prepared'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: EdgeInsets.zero,
            children: [steps],
          ),
        )
      : steps;

  Widget _photo(PreparedPhoto photo, int decodePixels) => FutureBuilder<File>(
    future: _files[photo.ordinal],
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(switch (snapshot.error) {
              InstagramPreparationException(:final message) => message,
              _ => userSafeMessage('unknown'),
            }),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(
                      () => _files[photo.ordinal] = service.fileFor(
                        package,
                        photo,
                      ),
                    ),
              child: const Text('Retry photo check'),
            ),
          ],
        );
      }
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 110,
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
        height: 110,
        fit: BoxFit.cover,
        semanticLabel:
            'Photo ${photo.ordinal} of ${package.photos.length}. ${photo.altText.isEmpty ? 'No description' : photo.altText}',
        errorBuilder: (_, _, _) => Text(
          'Prepared photo ${photo.ordinal} could not be displayed. Keep this package and check storage.',
        ),
      );
    },
  );
}
