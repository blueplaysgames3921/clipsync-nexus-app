// ignore_for_file: lines_longer_than_80_chars
// All BLoC classes consolidated — imports must be at top in Dart.

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../../../core/services/chunk_engine_service.dart';
import '../../../core/services/ghost_layer_service.dart';
import '../../../core/services/teleport_service.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/clip_record.dart';
import '../../../data/repositories/clip_repository.dart';
import '../../../data/repositories/settings_repository.dart';

// ignore_for_file: lines_longer_than_80_chars


// ═══════════════════════════════════════════════════════════════════════════
// stack_bloc.dart
// ═══════════════════════════════════════════════════════════════════════════


// Events
abstract class StackEvent extends Equatable {
  const StackEvent();
  @override List<Object?> get props => [];
}
class StackToggleMode    extends StackEvent { const StackToggleMode(); }
class StackPush          extends StackEvent { final ClipRecord clip; const StackPush(this.clip); @override List<Object?> get props => [clip.id]; }
class StackPasteNext     extends StackEvent { const StackPasteNext(); }
class StackReorder       extends StackEvent { final int oldIndex; final int newIndex; const StackReorder(this.oldIndex, this.newIndex); @override List<Object?> get props => [oldIndex, newIndex]; }
class StackRemoveAt      extends StackEvent { final int index; const StackRemoveAt(this.index); @override List<Object?> get props => [index]; }
class StackClear         extends StackEvent { const StackClear(); }
class StackToggleCycle   extends StackEvent { const StackToggleCycle(); }

// State
class StackState extends Equatable {
  final bool isActive;
  final List<ClipRecord> queue;
  final int pointer; // next item to paste
  final bool cycleMode;
  final ClipRecord? lastPasted;

  const StackState({
    this.isActive = false,
    this.queue = const [],
    this.pointer = 0,
    this.cycleMode = false,
    this.lastPasted,
  });

  bool get isExhausted => !cycleMode && pointer >= queue.length;
  ClipRecord? get nextItem => queue.isNotEmpty && pointer < queue.length ? queue[pointer] : null;
  int get remaining => queue.length - pointer;

  StackState copyWith({bool? isActive, List<ClipRecord>? queue, int? pointer, bool? cycleMode, ClipRecord? lastPasted}) =>
    StackState(isActive: isActive ?? this.isActive, queue: queue ?? this.queue,
      pointer: pointer ?? this.pointer, cycleMode: cycleMode ?? this.cycleMode, lastPasted: lastPasted ?? this.lastPasted);

  @override List<Object?> get props => [isActive, queue.length, pointer, cycleMode];
}

// BLoC
class StackBloc extends Bloc<StackEvent, StackState> {
  final ClipRepository clipRepo;
  StackBloc({required this.clipRepo}) : super(const StackState()) {
    on<StackToggleMode>((e, emit) => emit(state.copyWith(isActive: !state.isActive)));
    on<StackPush>((e, emit) {
      if (!state.isActive) return;
      emit(state.copyWith(queue: [...state.queue, e.clip]));
    });
    on<StackPasteNext>((e, emit) async {
      if (state.queue.isEmpty) return;
      final idx = state.pointer % state.queue.length;
      final clip = state.queue[idx];
      // TODO: write clip to OS clipboard via platform channel
      int next = state.pointer + 1;
      if (state.cycleMode && next >= state.queue.length) next = 0;
      emit(state.copyWith(pointer: next, lastPasted: clip));
    });
    on<StackReorder>((e, emit) {
      final q = List<ClipRecord>.from(state.queue);
      final item = q.removeAt(e.oldIndex);
      q.insert(e.newIndex, item);
      emit(state.copyWith(queue: q));
    });
    on<StackRemoveAt>((e, emit) {
      final q = List<ClipRecord>.from(state.queue)..removeAt(e.index);
      emit(state.copyWith(queue: q));
    });
    on<StackClear>((e, emit) => emit(state.copyWith(queue: [], pointer: 0, lastPasted: null)));
    on<StackToggleCycle>((e, emit) => emit(state.copyWith(cycleMode: !state.cycleMode)));
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// scratchpad_bloc.dart
// ═══════════════════════════════════════════════════════════════════════════

class ScratchBlock {
  final String id;
  final ClipRecord sourceClip;
  String editText;

  ScratchBlock({required this.id, required this.sourceClip, String? editText})
      : editText = editText ?? sourceClip.primaryText;
}

abstract class ScratchpadEvent extends Equatable {
  const ScratchpadEvent();
  @override List<Object?> get props => [];
}
class ScratchAddBlock    extends ScratchpadEvent { final ClipRecord clip; const ScratchAddBlock(this.clip); @override List<Object?> get props => [clip.id]; }
class ScratchRemoveBlock extends ScratchpadEvent { final String blockId; const ScratchRemoveBlock(this.blockId); @override List<Object?> get props => [blockId]; }
class ScratchEditBlock   extends ScratchpadEvent { final String blockId; final String text; const ScratchEditBlock(this.blockId, this.text); @override List<Object?> get props => [blockId]; }
class ScratchReorder     extends ScratchpadEvent { final int oldIndex; final int newIndex; const ScratchReorder(this.oldIndex, this.newIndex); @override List<Object?> get props => [oldIndex, newIndex]; }
class ScratchMerge       extends ScratchpadEvent { final String separator; const ScratchMerge(this.separator); @override List<Object?> get props => [separator]; }
class ScratchClear       extends ScratchpadEvent { const ScratchClear(); }

class ScratchpadState extends Equatable {
  final List<ScratchBlock> blocks;
  final String? mergedText;

  const ScratchpadState({this.blocks = const [], this.mergedText});
  ScratchpadState copyWith({List<ScratchBlock>? blocks, String? mergedText}) =>
    ScratchpadState(blocks: blocks ?? this.blocks, mergedText: mergedText ?? this.mergedText);
  @override List<Object?> get props => [blocks.length, mergedText];
}

class ScratchpadBloc extends Bloc<ScratchpadEvent, ScratchpadState> {
  ScratchpadBloc() : super(const ScratchpadState()) {
    on<ScratchAddBlock>((e, emit) {
      final block = ScratchBlock(id: '${e.clip.id}_${DateTime.now().millisecondsSinceEpoch}', sourceClip: e.clip);
      emit(state.copyWith(blocks: [...state.blocks, block]));
    });
    on<ScratchRemoveBlock>((e, emit) {
      emit(state.copyWith(blocks: state.blocks.where((b) => b.id != e.blockId).toList()));
    });
    on<ScratchEditBlock>((e, emit) {
      for (final b in state.blocks) { if (b.id == e.blockId) b.editText = e.text; }
      emit(state.copyWith(blocks: List.from(state.blocks)));
    });
    on<ScratchReorder>((e, emit) {
      final list = List<ScratchBlock>.from(state.blocks);
      final item = list.removeAt(e.oldIndex);
      list.insert(e.newIndex, item);
      emit(state.copyWith(blocks: list));
    });
    on<ScratchMerge>((e, emit) {
      final sep = e.separator.replaceAll(r'\n', '\n');
      final merged = state.blocks.map((b) => b.editText).join(sep);
      // TODO: write merged to OS clipboard
      emit(state.copyWith(mergedText: merged));
    });
    on<ScratchClear>((e, emit) => emit(const ScratchpadState()));
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// ghost_bloc.dart
// ═══════════════════════════════════════════════════════════════════════════

abstract class GhostEvent extends Equatable {
  const GhostEvent();
  @override List<Object?> get props => [];
}
class GhostStartWatching   extends GhostEvent { const GhostStartWatching(); }
class GhostItemExpired     extends GhostEvent { final String clipId; const GhostItemExpired(this.clipId); @override List<Object?> get props => [clipId]; }
class GhostExtendTtl       extends GhostEvent { final String clipId; final int extraSeconds; const GhostExtendTtl(this.clipId, this.extraSeconds); @override List<Object?> get props => [clipId, extraSeconds]; }
class GhostPurgeNow        extends GhostEvent { final String clipId; const GhostPurgeNow(this.clipId); @override List<Object?> get props => [clipId]; }
class GhostMarkNotSensitive extends GhostEvent { final String clipId; const GhostMarkNotSensitive(this.clipId); @override List<Object?> get props => [clipId]; }
class GhostRefresh         extends GhostEvent { final List<ClipRecord> sensitiveClips; const GhostRefresh(this.sensitiveClips); @override List<Object?> get props => [sensitiveClips.length]; }

class GhostState extends Equatable {
  final List<ClipRecord> sensitiveItems;
  const GhostState({this.sensitiveItems = const []});
  GhostState copyWith({List<ClipRecord>? sensitiveItems}) => GhostState(sensitiveItems: sensitiveItems ?? this.sensitiveItems);
  @override List<Object?> get props => [sensitiveItems.length];
}

class GhostBloc extends Bloc<GhostEvent, GhostState> {
  final GhostLayerService ghostService;
  final ClipRepository clipRepo;

  GhostBloc({required this.ghostService, required this.clipRepo}) : super(const GhostState()) {
    on<GhostStartWatching>(_onStart);
    on<GhostItemExpired>((e, emit) => emit(state.copyWith(sensitiveItems: state.sensitiveItems.where((c) => c.id != e.clipId).toList())));
    on<GhostExtendTtl>((e, emit) async { await ghostService.extendTtl(e.clipId, e.extraSeconds); });
    on<GhostPurgeNow>((e, emit) async {
      await ghostService.purgeNow(e.clipId);
      emit(state.copyWith(sensitiveItems: state.sensitiveItems.where((c) => c.id != e.clipId).toList()));
    });
    on<GhostMarkNotSensitive>((e, emit) async {
      await ghostService.clearTtl(e.clipId);
      emit(state.copyWith(sensitiveItems: state.sensitiveItems.where((c) => c.id != e.clipId).toList()));
    });
    on<GhostRefresh>((e, emit) => emit(state.copyWith(sensitiveItems: e.sensitiveClips)));
  }

  Future<void> _onStart(GhostStartWatching event, Emitter<GhostState> emit) async {
    final sensitive = await clipRepo.fetchPage(sensitiveOnly: true);
    emit(state.copyWith(sensitiveItems: sensitive));
    ghostService.onExpiry((id) => add(GhostItemExpired(id)));
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// teleport_bloc.dart
// ═══════════════════════════════════════════════════════════════════════════

abstract class TeleportEvent extends Equatable {
  const TeleportEvent();
  @override List<Object?> get props => [];
}
class TeleportInit         extends TeleportEvent { const TeleportInit(); }
class TeleportSendClip     extends TeleportEvent { final String peerId; final ClipRecord clip; const TeleportSendClip(this.peerId, this.clip); @override List<Object?> get props => [peerId, clip.id]; }
class TeleportInitiatePair extends TeleportEvent { final String peerId; const TeleportInitiatePair(this.peerId); @override List<Object?> get props => [peerId]; }
class TeleportConfirmPair  extends TeleportEvent { final String peerId; final bool confirmed; const TeleportConfirmPair(this.peerId, {required this.confirmed}); @override List<Object?> get props => [peerId, confirmed]; }
class TeleportPeersUpdated extends TeleportEvent { final List<TeleportPeer> peers; const TeleportPeersUpdated(this.peers); @override List<Object?> get props => [peers.length]; }

class TeleportState extends Equatable {
  final List<TeleportPeer> peers;
  final TransferProgress? activeTransfer;
  final String? pairingSasCode;
  final String? pairingPeerId;

  const TeleportState({this.peers = const [], this.activeTransfer, this.pairingSasCode, this.pairingPeerId});
  TeleportState copyWith({List<TeleportPeer>? peers, TransferProgress? activeTransfer, String? pairingSasCode, String? pairingPeerId}) =>
    TeleportState(peers: peers ?? this.peers, activeTransfer: activeTransfer ?? this.activeTransfer,
      pairingSasCode: pairingSasCode ?? this.pairingSasCode, pairingPeerId: pairingPeerId ?? this.pairingPeerId);
  @override List<Object?> get props => [peers.length, pairingSasCode, pairingPeerId];
}

class TeleportBloc extends Bloc<TeleportEvent, TeleportState> {
  final TeleportService teleportService;

  TeleportBloc({required this.teleportService}) : super(const TeleportState()) {
    on<TeleportInit>(_onInit);
    on<TeleportSendClip>(_onSend);
    on<TeleportInitiatePair>(_onInitiatePair);
    on<TeleportConfirmPair>(_onConfirmPair);
    on<TeleportPeersUpdated>((e, emit) => emit(state.copyWith(peers: e.peers)));
  }

  Future<void> _onInit(TeleportInit event, Emitter<TeleportState> emit) async {
    teleportService.peersStream.listen((peers) => add(TeleportPeersUpdated(peers)));
  }

  Future<void> _onSend(TeleportSendClip event, Emitter<TeleportState> emit) async {
    await teleportService.sendClip(event.peerId, event.clip);
  }

  Future<void> _onInitiatePair(TeleportInitiatePair event, Emitter<TeleportState> emit) async {
    final sas = await teleportService.initiatePairing(event.peerId);
    emit(state.copyWith(pairingSasCode: sas, pairingPeerId: event.peerId));
  }

  Future<void> _onConfirmPair(TeleportConfirmPair event, Emitter<TeleportState> emit) async {
    await teleportService.confirmPairing(event.peerId, event.confirmed);
    emit(state.copyWith(pairingSasCode: null, pairingPeerId: null));
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// chunk_bloc.dart
// ═══════════════════════════════════════════════════════════════════════════

abstract class ChunkEvent extends Equatable {
  const ChunkEvent();
  @override List<Object?> get props => [];
}
class ChunkCreate     extends ChunkEvent { final String parentId; final String text; final ChunkStrategy? strategy; const ChunkCreate({required this.parentId, required this.text, this.strategy}); @override List<Object?> get props => [parentId]; }
class ChunkPasteNext  extends ChunkEvent { const ChunkPasteNext(); }
class ChunkCancel     extends ChunkEvent { const ChunkCancel(); }
class ChunkJumpTo     extends ChunkEvent { final int index; const ChunkJumpTo(this.index); @override List<Object?> get props => [index]; }

class ChunkState extends Equatable {
  final ChunkSession? session;
  const ChunkState({this.session});
  ChunkState copyWith({ChunkSession? session}) => ChunkState(session: session ?? this.session);
  @override List<Object?> get props => [session?.currentIndex, session?.totalSegments];
}

class ChunkBloc extends Bloc<ChunkEvent, ChunkState> {
  final ChunkEngineService engine;

  ChunkBloc({required this.engine}) : super(const ChunkState()) {
    on<ChunkCreate>((e, emit) {
      final session = engine.createSession(parentClipId: e.parentId, text: e.text, strategy: e.strategy);
      emit(ChunkState(session: session));
    });
    on<ChunkPasteNext>((e, emit) async {
      final s = state.session;
      if (s == null || s.isComplete) return;
      // TODO: write current segment to OS clipboard
      s.advance();
      emit(ChunkState(session: s));
    });
    on<ChunkCancel>((e, emit) {
      state.session?.isActive = false;
      emit(const ChunkState());
    });
    on<ChunkJumpTo>((e, emit) {
      final s = state.session;
      if (s == null) return;
      s.currentIndex = e.index.clamp(0, s.totalSegments - 1);
      emit(ChunkState(session: s));
    });
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// search_bloc.dart
// ═══════════════════════════════════════════════════════════════════════════

abstract class SearchEvent extends Equatable {
  const SearchEvent();
  @override List<Object?> get props => [];
}
class SearchQuery   extends SearchEvent { final String query; const SearchQuery(this.query); @override List<Object?> get props => [query]; }
class SearchClear   extends SearchEvent { const SearchClear(); }

class SearchState extends Equatable {
  final String query;
  final List<ClipRecord> results;
  final bool isLoading;

  const SearchState({this.query = '', this.results = const [], this.isLoading = false});
  SearchState copyWith({String? query, List<ClipRecord>? results, bool? isLoading}) =>
    SearchState(query: query ?? this.query, results: results ?? this.results, isLoading: isLoading ?? this.isLoading);
  @override List<Object?> get props => [query, results.length, isLoading];
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final ClipRepository clipRepo;

  SearchBloc({required this.clipRepo}) : super(const SearchState()) {
    on<SearchQuery>(_onQuery, transformer: (events, mapper) =>
      events.debounceTime(const Duration(milliseconds: 250)).asyncExpand(mapper));
    on<SearchClear>((e, emit) => emit(const SearchState()));
  }

  Future<void> _onQuery(SearchQuery event, Emitter<SearchState> emit) async {
    if (event.query.trim().isEmpty) { emit(const SearchState()); return; }
    emit(state.copyWith(query: event.query, isLoading: true));
    final results = await clipRepo.search(event.query);
    emit(state.copyWith(results: results, isLoading: false));
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// settings_bloc.dart
// ═══════════════════════════════════════════════════════════════════════════

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override List<Object?> get props => [];
}
class SettingsLoad   extends SettingsEvent { const SettingsLoad(); }
class SettingsUpdate extends SettingsEvent { final AppSettings settings; const SettingsUpdate(this.settings); @override List<Object?> get props => [settings]; }

class SettingsState extends Equatable {
  final AppSettings settings;
  ThemeMode get themeMode => settings.themeMode;

  const SettingsState({this.settings = const AppSettings()});
  SettingsState copyWith({AppSettings? settings}) => SettingsState(settings: settings ?? this.settings);
  @override List<Object?> get props => [settings];
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository settingsRepo;
  final SettingsService settingsService;

  SettingsBloc({required this.settingsRepo, required this.settingsService}) : super(const SettingsState()) {
    on<SettingsLoad>((e, emit) => emit(SettingsState(settings: settingsRepo.current)));
    on<SettingsUpdate>((e, emit) async {
      await settingsService.update(e.settings);
      emit(SettingsState(settings: e.settings));
    });
  }
}
