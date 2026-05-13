import 'dart:convert';

import 'package:langchain/langchain.dart';
import 'package:langchain_ollama/langchain_ollama.dart';

import '../../data/models/clip_record.dart';

enum PipelineId {
  uppercase,
  lowercase,
  titleCase,
  camelCase,
  snakeCase,
  kebabCase,
  pascalCase,
  trimWhitespace,
  removeBlankLines,
  reverseLines,
  sortLines,
  deduplicateLines,
  base64Encode,
  base64Decode,
  urlEncode,
  urlDecode,
  htmlEntityEncode,
  htmlEntityDecode,
  jsonBeautify,
  jsonMinify,
  stripHtml,
  markdownToHtml,
  countWords,
  reverseText,
  hexToRgb,
  rgbToHex,
  allColorFormats,
  timestampToIso,
  isoToTimestamp,
  unixToHuman,
  csvToJson,
  jsonToCsv,
  summarize,
  translate,
  extractEmails,
  extractUrls,
  extractNumbers,
  rot13,
  slugify,
}

class PipelineResult {
  final String output;
  final String pipelineName;
  final bool success;
  final String? error;

  const PipelineResult({
    required this.output,
    required this.pipelineName,
    this.success = true,
    this.error,
  });
}

class PipelineDefinition {
  final PipelineId id;
  final String name;
  final String icon;
  final String description;
  final List<ClipContentType> applicableTypes;

  const PipelineDefinition({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.applicableTypes,
  });
}

class PipelinesService {

  static const allPipelines = <PipelineDefinition>[
    // Case transforms
    PipelineDefinition(id: PipelineId.uppercase,        name: 'UPPERCASE',        icon: '🔠', description: 'Convert all text to uppercase',              applicableTypes: [ClipContentType.plainText, ClipContentType.code, ClipContentType.contact]),
    PipelineDefinition(id: PipelineId.lowercase,        name: 'lowercase',        icon: '🔡', description: 'Convert all text to lowercase',              applicableTypes: [ClipContentType.plainText, ClipContentType.code, ClipContentType.contact]),
    PipelineDefinition(id: PipelineId.titleCase,        name: 'Title Case',       icon: '📝', description: 'Capitalise first letter of each word',       applicableTypes: [ClipContentType.plainText, ClipContentType.contact]),
    PipelineDefinition(id: PipelineId.camelCase,        name: 'camelCase',        icon: '🐪', description: 'Convert to camelCase identifier',            applicableTypes: [ClipContentType.plainText, ClipContentType.code]),
    PipelineDefinition(id: PipelineId.snakeCase,        name: 'snake_case',       icon: '🐍', description: 'Convert to snake_case identifier',           applicableTypes: [ClipContentType.plainText, ClipContentType.code]),
    PipelineDefinition(id: PipelineId.kebabCase,        name: 'kebab-case',       icon: '🍡', description: 'Convert to kebab-case identifier',           applicableTypes: [ClipContentType.plainText, ClipContentType.code]),
    PipelineDefinition(id: PipelineId.pascalCase,       name: 'PascalCase',       icon: '🏛️', description: 'Convert to PascalCase identifier',           applicableTypes: [ClipContentType.plainText, ClipContentType.code]),
    // Text manipulation
    PipelineDefinition(id: PipelineId.trimWhitespace,   name: 'Trim Whitespace',  icon: '✂️', description: 'Remove leading/trailing whitespace',         applicableTypes: [ClipContentType.plainText, ClipContentType.code]),
    PipelineDefinition(id: PipelineId.removeBlankLines, name: 'Remove Blanks',    icon: '🧹', description: 'Remove all blank lines',                     applicableTypes: [ClipContentType.plainText, ClipContentType.code]),
    PipelineDefinition(id: PipelineId.reverseLines,     name: 'Reverse Lines',    icon: '🔄', description: 'Reverse the order of lines',                 applicableTypes: [ClipContentType.plainText, ClipContentType.code]),
    PipelineDefinition(id: PipelineId.sortLines,        name: 'Sort Lines',       icon: '🔢', description: 'Sort lines alphabetically',                  applicableTypes: [ClipContentType.plainText, ClipContentType.code]),
    PipelineDefinition(id: PipelineId.deduplicateLines, name: 'Deduplicate',      icon: '🎯', description: 'Remove duplicate lines',                     applicableTypes: [ClipContentType.plainText, ClipContentType.code]),
    PipelineDefinition(id: PipelineId.reverseText,      name: 'Reverse Text',     icon: '⬅️', description: 'Reverse all characters',                    applicableTypes: [ClipContentType.plainText]),
    PipelineDefinition(id: PipelineId.slugify,          name: 'Slugify',          icon: '🔗', description: 'Convert to URL-safe slug',                  applicableTypes: [ClipContentType.plainText, ClipContentType.url]),
    // Encode / decode
    PipelineDefinition(id: PipelineId.base64Encode,     name: 'Base64 Encode',    icon: '🔐', description: 'Encode text as Base64',                      applicableTypes: [ClipContentType.plainText, ClipContentType.code]),
    PipelineDefinition(id: PipelineId.base64Decode,     name: 'Base64 Decode',    icon: '🔓', description: 'Decode Base64 to text',                      applicableTypes: [ClipContentType.plainText, ClipContentType.code]),
    PipelineDefinition(id: PipelineId.urlEncode,        name: 'URL Encode',       icon: '🔗', description: 'Percent-encode for use in URLs',             applicableTypes: [ClipContentType.plainText, ClipContentType.url]),
    PipelineDefinition(id: PipelineId.urlDecode,        name: 'URL Decode',       icon: '🔓', description: 'Decode percent-encoded URL string',          applicableTypes: [ClipContentType.plainText, ClipContentType.url]),
    PipelineDefinition(id: PipelineId.htmlEntityEncode, name: 'HTML Encode',      icon: '🌐', description: 'Encode special chars as HTML entities',      applicableTypes: [ClipContentType.plainText, ClipContentType.code]),
    PipelineDefinition(id: PipelineId.htmlEntityDecode, name: 'HTML Decode',      icon: '🌐', description: 'Decode HTML entities to characters',         applicableTypes: [ClipContentType.plainText, ClipContentType.code]),
    PipelineDefinition(id: PipelineId.rot13,            name: 'ROT13',            icon: '🔁', description: 'Apply ROT13 substitution cipher',            applicableTypes: [ClipContentType.plainText]),
    // Code
    PipelineDefinition(id: PipelineId.jsonBeautify,     name: 'Beautify JSON',    icon: '✨', description: 'Format JSON with indentation',               applicableTypes: [ClipContentType.code, ClipContentType.plainText]),
    PipelineDefinition(id: PipelineId.jsonMinify,       name: 'Minify JSON',      icon: '🗜️', description: 'Minify JSON (remove whitespace)',            applicableTypes: [ClipContentType.code, ClipContentType.plainText]),
    PipelineDefinition(id: PipelineId.stripHtml,        name: 'Strip HTML',       icon: '🧽', description: 'Remove all HTML tags',                       applicableTypes: [ClipContentType.plainText, ClipContentType.code]),
    PipelineDefinition(id: PipelineId.markdownToHtml,   name: 'Markdown → HTML',  icon: '📄', description: 'Render Markdown as HTML',                    applicableTypes: [ClipContentType.code, ClipContentType.plainText]),
    PipelineDefinition(id: PipelineId.csvToJson,        name: 'CSV → JSON',       icon: '📊', description: 'Convert CSV to JSON array',                  applicableTypes: [ClipContentType.code, ClipContentType.plainText]),
    PipelineDefinition(id: PipelineId.jsonToCsv,        name: 'JSON → CSV',       icon: '📋', description: 'Convert JSON array to CSV',                  applicableTypes: [ClipContentType.code, ClipContentType.plainText]),
    // Stats / extraction
    PipelineDefinition(id: PipelineId.countWords,       name: 'Word Count',       icon: '🔢', description: 'Count words, characters, and lines',         applicableTypes: [ClipContentType.plainText, ClipContentType.legal, ClipContentType.code]),
    PipelineDefinition(id: PipelineId.extractEmails,    name: 'Extract Emails',   icon: '📧', description: 'Extract all email addresses',                applicableTypes: [ClipContentType.plainText, ClipContentType.contact]),
    PipelineDefinition(id: PipelineId.extractUrls,      name: 'Extract URLs',     icon: '🔗', description: 'Extract all URLs',                           applicableTypes: [ClipContentType.plainText]),
    PipelineDefinition(id: PipelineId.extractNumbers,   name: 'Extract Numbers',  icon: '🔢', description: 'Extract all numeric values',                 applicableTypes: [ClipContentType.plainText]),
    // Color
    PipelineDefinition(id: PipelineId.hexToRgb,         name: 'HEX → RGB',        icon: '🎨', description: 'Convert HEX color to RGB',                   applicableTypes: [ClipContentType.color, ClipContentType.plainText]),
    PipelineDefinition(id: PipelineId.rgbToHex,         name: 'RGB → HEX',        icon: '🎨', description: 'Convert RGB color to HEX',                   applicableTypes: [ClipContentType.color, ClipContentType.plainText]),
    PipelineDefinition(id: PipelineId.allColorFormats,  name: 'All Color Formats',icon: '🌈', description: 'Show HEX, RGB, HSL, CMYK equivalents',       applicableTypes: [ClipContentType.color, ClipContentType.plainText]),
    // Timestamps
    PipelineDefinition(id: PipelineId.timestampToIso,   name: 'Unix → ISO 8601',  icon: '🕐', description: 'Convert Unix timestamp to ISO date',         applicableTypes: [ClipContentType.plainText]),
    PipelineDefinition(id: PipelineId.isoToTimestamp,   name: 'ISO → Unix',       icon: '🕐', description: 'Convert ISO date to Unix timestamp',         applicableTypes: [ClipContentType.plainText]),
    PipelineDefinition(id: PipelineId.unixToHuman,      name: 'Unix → Human',     icon: '📅', description: 'Convert Unix timestamp to readable date',    applicableTypes: [ClipContentType.plainText]),
    // AI
    PipelineDefinition(id: PipelineId.summarize,        name: 'Summarize',        icon: '📋', description: 'Generate an extractive summary (on-device)', applicableTypes: [ClipContentType.plainText, ClipContentType.legal]),
    PipelineDefinition(id: PipelineId.translate,        name: 'Translate',        icon: '🌐', description: 'Translate text (on-device LLM)',              applicableTypes: [ClipContentType.plainText, ClipContentType.legal, ClipContentType.contact]),
  ];

  List<PipelineDefinition> pipelinesFor(ClipContentType type) {
    return allPipelines.where((p) => p.applicableTypes.contains(type)).toList();
  }

  // ── RUN ──────────────────────────────────────────────────────────────────

  Future<PipelineResult> run(PipelineId id, String input) async {
    try {
      final output = await _execute(id, input);
      return PipelineResult(output: output, pipelineName: id.name, success: true);
    } catch (e) {
      return PipelineResult(
        output: input,
        pipelineName: id.name,
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<String> _execute(PipelineId id, String input) async {
    switch (id) {
      // ── Case ──
      case PipelineId.uppercase:        return input.toUpperCase();
      case PipelineId.lowercase:        return input.toLowerCase();
      case PipelineId.titleCase:        return _titleCase(input);
      case PipelineId.camelCase:        return _toCamelCase(input);
      case PipelineId.snakeCase:        return _toSnakeCase(input);
      case PipelineId.kebabCase:        return _toKebabCase(input);
      case PipelineId.pascalCase:       return _toPascalCase(input);
      // ── Text ──
      case PipelineId.trimWhitespace:   return input.trim();
      case PipelineId.removeBlankLines: return input.split('\n').where((l) => l.trim().isNotEmpty).join('\n');
      case PipelineId.reverseLines:     return input.split('\n').reversed.join('\n');
      case PipelineId.sortLines:        return (input.split('\n')..sort()).join('\n');
      case PipelineId.deduplicateLines: return input.split('\n').toSet().join('\n');
      case PipelineId.reverseText:      return String.fromCharCodes(input.runes.toList().reversed);
      case PipelineId.slugify:          return _slugify(input);
      // ── Encode ──
      case PipelineId.base64Encode:     return base64Encode(utf8.encode(input));
      case PipelineId.base64Decode:     return utf8.decode(base64Decode(input));
      case PipelineId.urlEncode:        return Uri.encodeComponent(input);
      case PipelineId.urlDecode:        return Uri.decodeComponent(input);
      case PipelineId.htmlEntityEncode: return _htmlEncode(input);
      case PipelineId.htmlEntityDecode: return _htmlDecode(input);
      case PipelineId.rot13:            return _rot13(input);
      // ── Code ──
      case PipelineId.jsonBeautify:     return _jsonBeautify(input);
      case PipelineId.jsonMinify:       return _jsonMinify(input);
      case PipelineId.stripHtml:        return input.replaceAll(RegExp(r'<[^>]+>'), '');
      case PipelineId.markdownToHtml:   return _mdToHtml(input);
      case PipelineId.csvToJson:        return _csvToJson(input);
      case PipelineId.jsonToCsv:        return _jsonToCsv(input);
      // ── Stats ──
      case PipelineId.countWords:       return _countWords(input);
      case PipelineId.extractEmails:    return _extractPattern(input, RegExp(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}'));
      case PipelineId.extractUrls:      return _extractPattern(input, RegExp(r'https?://[^\s]+'));
      case PipelineId.extractNumbers:   return _extractPattern(input, RegExp(r'-?\d+(?:\.\d+)?'));
      // ── Color ──
      case PipelineId.hexToRgb:         return _hexToRgb(input);
      case PipelineId.rgbToHex:         return _rgbToHex(input);
      case PipelineId.allColorFormats:  return _allColorFormats(input);
      // ── Time ──
      case PipelineId.timestampToIso:   return _unixToIso(input);
      case PipelineId.isoToTimestamp:   return _isoToUnix(input);
      case PipelineId.unixToHuman:      return _unixToHuman(input);
      // ── AI ──
      case PipelineId.summarize:        return _summarize(input);
      case PipelineId.translate:        return _translate(input);
    }
  }

  // ── IMPLEMENTATIONS ───────────────────────────────────────────────────────

  String _titleCase(String s) =>
      s.split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');

  String _toWords(String s) {
    final spaced = s.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' \${m.group(0)}');
    return spaced.replaceAll(RegExp(r'[-_]'), ' ').trim().toLowerCase();
  }');
    return spaced.replaceAll(RegExp(r'[-_]'), ' ').trim().toLowerCase();
  }

  String _toCamelCase(String s) {
    final words = _toWords(s).split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return s;
    return words.first + words.skip(1).map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join();
  }

  String _toSnakeCase(String s) => _toWords(s).replaceAll(' ', '_');
  String _toKebabCase(String s)  => _toWords(s).replaceAll(' ', '-');
  String _toPascalCase(String s) {
    final words = _toWords(s).split(' ').where((w) => w.isNotEmpty);
    return words.map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join();
  }

  String _slugify(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s\-]'), '')
      .replaceAll(RegExp(r'[\s_]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .trim();

  String _htmlEncode(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  String _htmlDecode(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");

  String _rot13(String s) => s.splitMapJoin(
    RegExp(r'[A-Za-z]'),
    onMatch: (m) {
      final c = m.group(0)!.codeUnitAt(0);
      if (c >= 65 && c <= 90) return String.fromCharCode((c - 65 + 13) % 26 + 65);
      return String.fromCharCode((c - 97 + 13) % 26 + 97);
    },
    onNonMatch: (s) => s,
  );

  String _jsonBeautify(String s) {
    final obj = jsonDecode(s);
    return const JsonEncoder.withIndent('  ').convert(obj);
  }

  String _jsonMinify(String s) => jsonEncode(jsonDecode(s));

  String _mdToHtml(String md) {
    // Basic Markdown → HTML (real impl uses the markdown package)
    return md
        .replaceAllMapped(RegExp(r'^# (.+)$', multiLine: true), (m) => '<h1>${m.group(1)}</h1>')
        .replaceAllMapped(RegExp(r'^## (.+)$', multiLine: true), (m) => '<h2>${m.group(1)}</h2>')
        .replaceAllMapped(RegExp(r'^### (.+)$', multiLine: true), (m) => '<h3>${m.group(1)}</h3>')
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => '<strong>${m.group(1)}</strong>')
        .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => '<em>${m.group(1)}</em>')
        .replaceAllMapped(RegExp(r'`(.+?)`'), (m) => '<code>${m.group(1)}</code>')
        .replaceAll('\n\n', '</p><p>')
        .replaceAll('\n', '<br>');
  }

  String _countWords(String s) {
    final words = s.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final chars = s.length;
    final lines = s.split('\n').length;
    final sentences = s.split(RegExp(r'[.!?]')).where((s) => s.trim().isNotEmpty).length;
    return 'Words: $words\nCharacters: $chars\nCharacters (no spaces): ${s.replaceAll(' ', '').length}\nLines: $lines\nSentences: $sentences';
  }

  String _extractPattern(String s, RegExp pattern) {
    final matches = pattern.allMatches(s).map((m) => m.group(0)!).toSet().toList();
    return matches.isEmpty ? '(none found)' : matches.join('\n');
  }

  String _hexToRgb(String s) {
    final hex = s.trim().replaceFirst('#', '');
    if (hex.length != 6) return 'Invalid HEX color';
    final r = int.parse(hex.substring(0, 2), radix: 16);
    final g = int.parse(hex.substring(2, 4), radix: 16);
    final b = int.parse(hex.substring(4, 6), radix: 16);
    return 'rgb($r, $g, $b)';
  }

  String _rgbToHex(String s) {
    final nums = RegExp(r'\d+').allMatches(s).map((m) => int.parse(m.group(0)!)).toList();
    if (nums.length < 3) return 'Invalid RGB value';
    return '#${nums[0].toRadixString(16).padLeft(2, '0')}${nums[1].toRadixString(16).padLeft(2, '0')}${nums[2].toRadixString(16).padLeft(2, '0')}'.toUpperCase();
  }

  String _allColorFormats(String s) {
    final t = s.trim();
    int r = 0, g = 0, b = 0;
    if (t.startsWith('#')) {
      final hex = t.replaceFirst('#', '');
      if (hex.length == 6) {
        r = int.parse(hex.substring(0, 2), radix: 16);
        g = int.parse(hex.substring(2, 4), radix: 16);
        b = int.parse(hex.substring(4, 6), radix: 16);
      }
    } else {
      final nums = RegExp(r'\d+').allMatches(t).map((m) => int.parse(m.group(0)!)).toList();
      if (nums.length >= 3) { r = nums[0]; g = nums[1]; b = nums[2]; }
    }
    final hex = '#${r.toRadixString(16).padLeft(2,'0')}${g.toRadixString(16).padLeft(2,'0')}${b.toRadixString(16).padLeft(2,'0')}'.toUpperCase();
    final h = _rgbToHslH(r, g, b);
    final sl = _rgbToHslSL(r, g, b);
    return 'HEX:  $hex\nRGB:  rgb($r, $g, $b)\nHSL:  hsl($h, ${sl.$1}%, ${sl.$2}%)\nCSS:  color: $hex;\nSCSS: \$color: $hex;';
  }

  int _rgbToHslH(int r, int g, int b) {
    final rf = r / 255; final gf = g / 255; final bf = b / 255;
    final max = [rf, gf, bf].reduce((a, b) => a > b ? a : b);
    final min = [rf, gf, bf].reduce((a, b) => a < b ? a : b);
    if (max == min) return 0;
    double h;
    if (max == rf) h = (gf - bf) / (max - min);
    else if (max == gf) h = 2 + (bf - rf) / (max - min);
    else h = 4 + (rf - gf) / (max - min);
    h = (h * 60) % 360;
    return h.round().abs();
  }

  (int, int) _rgbToHslSL(int r, int g, int b) {
    final rf = r / 255; final gf = g / 255; final bf = b / 255;
    final max = [rf, gf, bf].reduce((a, b) => a > b ? a : b);
    final min = [rf, gf, bf].reduce((a, b) => a < b ? a : b);
    final l = (max + min) / 2;
    final s = max == min ? 0 : (max - min) / (1 - (2 * l - 1).abs());
    return ((s * 100).round(), (l * 100).round());
  }

  String _unixToIso(String s) {
    final ts = int.tryParse(s.trim());
    if (ts == null) return 'Invalid Unix timestamp';
    return DateTime.fromMillisecondsSinceEpoch(
      ts < 9999999999 ? ts * 1000 : ts, // handle seconds vs ms
    ).toUtc().toIso8601String();
  }

  String _isoToUnix(String s) {
    final dt = DateTime.tryParse(s.trim());
    if (dt == null) return 'Invalid ISO date';
    return '${dt.millisecondsSinceEpoch ~/ 1000}';
  }

  String _unixToHuman(String s) {
    final ts = int.tryParse(s.trim());
    if (ts == null) return 'Invalid Unix timestamp';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts < 9999999999 ? ts * 1000 : ts);
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} ${_pad(dt.hour)}:${_pad(dt.minute)}:${_pad(dt.second)} ${dt.timeZoneName}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _csvToJson(String csv) {
    final lines = csv.trim().split('\n').where((l) => l.isNotEmpty).toList();
    if (lines.length < 2) return '[]';
    final headers = lines.first.split(',').map((h) => h.trim().replaceAll('"', '')).toList();
    final rows = lines.skip(1).map((line) {
      final values = line.split(',').map((v) => v.trim().replaceAll('"', '')).toList();
      final map = <String, String>{};
      for (int i = 0; i < headers.length; i++) {
        map[headers[i]] = i < values.length ? values[i] : '';
      }
      return map;
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(rows);
  }

  String _jsonToCsv(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    if (list.isEmpty) return '';
    final headers = (list.first as Map<String, dynamic>).keys.toList();
    final rows = [
      headers.join(','),
      ...list.map((row) {
        final m = row as Map<String, dynamic>;
        return headers.map((h) => '"${(m[h] ?? '').toString().replaceAll('"', '""')}"').join(',');
      }),
    ];
    return rows.join('\n');
  }

  Future<String> _summarize(String text) async {
    try {
      final llm = Ollama(
        defaultOptions: const OllamaOptions(model: 'llama3.2:1b'),
      );
      final chain = PromptTemplate.fromTemplate(
        'Summarize the following text in 2-3 concise sentences. '
        'Reply with only the summary, no preamble:\n\n{text}',
      ).pipe(llm).pipe(const StringOutputParser());
      return await chain.invoke({'text': text});
    } catch (e) {
      // Ollama not running or model not available — return truncated preview
      final preview = text.trim();
      final words = preview.split(RegExp(r'\s+')).length;
      return 'Ollama unavailable ($e). '
          'Run: ollama pull llama3.2:1b\n\n'
          'Input was $words words.';
    }
  }

  Future<String> _translate(String text) async {
    try {
      final llm = Ollama(
        defaultOptions: const OllamaOptions(model: 'llama3.2:1b'),
      );
      final chain = PromptTemplate.fromTemplate(
        'Detect the source language of the following text, then translate it '
        'to English. Reply with only the translated text, no explanation:\n\n{text}',
      ).pipe(llm).pipe(const StringOutputParser());
      return await chain.invoke({'text': text});
    } catch (e) {
      return 'Ollama unavailable ($e). '
          'Run: ollama pull llama3.2:1b';
    }
  }
}
