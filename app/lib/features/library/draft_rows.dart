import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../design/caption_text.dart';
import '../../design/caption_tokens.dart';
import '../../storage/media_files.dart';
import '../accounts/account.dart';
import '../drafts/draft.dart';
import '../media/media_strip.dart';

/// "Today 1:40 PM", "Yesterday 9:05 AM" or "Nov 12".
String draftWhen(DateTime time, DateTime now) {
  final t = time.toLocal();
  final n = now.toLocal();
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final clock =
      '$hour:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  final days = DateTime(
    n.year,
    n.month,
    n.day,
  ).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (days == 0) return 'Today $clock';
  if (days == 1) return 'Yesterday $clock';
  return '${_months[t.month - 1]} ${t.day}';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _caption(Draft d) =>
    d.shared.text.trim().isEmpty ? 'Untitled draft' : d.shared.text.trim();

List<Destination> _destinations(Draft d) => [
  for (final x in Destination.values)
    if (d.selected.contains(x)) x,
];

String _destinationLine(Draft d) {
  final names = _destinations(d).map(destinationName).toList();
  return names.isEmpty ? 'No destinations' : names.join(', ');
}

String _initial(Destination d) => switch (d) {
  Destination.x => 'X',
  Destination.bluesky => 'B',
  Destination.instagram => 'IG',
};

int _stageIndex(ComposeStage s) => switch (s) {
  ComposeStage.choose => 0,
  ComposeStage.write => 1,
  ComposeStage.review => 2,
};

String _stageName(ComposeStage s) =>
    const ['Choose', 'Write', 'Review'][_stageIndex(s)];

/// One label for screen readers; the visuals repeat it.
String draftSemantics(Draft d, DateTime now) =>
    '${_caption(d)}${RegExp(r'[.!?…]$').hasMatch(_caption(d)) ? '' : '.'} ${_destinationLine(d)}. Step ${_stageIndex(d.stage) + 1} of 3, ${_stageName(d.stage)}. ${d.retryParentAttemptId == null ? 'Saved' : 'Saved retry'} ${draftWhen(d.updatedAt, now)}.';

/// Three short ink segments, filled up to the current step, then its name.
class StageRail extends StatelessWidget {
  const StageRail({super.key, required this.stage});
  final ComposeStage stage;
  @override
  Widget build(BuildContext context) {
    final t = CaptionTokens.of(context);
    final at = _stageIndex(stage);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            width: 16,
            height: 4,
            decoration: BoxDecoration(
              color: i <= at ? t.text : t.raised2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 3),
        ],
        const SizedBox(width: 5),
        Text(
          _stageName(stage),
          style: TextStyle(
            fontFamily: brandFace,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: t.text,
          ),
        ),
      ],
    );
  }
}

Widget _deleteButton(VoidCallback? onDelete) => IconButton(
  tooltip: 'Delete draft',
  onPressed: onDelete,
  icon: const Icon(Icons.delete_outline),
);

/// The whole draft opens as one button; Delete stays its own control.
Widget _opening({
  required Draft draft,
  required DateTime now,
  required VoidCallback? onOpen,
  required Widget child,
}) => Semantics(
  button: true,
  label: draftSemantics(draft, now),
  excludeSemantics: true,
  onTap: onOpen,
  child: InkWell(onTap: onOpen, child: child),
);

// ─── List: fanned proofs ──────────────────────────────────────────────

/// Each draft leads with a fan of small proofs, one per destination.
class DraftListRow extends StatelessWidget {
  const DraftListRow({
    super.key,
    required this.draft,
    required this.media,
    required this.now,
    required this.onOpen,
    required this.onDelete,
  });
  final Draft draft;
  final MediaFiles media;
  final DateTime now;
  final VoidCallback? onOpen, onDelete;

  @override
  Widget build(BuildContext context) {
    final t = CaptionTokens.of(context);
    final destinations = _destinations(draft);
    final sheets = math.max(1, destinations.length);
    final still = MediaQuery.disableAnimationsOf(context);

    Widget proof(int i, double spread) {
      final top = i == sheets - 1;
      final offset = i - (sheets - 1) / 2;
      return Transform.translate(
        offset: Offset(offset * 7 * spread, 0),
        child: Transform.rotate(
          angle: offset * 0.24 * spread,
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 58,
            height: 72,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: t.sheet,
              border: Border.all(color: top ? t.boundary : t.hairline),
              borderRadius: BorderRadius.circular(6),
            ),
            child: top
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: draft.shared.media.isEmpty
                            // A text-only proof shows its lines, not tiny type.
                            ? CustomPaint(
                                painter: _ProofLines(
                                  t.text.withValues(alpha: 0.55),
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                // Laid out at strip size, then scaled down, so
                                // a video placeholder fits the tiny proof too.
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  clipBehavior: Clip.hardEdge,
                                  child: SizedBox(
                                    width: 174,
                                    height: 108,
                                    child: MediaPreview(
                                      attachment: draft.shared.media.first,
                                      media: media,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        destinations.isEmpty
                            ? '–'
                            : destinations.map(_initial).join(' '),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: brandFace,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: t.text,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
      );
    }

    Widget fan(double spread) => SizedBox(
      width: 76,
      height: 82,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [for (var i = 0; i < sheets; i++) proof(i, spread)],
      ),
    );

    return Row(
      children: [
        Expanded(
          child: _opening(
            draft: draft,
            now: now,
            onOpen: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  // The fan opens once as the list appears.
                  still
                      ? fan(1)
                      : TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 520),
                          curve: Curves.easeOutBack,
                          builder: (context, v, _) => fan(v),
                        ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CaptionText(_caption(draft), own: false, maxLines: 2),
                        const SizedBox(height: 8),
                        StageRail(stage: draft.stage),
                        const SizedBox(height: 4),
                        Text(
                          '${_destinationLine(draft)} · ${draft.retryParentAttemptId == null ? '' : 'Retry · '}${draftWhen(draft.updatedAt, now)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: t.secondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _deleteButton(onDelete),
      ],
    );
  }
}

// ─── Grid: contact sheet ──────────────────────────────────────────────

/// Two columns where the picture leads; text-only drafts set their caption
/// large on the sheet instead. One column at large text or narrow widths.
class DraftGrid extends StatelessWidget {
  const DraftGrid({
    super.key,
    required this.drafts,
    required this.media,
    required this.now,
    required this.onOpen,
    required this.onDelete,
  });
  final List<Draft> drafts;
  final MediaFiles media;
  final DateTime now;
  final void Function(Draft)? onOpen, onDelete;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final normalText = MediaQuery.textScalerOf(context).scale(16) <= 24;
      final columns = normalText && constraints.maxWidth >= 320 ? 2 : 1;
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final draft in drafts)
              SizedBox(
                key: ValueKey(draft.id),
                width: width,
                child: _GridTile(
                  draft: draft,
                  media: media,
                  now: now,
                  onOpen: onOpen == null ? null : () => onOpen!(draft),
                  onDelete: onDelete == null ? null : () => onDelete!(draft),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.draft,
    required this.media,
    required this.now,
    required this.onOpen,
    required this.onDelete,
  });
  final Draft draft;
  final MediaFiles media;
  final DateTime now;
  final VoidCallback? onOpen, onDelete;

  @override
  Widget build(BuildContext context) {
    final t = CaptionTokens.of(context);
    final hasPhoto = draft.shared.media.isNotEmpty;
    final destinations = _destinations(draft);
    return Stack(
      children: [
        Material(
          color: t.sheet,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: t.hairline),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: _opening(
            draft: draft,
            now: now,
            onOpen: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasPhoto)
                        MediaPreview(
                          attachment: draft.shared.media.first,
                          media: media,
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 52, 14, 0),
                          child: Text(
                            _caption(draft),
                            maxLines: 5,
                            overflow: TextOverflow.fade,
                            style: captionStyle(context).copyWith(
                              fontSize: 19,
                              height: 1.3,
                              color: t.text,
                            ),
                          ),
                        ),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Row(
                          children: [
                            for (final d in destinations)
                              Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: t.sheet,
                                  border: Border.all(color: t.text, width: 1.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _initial(d),
                                  style: TextStyle(
                                    fontFamily: brandFace,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: t.text,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasPhoto) ...[
                        Text(
                          _caption(draft),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: captionStyle(context).copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                      ],
                      StageRail(stage: draft.stage),
                      const SizedBox(height: 4),
                      Text(
                        draftWhen(draft.updatedAt, now),
                        style: TextStyle(fontSize: 13, color: t.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Over the tile but announced on its own, after the draft itself.
        Positioned(
          right: 0,
          top: 0,
          child: Padding(
            padding: const EdgeInsets.all(4),
            // A sheet-coloured disc keeps the icon legible over any photo.
            child: Material(
              color: t.sheet.withValues(alpha: 0.9),
              shape: const CircleBorder(),
              child: _deleteButton(onDelete),
            ),
          ),
        ),
      ],
    );
  }
}

/// Caption lines on a text-only proof, fitted to whatever space it has.
class _ProofLines extends CustomPainter {
  const _ProofLines(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const widths = [1.0, 0.85, 1.0, 0.6];
    for (var i = 0; i < widths.length; i++) {
      final top = 5.0 + i * 9;
      if (top + 4 > size.height) break;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, top, size.width * widths[i], 4),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProofLines old) => old.color != color;
}
