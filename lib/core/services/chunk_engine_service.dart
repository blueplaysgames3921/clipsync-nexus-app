import '../../data/models/clip_record.dart';
import 'settings_service.dart';

enum ChunkStrategy {
  paragraph,
  sentence,
  line,
  csv,
  json,
  markdown,
  topLevelSection,
}

class ChunkSession {
  final String parentClipId;
  final ChunkStrategy strategy;
  final List<String> segments;
  int currentIndex;
  bool isActive;
  DateTime lastPasteAt;

  ChunkSession({
    required this.parentClipId,
    required this.strategy,
    required this.segments,
    this.currentIndex = 0,
    this.isActive = true,
  }) : lastPasteAt = DateTime.now();

  int get totalSegments => segments.length;
  int get remainingSegments => totalSegments - currentIndex;
  bool get isComplete => currentIndex >= totalSegments;
  double get progress => totalSegments == 0 ? 1.0 : currentIndex / totalSegments;

  String? get currentSegment =>
      currentIndex < totalSegments ? segments[currentIndex] : null;

  String? get nextSegment =>
      currentIndex + 1 < totalSegments ? segments[currentIndex + 1] : null;

  void advance() {
    currentIndex++;
    lastPasteAt = DateTime.now();
  }
}

class ChunkEngineService {
  final SettingsService settings;

  ChunkEngineService({required this.settings});

  // ── THRESHOLD CHECK ───────────────────────────────────────────────────────

  bool shouldChunk(ClipPayload payload) {
    final s = settings.current;
    if (!s.autoChunkEnabled) return false;
    final text = payload.text ?? '';
    return text.length >= s.chunkThresholdChars;
  }

  /// Select best strategy for a given content type.
  ChunkStrategy autoSelectStrategy(ClipContentType type, String text) {
    switch (type) {
      case ClipContentType.code:
        if (_looksLikeCsv(text)) return ChunkStrategy.csv;
        if (_looksLikeJson(text)) return ChunkStrategy.json;
        return ChunkStrategy.line;
      case ClipContentType.legal:
        return ChunkStrategy.topLevelSection;
      default:
        if (_looksLikeMarkdown(text)) return ChunkStrategy.markdown;
        if (_looksLikeCsv(text)) return ChunkStrategy.csv;
        if (_looksLikeJson(text)) return ChunkStrategy.json;
        return ChunkStrategy.paragraph;
    }
  }

  // ── SEGMENTATION ──────────────────────────────────────────────────────────

  ChunkSession createSession({
    required String parentClipId,
    required String text,
    ChunkStrategy? strategy,
    ClipContentType contentType = ClipContentType.plainText,
    int? targetChars,
  }) {
    final strat = strategy ?? autoSelectStrategy(contentType, text);
    final target = targetChars ?? settings.current.chunkTargetChars;
    final segments = segment(text, strat, target);

    return ChunkSession(
      parentClipId: parentClipId,
      strategy: strat,
      segments: segments,
    );
  }

  List<String> segment(String text, ChunkStrategy strategy, int targetChars) {
    switch (strategy) {
      case ChunkStrategy.paragraph:
        return _splitByParagraph(text, targetChars);
      case ChunkStrategy.sentence:
        return _splitBySentence(text, targetChars);
      case ChunkStrategy.line:
        return _splitByLine(text, targetChars);
      case ChunkStrategy.csv:
        return _splitCsv(text, targetChars);
      case ChunkStrategy.json:
        return _splitJson(text, targetChars);
      case ChunkStrategy.markdown:
        return _splitMarkdown(text, targetChars);
      case ChunkStrategy.topLevelSection:
        return _splitByTopLevelSection(text, targetChars);
    }
  }

  // ── SPLIT STRATEGIES ──────────────────────────────────────────────────────

  List<String> _splitByParagraph(String text, int target) {
    final paras = text.split(RegExp(r'\n\n+'));
    return _mergeToTarget(paras, target, '\n\n');
  }

  List<String> _splitBySentence(String text, int target) {
    // Sentence boundary regex that avoids splitting on abbreviations
    final sentences = text.split(RegExp(
      r'(?<=[.!?])\s+(?=[A-Z])',
    ));
    return _mergeToTarget(sentences, target, ' ');
  }

  List<String> _splitByLine(String text, int target) {
    final lines = text.split('\n');
    final chunks = <String>[];
    final buffer = StringBuffer();
    int depth = 0; // bracket depth — never split inside a block

    for (final line in lines) {
      for (final ch in line.split('')) {
        if ('{(['.contains(ch)) depth++;
        if ('})]'.contains(ch)) depth = (depth - 1).clamp(0, 999);
      }
      buffer.writeln(line);
      if (buffer.length >= target && depth == 0) {
        chunks.add(buffer.toString().trimRight());
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString().trimRight());
    return chunks;
  }

  List<String> _splitCsv(String text, int target) {
    final lines = text.split('\n');
    if (lines.isEmpty) return [text];

    // Always include header in every chunk
    final header = lines.first;
    final dataLines = lines.skip(1).toList();
    final chunks = <String>[];
    final buffer = StringBuffer();
    buffer.writeln(header);

    for (final line in dataLines) {
      buffer.writeln(line);
      if (buffer.length >= target) {
        chunks.add(buffer.toString().trimRight());
        buffer.clear();
        buffer.writeln(header); // re-add header
      }
    }
    if (buffer.length > header.length + 1) {
      chunks.add(buffer.toString().trimRight());
    }
    return chunks.isEmpty ? [text] : chunks;
  }

  List<String> _splitJson(String text, int target) {
    // Try to parse as array — split elements
    try {
      final trimmed = text.trim();
      if (trimmed.startsWith('[')) {
        return _splitJsonArray(trimmed, target);
      } else if (trimmed.startsWith('{')) {
        return _splitJsonObject(trimmed, target);
      }
    } catch (_) {}
    // Fallback to line split
    return _splitByLine(text, target);
  }

  List<String> _splitJsonArray(String text, int target) {
    // Extract top-level array elements without full parse
    final elements = _extractJsonElements(text);
    final chunks = <String>[];
    final buffer = <String>[];
    int bufLen = 0;

    for (final el in elements) {
      buffer.add(el);
      bufLen += el.length;
      if (bufLen >= target) {
        chunks.add('[${buffer.join(',')}]');
        buffer.clear();
        bufLen = 0;
      }
    }
    if (buffer.isNotEmpty) chunks.add('[${buffer.join(',')}]');
    return chunks.isEmpty ? [text] : chunks;
  }

  List<String> _splitJsonObject(String text, int target) {
    final pairs = _extractJsonKeyValuePairs(text);
    final chunks = <String>[];
    final buffer = <String>[];
    int bufLen = 0;

    for (final pair in pairs) {
      buffer.add(pair);
      bufLen += pair.length;
      if (bufLen >= target) {
        chunks.add('{${buffer.join(',')}}');
        buffer.clear();
        bufLen = 0;
      }
    }
    if (buffer.isNotEmpty) chunks.add('{${buffer.join(',')}}');
    return chunks.isEmpty ? [text] : chunks;
  }

  List<String> _splitMarkdown(String text, int target) {
    // Split at top-level headings (# and ##)
    final sections = text.split(RegExp(r'(?=^#{1,2} )', multiLine: true));
    return _mergeToTarget(sections, target, '\n\n');
  }

  List<String> _splitByTopLevelSection(String text, int target) {
    // Legal / structured docs: split at numbered articles/sections
    final sections = text.split(RegExp(
      r'(?=\b(?:Article|Section|ARTICLE|SECTION)\s+\d+|\b\d+\.\s+[A-Z])',
    ));
    return _mergeToTarget(sections, target, '\n\n');
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  List<String> _mergeToTarget(List<String> parts, int target, String joiner) {
    final chunks = <String>[];
    final buffer = StringBuffer();

    for (final part in parts) {
      if (part.trim().isEmpty) continue;
      if (buffer.isNotEmpty && buffer.length + part.length > target) {
        chunks.add(buffer.toString().trim());
        buffer.clear();
      }
      if (buffer.isNotEmpty) buffer.write(joiner);
      buffer.write(part);
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString().trim());
    return chunks.isEmpty ? [parts.join(joiner)] : chunks;
  }

  List<String> _extractJsonElements(String arrayText) {
    final elements = <String>[];
    int depth = 0;
    int start = 1; // skip opening [
    bool inString = false;

    for (int i = 0; i < arrayText.length; i++) {
      final ch = arrayText[i];
      if (ch == '"' && (i == 0 || arrayText[i - 1] != '\\')) {
        inString = !inString;
      }
      if (!inString) {
        if (ch == '{' || ch == '[') depth++;
        if (ch == '}' || ch == ']') depth--;
        if ((ch == ',' && depth == 0) || (ch == ']' && depth == -1)) {
          elements.add(arrayText.substring(start, i).trim());
          start = i + 1;
        }
      }
    }
    return elements.where((e) => e.isNotEmpty).toList();
  }

  List<String> _extractJsonKeyValuePairs(String objectText) {
    final pairs = <String>[];
    int depth = 0;
    int start = 1;
    bool inString = false;

    for (int i = 0; i < objectText.length; i++) {
      final ch = objectText[i];
      if (ch == '"' && (i == 0 || objectText[i - 1] != '\\')) {
        inString = !inString;
      }
      if (!inString) {
        if (ch == '{' || ch == '[') depth++;
        if (ch == '}' || ch == ']') depth--;
        if ((ch == ',' && depth == 0) || (ch == '}' && depth == -1)) {
          pairs.add(objectText.substring(start, i).trim());
          start = i + 1;
        }
      }
    }
    return pairs.where((p) => p.isNotEmpty).toList();
  }

  bool _looksLikeCsv(String text) {
    final firstLine = text.split('\n').first;
    return firstLine.split(',').length >= 3 &&
        text.split('\n').length > 5;
  }

  bool _looksLikeJson(String text) {
    final t = text.trim();
    return (t.startsWith('{') || t.startsWith('[')) && t.length > 100;
  }

  bool _looksLikeMarkdown(String text) {
    return RegExp(r'^#{1,6} ', multiLine: true).hasMatch(text);
  }
}
