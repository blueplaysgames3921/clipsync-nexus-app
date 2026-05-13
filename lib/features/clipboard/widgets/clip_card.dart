import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../data/models/clip_record.dart';
import '../../../shared/theme/app_theme.dart';

class ClipCard extends StatefulWidget {
  final ClipRecord clip;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool> onPin;
  final VoidCallback onAddToStack;
  final VoidCallback onAddToScratch;
  final bool isSelected;

  const ClipCard({
    super.key,
    required this.clip,
    required this.searchQuery,
    required this.onTap,
    required this.onDelete,
    required this.onPin,
    required this.onAddToStack,
    required this.onAddToScratch,
    this.isSelected = false,
  });

  @override
  State<ClipCard> createState() => _ClipCardState();
}

class _ClipCardState extends State<ClipCard> {
  bool _hovered = false;
  Timer? _ttlTimer;
  double _ttlFraction = 1.0;

  @override
  void initState() {
    super.initState();
    if (widget.clip.isSensitive && widget.clip.ttlExpiry != null) {
      _startTtlTimer();
    }
  }

  void _startTtlTimer() {
    _updateTtl();
    _ttlTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTtl());
  }

  void _updateTtl() {
    if (!mounted) return;
    final expiry = widget.clip.ttlExpiry;
    if (expiry == null) return;
    final total = widget.clip.metadata.exifData['ttlTotal'] != null
        ? int.tryParse(widget.clip.metadata.exifData['ttlTotal']!) ?? 60
        : 60;
    final remaining = expiry.difference(DateTime.now()).inSeconds;
    setState(() {
      _ttlFraction = (remaining / total).clamp(0.0, 1.0);
    });
  }

  @override
  void dispose() {
    _ttlTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final clip = widget.clip;
    final isSensitive = clip.isSensitive;

    return GestureDetector(
      onTap: widget.onTap,
      onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSensitive
                ? colors.redBg
                : widget.isSelected
                    ? colors.accentBg
                    : _hovered
                        ? colors.surface2
                        : colors.surface,
            border: Border.all(
              color: isSensitive
                  ? colors.red.withOpacity(0.5)
                  : widget.isSelected
                      ? colors.accentDim
                      : _hovered
                          ? colors.border2
                          : colors.border,
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 48, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header row
                    Row(children: [
                      _typeIcon(clip.contentType, colors),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          clip.metadata.sourceApp ?? 'Unknown',
                          style: AppTheme.mono(size: 10, color: colors.text3),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (clip.flags.pinned)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.push_pin_rounded, size: 10, color: colors.accent),
                        ),
                      Text(
                        _formatTime(clip.capturedAt),
                        style: AppTheme.mono(size: 10, color: colors.text3),
                      ),
                    ]),
                    const SizedBox(height: 5),
                    // Preview text
                    _PreviewText(
                      clip: clip,
                      searchQuery: widget.searchQuery,
                      colors: colors,
                    ),
                    // Tags
                    if (clip.metadata.aiTags.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _TagRow(tags: clip.metadata.aiTags, colors: colors),
                    ],
                    // TTL countdown for sensitive items
                    if (isSensitive && clip.ttlExpiry != null) ...[
                      const SizedBox(height: 6),
                      _TtlBar(fraction: _ttlFraction, colors: colors, expiry: clip.ttlExpiry!),
                    ],
                  ],
                ),
              ),
              // Hover action buttons
              if (_hovered)
                Positioned(
                  right: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ActionButtons(
                      clip: clip,
                      onDelete: widget.onDelete,
                      onStack: widget.onAddToStack,
                      onScratch: widget.onAddToScratch,
                      colors: colors,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) async {
    final colors = context.colors;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx + 1, position.dy + 1,
      ),
      color: colors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border2),
      ),
      items: [
        _menuItem('paste',   Icons.content_paste_rounded,  'Paste',              colors),
        _menuItem('stack',   Icons.layers_rounded,          'Add to Stack',       colors),
        _menuItem('scratch', Icons.edit_note_rounded,       'Add to Scratchpad',  colors),
        _menuItem('pin',     widget.clip.flags.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                             widget.clip.flags.pinned ? 'Unpin' : 'Pin',         colors),
        if (widget.clip.contentType == ClipContentType.url)
          _menuItem('clean', Icons.cleaning_services_rounded, 'Clean Room',       colors),
        const PopupMenuDivider(),
        _menuItem('delete',  Icons.delete_outline_rounded,  'Delete',             colors, danger: true),
      ],
    );

    if (!mounted) return;
    switch (result) {
      case 'paste':  widget.onTap(); break;
      case 'stack':  widget.onAddToStack(); break;
      case 'scratch':widget.onAddToScratch(); break;
      case 'pin':    widget.onPin(!widget.clip.flags.pinned); break;
      case 'delete': widget.onDelete(); break;
    }
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, AppColors colors, {bool danger = false}) {
    return PopupMenuItem<String>(
      value: value,
      height: 36,
      child: Row(children: [
        Icon(icon, size: 14, color: danger ? colors.red : colors.text2),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(
          fontSize: 13, color: danger ? colors.red : colors.text,
        )),
      ]),
    );
  }

  Widget _typeIcon(ClipContentType type, AppColors colors) {
    final (icon, color) = switch (type) {
      ClipContentType.code      => (Icons.code_rounded, const Color(0xFF7DD3FC)),
      ClipContentType.url       => (Icons.link_rounded, colors.green),
      ClipContentType.image     => (Icons.image_rounded, const Color(0xFF60A5FA)),
      ClipContentType.contact   => (Icons.person_rounded, colors.purple),
      ClipContentType.legal     => (Icons.gavel_rounded, colors.amber),
      ClipContentType.financial => (Icons.attach_money_rounded, colors.green),
      ClipContentType.medical   => (Icons.medical_services_rounded, const Color(0xFFF87171)),
      ClipContentType.color     => (Icons.palette_rounded, colors.purple),
      ClipContentType.fileRef   => (Icons.insert_drive_file_rounded, colors.text3),
      _                         => (Icons.text_fields_rounded, colors.text3),
    };
    return Icon(icon, size: 13, color: color);
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return '${diff.inSeconds}s';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m';
    if (diff.inHours < 24)    return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ── PREVIEW TEXT ──────────────────────────────────────────────────────────

class _PreviewText extends StatelessWidget {
  final ClipRecord clip;
  final String searchQuery;
  final AppColors colors;

  const _PreviewText({required this.clip, required this.searchQuery, required this.colors});

  @override
  Widget build(BuildContext context) {
    final text = clip.preview;
    final isCode = clip.contentType == ClipContentType.code;
    final isUrl  = clip.contentType == ClipContentType.url;

    final baseStyle = isCode
        ? AppTheme.mono(size: 11, color: const Color(0xFF7DD3FC))
        : TextStyle(
            fontSize: 12,
            color: isUrl ? colors.accent : colors.text2,
            height: 1.45,
          );

    if (searchQuery.isEmpty) {
      return Text(text, style: baseStyle, maxLines: 2, overflow: TextOverflow.ellipsis);
    }

    // Highlight search matches
    final spans = _buildHighlightSpans(text, searchQuery, baseStyle, colors);
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<InlineSpan> _buildHighlightSpans(
      String text, String query, TextStyle base, AppColors colors) {
    final spans = <InlineSpan>[];
    final lower = text.toLowerCase();
    final lowerQ = query.toLowerCase();
    int start = 0;
    int idx;

    while ((idx = lower.indexOf(lowerQ, start)) != -1) {
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: base));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: base.copyWith(
          backgroundColor: colors.accent.withOpacity(0.25),
          color: colors.accent,
        ),
      ));
      start = idx + query.length;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: base));
    }
    return spans;
  }
}

// ── TAG ROW ───────────────────────────────────────────────────────────────

class _TagRow extends StatelessWidget {
  final List<String> tags;
  final AppColors colors;

  const _TagRow({required this.tags, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: tags.take(4).map((tag) {
        final (bg, fg) = _tagColors(tag, colors);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
          child: Text(tag.toUpperCase(),
            style: AppTheme.mono(size: 9, color: fg),
          ),
        );
      }).toList(),
    );
  }

  (Color, Color) _tagColors(String tag, AppColors c) => switch (tag) {
    'code'      => (const Color(0xFF1E3A5F), const Color(0xFF7DD3FC)),
    'url'       => (c.greenBg, c.green),
    'sensitive' => (c.redBg, c.red),
    'contact'   => (c.purpleBg, c.purple),
    'legal'     => (c.amberBg, c.amber),
    'image'     => (const Color(0xFF1A2A3A), const Color(0xFF60A5FA)),
    'clean'     => (c.greenBg, c.green),
    'pipeline'  => (c.purpleBg, c.purple),
    _           => (c.surface3, c.text3),
  };
}

// ── TTL BAR ───────────────────────────────────────────────────────────────

class _TtlBar extends StatelessWidget {
  final double fraction;
  final AppColors colors;
  final DateTime expiry;

  const _TtlBar({required this.fraction, required this.colors, required this.expiry});

  @override
  Widget build(BuildContext context) {
    final remaining = expiry.difference(DateTime.now());
    final secs = remaining.inSeconds.clamp(0, 999);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.timer_outlined, size: 10, color: colors.red),
        const SizedBox(width: 3),
        Text(
          'Auto-deletes in ${secs}s',
          style: AppTheme.mono(size: 9, color: colors.red),
        ),
      ]),
      const SizedBox(height: 3),
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: fraction,
          minHeight: 2,
          backgroundColor: colors.red.withOpacity(0.15),
          valueColor: AlwaysStoppedAnimation(colors.red),
        ),
      ),
    ]);
  }
}

// ── ACTION BUTTONS ────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final ClipRecord clip;
  final VoidCallback onDelete;
  final VoidCallback onStack;
  final VoidCallback onScratch;
  final AppColors colors;

  const _ActionButtons({
    required this.clip,
    required this.onDelete,
    required this.onStack,
    required this.onScratch,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Btn(icon: Icons.content_paste_rounded, tooltip: 'Paste', color: colors.accent,
          onTap: () {}),
        const SizedBox(height: 2),
        _Btn(icon: Icons.layers_rounded, tooltip: 'Add to Stack', color: colors.text2,
          onTap: onStack),
        const SizedBox(height: 2),
        _Btn(icon: Icons.delete_outline_rounded, tooltip: 'Delete', color: colors.red,
          onTap: onDelete),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _Btn({required this.icon, required this.tooltip, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colors.border2),
            color: colors.surface3,
          ),
          child: Icon(icon, size: 11, color: color),
        ),
      ),
    );
  }
}
