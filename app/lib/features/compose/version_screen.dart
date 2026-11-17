import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';

import '../../design/caption_scaffold.dart';
import '../../design/caption_text.dart';
import '../../design/caption_tokens.dart';
import '../../storage/media_files.dart';
import '../accounts/account.dart';
import '../drafts/draft.dart';
import '../drafts/draft_controller.dart';
import '../drafts/draft_editor.dart';
import '../media/picker_imports.dart';
import '../media/draft_media_picker.dart';
import '../media/media_editor_screen.dart';
import '../media/media_strip.dart';
import 'draft_session.dart';

class VersionScreen extends StatefulWidget {
  const VersionScreen({
    super.key,
    required this.controller,
    required this.destination,
    required this.media,
    required this.pickerImports,
    required this.canLaunchPicker,
  });
  final DraftController controller;
  final Destination destination;
  final MediaFiles media;
  final PickerImports pickerImports;
  final bool canLaunchPicker;
  @override
  State<VersionScreen> createState() => _VersionScreenState();
}

class _VersionScreenState extends State<VersionScreen> {
  late final TextEditingController _text;
  DestinationVersion? _captionUndo;
  DestinationVersion? _mediaUndo;
  bool _busy = false;
  bool _exitPending = false;
  bool _pickerFailed = false;
  Object? _mediaError;
  bool get _blocked => _busy || _exitPending;
  Draft get _draft => widget.controller.draft;
  DestinationVersion get _version =>
      _draft.versions[widget.destination] ?? DestinationVersion();
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
      text: resolveContent(_draft, widget.destination).text,
    );
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (_version.ownText != null) _captionUndo = null;
    if (_version.ownMedia != null) _mediaUndo = null;
    syncCaptionText(_text, resolveContent(_draft, widget.destination).text);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _text.dispose();
    super.dispose();
  }

  void _ownCaption() {
    if (_blocked || _version.ownText != null) return;
    _captionUndo = null;
    widget.controller.change(
      editOwnCaption(
        _draft,
        widget.destination,
        _draft.shared.text,
        DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _resetCaption() async {
    if (_blocked || _version.ownText == null) return;
    final previous = _version;
    setState(() => _busy = true);
    FocusScope.of(context).unfocus();
    try {
      if (previous.ownText != _draft.shared.text) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: const Text('Use the shared caption?'),
            content: const Text(
              'Your own caption will be replaced. You can undo this until you edit this caption again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep own caption'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Use shared caption'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      if (_version.ownText != previous.ownText ||
          _version.baseTextRevision != previous.baseTextRevision) {
        return;
      }
      widget.controller.change(
        restoreSharedCaption(
          _draft,
          widget.destination,
          DateTime.now().toUtc(),
        ),
      );
      setState(() => _captionUndo = previous);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _undoCaption() {
    final previous = _captionUndo;
    if (_blocked || previous == null || _version.ownText != null) return;
    _captionUndo = null;
    widget.controller.change(
      restoreVersion(
        _draft,
        widget.destination,
        _version.copyWith(
          ownText: previous.ownText,
          baseTextRevision: previous.baseTextRevision,
        ),
        DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _toggleMedia(bool shared) async {
    if (_blocked) return;
    if (!shared) {
      _mediaUndo = null;
      widget.controller.change(
        editOwnMedia(
          _draft,
          widget.destination,
          _draft.shared.media,
          DateTime.now().toUtc(),
        ),
      );
      return;
    }
    final previous = _version;
    if (previous.ownMedia == null) return;
    setState(() => _busy = true);
    try {
      if (!listEquals(previous.ownMedia, _draft.shared.media)) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: const Text('Use the shared photos?'),
            content: const Text(
              'Your destination media and descriptions will be replaced. You can undo this until you edit this media again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep own media'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Use shared photos'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      if (_version.ownMedia != previous.ownMedia ||
          _version.baseMediaRevision != previous.baseMediaRevision) {
        return;
      }
      widget.controller.change(
        restoreSharedMedia(_draft, widget.destination, DateTime.now().toUtc()),
      );
      setState(() => _mediaUndo = previous);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _undoMedia() {
    final previous = _mediaUndo;
    if (_blocked || previous == null || _version.ownMedia != null) return;
    _mediaUndo = null;
    widget.controller.change(
      restoreVersion(
        _draft,
        widget.destination,
        _version.copyWith(
          ownMedia: previous.ownMedia,
          baseMediaRevision: previous.baseMediaRevision,
        ),
        DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _compare() async {
    if (_blocked) return;
    setState(() => _busy = true);
    FocusScope.of(context).unfocus();
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Compare captions'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Shared caption'),
                SelectableText(_draft.shared.text),
                const SizedBox(height: 24),
                Text('${destinationName(widget.destination)} own caption'),
                SelectableText(
                  _version.ownText ?? _draft.shared.text,
                  style: const TextStyle(color: CaptionTokens.own),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close comparison'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickMedia() async {
    if (_blocked || _pickerFailed || _version.ownMedia == null) return;
    setState(() {
      _busy = true;
      _mediaError = null;
    });
    FocusScope.of(context).unfocus();
    try {
      final saved = await pickDraftMedia(
        controller: widget.controller,
        media: widget.media,
        pickerImports: widget.pickerImports,
        canLaunchPicker: widget.canLaunchPicker,
        destination: widget.destination,
      );
      if (!saved && mounted) {
        setState(() {
          _pickerFailed = true;
          _mediaError = 'Media could not be attached. Keep this editor open to repair or retry saving. Pending selections can be recovered in Your posts.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _pickerFailed = true;
          _mediaError = error;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editMedia() async {
    if (_blocked || _version.ownMedia == null) return;
    setState(() => _busy = true);
    FocusScope.of(context).unfocus();
    try {
      if (!await widget.controller.flush() &&
          widget.controller.lastError is! MediaFileException) {
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MediaEditorScreen(
            items: _version.ownMedia!,
            media: widget.media,
            controller: widget.controller,
            destination: widget.destination,
            pickerImports: widget.pickerImports,
            canLaunchPicker: widget.canLaunchPicker && !_pickerFailed,
            onChanged: (items) {
              _mediaUndo = null;
              widget.controller.change(
                editOwnMedia(
                  _draft,
                  widget.destination,
                  items,
                  DateTime.now().toUtc(),
                ),
              );
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = destinationName(widget.destination);
    final own = _version.ownText != null;
    final outdated =
        own && _version.baseTextRevision != _draft.sharedTextRevision;
    return DraftSession(
      controller: widget.controller,
      allowMediaRepairReturn: true,
      exitBlocked: _busy,
      onExitPendingChanged: (value) {
        if (mounted) setState(() => _exitPending = value);
      },
      child: AbsorbPointer(
        absorbing: _blocked,
        child: CaptionScaffold(
          title: '$name version',
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
              Text(
                widget.destination == Destination.instagram
                    ? 'You finish it in Instagram · choose the account there'
                    : 'Publishes from this app once connected',
                style: const TextStyle(color: CaptionTokens.secondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Shared caption'),
                    selected: !own,
                    onSelected: _blocked ? null : (_) => _resetCaption(),
                    selectedColor: CaptionTokens.text,
                    checkmarkColor: CaptionTokens.onAction,
                    side: !own
                        ? BorderSide.none
                        : const BorderSide(color: CaptionTokens.boundary),
                    labelStyle: TextStyle(
                      color: !own ? CaptionTokens.onAction : CaptionTokens.text,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('Own caption'),
                    selected: own,
                    onSelected: _blocked ? null : (_) => _ownCaption(),
                    selectedColor: CaptionTokens.own,
                    checkmarkColor: CaptionTokens.onAction,
                    side: own
                        ? BorderSide.none
                        : const BorderSide(color: CaptionTokens.boundary),
                    labelStyle: TextStyle(
                      color: own ? CaptionTokens.onAction : CaptionTokens.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CaptionEditor(
                controller: _text,
                label: "$name's caption",
                own: own,
                readOnly: !own,
                onChanged: (value) {
                  if (!_blocked && own) {
                    _captionUndo = null;
                    widget.controller.change(
                      editOwnCaption(
                        _draft,
                        widget.destination,
                        value,
                        DateTime.now().toUtc(),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text(
                    '${_text.text.characters.length} characters',
                    style: const TextStyle(
                      fontSize: 14,
                      color: CaptionTokens.secondary,
                    ),
                  ),
                  DraftSaveStatus(controller: widget.controller),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$name limits are checked at review',
                style: const TextStyle(
                  fontSize: 14,
                  color: CaptionTokens.secondary,
                ),
              ),
              if (!own)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Using the shared caption. Choose Own caption to write a separate version.',
                  ),
                ),
              if (_captionUndo != null)
                TextButton(
                  onPressed: _blocked ? null : _undoCaption,
                  child: const Text('Undo caption reset'),
                ),
              if (own) ...[
                const SizedBox(height: 24),
                if (outdated)
                  Text(
                    'The shared caption changed after you wrote this one. $name keeps its own.',
                  ),
                TextButton(
                  onPressed: _blocked ? null : _compare,
                  child: const Text('Compare captions'),
                ),
              ],
              const SizedBox(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use shared photos'),
                subtitle: Text(
                  'Turn off to choose different ${widget.destination == Destination.instagram ? 'photos' : 'media'} for $name.',
                ),
                value: _version.ownMedia == null,
                onChanged: _blocked ? null : _toggleMedia,
              ),
              if (_mediaUndo != null)
                TextButton(
                  onPressed: _blocked ? null : _undoMedia,
                  child: const Text('Undo media reset'),
                ),
              if (_version.ownMedia != null) ...[
                const SizedBox(height: 16),
                if (_version.ownMedia!.isNotEmpty)
                  MediaStrip(
                    items: _version.ownMedia!,
                    media: widget.media,
                    onEdit: _blocked ? null : _editMedia,
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _blocked ? null : _editMedia,
                      child: const Text('Edit own media'),
                    ),
                    TextButton.icon(
                      onPressed:
                          _blocked || _pickerFailed || !widget.canLaunchPicker
                          ? null
                          : _pickMedia,
                      icon: const Icon(Icons.add),
                      label: Text(
                        widget.destination == Destination.instagram
                            ? 'Add photos'
                            : 'Add media',
                      ),
                    ),
                  ],
                ),
              ],
              if (_mediaError != null)
                Text(
                  '$_mediaError Return to Your posts for media recovery.',
                  style: const TextStyle(color: CaptionTokens.error),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
