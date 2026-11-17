import 'package:material_ui/material_ui.dart';

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
import 'compose_stage.dart';
import 'version_screen.dart';

class WriteScreen extends StatefulWidget {
  const WriteScreen({
    super.key,
    required this.controller,
    required this.media,
    required this.pickerImports,
    required this.canLaunchPicker,
    required this.onReview,
    this.onChangeDestinations,
    this.repairOnly = false,
  });
  final DraftController controller;
  final MediaFiles media;
  final PickerImports pickerImports;
  final bool canLaunchPicker;
  final VoidCallback onReview;
  final Future<void> Function()? onChangeDestinations;
  final bool repairOnly;
  @override
  State<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends State<WriteScreen> {
  late final TextEditingController _text;
  bool _busy = false;
  bool _exitPending = false;
  bool _pickerFailed = false;
  Object? _mediaError;
  bool get _blocked => _busy || _exitPending;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.controller.draft.shared.text);
    widget.controller.addListener(_changed);
  }

  void _changed() {
    syncCaptionText(_text, widget.controller.draft.shared.text);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _text.dispose();
    super.dispose();
  }

  Future<void> _review() async {
    if (_blocked) return;
    setState(() => _busy = true);
    FocusScope.of(context).unfocus();
    try {
      if (await saveComposeStage(widget.controller, ComposeStage.review) &&
          mounted) {
        widget.onReview();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _version(Destination destination) async {
    if (_blocked) return;
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
          builder: (_) => VersionScreen(
            controller: widget.controller,
            destination: destination,
            media: widget.media,
            pickerImports: widget.pickerImports,
            canLaunchPicker: widget.canLaunchPicker,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    if (_blocked || widget.onChangeDestinations == null) return;
    setState(() => _busy = true);
    FocusScope.of(context).unfocus();
    try {
      if (await widget.controller.flush() && mounted) {
        await widget.onChangeDestinations!();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickMedia() async {
    if (_blocked || _pickerFailed) return;
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
    if (_blocked) return;
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
            items: widget.controller.draft.shared.media,
            media: widget.media,
            controller: widget.controller,
            pickerImports: widget.pickerImports,
            canLaunchPicker: widget.canLaunchPicker && !_pickerFailed,
            onChanged: (items) => widget.controller.change(
              editSharedMedia(
                widget.controller.draft,
                items,
                DateTime.now().toUtc(),
              ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.controller.draft;
    return DraftSession(
      controller: widget.controller,
      allowMediaRepairReturn: widget.repairOnly,
      exitBlocked: _busy,
      onExitPendingChanged: (value) {
        if (mounted) setState(() => _exitPending = value);
      },
      child: AbsorbPointer(
        absorbing: _blocked,
        child: CaptionScaffold(
          title: widget.repairOnly ? 'Repair draft media' : 'New post',
          stageIndicator: widget.repairOnly
              ? null
              : const CaptionStageIndicator(currentStage: 2),
          actions: [
            IconButton(
              tooltip: widget.repairOnly
                  ? 'Return to destinations'
                  : 'Back to library',
              onPressed: _blocked ? null : () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back),
            ),
          ],
          primaryAction: FilledButton(
            onPressed: _blocked
                ? null
                : widget.repairOnly
                ? () => Navigator.maybePop(context)
                : _review,
            child: Text(widget.repairOnly ? 'Done repairing' : 'Review post'),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    'Media · ${draft.shared.media.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton.icon(
                    onPressed:
                        _blocked || _pickerFailed || !widget.canLaunchPicker
                        ? null
                        : _pickMedia,
                    icon: const Icon(Icons.add),
                    label: const Text('Add media'),
                  ),
                  if (draft.shared.media.isNotEmpty)
                    IconButton(
                      tooltip: 'Edit media',
                      onPressed: _blocked ? null : _editMedia,
                      icon: const Icon(Icons.tune),
                    ),
                ],
              ),
              if (draft.shared.media.isNotEmpty) ...[
                MediaStrip(
                  items: draft.shared.media,
                  media: widget.media,
                  onEdit: _blocked ? null : _editMedia,
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Photos and video for your post. You can also write without media.',
                  ),
                ),
              if (_mediaError != null)
                Text(
                  '$_mediaError Return to Your posts for media recovery.',
                  style: const TextStyle(color: CaptionTokens.error),
                ),
              const SizedBox(height: 16),
              CaptionEditor(
                controller: _text,
                label: 'Shared caption',
                own: false,
                onChanged: (value) {
                  if (!_blocked) {
                    widget.controller.change(
                      editSharedCaption(
                        widget.controller.draft,
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
                    '${draft.shared.text.characters.length} characters',
                    style: const TextStyle(
                      fontSize: 14,
                      color: CaptionTokens.secondary,
                    ),
                  ),
                  DraftSaveStatus(controller: widget.controller),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Destinations',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (widget.onChangeDestinations != null)
                    TextButton(
                      onPressed: _blocked ? null : _choose,
                      child: const Text('Change'),
                    ),
                ],
              ),
              for (final destination in Destination.values.where(
                (d) =>
                    draft.selected.contains(d) ||
                    ((widget.repairOnly ||
                            widget.controller.lastError
                                is MediaFileException) &&
                        draft.versions.containsKey(d)),
              )) ...[
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${destinationName(destination)}${draft.selected.contains(destination) ? '' : ' · Not selected'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _DestinationCaptionSample(
                      text: resolveContent(draft, destination).text,
                      own: draft.versions[destination]?.ownText != null,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _blocked ? null : () => _version(destination),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationCaptionSample extends StatelessWidget {
  const _DestinationCaptionSample({required this.text, required this.own});
  final String text;
  final bool own;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final sample = CaptionText(
        text.isEmpty ? 'No caption yet' : text,
        own: own,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      );
      final source = Text(
        own ? 'Own caption' : 'Shared',
        style: const TextStyle(fontSize: 14, color: CaptionTokens.secondary),
      );
      if (constraints.maxWidth < 260 ||
          MediaQuery.textScalerOf(context).scale(16) > 24) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [sample, const SizedBox(height: 2), source],
        );
      }
      return Row(
        children: [
          Expanded(child: sample),
          const SizedBox(width: 12),
          source,
        ],
      );
    },
  );
}
