import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/clock.dart';
import 'draft.dart';
import 'draft_repository.dart';

enum SaveState { saving, saved, failed }

/// One editor's serial save lane. New drafts are unsaved until acknowledged;
/// restored snapshots are verified against storage before reporting Saved.
///
/// L5/L6 must await [flush] before leaving the editor, changing stage, opening
/// pickers/accounts/Instagram, capturing review snapshots, or backgrounding.
/// A false result keeps the editor open with its current selectable/copyable
/// text and Retry saving. [lastError] distinguishes conflicts (reload only by
/// explicit user choice) from retryable storage/media errors. Disposal does
/// not flush, and a force-kill can lose unacknowledged edits.
class DraftController extends ChangeNotifier {
  DraftController(Draft initial, this._repo, this._clock)
    : _initial = initial,
      _draft = initial {
    _scheduleSave();
  }

  final Draft _initial;
  final DraftRepository _repo;
  final Clock _clock;
  Draft _draft;
  SaveState _saveState = SaveState.saving;
  int _savedRevision = -1;
  Object? _lastError;
  bool _initialized = false;
  bool _disposed = false;
  Timer? _debounce;
  Future<bool>? _lane;

  Draft get draft => _draft;
  SaveState get saveState => _saveState;
  int get savedRevision => _savedRevision;
  Object? get lastError => _lastError;

  /// Accepts a domain edit with the same id and a strictly newer revision.
  void change(Draft next) {
    if (_disposed) throw StateError('This draft editor is closed.');
    if (next.id != _draft.id || next.revision <= _draft.revision) {
      throw ArgumentError(
        'An edit must keep the draft id and advance revision.',
      );
    }
    _draft = next.copyWith(updatedAt: _clock.now());
    _saveState = SaveState.saving;
    _lastError = null;
    _scheduleSave();
    notifyListeners();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(flush());
    });
  }

  /// Cancels debounce and joins the one lane, including edits arriving while
  /// a write is pending. False always means the latest content is not saved.
  /// Save failures are exposed in state and never swallowed as success.
  Future<bool> flush() {
    _debounce?.cancel();
    if (_disposed) return Future.value(false);
    // Publish the lane before listeners can reenter flush from notifications.
    return _lane ??= Future<bool>.microtask(_saveLatest)
        .whenComplete(() => _lane = null);
  }

  /// Retries the current in-memory text using the last acknowledged CAS base.
  /// In particular this never reloads/rebases after a conflict.
  Future<bool> retrySave() => flush();

  Future<bool> _saveLatest() async {
    _saveState = SaveState.saving;
    _lastError = null;
    _notify();
    try {
      if (!_initialized) {
        final stored = await _repo.get(_initial.id);
        if (stored != null && stored != _initial) {
          throw DraftConflict(_initial.id);
        }
        _savedRevision = stored?.revision ?? -1;
        _initialized = true;
      }
      do {
        if (_disposed) return false;
        if (_savedRevision != _draft.revision) {
          _debounce?.cancel();
          final snapshot = _draft;
          await _repo.save(snapshot, expectedRevision: _savedRevision);
          _savedRevision = snapshot.revision;
        }
        _saveState = _savedRevision == _draft.revision
            ? SaveState.saved
            : SaveState.saving;
        _notify();
      } while (_savedRevision != _draft.revision);
      return true;
    } catch (error) {
      _debounce?.cancel();
      _lastError = error;
      _saveState = SaveState.failed;
      _notify();
      return false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
