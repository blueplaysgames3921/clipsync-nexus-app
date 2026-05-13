import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

import '../../../data/models/clip_record.dart';
import '../../../data/repositories/clip_repository.dart';
import '../../../core/services/clipboard_monitor_service.dart';
import '../../../core/services/clean_room_service.dart';
import '../../../core/services/ghost_layer_service.dart';

// ── EVENTS ────────────────────────────────────────────────────────────────

abstract class ClipboardEvent extends Equatable {
  const ClipboardEvent();
  @override List<Object?> get props => [];
}

class ClipboardStartMonitoring extends ClipboardEvent { const ClipboardStartMonitoring(); }
class ClipboardLoad extends ClipboardEvent {
  final int limit; final int offset;
  const ClipboardLoad({this.limit = 200, this.offset = 0});
  @override List<Object?> get props => [limit, offset];
}
class ClipboardItemCaptured extends ClipboardEvent {
  final ClipRecord clip;
  const ClipboardItemCaptured(this.clip);
  @override List<Object?> get props => [clip.id];
}
class ClipboardSelect extends ClipboardEvent {
  final String? clipId;
  const ClipboardSelect(this.clipId);
  @override List<Object?> get props => [clipId];
}
class ClipboardPaste extends ClipboardEvent {
  final String clipId;
  const ClipboardPaste(this.clipId);
  @override List<Object?> get props => [clipId];
}
class ClipboardDelete extends ClipboardEvent {
  final String clipId;
  const ClipboardDelete(this.clipId);
  @override List<Object?> get props => [clipId];
}
class ClipboardPin extends ClipboardEvent {
  final String clipId; final bool pinned;
  const ClipboardPin(this.clipId, {required this.pinned});
  @override List<Object?> get props => [clipId, pinned];
}
class ClipboardFilterChanged extends ClipboardEvent {
  final ClipContentType? filterType; final bool sensitiveOnly;
  const ClipboardFilterChanged({this.filterType, this.sensitiveOnly = false});
  @override List<Object?> get props => [filterType, sensitiveOnly];
}
class ClipboardClearAll extends ClipboardEvent { const ClipboardClearAll(); }
class ClipboardGhostExpired extends ClipboardEvent {
  final String clipId;
  const ClipboardGhostExpired(this.clipId);
  @override List<Object?> get props => [clipId];
}

// ── STATE ─────────────────────────────────────────────────────────────────

enum ClipboardStatus { initial, loading, ready, error }

class ClipboardState extends Equatable {
  final ClipboardStatus status;
  final List<ClipRecord> clips;
  final String? selectedId;
  final ClipContentType? filterType;
  final bool sensitiveOnly;
  final String? error;
  final int totalCount;

  const ClipboardState({
    this.status = ClipboardStatus.initial,
    this.clips = const [],
    this.selectedId,
    this.filterType,
    this.sensitiveOnly = false,
    this.error,
    this.totalCount = 0,
  });

  ClipRecord? get selectedClip =>
      selectedId != null ? clips.cast<ClipRecord?>().firstWhere(
        (c) => c?.id == selectedId, orElse: () => null) : null;

  ClipboardState copyWith({
    ClipboardStatus? status,
    List<ClipRecord>? clips,
    String? selectedId,
    ClipContentType? filterType,
    bool? sensitiveOnly,
    String? error,
    int? totalCount,
    bool clearSelected = false,
  }) {
    return ClipboardState(
      status: status ?? this.status,
      clips: clips ?? this.clips,
      selectedId: clearSelected ? null : (selectedId ?? this.selectedId),
      filterType: filterType ?? this.filterType,
      sensitiveOnly: sensitiveOnly ?? this.sensitiveOnly,
      error: error ?? this.error,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  @override
  List<Object?> get props => [status, clips.length, selectedId, filterType, sensitiveOnly, totalCount];
}

// ── BLOC ──────────────────────────────────────────────────────────────────

class ClipboardBloc extends Bloc<ClipboardEvent, ClipboardState> {
  final ClipRepository clipRepo;
  final GhostLayerService ghostService;
  final CleanRoomService cleanRoomService;
  final ClipboardMonitorService monitor;

  StreamSubscription<ClipRecord>? _monitorSub;

  ClipboardBloc({
    required this.clipRepo,
    required this.ghostService,
    required this.cleanRoomService,
    required this.monitor,
  }) : super(const ClipboardState()) {
    on<ClipboardStartMonitoring>(_onStartMonitoring);
    on<ClipboardLoad>(_onLoad);
    on<ClipboardItemCaptured>(_onItemCaptured);
    on<ClipboardSelect>(_onSelect);
    on<ClipboardPaste>(_onPaste);
    on<ClipboardDelete>(_onDelete);
    on<ClipboardPin>(_onPin);
    on<ClipboardFilterChanged>(_onFilterChanged);
    on<ClipboardClearAll>(_onClearAll);
    on<ClipboardGhostExpired>(_onGhostExpired);

    // Listen for ghost layer expirations
    ghostService.onExpiry((clipId) {
      add(ClipboardGhostExpired(clipId));
    });
  }

  Future<void> _onStartMonitoring(
    ClipboardStartMonitoring event, Emitter<ClipboardState> emit) async {
    // Subscribe to real-time captures from monitor
    await _monitorSub?.cancel();
    _monitorSub = monitor.clipStream.listen((clip) {
      add(ClipboardItemCaptured(clip));
    });
    add(const ClipboardLoad());
  }

  Future<void> _onLoad(ClipboardLoad event, Emitter<ClipboardState> emit) async {
    emit(state.copyWith(status: ClipboardStatus.loading));
    try {
      final clips = await clipRepo.fetchPage(
        limit: event.limit,
        offset: event.offset,
        filterType: state.filterType,
        sensitiveOnly: state.sensitiveOnly,
      );
      emit(state.copyWith(
        status: ClipboardStatus.ready,
        clips: clips,
        totalCount: clips.length,
      ));
    } catch (e) {
      emit(state.copyWith(status: ClipboardStatus.error, error: e.toString()));
    }
  }

  Future<void> _onItemCaptured(
    ClipboardItemCaptured event, Emitter<ClipboardState> emit) async {
    // Prepend new item to list without full reload
    final updated = [event.clip, ...state.clips];
    // Respect current filter
    final filtered = _applyFilter(updated);
    emit(state.copyWith(
      status: ClipboardStatus.ready,
      clips: filtered,
      totalCount: updated.length,
    ));
  }

  Future<void> _onSelect(ClipboardSelect event, Emitter<ClipboardState> emit) async {
    emit(state.copyWith(selectedId: event.clipId));
  }

  Future<void> _onPaste(ClipboardPaste event, Emitter<ClipboardState> emit) async {
    final clip = state.clips.firstWhere(
      (c) => c.id == event.clipId,
      orElse: () => state.clips.first,
    );
    final fullClip = await clipRepo.fetchById(event.clipId) ?? clip;
    final text = fullClip.primaryText;
    if (text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
    }
    monitor.suppressNextCapture();
  }

  Future<void> _onDelete(ClipboardDelete event, Emitter<ClipboardState> emit) async {
    await clipRepo.delete(event.clipId);
    final updated = state.clips.where((c) => c.id != event.clipId).toList();
    emit(state.copyWith(
      clips: updated,
      totalCount: state.totalCount - 1,
      clearSelected: state.selectedId == event.clipId,
    ));
  }

  Future<void> _onPin(ClipboardPin event, Emitter<ClipboardState> emit) async {
    final clip = state.clips.firstWhere((c) => c.id == event.clipId,
        orElse: () => state.clips.first);
    final updated = clip.copyWith(
      flags: clip.flags.copyWith(pinned: event.pinned),
    );
    await clipRepo.update(updated);
    final newList = state.clips.map((c) => c.id == event.clipId ? updated : c).toList();
    emit(state.copyWith(clips: newList));
  }

  Future<void> _onFilterChanged(
    ClipboardFilterChanged event, Emitter<ClipboardState> emit) async {
    emit(state.copyWith(
      filterType: event.filterType,
      sensitiveOnly: event.sensitiveOnly,
    ));
    add(const ClipboardLoad());
  }

  Future<void> _onClearAll(ClipboardClearAll event, Emitter<ClipboardState> emit) async {
    await clipRepo.deleteAll();
    emit(state.copyWith(clips: [], totalCount: 0, clearSelected: true));
  }

  Future<void> _onGhostExpired(
    ClipboardGhostExpired event, Emitter<ClipboardState> emit) async {
    final updated = state.clips.where((c) => c.id != event.clipId).toList();
    emit(state.copyWith(
      clips: updated,
      totalCount: state.totalCount - 1,
      clearSelected: state.selectedId == event.clipId,
    ));
  }

  List<ClipRecord> _applyFilter(List<ClipRecord> clips) {
    if (state.filterType == null && !state.sensitiveOnly) return clips;
    return clips.where((c) {
      if (state.sensitiveOnly) return c.isSensitive;
      return c.contentType == state.filterType;
    }).toList();
  }

  @override
  Future<void> close() async {
    await _monitorSub?.cancel();
    super.close();
  }
}
