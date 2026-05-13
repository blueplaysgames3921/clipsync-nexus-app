import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/clip_record.dart';
import '../../../shared/theme/app_theme.dart';
import '../../clipboard/bloc/clipboard_bloc.dart';
import '../../search/bloc/search_bloc.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../../stack_mode/bloc/stack_bloc.dart';
import '../../scratchpad/bloc/scratchpad_bloc.dart';
import 'clip_card.dart';
import 'clip_detail_panel.dart';

class ClipboardView extends StatefulWidget {
  const ClipboardView({super.key});
  @override State<ClipboardView> createState() => _ClipboardViewState();
}

class _ClipboardViewState extends State<ClipboardView> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  ClipContentType? _filterType;
  bool _sensitiveOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(children: [
      // ── LEFT: search + list ──────────────────────────────────────────────
      SizedBox(
        width: 320,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(right: BorderSide(color: colors.border)),
          ),
          child: Column(children: [
            // Top bar
            _TopBar(
              filterType: _filterType,
              sensitiveOnly: _sensitiveOnly,
              onFilter: _applyFilter,
            ),
            // Search
            _SearchBar(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: (q) {
                setState(() {}); // rebuild to pass updated searchQuery to _ClipList
                if (q.isEmpty) {
                  context.read<SearchBloc>().add(const SearchClear());
                } else {
                  context.read<SearchBloc>().add(SearchQuery(q));
                }
              },
            ),
            // Filter chips
            _FilterRail(
              active: _filterType,
              sensitiveOnly: _sensitiveOnly,
              onSelect: _applyFilter,
            ),
            // Clip list
            Expanded(child: _ClipList(
              filterType: _filterType,
              sensitiveOnly: _sensitiveOnly,
              searchQuery: _searchCtrl.text,
            )),
          ]),
        ),
      ),
      // ── RIGHT: detail ────────────────────────────────────────────────────
      const Expanded(child: ClipDetailPanel()),
    ]);
  }

  void _applyFilter(ClipContentType? type, bool sensitive) {
    setState(() { _filterType = type; _sensitiveOnly = sensitive; });
    context.read<ClipboardBloc>().add(ClipboardFilterChanged(
      filterType: type, sensitiveOnly: sensitive,
    ));
  }
}

// ── TOP BAR ───────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final ClipContentType? filterType;
  final bool sensitiveOnly;
  final void Function(ClipContentType?, bool) onFilter;

  const _TopBar({required this.filterType, required this.sensitiveOnly, required this.onFilter});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))),
      child: Row(children: [
        Text('History', style: context.text.labelLarge?.copyWith(color: colors.text2, letterSpacing: 0.05, fontSize: 11, fontWeight: FontWeight.w600)),
        const Spacer(),
        BlocBuilder<ClipboardBloc, ClipboardState>(
          builder: (ctx, s) {
            final maxSlots = ctx.read<SettingsBloc>().state.settings.maxSlots;
            return Text(
              '${s.totalCount} / $maxSlots',
              style: AppTheme.mono(size: 11, color: colors.text3),
            );
          },
        ),
      ]),
    );
  }
}

// ── SEARCH BAR ────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.focusNode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: TextStyle(color: colors.text, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search… (type:code, from:app)',
          prefixIcon: Icon(Icons.search_rounded, size: 16, color: colors.text3),
          suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close_rounded, size: 14, color: colors.text3),
                onPressed: () { controller.clear(); onChanged(''); },
              )
            : null,
          isDense: true,
        ),
      ),
    );
  }
}

// ── FILTER CHIPS ──────────────────────────────────────────────────────────

class _FilterRail extends StatelessWidget {
  final ClipContentType? active;
  final bool sensitiveOnly;
  final void Function(ClipContentType?, bool) onSelect;

  const _FilterRail({required this.active, required this.sensitiveOnly, required this.onSelect});

  static const _filters = [
    (label: 'All',      type: null,                       sensitive: false, icon: Icons.apps_rounded),
    (label: 'Text',     type: ClipContentType.plainText,  sensitive: false, icon: Icons.text_fields_rounded),
    (label: 'Code',     type: ClipContentType.code,       sensitive: false, icon: Icons.code_rounded),
    (label: 'URLs',     type: ClipContentType.url,        sensitive: false, icon: Icons.link_rounded),
    (label: 'Images',   type: ClipContentType.image,      sensitive: false, icon: Icons.image_rounded),
    (label: 'Sensitive',type: null,                       sensitive: true,  icon: Icons.shield_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: _filters.map((f) {
          final isActive = f.sensitive ? sensitiveOnly : active == f.type;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: () => onSelect(f.type, f.sensitive),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? colors.accentBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? colors.accentDim : colors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(f.icon, size: 11,
                      color: isActive ? colors.accent : colors.text3),
                    const SizedBox(width: 4),
                    Text(f.label,
                      style: AppTheme.mono(size: 10,
                        color: isActive ? colors.accent : colors.text3)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── CLIP LIST ─────────────────────────────────────────────────────────────

class _ClipList extends StatelessWidget {
  final ClipContentType? filterType;
  final bool sensitiveOnly;
  final String searchQuery;

  const _ClipList({required this.filterType, required this.sensitiveOnly, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Show search results if query active, else show full history
    if (searchQuery.isNotEmpty) {
      return BlocBuilder<SearchBloc, SearchState>(
        builder: (ctx, state) {
          if (state.isLoading) return _Loading(colors: colors);
          if (state.results.isEmpty) return _Empty(label: 'No results for "$searchQuery"');
          return _List(clips: state.results, searchQuery: searchQuery);
        },
      );
    }

    return BlocBuilder<ClipboardBloc, ClipboardState>(
      builder: (ctx, state) {
        if (state.status == ClipboardStatus.loading) return _Loading(colors: colors);
        if (state.clips.isEmpty) return _Empty(label: 'No clipboard history yet');
        return _List(clips: state.clips, searchQuery: '');
      },
    );
  }
}

class _List extends StatelessWidget {
  final List<ClipRecord> clips;
  final String searchQuery;
  const _List({required this.clips, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      itemCount: clips.length,
      // Virtual-scroll: only build visible items
      itemExtentBuilder: (i, _) => 80, // approx card height
      itemBuilder: (ctx, i) {
        final clip = clips[i];
        return ClipCard(
          key: ValueKey(clip.id),
          clip: clip,
          searchQuery: searchQuery,
          onTap: () => ctx.read<ClipboardBloc>().add(ClipboardSelect(clip.id)),
          onDelete: () => ctx.read<ClipboardBloc>().add(ClipboardDelete(clip.id)),
          onPin: (p) => ctx.read<ClipboardBloc>().add(ClipboardPin(clip.id, pinned: p)),
          onAddToStack: () {
            ctx.read<StackBloc>().add(StackPush(clip));
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('Added to stack (${ctx.read<StackBloc>().state.queue.length} items)')),
            );
          },
          onAddToScratch: () {
            ctx.read<ScratchpadBloc>().add(ScratchAddBlock(clip));
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Added to Scratchpad')),
            );
          },
        ).animate().fadeIn(duration: 150.ms).slideY(begin: 0.05, duration: 150.ms);
      },
    );
  }
}

class _Loading extends StatelessWidget {
  final AppColors colors;
  const _Loading({required this.colors});
  @override
  Widget build(BuildContext context) => Center(
    child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2),
  );
}

class _Empty extends StatelessWidget {
  final String label;
  const _Empty({required this.label});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.content_paste_off_rounded, size: 40, color: context.colors.text3),
      const SizedBox(height: 12),
      Text(label, style: TextStyle(color: context.colors.text3, fontSize: 13)),
    ]),
  );
}


