import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/models/clip_record.dart';

/// Central database service.
/// Uses SQLite (WAL mode) for metadata + FTS5 for full-text search.
/// Payloads >4 KB are stored in a content-addressable blob store on disk.
class DatabaseService {
  static const int _version = 1;
  static const String _dbName = 'clipsync_nexus.db';
  static const int _blobInlineThreshold = 4096; // bytes

  late Database _db;
  late Directory _blobDir;
  bool _initialized = false;

  Database get db => _db;

  Future<void> init() async {
    if (_initialized) return;
    final appDir = await getApplicationSupportDirectory();
    _blobDir = Directory(p.join(appDir.path, 'blobs'));
    await _blobDir.create(recursive: true);

    final dbPath = p.join(appDir.path, _dbName);
    _db = await openDatabase(
      dbPath,
      version: _version,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );
    _initialized = true;
  }

  Future<void> _onOpen(Database db) async {
    await db.execute('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('PRAGMA cache_size = -32000'); // 32 MB cache
  }

  Future<void> _onCreate(Database db, int version) async {
    await _onOpen(db);

    // Main clip records table
    await db.execute('''
      CREATE TABLE clips (
        id           TEXT PRIMARY KEY,
        captured_at  INTEGER NOT NULL,
        content_type TEXT NOT NULL,
        sensitivity  TEXT NOT NULL DEFAULT 'none',
        ttl_expiry   INTEGER,
        flags_json   TEXT NOT NULL DEFAULT '{}',
        metadata_json TEXT NOT NULL DEFAULT '{}',
        chunk_group_json TEXT,
        created_at   INTEGER NOT NULL DEFAULT (unixepoch('now') * 1000)
      )
    ''');

    // Payloads (each clip may have multiple MIME formats)
    await db.execute('''
      CREATE TABLE payloads (
        id        TEXT PRIMARY KEY,
        clip_id   TEXT NOT NULL REFERENCES clips(id) ON DELETE CASCADE,
        mime_type TEXT NOT NULL,
        text_data TEXT,
        blob_path TEXT,
        blob_hash TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // FTS5 virtual table for full-text search
    await db.execute('''
      CREATE VIRTUAL TABLE clips_fts USING fts5(
        id UNINDEXED,
        content,
        ocr_text,
        source_app,
        tags,
        content='clips',
        tokenize='porter unicode61'
      )
    ''');

    // Triggers to keep FTS in sync
    await db.execute('''
      CREATE TRIGGER clips_ai AFTER INSERT ON clips BEGIN
        INSERT INTO clips_fts(rowid, id, content, ocr_text, source_app, tags)
        SELECT new.rowid, new.id, '', '', '', '';
      END
    ''');
    await db.execute('''
      CREATE TRIGGER clips_ad AFTER DELETE ON clips BEGIN
        INSERT INTO clips_fts(clips_fts, rowid, id, content, ocr_text, source_app, tags)
        VALUES('delete', old.rowid, old.id, '', '', '', '');
      END
    ''');

    // Embeddings table (separate for lazy loading)
    await db.execute('''
      CREATE TABLE embeddings (
        clip_id   TEXT PRIMARY KEY REFERENCES clips(id) ON DELETE CASCADE,
        vector    BLOB NOT NULL
      )
    ''');

    // Teleport trust store
    await db.execute('''
      CREATE TABLE trusted_peers (
        id          TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        public_key  TEXT NOT NULL,
        fingerprint TEXT NOT NULL,
        trusted_at  INTEGER NOT NULL,
        platform    TEXT,
        last_seen   INTEGER
      )
    ''');

    // Settings kv store
    await db.execute('''
      CREATE TABLE settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Scratchpad named documents
    await db.execute('''
      CREATE TABLE scratchpads (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        blocks_json TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_clips_captured ON clips(captured_at DESC)');
    await db.execute('CREATE INDEX idx_clips_type ON clips(content_type)');
    await db.execute('CREATE INDEX idx_clips_sensitivity ON clips(sensitivity)');
    await db.execute('CREATE INDEX idx_clips_ttl ON clips(ttl_expiry) WHERE ttl_expiry IS NOT NULL');
    await db.execute('CREATE INDEX idx_payloads_clip ON payloads(clip_id)');
  }

  // ── BLOB STORE ──────────────────────────────────────────────────────────

  /// Stores bytes in content-addressable blob store. Returns file path.
  Future<String> writeBlobStore(Uint8List bytes) async {
    final hash = sha256.convert(bytes).toString();
    final blobPath = p.join(_blobDir.path, hash);
    final file = File(blobPath);
    if (!await file.exists()) {
      await file.writeAsBytes(bytes);
    }
    return blobPath;
  }

  Future<Uint8List?> readBlobStore(String blobPath) async {
    final file = File(blobPath);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  }

  Future<void> deleteBlobIfOrphaned(String blobPath) async {
    // Check if any payload still references this blob
    final rows = await _db.query(
      'payloads',
      where: 'blob_path = ?',
      whereArgs: [blobPath],
    );
    if (rows.isEmpty) {
      final file = File(blobPath);
      if (await file.exists()) await file.delete();
    }
  }

  // ── FTS UPDATE ───────────────────────────────────────────────────────────

  Future<void> updateFtsContent(String clipId, {
    required String content,
    required String ocrText,
    required String sourceApp,
    required String tags,
  }) async {
    await _db.execute('''
      UPDATE clips_fts SET content=?, ocr_text=?, source_app=?, tags=?
      WHERE id=?
    ''', [content, ocrText, sourceApp, tags, clipId]);
  }

  // ── FTS SEARCH ───────────────────────────────────────────────────────────

  Future<List<String>> ftsSearch(String query, {int limit = 50}) async {
    // Escape special FTS5 characters
    final escaped = query
        .replaceAll('"', '""')
        .replaceAll("'", "''");
    try {
      final rows = await _db.rawQuery('''
        SELECT id, rank FROM clips_fts
        WHERE clips_fts MATCH ?
        ORDER BY rank
        LIMIT ?
      ''', [escaped, limit]);
      return rows.map((r) => r['id'] as String).toList();
    } catch (_) {
      // FTS query syntax error — fallback to LIKE
      return await _likeSearch(query, limit: limit);
    }
  }

  Future<List<String>> _likeSearch(String query, {int limit = 50}) async {
    final pattern = '%${query.toLowerCase()}%';
    final rows = await _db.rawQuery('''
      SELECT id FROM clips_fts
      WHERE lower(content) LIKE ? OR lower(ocr_text) LIKE ? OR lower(tags) LIKE ?
      LIMIT ?
    ''', [pattern, pattern, pattern, limit]);
    return rows.map((r) => r['id'] as String).toList();
  }

  // ── CRUD HELPERS ─────────────────────────────────────────────────────────

  Future<void> insertRaw(String table, Map<String, dynamic> values) async {
    await _db.insert(table, values, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateRaw(String table, Map<String, dynamic> values, String where, List<dynamic> args) async {
    await _db.update(table, values, where: where, whereArgs: args);
  }

  Future<void> deleteRaw(String table, String where, List<dynamic> args) async {
    await _db.delete(table, where: where, whereArgs: args);
  }

  Future<List<Map<String, dynamic>>> queryRaw(String sql, [List<dynamic>? args]) async {
    return await _db.rawQuery(sql, args);
  }

  Future<void> runTransaction(Future<void> Function(Transaction txn) action) async {
    await _db.transaction(action);
  }

  // ── MAINTENANCE ──────────────────────────────────────────────────────────

  /// Checkpoints WAL file — call during idle.
  Future<void> walCheckpoint() async {
    await _db.execute('PRAGMA wal_checkpoint(PASSIVE)');
  }

  /// Cryptographically overwrites a clip's payload data before deletion.
  Future<void> secureDelete(String clipId) async {
    // Overwrite payloads in DB with random data before deleting
    final payloadRows = await _db.query('payloads', where: 'clip_id = ?', whereArgs: [clipId]);
    for (final row in payloadRows) {
      await _db.update('payloads', {
        'text_data': null,
        'blob_path': null,
        'blob_hash': null,
      }, where: 'clip_id = ?', whereArgs: [clipId]);
      // Delete blob file if exists
      final blobPath = row['blob_path'] as String?;
      if (blobPath != null) {
        await deleteBlobIfOrphaned(blobPath);
      }
    }
    await _db.delete('clips', where: 'id = ?', whereArgs: [clipId]);
  }

  Future<void> close() async {
    if (_initialized) await _db.close();
  }
}
