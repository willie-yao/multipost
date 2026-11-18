import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/caption_scaffold.dart';
import '../../design/caption_tokens.dart';
import '../../storage/media_files.dart';
import '../compose/draft_session.dart';
import '../drafts/draft.dart';
import '../drafts/draft_controller.dart';
import '../drafts/draft_editor.dart';
import 'draft_media_picker.dart';
import 'media_strip.dart';
import 'photo_transform_screen.dart';
import 'picker_imports.dart';

class MediaEditorScreen extends StatefulWidget {
  const MediaEditorScreen({
    super.key,
    required this.items,
    required this.media,
    required this.onChanged,
    required this.controller,
    required this.pickerImports,
    required this.canLaunchPicker,
    this.destination,
  });
  final List<Attachment> items;
  final MediaFiles media;
  final ValueChanged<List<Attachment>> onChanged;
  final DraftController controller;
  final PickerImports pickerImports;
  final bool canLaunchPicker;
  final Destination? destination;
  @override
  State<MediaEditorScreen> createState() => _MediaEditorScreenState();
}

class _MediaEditorScreenState extends State<MediaEditorScreen> {
  late List<Attachment> _items;
  bool _busy = false;
  bool _exitPending = false;
  bool get _blocked => _busy || _exitPending;
  String? _error;
  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
    widget.controller.addListener(_changed);
  }

  List<Attachment> get _current => widget.destination == null
      ? widget.controller.draft.shared.media
      : resolveContent(widget.controller.draft, widget.destination!).media;
  void _changed() {
    if (mounted) setState(() => _items = List.of(_current));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _commit(List<Attachment> next) {
    widget.onChanged(List.unmodifiable(next));
    setState(() {
      _items = List.of(next);
      _error = null;
    });
  }

  Future<void> _pick([String? replacement]) async {
    if (_blocked) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await pickDraftMedia(
        controller: widget.controller,
        media: widget.media,
        pickerImports: widget.pickerImports,
        canLaunchPicker: widget.canLaunchPicker,
        destination: widget.destination,
        replacementAssetId: replacement,
      );
      if (mounted && !saved) {
        setState(
          () => _error = 'Media could not be attached. Keep this editor open to repair or retry saving. Pending selections can be recovered in Your posts.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error) {
            MediaFileException(:final message) => message,
            _ => 'The media action could not finish. Keep this editor open and retry or replace the item.',
          },
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _describe(int index) async {
    if (_blocked) return;
    final previous = _items[index];
    final text = TextEditingController(text: previous.altText);
    setState(() => _busy = true);
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Describe media ${index + 1}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Describe what matters for someone who cannot see it.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: text,
                  autofocus: true,
                  minLines: 3,
                  maxLines: null,
                  decoration: const InputDecoration(
                    labelText: 'Media description',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, text.text),
              child: const Text('Save description'),
            ),
          ],
        ),
      );
      if (result != null &&
          mounted &&
          index < _items.length &&
          _items[index] == previous) {
        final next = [..._items];
        next[index] = previous.copyWith(altText: result);
        _commit(next);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => text.dispose());
    }
  }

  void _move(int index, int delta) {
    if (_blocked || index + delta < 0 || index + delta >= _items.length) return;
    final next = [..._items];
    final item = next.removeAt(index);
    next.insert(index + delta, item);
    _commit(next);
  }

  /// Removing is immediate, so it offers Undo while nothing else changed.
  void _remove(int index) {
    if (_blocked || index < 0 || index >= _items.length) return;
    final before = List.of(_items);
    final after = [..._items]..removeAt(index);
    _commit(after);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Removed media ${index + 1}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted || _blocked || !listEquals(_items, after)) return;
            _commit(before);
          },
        ),
      ),
    );
  }

  Future<void> _transform(int index, {required bool crop}) async {
    if (_blocked) return;
    final previous = _items[index];
    final originalItems = List.of(_items);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await widget.controller.flush() || !mounted) return;
      final result = await Navigator.of(context).push<MediaAsset>(
        MaterialPageRoute(
          builder: (_) => PhotoTransformScreen(
            attachment: previous,
            media: widget.media,
            crop: crop,
          ),
        ),
      );
      if (result != null && mounted) {
        await widget.media.fileFor(result.id);
        if (!listEquals(_items, originalItems)) {
          throw const MediaFileException(
            'The media changed while editing. Your original attachments are kept.',
          );
        }
        final next = [..._items];
        next[index] = previous.copyWith(assetId: result.id);
        _commit(next);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error) {
            MediaFileException(:final message) => message,
            _ => 'The media action could not finish. Keep this editor open and retry or replace the item.',
          },
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => DraftSession(
    controller: widget.controller,
    allowMediaRepairReturn: true,
    exitBlocked: _busy,
    onExitPendingChanged: (value) {
      if (mounted) setState(() => _exitPending = value);
    },
    child: AbsorbPointer(
      absorbing: _blocked,
      child: CaptionScaffold(
        title: widget.destination == Destination.instagram
            ? 'Instagram photos'
            : 'Edit media',
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _blocked ? null : () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        primaryAction: FilledButton(
          onPressed: _blocked ? null : () => Navigator.maybePop(context),
          child: const Text('Done'),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DraftSaveStatus(controller: widget.controller),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: CaptionTokens.of(context).error),
                ),
              ),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No media in this version yet.'),
              ),
            for (var index = 0; index < _items.length; index++) ...[
              const SizedBox(height: 24),
              Text(
                'Media ${index + 1}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: MediaPreview(
                  key: ValueKey(_items[index].assetId),
                  attachment: _items[index],
                  media: widget.media,
                ),
              ),
              if (_items[index].altText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_items[index].altText),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton(
                    onPressed: _blocked ? null : () => _describe(index),
                    child: Text(
                      _items[index].altText.isEmpty
                          ? 'Add description'
                          : 'Edit description',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Move media ${index + 1} earlier',
                    onPressed: _blocked || index == 0
                        ? null
                        : () => _move(index, -1),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: 'Move media ${index + 1} later',
                    onPressed: _blocked || index == _items.length - 1
                        ? null
                        : () => _move(index, 1),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More for media ${index + 1}',
                    enabled: !_blocked,
                    icon: const Icon(Icons.more_vert),
                    onSelected: (choice) => switch (choice) {
                      'replace' => _pick(_items[index].assetId),
                      'rotate' => _transform(index, crop: false),
                      _ => _transform(index, crop: true),
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'replace',
                        enabled: widget.canLaunchPicker,
                        child: const Text('Replace'),
                      ),
                      const PopupMenuItem(
                        value: 'rotate',
                        child: Text('Rotate'),
                      ),
                      const PopupMenuItem(value: 'crop', child: Text('Crop')),
                    ],
                  ),
                  TextButton(
                    onPressed: _blocked ? null : () => _remove(index),
                    child: const Text('Remove'),
                  ),
                ],
              ),
              const Divider(),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _blocked || !widget.canLaunchPicker
                  ? null
                  : () => _pick(),
              icon: const Icon(Icons.add),
              label: Text(
                widget.destination == Destination.instagram
                    ? 'Add photos'
                    : 'Add media',
              ),
            ),
            if (!widget.canLaunchPicker)
              const Text(
                'Return to Your posts to resolve media recovery before choosing more media.',
              ),
          ],
        ),
      ),
    ),
  );
}
