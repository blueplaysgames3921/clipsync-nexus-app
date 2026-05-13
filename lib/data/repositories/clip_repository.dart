import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../core/database/database_service.dart';
import 'models/clip_record.dart';

class ClipRepository {
  final DatabaseService db;

  ClipRepository({required this.db});

  // ── INSERT ───────────────────────────────────────────────────────────────

  Future<void> insert(ClipRecord clip) async {
    await db.runTransaction((txn) async {
      await txn.insert('clips', {
        'id': clip.id,
        'captured_at': clip.capturedAt.millisecondsSinceEpoch,
        'content_type': clip.contentType.name,
        'sensitivity': clip.sensitivityCategory.name,
        'ttl_expiry': clip.ttlExpiry?.millisecondsSinceEpoch,
        'flags_json': jsonEncode(_flagsToJson(clip.flags)),
        'metadata_json': jsonEncode(_metadataToJson(clip.metadata)),
        'chunk_group_json': clip.chunkGroup != null ? jsonEncode(_chunkGroupToJson(clip.chunkGroup!)) : null,
      });

      for (int i = 0; i < clip.payloads.length; i++) {
        final p = clip.payloads[i];
        String? blobPath;

        // Store large blobs in blob store
        if (p.bytes != null && p.bytes!.length > 4096) {
          blobPath = await db.writeBlobStore(p.bytes!);
        }

        await txn.insert('payloads', {
          'id': const Uuid().v4(),
          'clip_id': clip.id,
          'mime_type': p.mimeType,
          'text_data': p.text,
          'blob_path': blobPath ?? p.blobPath,
          'blob_hash': blobPath != null ? blobPath.split('/').last : null,
          'sort_order': i,
        });
      }
    });

    // Update FTS index (async — non-blocking)
    _updateFts(clip);
  }

  Future<void> _updateFts(ClipRecord clip) async {
    final content = clip.payloads.map((p) => p.text ?? '').join(' ');
    await db.updateFtsContent(
      clip.id,
      content: content,
      ocrText: clip.metadata.ocrText ?? '',
      sourceApp: clip.metadata.sourceApp ?? '',
      tags: clip.metadata.aiTags.join(' '),
    );
  }

  // ── FETCH ────────────────────────────────────────────────────────────────

  Future<List<ClipRecord>> fetchPage({
    int limit = 50,
    int offset = 0,
    ClipContentType? filterType,
    bool sensitiveOnly = false,
  }) async {
    String where = '1=1';
    final args = <dynamic>[];

    if (filterType != null) {
      where += ' AND content_type = ?';
      args.add(filterType.name);
    }
    if (sensitiveOnly) {
      where += " AND sensitivity != 'none'";
    }

    final rows = await db.queryRaw('''
      SELECT c.*, GROUP_CONCAT(p.mime_type, '|') as mime_types
      FROM clips c
      LEFT JOIN payloads p ON p.clip_id = c.id
      WHERE $where
      GROUP BY c.id
      ORDER BY c.captured_at DESC
      LIMIT ? OFFSET ?
    ''', [...args, limit, offset]);

    final clips = <ClipRecord>[];
    for (final row in rows) {
      clips.add(await _rowToClip(row));
    }
    return clips;
  }

  Future<ClipRecord?> fetchById(String id) async {
    final rows = await db.queryRaw(
      'SELECT * FROM clips WHERE id = ?', [id],
    );
    if (rows.isEmpty) return null;
    return _rowToClip(rows.first);
  }

  Future<List<ClipRecord>> fetchExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.queryRaw(
      'SELECT * FROM clips WHERE ttl_expiry IS NOT NULL AND ttl_expiry <= ?',
      [now],
    );
    final clips = <ClipRecord>[];
    for (final row in rows) {
      clips.add(await _rowToClip(row));
    }
    return clips;
  }

  Future<List<ClipRecord>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final placeholders = ids.map((_) => '?').join(',');
    final rows = await db.queryRaw(
      'SELECT * FROM clips WHERE id IN ($placeholders) ORDER BY captured_at DESC',
      ids,
    );
    final clips = <ClipRecord>[];
    for (final row in rows) {
      clips.add(await _rowToClip(row));
    }
    return clips;
  }

  // Load only metadata for history list (no payloads — lazy loading)
  Future<List<Map<String, dynamic>>> fetchMetaList({int limit = 200}) async {
    return await db.queryRaw('''
      SELECT id, captured_at, content_type, sensitivity, ttl_expiry,
             metadata_json, flags_json
      FROM clips
      ORDER BY captured_at DESC
      LIMIT ?
    ''', [limit]);
  }

  // ── UPDATE ───────────────────────────────────────────────────────────────

  Future<void> update(ClipRecord clip) async {
    await db.updateRaw('clips', {
      'content_type': clip.contentType.name,
      'sensitivity': clip.sensitivityCategory.name,
      'ttl_expiry': clip.ttlExpiry?.millisecondsSinceEpoch,
      'flags_json': jsonEncode(_flagsToJson(clip.flags)),
      'metadata_json': jsonEncode(_metadataToJson(clip.metadata)),
    }, 'id = ?', [clip.id]);
    _updateFts(clip);
  }

  Future<void> updateTtl(String clipId, DateTime? newExpiry) async {
    await db.updateRaw('clips', {
      'ttl_expiry': newExpiry?.millisecondsSinceEpoch,
    }, 'id = ?', [clipId]);
  }

  Future<void> updateEmbedding(String clipId, Float32List vector) async {
    await db.insertRaw('embeddings', {
      'clip_id': clipId,
      'vector': _float32ToBlob(vector),
    });
  }

  // ── DELETE ───────────────────────────────────────────────────────────────

  Future<void> delete(String clipId) async {
    await db.secureDelete(clipId);
  }

  Future<void> deleteAll() async {
    await db.deleteRaw('clips', '1=1', []);
  }

  /// Evict oldest non-pinned clips to stay within maxSlots.
  Future<void> evictToLimit(int maxSlots) async {
    final countRow = await db.queryRaw(
      "SELECT COUNT(*) as cnt FROM clips WHERE flags_json NOT LIKE '%\"pinned\":true%'",
    );
    final total = (countRow.first['cnt'] as int?) ?? 0;
    final excess = total - maxSlots;
    if (excess <= 0) return;

    await db.queryRaw('''
      DELETE FROM clips
      WHERE id IN (
        SELECT id FROM clips
        WHERE flags_json NOT LIKE '%"pinned":true%'
        ORDER BY captured_at ASC
        LIMIT ?
      )
    ''', [excess]);
  }

  // ── SEARCH ───────────────────────────────────────────────────────────────

  Future<List<ClipRecord>> search(String query, {int limit = 50}) async {
    final ids = await db.ftsSearch(query, limit: limit);
    if (ids.isEmpty) return [];
    return fetchByIds(ids);
  }

  // ── SETTINGS ─────────────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final rows = await db.queryRaw(
      'SELECT value FROM settings WHERE key = ?', [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    await db.insertRaw('settings', {'key': key, 'value': value});
  }

  // ── SCRATCHPADS ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchScratchpads() async {
    return await db.queryRaw(
      'SELECT * FROM scratchpads ORDER BY updated_at DESC',
    );
  }

  Future<void> saveScratchpad(String id, String name, List<Map<String, dynamic>> blocks) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insertRaw('scratchpads', {
      'id': id,
      'name': name,
      'created_at': now,
      'updated_at': now,
      'blocks_json': jsonEncode(blocks),
    });
  }

  Future<void> updateScratchpad(String id, List<Map<String, dynamic>> blocks) async {
    await db.updateRaw('scratchpads', {
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'blocks_json': jsonEncode(blocks),
    }, 'id = ?', [id]);
  }

  Future<void> deleteScratchpad(String id) async {
    await db.deleteRaw('scratchpads', 'id = ?', [id]);
  }

  // ── TRUSTED PEERS ─────────────────────────────────────────────────────────

  Future<void> saveTrustedPeer(Map<String, dynamic> peer) async {
    await db.insertRaw('trusted_peers', peer);
  }

  Future<List<Map<String, dynamic>>> fetchTrustedPeers() async {
    return await db.queryRaw('SELECT * FROM trusted_peers');
  }

  Future<void> removeTrustedPeer(String peerId) async {
    await db.deleteRaw('trusted_peers', 'id = ?', [peerId]);
  }

  // ── PRIVATE HELPERS ───────────────────────────────────────────────────────

  Future<ClipRecord> _rowToClip(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final payloadRows = await db.queryRaw(
      'SELECT * FROM payloads WHERE clip_id = ? ORDER BY sort_order',
      [id],
    );

    final payloads = <ClipPayload>[];
    for (final pr in payloadRows) {
      Uint8List? bytes;
      final blobPath = pr['blob_path'] as String?;
      if (blobPath != null) {
        bytes = await db.readBlobStore(blobPath);
      }
      payloads.add(ClipPayload(
        mimeType: pr['mime_type'] as String,
        text: pr['text_data'] as String?,
        bytes: bytes,
        blobPath: blobPath,
      ));
    }

    final metaJson = jsonDecode(row['metadata_json'] as String? ?? '{}') as Map<String, dynamic>;
    final flagsJson = jsonDecode(row['flags_json'] as String? ?? '{}') as Map<String, dynamic>;
    final chunkJson = row['chunk_group_json'] as String?;

    return ClipRecord(
      id: id,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(row['captured_at'] as int),
      contentType: ClipContentType.values.firstWhere(
        (e) => e.name == row['content_type'],
        orElse: () => ClipContentType.plainText,
      ),
      payloads: payloads,
      metadata: _metadataFromJson(metaJson),
      flags: _flagsFromJson(flagsJson),
      sensitivityCategory: ClipSensitivityCategory.values.firstWhere(
        (e) => e.name == (row['sensitivity'] ?? 'none'),
        orElse: () => ClipSensitivityCategory.none,
      ),
      ttlExpiry: row['ttl_expiry'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['ttl_expiry'] as int)
          : null,
      chunkGroup: chunkJson != null ? _chunkGroupFromJson(jsonDecode(chunkJson)) : null,
    );
  }

  Map<String, dynamic> _metadataToJson(ClipMetadata m) => {
    'ocrText': m.ocrText,
    'aiTags': m.aiTags,
    'sourceApp': m.sourceApp,
    'sourceBundleId': m.sourceBundleId,
    'contentHash': m.contentHash,
    'language': m.language,
    'codeLanguage': m.codeLanguage,
    'colorHex': m.colorHex,
    'pageTitle': m.pageTitle,
    'cleanedUrl': m.cleanedUrl,
    'exifData': m.exifData,
  };

  ClipMetadata _metadataFromJson(Map<String, dynamic> j) => ClipMetadata(
    ocrText: j['ocrText'] as String?,
    aiTags: List<String>.from(j['aiTags'] ?? []),
    sourceApp: j['sourceApp'] as String?,
    sourceBundleId: j['sourceBundleId'] as String?,
    contentHash: j['contentHash'] as String? ?? '',
    language: j['language'] as String?,
    codeLanguage: j['codeLanguage'] as String?,
    colorHex: j['colorHex'] as String?,
    pageTitle: j['pageTitle'] as String?,
    cleanedUrl: j['cleanedUrl'] as String?,
    exifData: Map<String, String>.from(j['exifData'] ?? {}),
  );

  Map<String, dynamic> _flagsToJson(ClipFlags f) => {
    'pinned': f.pinned,
    'cleaned': f.cleaned,
    'isChunkParent': f.isChunkParent,
    'isChunkChild': f.isChunkChild,
    'markedNotSensitive': f.markedNotSensitive,
    'teleportBlocked': f.teleportBlocked,
  };

  ClipFlags _flagsFromJson(Map<String, dynamic> j) => ClipFlags(
    pinned: j['pinned'] as bool? ?? false,
    cleaned: j['cleaned'] as bool? ?? false,
    isChunkParent: j['isChunkParent'] as bool? ?? false,
    isChunkChild: j['isChunkChild'] as bool? ?? false,
    markedNotSensitive: j['markedNotSensitive'] as bool? ?? false,
    teleportBlocked: j['teleportBlocked'] as bool? ?? false,
  );

  Map<String, dynamic> _chunkGroupToJson(ChunkGroupRef c) => {
    'parentId': c.parentId,
    'segmentIndex': c.segmentIndex,
    'totalSegments': c.totalSegments,
    'strategy': c.strategy,
  };

  ChunkGroupRef _chunkGroupFromJson(Map<String, dynamic> j) => ChunkGroupRef(
    parentId: j['parentId'] as String,
    segmentIndex: j['segmentIndex'] as int,
    totalSegments: j['totalSegments'] as int,
    strategy: j['strategy'] as String,
  );

  Uint8List _float32ToBlob(Float32List v) {
    final bd = ByteData(v.length * 4);
    for (int i = 0; i < v.length; i++) {
      bd.setFloat32(i * 4, v[i], Endian.little);
    }
    return bd.buffer.asUint8List();
  }
}
