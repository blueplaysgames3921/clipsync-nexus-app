import '../../data/models/clip_record.dart';

/// Classifies clipboard payloads into content types and semantic tags.
/// Rule-based with ML refinement hooks.
class ClassifierService {

  // ── PRIMARY TYPE ──────────────────────────────────────────────────────────

  ClipContentType classifyType(List<ClipPayload> payloads) {
    // Image payload takes priority
    if (payloads.any((p) => p.mimeType.startsWith('image/'))) {
      return ClipContentType.image;
    }
    // File reference
    if (payloads.any((p) => p.mimeType == 'application/x-file-ref')) {
      return ClipContentType.fileRef;
    }

    final text = payloads
        .firstWhere((p) => p.mimeType == 'text/plain',
            orElse: () => const ClipPayload(mimeType: ''))
        .text ?? '';

    if (text.isEmpty) return ClipContentType.mixed;

    if (_isUrl(text)) return ClipContentType.url;
    if (_isColor(text)) return ClipContentType.color;
    if (_isCode(text)) return ClipContentType.code;
    if (_isContact(text)) return ClipContentType.contact;
    if (_isLegal(text)) return ClipContentType.legal;
    if (_isFinancial(text)) return ClipContentType.financial;
    if (_isMedical(text)) return ClipContentType.medical;

    return ClipContentType.plainText;
  }

  // ── TAG LIST ──────────────────────────────────────────────────────────────

  List<String> classifyTags(List<ClipPayload> payloads, ClipContentType type) {
    final tags = <String>[type.name];
    final text = payloads
        .firstWhere((p) => p.mimeType == 'text/plain',
            orElse: () => const ClipPayload(mimeType: ''))
        .text ?? '';

    if (text.isEmpty) return tags;

    if (_isUrl(text)) tags.add('url');
    if (_isCode(text)) {
      tags.add('code');
      final lang = detectCodeLanguage(text);
      if (lang.isNotEmpty) tags.add(lang.toLowerCase());
    }
    if (_isContact(text)) tags.add('contact');
    if (_isLegal(text)) tags.add('legal');
    if (_isFinancial(text)) tags.add('financial');
    if (_isMedical(text)) tags.add('medical');
    if (_isColor(text)) tags.add('color');
    if (_hasTrackingParams(text)) tags.add('tracking');
    if (text.length > 5000) tags.add('large');

    return tags.toSet().toList(); // deduplicate
  }

  // ── CODE LANGUAGE DETECTION ───────────────────────────────────────────────

  String detectCodeLanguage(String text) {
    final t = text.trim();

    if (_dartPattern.hasMatch(t)) return 'Dart';
    if (_kotlinPattern.hasMatch(t)) return 'Kotlin';
    if (_swiftPattern.hasMatch(t)) return 'Swift';
    if (_pythonPattern.hasMatch(t)) return 'Python';
    if (_tsPattern.hasMatch(t)) return 'TypeScript';
    if (_jsPattern.hasMatch(t)) return 'JavaScript';
    if (_javaPattern.hasMatch(t)) return 'Java';
    if (_rustPattern.hasMatch(t)) return 'Rust';
    if (_cppPattern.hasMatch(t)) return 'C++';
    if (_goPattern.hasMatch(t)) return 'Go';
    if (_sqlPattern.hasMatch(t)) return 'SQL';
    if (_htmlPattern.hasMatch(t)) return 'HTML';
    if (_cssPattern.hasMatch(t)) return 'CSS';
    if (_jsonPattern.hasMatch(t)) return 'JSON';
    if (_xmlPattern.hasMatch(t)) return 'XML';
    if (_shellPattern.hasMatch(t)) return 'Shell';
    if (_yamlPattern.hasMatch(t)) return 'YAML';
    if (_mdPattern.hasMatch(t)) return 'Markdown';

    return 'Code';
  }

  // ── COLOR EXTRACTION ──────────────────────────────────────────────────────

  String extractColorHex(String text) {
    final match = _hexColorPattern.firstMatch(text.trim());
    if (match != null) return match.group(0)!.toUpperCase();
    return '';
  }

  // ── PRIVATE CLASSIFIERS ───────────────────────────────────────────────────

  static final _urlPattern = RegExp(
    r'^https?://[^\s]+$',
    caseSensitive: false,
  );
  bool _isUrl(String t) => _urlPattern.hasMatch(t.trim());

  static final _hexColorPattern = RegExp(r'#(?:[0-9A-Fa-f]{3}){1,2}\b');
  static final _rgbPattern = RegExp(r'rgb\(\s*\d{1,3},\s*\d{1,3},\s*\d{1,3}\s*\)', caseSensitive: false);
  static final _hslPattern = RegExp(r'hsl\(\s*\d{1,3},\s*\d{1,3}%?,\s*\d{1,3}%?\s*\)', caseSensitive: false);
  bool _isColor(String t) {
    final s = t.trim();
    return _hexColorPattern.hasMatch(s) || _rgbPattern.hasMatch(s) || _hslPattern.hasMatch(s);
  }

  static final _codeKeywords = RegExp(
    r'\b(function|class|def |import |export |const |let |var |return |async |await |interface |struct |enum |fn |pub |mod |use |namespace |#include|SELECT |INSERT |UPDATE |DELETE FROM|CREATE TABLE)\b',
  );
  static final _bracesPattern = RegExp(r'[{}\[\]();]');
  bool _isCode(String t) {
    int braceCount = _bracesPattern.allMatches(t).length;
    return _codeKeywords.hasMatch(t) && braceCount >= 2;
  }

  static final _contactPattern = RegExp(
    r'(?:[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,})|'
    r'(?:\+?[\d\s\-().]{10,17})',
  );
  bool _isContact(String t) {
    final matches = _contactPattern.allMatches(t);
    return matches.length >= 2 || (t.contains('@') && _contactPattern.hasMatch(t));
  }

  static final _legalPattern = RegExp(
    r'\b(WHEREAS|HEREINAFTER|IN WITNESS WHEREOF|NOTWITHSTANDING|INDEMNIFY|'
    r'ARBITRATION|JURISDICTION|LIABILITY|WHEREAS|Article \d+|Section \d+|'
    r'§\s*\d+|Force Majeure|Intellectual Property|Confidentiality)\b',
    caseSensitive: false,
  );
  bool _isLegal(String t) => _legalPattern.hasMatch(t);

  static final _financialPattern = RegExp(
    r'(?:\$|€|£|¥|USD|EUR|GBP)\s*[\d,]+\.?\d*|'
    r'\b(?:invoice|revenue|profit|loss|balance|debit|credit|IBAN|SWIFT|BIC)\b',
    caseSensitive: false,
  );
  bool _isFinancial(String t) => _financialPattern.hasMatch(t);

  static final _medicalPattern = RegExp(
    r'\b(?:diagnosis|prescription|ICD-?\d+|medication|dosage|mg\b|'
    r'patient|physician|DEA#|NPI|clinical|symptom|treatment)\b',
    caseSensitive: false,
  );
  bool _isMedical(String t) => _medicalPattern.hasMatch(t);

  static final _trackingParams = RegExp(
    r'[?&](?:utm_|fbclid|gclid|msclkid|yclid|mc_eid|_ga|ref=)',
    caseSensitive: false,
  );
  bool _hasTrackingParams(String t) => _trackingParams.hasMatch(t);

  // ── LANGUAGE PATTERNS ─────────────────────────────────────────────────────

  static final _dartPattern = RegExp(r'\b(?:void main\(\)|Widget|StatelessWidget|StatefulWidget|BuildContext|dart:)\b');
  static final _kotlinPattern = RegExp(r'\b(?:fun |val |var |data class|companion object|suspend fun|coroutine)\b');
  static final _swiftPattern = RegExp(r'\b(?:func |guard |@IBOutlet|SwiftUI|@State|@Binding|var body: some)\b');
  static final _pythonPattern = RegExp(r'\b(?:def |import |from .* import|__init__|if __name__|print\(|self\.|:$)', multiLine: true);
  static final _tsPattern = RegExp(r'\b(?:interface |type |readonly |as const|satisfies |namespace |<[A-Z][a-z]+>)\b');
  static final _jsPattern = RegExp(r'\b(?:const |let |var |function |=>|require\(|module\.exports|document\.|window\.)\b');
  static final _javaPattern = RegExp(r'\b(?:public class|private |protected |@Override|System\.out|throws |extends |implements )\b');
  static final _rustPattern = RegExp(r'\b(?:fn |let mut |impl |pub struct|use std::|match |&str|Vec<|Result<)\b');
  static final _cppPattern = RegExp(r'\b(?:#include|std::|cout|cin|nullptr|template<|::)\b');
  static final _goPattern = RegExp(r'\b(?:func |package |import |goroutine|chan |defer |go func)\b');
  static final _sqlPattern = RegExp(r'\b(?:SELECT|INSERT INTO|UPDATE|DELETE FROM|CREATE TABLE|JOIN|WHERE|GROUP BY)\b', caseSensitive: false);
  static final _htmlPattern = RegExp(r'<(?:html|head|body|div|span|a |p |ul|li|script|style|meta|link)[^>]*>', caseSensitive: false);
  static final _cssPattern = RegExp(r'[.#]?[a-zA-Z-]+\s*\{[^}]+\}');
  static final _jsonPattern = RegExp(r'^\s*[\[{]');
  static final _xmlPattern = RegExp(r'<\?xml|<[a-zA-Z]+[^>]*>.*</[a-zA-Z]+>', dotAll: true);
  static final _shellPattern = RegExp(r'\b(?:#!/bin/|grep |awk |sed |curl |wget |chmod |sudo |apt |brew |npm |pip )\b');
  static final _yamlPattern = RegExp(r'^---\s*$|^\s{2,}[a-zA-Z_]+:\s', multiLine: true);
  static final _mdPattern = RegExp(r'^#{1,6} |^\*\*|^- \[|^\d+\. ', multiLine: true);
}
