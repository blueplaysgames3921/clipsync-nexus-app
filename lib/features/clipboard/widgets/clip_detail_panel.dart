import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/clip_record.dart';
import '../../../features/pipelines/pipelines_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../clipboard/bloc/clipboard_bloc.dart';
import '../../ghost_layer/bloc/ghost_bloc.dart';
import '../../scratchpad/bloc/scratchpad_bloc.dart';

class ClipDetailPanel extends StatelessWidget {
  const ClipDetailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClipboardBloc, ClipboardState>(
      buildWhen: (prev, curr) => prev.selectedId != curr.selectedId,
      builder: (ctx, state) {
        final clip = state.selectedClip;
        if (clip == null) return const _EmptyDetail();
        return _Detail(clip: clip);
      },
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.touch_app_rounded, size: 48, color: colors.text3),
        const SizedBox(height: 12),
        Text('Select a clip to inspect',
          style: TextStyle(color: colors.text3, fontSize: 13)),
      ]),
    );
  }
}

class _Detail extends StatefulWidget {
  final ClipRecord clip;
  const _Detail({required this.clip});
  @override State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  bool _showCleanDiff = false;
  String? _pipelineOutput;
  bool _pipelineLoading = false;
  final _pipelinesService = PipelinesService();

  @override
  void didUpdateWidget(_Detail old) {
    super.didUpdateWidget(old);
    if (old.clip.id != widget.clip.id) {
      setState(() { _showCleanDiff = false; _pipelineOutput = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final clip = widget.clip;

    return Column(children: [
      // ── Header ────────────────────────────────────────────────────────
      _DetailHeader(clip: clip, onCleanRoom: () => setState(() => _showCleanDiff = !_showCleanDiff)),

      // ── Body ──────────────────────────────────────────────────────────
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content preview
              _ContentSection(clip: clip, showCleanDiff: _showCleanDiff),
              const SizedBox(height: 20),
              // Pipeline output
              if (_pipelineOutput != null) ...[
                _SectionLabel('Pipeline Output'),
                const SizedBox(height: 6),
                _CodeBox(text: _pipelineOutput!, colors: colors),
                const SizedBox(height: 20),
              ],
              // Metadata
              _MetadataSection(clip: clip),
            ],
          ),
        ),
      ),

      // ── Pipeline Strip ────────────────────────────────────────────────
      _PipelineStrip(
        clip: clip,
        loading: _pipelineLoading,
        onRun: _runPipeline,
      ),
    ]);
  }

  Future<void> _runPipeline(PipelineId id) async {
    setState(() { _pipelineLoading = true; _pipelineOutput = null; });
    final result = await _pipelinesService.run(id, widget.clip.primaryText);
    if (!mounted) return;
    setState(() {
      _pipelineLoading = false;
      _pipelineOutput = result.success ? result.output : '⚠ ${result.error}';
    });
  }
}

// ── DETAIL HEADER ─────────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  final ClipRecord clip;
  final VoidCallback onCleanRoom;

  const _DetailHeader({required this.clip, required this.onCleanRoom});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Type icon large
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Center(child: Icon(_typeIcon(clip.contentType), size: 20, color: _typeColor(clip.contentType, colors))),
        ),
        const SizedBox(width: 12),

        // Title & meta
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(_typeLabel(clip.contentType),
                style: context.text.titleSmall),
              if (clip.isSensitive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.redBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: colors.red.withOpacity(0.5)),
                  ),
                  child: Text('SENSITIVE',
                    style: AppTheme.mono(size: 9, color: colors.red)),
                ),
              ],
              if (clip.flags.cleaned) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.greenBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: colors.green.withOpacity(0.4)),
                  ),
                  child: Text('CLEANED',
                    style: AppTheme.mono(size: 9, color: colors.green)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text(
              '${clip.metadata.sourceApp ?? 'Unknown'} · ${_formatTime(clip.capturedAt)}'
              '${clip.primaryText.isNotEmpty ? ' · ${clip.primaryText.length} chars' : ''}',
              style: AppTheme.mono(size: 10, color: colors.text3),
            ),
            if (clip.isSensitive && clip.ttlExpiry != null) ...[
              const SizedBox(height: 2),
              Text(
                '⚠ Auto-deletes in ${clip.ttlExpiry!.difference(DateTime.now()).inSeconds.clamp(0, 999)}s',
                style: AppTheme.mono(size: 10, color: colors.red),
              ),
            ],
          ]),
        ),

        // Actions
        Row(children: [
          if (clip.contentType == ClipContentType.url && clip.metadata.cleanedUrl != null)
            _HeaderBtn(icon: Icons.cleaning_services_rounded, label: 'Clean Room',
              color: colors.green, onTap: onCleanRoom),
          if (clip.isSensitive)
            _HeaderBtn(icon: Icons.delete_forever_rounded, label: 'Purge Now',
              color: colors.red,
              onTap: () => context.read<GhostBloc>().add(GhostPurgeNow(clip.id))),
          _HeaderBtn(icon: Icons.edit_note_rounded, label: 'Scratchpad',
            color: colors.text2,
            onTap: () => context.read<ScratchpadBloc>().add(ScratchAddBlock(clip))),
          _HeaderBtn(icon: Icons.content_paste_rounded, label: 'Paste',
            color: colors.accent, isPrimary: true,
            onTap: () => context.read<ClipboardBloc>().add(ClipboardPaste(clip.id))),
        ]),
      ]),
    );
  }

  IconData _typeIcon(ClipContentType t) => switch (t) {
    ClipContentType.code      => Icons.code_rounded,
    ClipContentType.url       => Icons.link_rounded,
    ClipContentType.image     => Icons.image_rounded,
    ClipContentType.contact   => Icons.person_rounded,
    ClipContentType.legal     => Icons.gavel_rounded,
    ClipContentType.financial => Icons.attach_money_rounded,
    ClipContentType.medical   => Icons.medical_services_rounded,
    ClipContentType.color     => Icons.palette_rounded,
    ClipContentType.fileRef   => Icons.insert_drive_file_rounded,
    _                         => Icons.text_fields_rounded,
  };

  Color _typeColor(ClipContentType t, AppColors c) => switch (t) {
    ClipContentType.code      => const Color(0xFF7DD3FC),
    ClipContentType.url       => c.green,
    ClipContentType.image     => const Color(0xFF60A5FA),
    ClipContentType.contact   => c.purple,
    ClipContentType.legal     => c.amber,
    ClipContentType.financial => c.green,
    ClipContentType.medical   => const Color(0xFFF87171),
    ClipContentType.color     => c.purple,
    _                         => c.text3,
  };

  String _typeLabel(ClipContentType t) => switch (t) {
    ClipContentType.plainText => 'Plain Text',
    ClipContentType.richText  => 'Rich Text',
    ClipContentType.code      => 'Source Code',
    ClipContentType.url       => 'URL',
    ClipContentType.image     => 'Image',
    ClipContentType.contact   => 'Contact Info',
    ClipContentType.legal     => 'Legal Text',
    ClipContentType.financial => 'Financial Data',
    ClipContentType.medical   => 'Medical / PII',
    ClipContentType.color     => 'Color Value',
    ClipContentType.fileRef   => 'File Reference',
    ClipContentType.mixed     => 'Mixed Content',
  };

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  const _HeaderBtn({
    required this.icon, required this.label, required this.color,
    required this.onTap, this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isPrimary ? color : colors.surface2,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: isPrimary ? color : colors.border2,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 13, color: isPrimary ? Colors.black : color),
              const SizedBox(width: 5),
              Text(label,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: isPrimary ? Colors.black : color,
                )),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── CONTENT SECTION ───────────────────────────────────────────────────────

class _ContentSection extends StatelessWidget {
  final ClipRecord clip;
  final bool showCleanDiff;

  const _ContentSection({required this.clip, required this.showCleanDiff});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionLabel('Content'
        + (clip.metadata.codeLanguage != null ? ' · ${clip.metadata.codeLanguage}' : '')),
      const SizedBox(height: 8),

      // Main content display
      switch (clip.contentType) {
        ClipContentType.image   => _ImagePreview(clip: clip, colors: colors),
        ClipContentType.color   => _ColorPreview(clip: clip, colors: colors),
        ClipContentType.code    => _CodeBox(text: clip.primaryText, colors: colors, language: clip.metadata.codeLanguage),
        ClipContentType.url     => _UrlDisplay(clip: clip, colors: colors, showDiff: showCleanDiff),
        _                       => _TextDisplay(text: clip.primaryText, colors: colors),
      },

      // OCR text from images
      if (clip.metadata.ocrText != null && clip.metadata.ocrText!.isNotEmpty) ...[
        const SizedBox(height: 16),
        _SectionLabel('OCR — Extracted Text'),
        const SizedBox(height: 6),
        _CodeBox(text: clip.metadata.ocrText!, colors: colors),
      ],
    ]);
  }
}

class _ImagePreview extends StatelessWidget {
  final ClipRecord clip;
  final AppColors colors;
  const _ImagePreview({required this.clip, required this.colors});

  @override
  Widget build(BuildContext context) {
    final payload = clip.payloads.firstWhere(
      (p) => p.mimeType.startsWith('image/'),
      orElse: () => const ClipPayload(mimeType: ''),
    );

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: payload.bytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.memory(payload.bytes!, fit: BoxFit.contain),
            )
          : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.image_rounded, size: 32, color: colors.text3),
              const SizedBox(height: 6),
              Text('[Image — ${clip.metadata.exifData['size'] ?? 'unknown size'}]',
                style: AppTheme.mono(size: 11, color: colors.text3)),
            ])),
    );
  }
}

class _ColorPreview extends StatelessWidget {
  final ClipRecord clip;
  final AppColors colors;
  const _ColorPreview({required this.clip, required this.colors});

  @override
  Widget build(BuildContext context) {
    final hex = clip.metadata.colorHex ?? '#FFFFFF';
    Color? parsed;
    try {
      parsed = Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {}

    return Row(children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: parsed ?? colors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border2),
        ),
      ),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _KV('HEX', hex, colors),
        _KV('RGB', _hexToRgb(hex), colors),
        _KV('HSL', _hexToHsl(hex), colors),
        _KV('CSS', 'color: $hex;', colors),
      ]),
    ]);
  }

  String _hexToRgb(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      final r = int.parse(h.substring(0, 2), radix: 16);
      final g = int.parse(h.substring(2, 4), radix: 16);
      final b = int.parse(h.substring(4, 6), radix: 16);
      return 'rgb($r, $g, $b)';
    } catch (_) { return '—'; }
  }

  String _hexToHsl(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      final r = int.parse(h.substring(0, 2), radix: 16) / 255;
      final g = int.parse(h.substring(2, 4), radix: 16) / 255;
      final b = int.parse(h.substring(4, 6), radix: 16) / 255;
      final max = [r, g, b].reduce((a, b) => a > b ? a : b);
      final min = [r, g, b].reduce((a, b) => a < b ? a : b);
      final l = (max + min) / 2;
      if (max == min) return 'hsl(0, 0%, ${(l * 100).round()}%)';
      final d = max - min;
      final s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      double hue;
      if (max == r) hue = (g - b) / d + (g < b ? 6 : 0);
      else if (max == g) hue = (b - r) / d + 2;
      else hue = (r - g) / d + 4;
      hue /= 6;
      return 'hsl(${(hue * 360).round()}, ${(s * 100).round()}%, ${(l * 100).round()}%)';
    } catch (_) { return '—'; }
  }
}

class _UrlDisplay extends StatelessWidget {
  final ClipRecord clip;
  final AppColors colors;
  final bool showDiff;
  const _UrlDisplay({required this.clip, required this.colors, required this.showDiff});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SelectableText(
        clip.primaryText,
        style: AppTheme.mono(size: 12, color: colors.accent),
      ),
      if (clip.metadata.pageTitle != null) ...[
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.web_rounded, size: 12, color: colors.text3),
          const SizedBox(width: 4),
          Text(clip.metadata.pageTitle!, style: TextStyle(fontSize: 12, color: colors.text2)),
        ]),
      ],
      if (showDiff && clip.metadata.cleanedUrl != null) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.cleaning_services_rounded, size: 12, color: colors.green),
              const SizedBox(width: 6),
              Text('Clean Room — Removed tracking params',
                style: AppTheme.mono(size: 10, color: colors.green)),
            ]),
            const SizedBox(height: 8),
            Text(clip.primaryText,
              style: AppTheme.mono(size: 11, color: colors.red)
                  .copyWith(decoration: TextDecoration.lineThrough,
                            decorationColor: colors.red)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.check_rounded, size: 11, color: colors.green),
              const SizedBox(width: 4),
              Expanded(
                child: Text(clip.metadata.cleanedUrl!,
                  style: AppTheme.mono(size: 11, color: colors.green)),
              ),
            ]),
          ]),
        ),
      ],
    ]);
  }
}

class _TextDisplay extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _TextDisplay({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: TextStyle(fontSize: 13, color: colors.text2, height: 1.7),
    );
  }
}

// ── METADATA SECTION ──────────────────────────────────────────────────────

class _MetadataSection extends StatelessWidget {
  final ClipRecord clip;
  const _MetadataSection({required this.clip});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionLabel('Metadata'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border),
        ),
        child: Column(children: [
          _KV('Source',    clip.metadata.sourceApp ?? '—', colors),
          _KV('Captured',  clip.capturedAt.toLocal().toString().substring(0, 19), colors),
          _KV('ID',        clip.id, colors),
          _KV('Hash',      clip.metadata.contentHash.substring(0, 16) + '…', colors),
          if (clip.metadata.codeLanguage != null)
            _KV('Language', clip.metadata.codeLanguage!, colors),
          if (clip.ttlExpiry != null)
            _KV('TTL Expiry', clip.ttlExpiry!.toLocal().toString().substring(0, 19), colors),
          if (clip.metadata.aiTags.isNotEmpty)
            _KV('Tags', clip.metadata.aiTags.join(', '), colors),
        ]),
      ),
    ]);
  }
}

// ── PIPELINE STRIP ────────────────────────────────────────────────────────

class _PipelineStrip extends StatelessWidget {
  final ClipRecord clip;
  final bool loading;
  final Future<void> Function(PipelineId) onRun;

  const _PipelineStrip({required this.clip, required this.loading, required this.onRun});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final service = PipelinesService();
    final pipes = service.pipelinesFor(clip.contentType);

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(children: [
        Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Text('PIPELINES',
            style: AppTheme.mono(size: 9, color: colors.text3)),
        ),
        if (loading)
          SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: colors.accent),
          )
        else
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: pipes.map((p) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton.icon(
                  onPressed: () => onRun(p.id),
                  icon: Text(p.icon, style: const TextStyle(fontSize: 11)),
                  label: Text(p.name,
                    style: AppTheme.mono(size: 10, color: colors.text2)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(color: colors.border),
                    backgroundColor: colors.surface2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              )).toList(),
            ),
          ),
      ]),
    );
  }
}

// ── SHARED WIDGETS ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: AppTheme.mono(size: 10, color: context.colors.text3)
        .copyWith(letterSpacing: 0.1),
  );
}

class _CodeBox extends StatelessWidget {
  final String text;
  final AppColors colors;
  final String? language;

  const _CodeBox({required this.text, required this.colors, this.language});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: AppTheme.mono(size: 12, color: const Color(0xFFE2E8F0))
              .copyWith(height: 1.7),
        ),
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String k;
  final String v;
  final AppColors colors;
  const _KV(this.k, this.v, this.colors);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 100,
          child: Text(k, style: AppTheme.mono(size: 11, color: colors.text3)),
        ),
        Expanded(
          child: SelectableText(v,
            style: AppTheme.mono(size: 11, color: colors.text2)),
        ),
      ]),
    );
  }
}
