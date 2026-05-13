import 'dart:async';
import 'dart:math' as math;

import '../../data/models/clip_record.dart';
import '../../data/repositories/clip_repository.dart';

/// Detects sensitive content and manages time-bounded auto-deletion.
class GhostLayerService {
  final ClipRepository clipRepo;

  Timer? _sweepTimer;
  final _expiryCallbacks = <void Function(String clipId)>[];

  static const Duration _sweepInterval = Duration(seconds: 1);

  GhostLayerService({required this.clipRepo});

  // ── DETECTION ────────────────────────────────────────────────────────────

  ClipSensitivityCategory detectSensitivity(
    String text,
    List<ClipPayload> payloads,
  ) {
    // 1. PEM private keys
    if (_pemKeyPattern.hasMatch(text)) {
      return ClipSensitivityCategory.privateKey;
    }

    // 2. API keys / tokens (high-entropy strings with prefixes)
    if (_apiKeyPattern.hasMatch(text) || _isHighEntropy(text)) {
      return ClipSensitivityCategory.apiKey;
    }

    // 3. Credit / debit card (Luhn check)
    final ccMatch = _creditCardPattern.firstMatch(text);
    if (ccMatch != null) {
      final digits = ccMatch.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (_luhnCheck(digits)) return ClipSensitivityCategory.creditCard;
    }

    // 4. SSN
    if (_ssnPattern.hasMatch(text)) {
      return ClipSensitivityCategory.ssn;
    }

    // 5. IBAN / bank account
    if (_ibanPattern.hasMatch(text)) {
      return ClipSensitivityCategory.bankAccount;
    }

    // 6. Password patterns
    if (_passwordPattern.hasMatch(text)) {
      return ClipSensitivityCategory.password;
    }

    return ClipSensitivityCategory.none;
  }

  // ── PATTERNS ─────────────────────────────────────────────────────────────

  static final _pemKeyPattern = RegExp(
    r'-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY-----',
    caseSensitive: false,
  );

  static final _apiKeyPattern = RegExp(
    r'(?:sk-ant-api\d{2}-|sk-[a-zA-Z0-9]{48}|'
    r'ghp_[a-zA-Z0-9]{36}|'
    r'xoxb-[0-9]+-[a-zA-Z0-9]+|'
    r'AIza[0-9A-Za-z\-_]{35}|'
    r'AKIA[0-9A-Z]{16}|'
    r'(?:api[_-]?key|token|secret|password|passwd|apikey)\s*[:=]\s*["\']?[a-zA-Z0-9\-_.+/]{16,})',
    caseSensitive: false,
  );

  static final _creditCardPattern = RegExp(
    r'(?:\d[ -]?){13,16}',
  );

  static final _ssnPattern = RegExp(
    r'\b(?!219-09-9999|078-05-1120)(?!666|000|9\d{2})\d{3}'
    r'(?!-00)(?!00)\d{2}(?!0{4})\d{4}\b',
  );

  static final _ibanPattern = RegExp(
    r'\b[A-Z]{2}\d{2}[A-Z0-9]{4}\d{7}(?:[A-Z0-9]?){0,16}\b',
  );

  static final _passwordPattern = RegExp(
    r'(?:password|passwd|pass|pwd)\s*[:=]\s*\S+',
    caseSensitive: false,
  );

  // Shannon entropy check for high-entropy strings (likely secrets)
  bool _isHighEntropy(String text) {
    final trimmed = text.trim();
    // Only check strings that look like tokens (no spaces, right length)
    if (trimmed.length < 20 || trimmed.length > 100 || trimmed.contains(' ')) {
      return false;
    }
    final entropy = _shannonEntropy(trimmed);
    return entropy > 4.5; // Typical secret threshold
  }

  double _shannonEntropy(String s) {
    final freq = <String, int>{};
    for (final c in s.split('')) {
      freq[c] = (freq[c] ?? 0) + 1;
    }
    double entropy = 0;
    final len = s.length;
    for (final count in freq.values) {
      final p = count / len;
      if (p > 0) entropy -= p * (math.log(p) / math.ln2);
    }
    return entropy;
  }

  bool _luhnCheck(String number) {
    if (number.length < 13 || number.length > 19) return false;
    int sum = 0;
    bool alternate = false;
    for (int i = number.length - 1; i >= 0; i--) {
      int n = int.tryParse(number[i]) ?? 0;
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  // ── TTL / SWEEP ───────────────────────────────────────────────────────────

  Future<void> startTimers() async {
    _sweepTimer?.cancel();
    _sweepTimer = Timer.periodic(_sweepInterval, (_) => _sweep());
  }

  Future<void> _sweep() async {
    final expired = await clipRepo.fetchExpired();
    for (final clip in expired) {
      await clipRepo.delete(clip.id);
      for (final cb in _expiryCallbacks) {
        cb(clip.id);
      }
    }
  }

  void onExpiry(void Function(String clipId) callback) {
    _expiryCallbacks.add(callback);
  }

  Future<void> extendTtl(String clipId, int additionalSeconds) async {
    final clip = await clipRepo.fetchById(clipId);
    if (clip == null) return;
    final newExpiry = (clip.ttlExpiry ?? DateTime.now()).add(
      Duration(seconds: additionalSeconds),
    );
    await clipRepo.updateTtl(clipId, newExpiry);
  }

  Future<void> clearTtl(String clipId) async {
    await clipRepo.updateTtl(clipId, null);
  }

  Future<void> purgeNow(String clipId) async {
    await clipRepo.delete(clipId);
    for (final cb in _expiryCallbacks) {
      cb(clipId);
    }
  }

  void dispose() {
    _sweepTimer?.cancel();
    _expiryCallbacks.clear();
  }
}
