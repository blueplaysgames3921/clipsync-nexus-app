// ignore_for_file: lines_longer_than_80_chars
// All feature views consolidated — imports must be at top in Dart.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reorderables/reorderables.dart';

import '../../../core/services/teleport_service.dart';
import '../../../data/models/clip_record.dart';
import '../../../shared/theme/app_theme.dart';
import '../../chunking/bloc/chunk_bloc.dart';
import '../../clipboard/bloc/clipboard_bloc.dart';
import '../../ghost_layer/bloc/ghost_bloc.dart';
import '../../scratchpad/bloc/scratchpad_bloc.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../../stack_mode/bloc/stack_bloc.dart';
import '../../teleport/bloc/teleport_bloc.dart';



// ═══════════════════════════════════════════════════════════════════════════
//              TeleportView, GhostView, SettingsView + shared widgets
// ═══════════════════════════════════════════════════════════════════════════



class StackView extends StatelessWidget {
  const StackView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BlocBuilder<StackBloc, StackState>(
      builder: (ctx, state) => Column(children: [
        // Header
        _ViewHeader(
          title: 'Stack Mode',
          subtitle: state.isActive
            ? '${state.queue.length} queued · ${state.remaining} remaining'
            : 'Inactive',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            _Chip(
              label: state.cycleMode ? 'Cycle ON' : 'Cycle OFF',
              active: state.cycleMode,
              onTap: () => ctx.read<StackBloc>().add(const StackToggleCycle()),
              colors: colors,
            ),
            const SizedBox(width: 8),
            _Chip(
              label: state.isActive ? 'STACK ON' : 'Stack Off',
              active: state.isActive,
              onTap: () => ctx.read<StackBloc>().add(const StackToggleMode()),
              colors: colors,
            ),
          ]),
        ),

        // Queue
        Expanded(
          child: state.queue.isEmpty
            ? _Empty('Enable Stack Mode then copy items\nto queue them for sequential paste')
            : ReorderableColumn(
                padding: const EdgeInsets.all(12),
                onReorder: (o, n) => ctx.read<StackBloc>().add(StackReorder(o, n)),
                children: state.queue.asMap().entries.map((e) {
                  final i = e.key;
                  final clip = e.value;
                  final isCurrent = i == state.pointer;
                  final isDone = i < state.pointer;
                  return _StackItem(
                    key: ValueKey(clip.id + i.toString()),
                    index: i,
                    clip: clip,
                    isCurrent: isCurrent,
                    isDone: isDone,
                    onRemove: () => ctx.read<StackBloc>().add(StackRemoveAt(i)),
                    colors: colors,
                  );
                }).toList(),
              ),
        ),

        // Controls
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: state.isActive && !state.isExhausted
                  ? () => ctx.read<StackBloc>().add(const StackPasteNext())
                  : null,
                icon: const Icon(Icons.keyboard_return_rounded, size: 16),
                label: Text(state.isExhausted
                  ? 'Stack Exhausted'
                  : 'Paste Next (${state.pointer + 1}/${state.queue.length})'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => ctx.read<StackBloc>().add(const StackClear()),
              child: const Text('Clear'),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _StackItem extends StatelessWidget {
  final int index;
  final ClipRecord clip;
  final bool isCurrent;
  final bool isDone;
  final VoidCallback onRemove;
  final AppColors colors;

  const _StackItem({super.key, required this.index, required this.clip,
    required this.isCurrent, required this.isDone, required this.onRemove, required this.colors});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDone ? 0.4 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent ? colors.accentBg : colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent ? colors.accentDim : colors.border,
          ),
        ),
        child: Row(children: [
          // Drag handle
          Icon(Icons.drag_handle_rounded, size: 16, color: colors.text3),
          const SizedBox(width: 8),
          // Index
          SizedBox(
            width: 24,
            child: Text('${index + 1}',
              style: AppTheme.mono(size: 10, color: colors.text3)),
          ),
          // Preview
          Expanded(
            child: Text(
              clip.preview,
              style: TextStyle(fontSize: 12, color: isCurrent ? colors.accent : colors.text2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Status
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.accentBg,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('NEXT', style: AppTheme.mono(size: 9, color: colors.accent)),
            )
          else if (isDone)
            Icon(Icons.check_circle_rounded, size: 14, color: colors.green)
          else
            IconButton(
              icon: Icon(Icons.close_rounded, size: 14, color: colors.text3),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            ),
        ]),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// scratchpad_view.dart
// ═══════════════════════════════════════════════════════════════════════════

class ScratchpadView extends StatefulWidget {
  const ScratchpadView({super.key});
  @override State<ScratchpadView> createState() => _ScratchpadViewState();
}

class _ScratchpadViewState extends State<ScratchpadView> {
  String _separator = '\n\n';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BlocBuilder<ScratchpadBloc, ScratchpadState>(
      builder: (ctx, state) => Column(children: [
        _ViewHeader(
          title: 'Scratchpad',
          subtitle: '${state.blocks.length} block${state.blocks.length != 1 ? 's' : ''}',
          trailing: OutlinedButton.icon(
            onPressed: () => ctx.read<ScratchpadBloc>().add(const ScratchClear()),
            icon: const Icon(Icons.clear_all_rounded, size: 14),
            label: const Text('Clear'),
          ),
        ),

        // Blocks list
        Expanded(
          child: state.blocks.isEmpty
            ? _Empty('Right-click any clip and choose\n"Add to Scratchpad" to start')
            : ReorderableColumn(
                padding: const EdgeInsets.all(12),
                onReorder: (o, n) => ctx.read<ScratchpadBloc>().add(ScratchReorder(o, n)),
                children: state.blocks.asMap().entries.map((e) {
                  final block = e.value;
                  return _ScratchBlock(
                    key: ValueKey(block.id),
                    block: block,
                    colors: colors,
                    onEdit: (t) => ctx.read<ScratchpadBloc>().add(ScratchEditBlock(block.id, t)),
                    onRemove: () => ctx.read<ScratchpadBloc>().add(ScratchRemoveBlock(block.id)),
                  );
                }).toList(),
              ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: Row(children: [
            Text('Separator:', style: AppTheme.mono(size: 11, color: colors.text3)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _separator,
              items: const [
                DropdownMenuItem(value: '\n\n',     child: Text('Blank line')),
                DropdownMenuItem(value: '\n---\n',  child: Text('Divider')),
                DropdownMenuItem(value: ' ',        child: Text('Space')),
                DropdownMenuItem(value: '',         child: Text('None')),
              ],
              onChanged: (v) => setState(() => _separator = v ?? '\n\n'),
              style: AppTheme.mono(size: 11, color: context.colors.text),
              dropdownColor: colors.surface2,
              underline: const SizedBox.shrink(),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: state.blocks.isEmpty
                ? null
                : () => ctx.read<ScratchpadBloc>().add(ScratchMerge(_separator)),
              icon: const Icon(Icons.merge_rounded, size: 14),
              label: const Text('Merge to Clipboard'),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ScratchBlock extends StatelessWidget {
  final ScratchBlock block;
  final AppColors colors;
  final ValueChanged<String> onEdit;
  final VoidCallback onRemove;

  const _ScratchBlock({super.key, required this.block, required this.colors,
    required this.onEdit, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Block header
        Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(children: [
            Icon(Icons.drag_handle_rounded, size: 14, color: colors.text3),
            const SizedBox(width: 6),
            Text(block.sourceClip.metadata.sourceApp ?? 'Unknown',
              style: AppTheme.mono(size: 10, color: colors.text3)),
            const Spacer(),
            InkWell(
              onTap: onRemove,
              child: Icon(Icons.close_rounded, size: 14, color: colors.text3),
            ),
          ]),
        ),
        // Editable text
        TextFormField(
          initialValue: block.editText,
          onChanged: onEdit,
          maxLines: null,
          style: TextStyle(fontSize: 13, color: colors.text2, height: 1.55),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.all(10),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ]),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// chunk_view.dart
// ═══════════════════════════════════════════════════════════════════════════

class ChunkView extends StatefulWidget {
  const ChunkView({super.key});
  @override State<ChunkView> createState() => _ChunkViewState();
}

class _ChunkViewState extends State<ChunkView> {
  final _inputCtrl = TextEditingController();
  ChunkStrategy _strategy = ChunkStrategy.paragraph;

  @override
  void dispose() { _inputCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BlocBuilder<ChunkBloc, ChunkState>(
      builder: (ctx, state) => Column(children: [
        _ViewHeader(title: 'Chunk Engine', subtitle: 'Sequence-paste large content safely'),

        Expanded(
          child: state.session == null
            ? _InputPane(
                ctrl: _inputCtrl,
                strategy: _strategy,
                onStrategyChange: (s) => setState(() => _strategy = s),
                onSegment: () {
                  final text = _inputCtrl.text.trim();
                  if (text.isEmpty) return;
                  ctx.read<ChunkBloc>().add(ChunkCreate(
                    parentId: 'manual_${DateTime.now().millisecondsSinceEpoch}',
                    text: text,
                    strategy: _strategy,
                  ));
                },
                colors: colors,
              )
            : _SessionPane(session: state.session!, colors: colors),
        ),

        // Controls
        if (state.session != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Row(children: [
              // Progress bar
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Segment ${state.session!.currentIndex + 1} of ${state.session!.totalSegments}',
                      style: AppTheme.mono(size: 10, color: colors.text3)),
                    const Spacer(),
                    Text('${(state.session!.progress * 100).toStringAsFixed(0)}%',
                      style: AppTheme.mono(size: 10, color: colors.accent)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: state.session!.progress,
                      minHeight: 4,
                      backgroundColor: colors.surface3,
                      valueColor: AlwaysStoppedAnimation(colors.accent),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: state.session!.isComplete ? null
                  : () => ctx.read<ChunkBloc>().add(const ChunkPasteNext()),
                icon: const Icon(Icons.keyboard_return_rounded, size: 14),
                label: Text(state.session!.isComplete ? 'Complete ✓' : 'Paste Next'),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => ctx.read<ChunkBloc>().add(const ChunkCancel()),
                child: const Text('Cancel'),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _InputPane extends StatelessWidget {
  final TextEditingController ctrl;
  final ChunkStrategy strategy;
  final ValueChanged<ChunkStrategy> onStrategyChange;
  final VoidCallback onSegment;
  final AppColors colors;

  const _InputPane({required this.ctrl, required this.strategy,
    required this.onStrategyChange, required this.onSegment, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PASTE LARGE TEXT TO SEGMENT', style: AppTheme.mono(size: 10, color: colors.text3)),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            controller: ctrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: AppTheme.mono(size: 12, color: colors.text),
            decoration: InputDecoration(
              hintText: 'Paste text here (500+ characters recommended)…',
              alignLabelWithHint: true,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Text('Strategy:', style: AppTheme.mono(size: 11, color: colors.text3)),
          const SizedBox(width: 10),
          DropdownButton<ChunkStrategy>(
            value: strategy,
            dropdownColor: colors.surface2,
            style: AppTheme.mono(size: 11, color: colors.text),
            underline: const SizedBox.shrink(),
            items: ChunkStrategy.values.map((s) => DropdownMenuItem(
              value: s,
              child: Text(s.name),
            )).toList(),
            onChanged: (s) { if (s != null) onStrategyChange(s); },
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: onSegment,
            icon: const Icon(Icons.content_cut_rounded, size: 14),
            label: const Text('Segment'),
          ),
        ]),
      ]),
    );
  }
}

class _SessionPane extends StatelessWidget {
  final ChunkSession session;
  final AppColors colors;
  const _SessionPane({required this.session, required this.colors});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: session.totalSegments,
      itemBuilder: (ctx, i) {
        final isDone    = i < session.currentIndex;
        final isCurrent = i == session.currentIndex;
        final text      = session.segments[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDone    ? colors.greenBg
                 : isCurrent ? colors.accentBg
                 : colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDone    ? colors.green.withOpacity(0.3)
                   : isCurrent ? colors.accentDim
                   : colors.border,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('SEGMENT ${i + 1} / ${session.totalSegments}',
                style: AppTheme.mono(size: 9, color: isDone ? colors.green : isCurrent ? colors.accent : colors.text3)),
              const Spacer(),
              if (isDone)    Icon(Icons.check_rounded, size: 14, color: colors.green)
              else if (isCurrent) Text('← READY', style: AppTheme.mono(size: 9, color: colors.accent))
              else Text('Queued', style: AppTheme.mono(size: 9, color: colors.text3)),
            ]),
            const SizedBox(height: 6),
            Text(
              text.length > 200 ? '${text.substring(0, 200)}…' : text,
              style: AppTheme.mono(size: 11, color: isDone ? colors.text3 : colors.text2),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        );
      },
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// teleport_view.dart
// ═══════════════════════════════════════════════════════════════════════════

class TeleportView extends StatelessWidget {
  const TeleportView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BlocBuilder<TeleportBloc, TeleportState>(
      builder: (ctx, state) => Column(children: [
        _ViewHeader(title: 'Teleport', subtitle: 'P2P encrypted local network sync'),

        // Status banner
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.greenBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.green.withOpacity(0.4)),
          ),
          child: Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: colors.green,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: colors.green.withOpacity(0.5), blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 10),
            Text('Broadcasting on local network · _clipsyncteleport._tcp',
              style: AppTheme.mono(size: 11, color: colors.green)),
          ]),
        ),

        // Pairing SAS dialog
        if (state.pairingSasCode != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.amberBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.amber.withOpacity(0.5)),
            ),
            child: Column(children: [
              Text('Pairing Code — verify this matches on both devices',
                style: TextStyle(fontSize: 12, color: colors.amber)),
              const SizedBox(height: 10),
              Text(state.pairingSasCode!,
                style: AppTheme.mono(size: 36, color: colors.amber)
                    .copyWith(letterSpacing: 8, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                OutlinedButton(
                  onPressed: () => ctx.read<TeleportBloc>().add(
                    TeleportConfirmPair(state.pairingPeerId!, confirmed: false)),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => ctx.read<TeleportBloc>().add(
                    TeleportConfirmPair(state.pairingPeerId!, confirmed: true)),
                  child: const Text('Confirm Match'),
                ),
              ]),
            ]),
          ),

        // Peers list
        Expanded(
          child: state.peers.isEmpty
            ? _Empty('No devices found on local network\nMake sure ClipSync Nexus is running on other devices')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('DISCOVERED PEERS',
                    style: AppTheme.mono(size: 10, color: colors.text3)
                        .copyWith(letterSpacing: 0.1)),
                  const SizedBox(height: 10),
                  ...state.peers.map((p) => _PeerCard(
                    peer: p,
                    colors: colors,
                    onSend: () {
                      // Get selected clip from ClipboardBloc; inform user if none selected
                      final clipState = ctx.read<ClipboardBloc>().state;
                      final clip = clipState.selectedClip;
                      if (clip == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Select a clip in the History tab first')),
                        );
                        return;
                      }
                      ctx.read<TeleportBloc>().add(TeleportSendClip(p.id, clip));
                    },
                    onPair: () => ctx.read<TeleportBloc>().add(TeleportInitiatePair(p.id)),
                  )),
                ],
              ),
        ),

        // Transfer progress
        if (state.activeTransfer != null)
          _TransferBar(progress: state.activeTransfer!, colors: colors),
      ]),
    );
  }
}

class _PeerCard extends StatelessWidget {
  final TeleportPeer peer;
  final AppColors colors;
  final VoidCallback onSend;
  final VoidCallback onPair;

  const _PeerCard({required this.peer, required this.colors, required this.onSend, required this.onPair});

  @override
  Widget build(BuildContext context) {
    final isOnline = peer.status == PeerStatus.online;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isOnline ? colors.greenBg : colors.surface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(
            switch (peer.platform) {
              'android' => '📱',
              'windows' => '🖥️',
              'macos'   => '💻',
              _         => '📡',
            }, style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(peer.displayName, style: context.text.labelLarge),
            const SizedBox(height: 2),
            Text('${peer.platform} · ${peer.publicKeyFingerprint}',
              style: AppTheme.mono(size: 10, color: colors.text3)),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: isOnline ? colors.green : colors.text3,
                  shape: BoxShape.circle,
                  boxShadow: isOnline ? [BoxShadow(color: colors.green.withOpacity(0.5), blurRadius: 4)] : null,
                ),
              ),
              const SizedBox(width: 5),
              Text(isOnline ? 'Online' : 'Offline',
                style: AppTheme.mono(size: 10, color: colors.text3)),
              if (peer.isTrusted) ...[
                const SizedBox(width: 8),
                Icon(Icons.verified_rounded, size: 11, color: colors.green),
                const SizedBox(width: 3),
                Text('Trusted', style: AppTheme.mono(size: 10, color: colors.green)),
              ],
            ]),
          ]),
        ),
        if (isOnline) ...[
          if (!peer.isTrusted)
            OutlinedButton.icon(
              onPressed: onPair,
              icon: const Icon(Icons.link_rounded, size: 12),
              label: const Text('Pair'),
            )
          else
            ElevatedButton.icon(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded, size: 12),
              label: const Text('Send Clip'),
            ),
        ],
      ]),
    );
  }
}

class _TransferBar extends StatelessWidget {
  final TransferProgress progress;
  final AppColors colors;
  const _TransferBar({required this.progress, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text(progress.isComplete ? '✓ Transfer complete' : 'Sending…',
            style: TextStyle(fontSize: 12, color: progress.isComplete ? colors.green : colors.text2)),
          const Spacer(),
          Text('${(progress.progress * 100).toStringAsFixed(0)}%',
            style: AppTheme.mono(size: 11, color: colors.accent)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress.progress,
            minHeight: 4,
            backgroundColor: colors.surface3,
            valueColor: AlwaysStoppedAnimation(
              progress.isComplete ? colors.green : colors.accent),
          ),
        ),
      ]),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// ghost_view.dart
// ═══════════════════════════════════════════════════════════════════════════

class GhostView extends StatelessWidget {
  const GhostView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BlocBuilder<GhostBloc, GhostState>(
      builder: (ctx, state) => Column(children: [
        _ViewHeader(
          title: 'Ghost Layer',
          subtitle: '${state.sensitiveItems.length} sensitive item${state.sensitiveItems.length != 1 ? 's' : ''}',
        ),
        Expanded(
          child: state.sensitiveItems.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle_outline_rounded, size: 40, color: colors.green),
                const SizedBox(height: 12),
                Text('No sensitive data detected', style: TextStyle(color: colors.text3, fontSize: 13)),
              ]))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: state.sensitiveItems.map((clip) =>
                  _GhostCard(clip: clip, colors: colors,
                    onPurge:    () => ctx.read<GhostBloc>().add(GhostPurgeNow(clip.id)),
                    onExtend:   () => ctx.read<GhostBloc>().add(GhostExtendTtl(clip.id, 60)),
                    onUnflag:   () => ctx.read<GhostBloc>().add(GhostMarkNotSensitive(clip.id)),
                  ),
                ).toList(),
              ),
        ),
      ]),
    );
  }
}

class _GhostCard extends StatefulWidget {
  final ClipRecord clip;
  final AppColors colors;
  final VoidCallback onPurge;
  final VoidCallback onExtend;
  final VoidCallback onUnflag;
  const _GhostCard({required this.clip, required this.colors, required this.onPurge, required this.onExtend, required this.onUnflag});
  @override State<_GhostCard> createState() => _GhostCardState();
}

class _GhostCardState extends State<_GhostCard> {
  Timer? _timer;
  double _fraction = 1.0;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    if (!mounted) return;
    final expiry = widget.clip.ttlExpiry;
    if (expiry == null) return;
    final rem = expiry.difference(DateTime.now()).inSeconds;
    setState(() => _fraction = (rem / 60).clamp(0.0, 1.0));
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final rem = widget.clip.ttlExpiry?.difference(DateTime.now()).inSeconds.clamp(0, 9999) ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.redBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.red.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.timer_outlined, size: 13, color: colors.red),
          const SizedBox(width: 6),
          Text('${widget.clip.sensitivityCategory.name.toUpperCase()} — purges in ${rem}s',
            style: AppTheme.mono(size: 11, color: colors.red)),
        ]),
        const SizedBox(height: 8),
        Text(
          widget.clip.isSensitive ? '••••••••••••••••••••' : widget.clip.preview,
          style: AppTheme.mono(size: 12, color: colors.text2),
          maxLines: 2, overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: _fraction, minHeight: 3,
            backgroundColor: colors.red.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(colors.red),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          OutlinedButton(onPressed: widget.onPurge, style: OutlinedButton.styleFrom(foregroundColor: colors.red, side: BorderSide(color: colors.red.withOpacity(0.5))), child: const Text('Purge Now')),
          const SizedBox(width: 6),
          OutlinedButton(onPressed: widget.onExtend, child: const Text('+60s')),
          const SizedBox(width: 6),
          OutlinedButton(onPressed: widget.onUnflag, child: const Text('Not Sensitive')),
        ]),
      ]),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// settings_view.dart
// ═══════════════════════════════════════════════════════════════════════════

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (ctx, state) {
        final s = state.settings;
        return Column(children: [
          _ViewHeader(title: 'Settings', subtitle: 'ClipSync Nexus configuration'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SettingsGroup('Storage', colors, [
                  _SettingsSlider('Max History Slots', s.maxSlots.toDouble(), 50, 1000,
                    '${s.maxSlots} slots', (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(maxSlots: v.round()))), colors),
                  _SettingsToggle('Encrypt Database (AES-256)', s.encryptDatabase,
                    (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(encryptDatabase: v))), colors),
                ]),
                _SettingsGroup('Ghost Layer', colors, [
                  _SettingsToggle('Enable Ghost Layer', s.ghostLayerEnabled,
                    (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(ghostLayerEnabled: v))), colors),
                  _SettingsSlider('Default TTL (seconds)', s.ghostDefaultTtlSeconds.toDouble(), 10, 600,
                    '${s.ghostDefaultTtlSeconds}s', (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(ghostDefaultTtlSeconds: v.round()))), colors),
                  _SettingsToggle('Detect API Keys',       s.detectApiKeys,      (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(detectApiKeys: v))), colors),
                  _SettingsToggle('Detect Credit Cards',   s.detectCreditCards,  (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(detectCreditCards: v))), colors),
                  _SettingsToggle('Detect Passwords',      s.detectPasswords,    (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(detectPasswords: v))), colors),
                  _SettingsToggle('Detect Private Keys',   s.detectPrivateKeys,  (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(detectPrivateKeys: v))), colors),
                  _SettingsToggle('Detect SSNs',           s.detectSsn,          (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(detectSsn: v))), colors),
                  _SettingsToggle('Detect Bank Accounts',  s.detectBankAccounts, (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(detectBankAccounts: v))), colors),
                ]),
                _SettingsGroup('Clean Room', colors, [
                  _SettingsToggle('Enable Clean Room',          s.cleanRoomEnabled,       (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(cleanRoomEnabled: v))), colors),
                  _SettingsToggle('Auto-clean URLs',            s.cleanRoomMode,          (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(cleanRoomMode: v))), colors),
                  _SettingsToggle('Strip EXIF GPS from Images', s.stripExifGps,           (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(stripExifGps: v))), colors),
                  _SettingsToggle('Strip All EXIF',             s.stripAllExif,           (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(stripAllExif: v))), colors),
                  _SettingsToggle('Strip Document Metadata',    s.stripDocumentMetadata,  (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(stripDocumentMetadata: v))), colors),
                  _SettingsToggle('Strip Zero-Width Chars',     s.stripZeroWidthChars,    (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(stripZeroWidthChars: v))), colors),
                  _SettingsToggle('Resolve Short URLs',         s.resolveRedirects,       (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(resolveRedirects: v))), colors),
                ]),
                _SettingsGroup('Smart Chunking', colors, [
                  _SettingsToggle('Auto-detect & chunk large content', s.autoChunkEnabled, (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(autoChunkEnabled: v))), colors),
                  _SettingsSlider('Chunk threshold (chars)', s.chunkThresholdChars.toDouble(), 1000, 100000,
                    '${(s.chunkThresholdChars / 1000).toStringAsFixed(0)}k chars',
                    (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(chunkThresholdChars: v.round()))), colors),
                  _SettingsSlider('Target chunk size (chars)', s.chunkTargetChars.toDouble(), 500, 50000,
                    '${(s.chunkTargetChars / 1000).toStringAsFixed(1)}k chars',
                    (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(chunkTargetChars: v.round()))), colors),
                ]),
                _SettingsGroup('Search & OCR', colors, [
                  _SettingsToggle('Semantic Vector Search', s.semanticSearchEnabled, (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(semanticSearchEnabled: v))), colors),
                  _SettingsToggle('OCR on Images',          s.ocrEnabled,            (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(ocrEnabled: v))), colors),
                ]),
                _SettingsGroup('Teleport', colors, [
                  _SettingsToggle('Enable Teleport',            s.teleportEnabled,       (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(teleportEnabled: v))), colors),
                  _SettingsToggle('Block Sensitive via Teleport',s.teleportBlockSensitive,(v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(teleportBlockSensitive: v))), colors),
                ]),
                _SettingsGroup('Appearance', colors, [
                  _SettingsToggle('Compact Density', s.compactDensity, (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(compactDensity: v))), colors),
                  _SettingsToggle('Reduce Motion',   s.reduceMotion,   (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(reduceMotion: v))), colors),
                  _SettingsToggle('High Contrast',   s.highContrast,   (v) => ctx.read<SettingsBloc>().add(SettingsUpdate(s.copyWith(highContrast: v))), colors),
                ]),
              ],
            ),
          ),
        ]);
      },
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final AppColors colors;
  final List<Widget> children;
  const _SettingsGroup(this.title, this.colors, this.children);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(title.toUpperCase(), style: AppTheme.mono(size: 10, color: colors.text3).copyWith(letterSpacing: 0.1)),
      ),
      Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Column(children: children),
      ),
    ]);
  }
}

class _SettingsToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChange;
  final AppColors colors;
  const _SettingsToggle(this.label, this.value, this.onChange, this.colors);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border, width: 0.5))),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: colors.text))),
        Switch(value: value, onChanged: onChange),
      ]),
    );
  }
}

class _SettingsSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChange;
  final AppColors colors;
  const _SettingsSlider(this.label, this.value, this.min, this.max, this.display, this.onChange, this.colors);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border, width: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: TextStyle(fontSize: 13, color: colors.text)),
          const Spacer(),
          Text(display, style: AppTheme.mono(size: 11, color: colors.accent)),
        ]),
        Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChange),
      ]),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// Shared widgets used by all views
// ═══════════════════════════════════════════════════════════════════════════

class _ViewHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _ViewHeader({required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 0, 14, 0),
      height: 48,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(children: [
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: context.text.labelLarge?.copyWith(fontSize: 13)),
          Text(subtitle, style: AppTheme.mono(size: 10, color: colors.text3)),
        ]),
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final AppColors colors;
  const _Chip({required this.label, required this.active, required this.onTap, required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? colors.accentBg : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? colors.accentDim : colors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: active ? colors.accent : colors.text3,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: AppTheme.mono(size: 10, color: active ? colors.accent : colors.text3)),
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String message;
  const _Empty(this.message);
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Text(message,
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.text3, fontSize: 13, height: 1.6)),
    );
  }
}
