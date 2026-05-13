import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:langchain_ollama/langchain_ollama.dart';
import 'package:rxdart/rxdart.dart';

import '../../data/models/clip_record.dart';
import '../../data/repositories/clip_repository.dart';
import 'classifier_service.dart';
import 'clean_room_service.dart';
import 'ghost_layer_service.dart';
import 'ocr_service.dart';
import 'settings_service.dart';

/// Monitors the OS clipboard for changes and runs the full
/// capture pipeline: classify → OCR → clean → ghost → store.
class ClipboardMonitorService {
  final ClipRepository clipRepo;
  final ClassifierService classifier;
  final OcrService ocr;
  final CleanRoomService cleanRoom;
  final GhostLayerService ghost;
  final SettingsService settings;

  final _clipStream = BehaviorSubject<ClipRecord>();
  Stream<ClipRecord> get clipStream => _clipStream.stream;

  Timer? _pollTimer;
  String? _lastHash;
  bool _monitoring = false;

  bool _suppressNext = false;

  /// Call before a programmatic clipboard write to prevent re-capturing
  /// the item we just pasted back.
  void suppressNextCapture() => _suppressNext = true;

  // Platform channels for native clipboard access
  static const _channel = MethodChannel('com.clipsync.nexus/clipboard');

  ClipboardMonitorService({
    required this.clipRepo,
    required this.classifier,
    required this.ocr,
    required this.cleanRoom,
    required this.ghost,
    required this.settings,
  });

  Future<void> startMonitoring() async {
    if (_monitoring) return;
    _monitoring = true;

    if (Platform.isAndroid) {
      // Android: use platform channel for background monitoring
      _channel.setMethodCallHandler(_handleNativeClipboardChange);
      await _channel.invokeMethod('startMonitoring');
    } else {
      // Windows / others: poll
      _pollTimer = Timer.periodic(_pollInterval, (_) => _pollClipboard());
    }
  }

  Future<void> stopMonitoring() async {
    _monitoring = false;
    _pollTimer?.cancel();
    if (Platform.isAndroid) {
      await _channel.invokeMethod('stopMonitoring');
    }
  }

  // ── ANDROID NATIVE CALLBACK ──────────────────────────────────────────────

  Future<dynamic> _handleNativeClipboardChange(MethodCall call) async {
    if (_suppressNext) { _suppressNext = false; return; }
    if (call.method == 'onClipboardChange') {
      final data = call.arguments as Map<dynamic, dynamic>;
      await _processNativeData(Map<String, dynamic>.from(data));
    }
  }

  // ── WINDOWS POLLING ───────────────────────────────────────────────────────

  Future<void> _pollClipboard() async {
    if (!_monitoring) return;
    if (_suppressNext) { _suppressNext = false; return; }
    try {
      final text = await Clipboard.getData(Clipboard.kTextPlain);
      if (text?.text == null) return;

      final hash = sha256.convert(utf8.encode(text!.text!)).toString();
      if (hash == _lastHash) return;
      _lastHash = hash;

      final payloads = <ClipPayload>[
        ClipPayload(
          mimeType: 'text/plain',
          text: text.text,
        ),
      ];

      // Try to get HTML version too
      // (Windows: use platform channel for rich formats)
      if (Platform.isWindows) {
        try {
          final html = await _channel.invokeMethod<String>('getRichText');
          if (html != null && html.isNotEmpty) {
            payloads.add(ClipPayload(mimeType: 'text/html', text: html));
          }
          final imageBytes = await _channel.invokeMethod<Uint8List>('getImage');
          if (imageBytes != null && imageBytes.isNotEmpty) {
            payloads.add(ClipPayload(mimeType: 'image/png', bytes: imageBytes));
          }
        } catch (_) {}
      }

      await _runCapturePipeline(payloads, sourceApp: _getActiveWindow());
    } catch (e) {
      // Clipboard access can fail if another app has exclusive lock
    }
  }

  // ── CAPTURE PIPELINE ──────────────────────────────────────────────────────

  Future<void> _processNativeData(Map<String, dynamic> data) async {
    final payloads = <ClipPayload>[];

    if (data['text'] != null) {
      payloads.add(ClipPayload(mimeType: 'text/plain', text: data['text'] as String));
    }
    if (data['html'] != null) {
      payloads.add(ClipPayload(mimeType: 'text/html', text: data['html'] as String));
    }
    if (data['imageBytes'] != null) {
      payloads.add(ClipPayload(mimeType: 'image/png', bytes: Uint8List.fromList(
        List<int>.from(data['imageBytes'] as List),
      )));
    }
    if (data['filePaths'] != null) {
      for (final path in data['filePaths'] as List) {
        payloads.add(ClipPayload(mimeType: 'application/x-file-ref', text: path as String));
      }
    }

    await _runCapturePipeline(
      payloads,
      sourceApp: data['sourceApp'] as String? ?? 'Unknown',
      sourceBundleId: data['bundleId'] as String?,
    );
  }

  Future<void> _runCapturePipeline(
    List<ClipPayload> payloads, {
    String? sourceApp,
    String? sourceBundleId,
  }) async {
    if (payloads.isEmpty) return;

    // 1. Compute content hash
    final primaryText = payloads.first.text ?? '';
    final hash = sha256.convert(utf8.encode(primaryText)).toString();

    // 2. Deduplicate — don't re-capture the same content
    // (unless sensitive — sensitive clips always need fresh TTL)
    final existing = await _findByHash(hash);
    if (existing != null && !existing.isSensitive) return;

    // 3. Classify content type
    final contentType = classifier.classifyType(payloads);

    // 4. OCR (async — run in background, update record after)
    ClipMetadata metadata = ClipMetadata(
      contentHash: hash,
      sourceApp: sourceApp,
      sourceBundleId: sourceBundleId,
    );

    // 5. Clean Room — apply to URLs and text immediately
    List<ClipPayload> cleanedPayloads = payloads;
    bool wasCleaned = false;
    if (settings.current.cleanRoomEnabled && contentType == ClipContentType.url) {
      final result = await cleanRoom.processUrl(primaryText);
      if (result.wasModified) {
        cleanedPayloads = [
          ClipPayload(mimeType: 'text/plain', text: result.cleanedUrl),
          ...payloads,
        ];
        metadata = metadata.copyWith(cleanedUrl: result.cleanedUrl);
        wasCleaned = true;
      }
    }
    if (settings.current.cleanRoomEnabled && settings.current.stripZeroWidthChars) {
      cleanedPayloads = cleanedPayloads.map((p) {
        if (p.text != null) {
          return ClipPayload(
            mimeType: p.mimeType,
            text: cleanRoom.stripZeroWidthChars(p.text!),
            blobPath: p.blobPath,
          );
        }
        return p;
      }).toList();
    }

    // 6. AI classification tags
    final tags = classifier.classifyTags(cleanedPayloads, contentType);
    metadata = metadata.copyWith(
      aiTags: tags,
      codeLanguage: contentType == ClipContentType.code
          ? classifier.detectCodeLanguage(primaryText)
          : null,
      colorHex: contentType == ClipContentType.color
          ? classifier.extractColorHex(primaryText)
          : null,
    );

    // 7. Sensitivity detection
    final sensitivity = ghost.detectSensitivity(primaryText, payloads);
    DateTime? ttlExpiry;
    if (sensitivity != ClipSensitivityCategory.none && settings.current.ghostLayerEnabled) {
      ttlExpiry = DateTime.now().add(
        Duration(seconds: settings.current.ghostDefaultTtlSeconds),
      );
    }

    // 8. Create and persist record
    final clip = ClipRecord.create(
      contentType: contentType,
      payloads: cleanedPayloads,
      metadata: metadata,
      flags: ClipFlags(cleaned: wasCleaned),
      sensitivityCategory: sensitivity,
      ttlExpiry: ttlExpiry,
    );

    await clipRepo.insert(clip);
    await clipRepo.evictToLimit(settings.current.maxSlots);

    // 9. Async: OCR for images
    if (settings.current.ocrEnabled) {
      _runOcrAsync(clip);
    }

    // 10. Async: generate semantic embedding
    if (settings.current.semanticSearchEnabled) {
      _generateEmbeddingAsync(clip);
    }

    // 11. Notify listeners
    _clipStream.add(clip);
  }

  void _runOcrAsync(ClipRecord clip) async {
    final imagePaylod = clip.payloads.firstWhere(
      (p) => p.mimeType.startsWith('image/'),
      orElse: () => const ClipPayload(mimeType: ''),
    );
    if (imagePaylod.mimeType.isEmpty) return;

    final bytes = imagePaylod.bytes;
    if (bytes == null || bytes.isEmpty) return;

    try {
      final text = await ocr.extractText(bytes);
      if (text.isNotEmpty) {
        final updated = clip.copyWith(
          metadata: clip.metadata.copyWith(ocrText: text),
        );
        await clipRepo.update(updated);
        _clipStream.add(updated);
      }
    } catch (_) {}
  }

  void _generateEmbeddingAsync(ClipRecord clip) async {
    try {
      final text = [
        clip.primaryText,
        clip.metadata.ocrText ?? '',
        clip.metadata.aiTags.join(' '),
      ].join(' ').trim();
      if (text.isEmpty) return;

      final embeddings = OllamaEmbeddings(model: 'nomic-embed-text');
      final vector = await embeddings.embedQuery(text);
      await clipRepo.updateEmbedding(
        clip.id,
        Float32List.fromList(vector.map((v) => v.toDouble()).toList()),
      );
    } catch (_) {
      // Ollama not running or model not pulled — silently skip embedding.
      // Keyword search (BM25) continues to work without embeddings.
    }
  }

  Future<ClipRecord?> _findByHash(String hash) async {
    final rows = await clipRepo.db.queryRaw(
      "SELECT id FROM clips WHERE metadata_json LIKE ? LIMIT 1",
      ['%"contentHash":"$hash"%'],
    );
    if (rows.isEmpty) return null;
    return clipRepo.fetchById(rows.first['id'] as String);
  }

  String _getActiveWindow() {
    // Platform-specific: return name of currently focused app
    // Implemented via platform channel on both Android and Windows
    return 'Unknown';
  }

  void dispose() {
    stopMonitoring();
    _clipStream.close();
  }
}
