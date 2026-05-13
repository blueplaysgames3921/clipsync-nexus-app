import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

enum ClipContentType {
  plainText,
  richText,
  code,
  image,
  fileRef,
  url,
  contact,
  legal,
  financial,
  medical,
  color,
  mixed,
}

enum ClipSensitivityCategory {
  none,
  password,
  apiKey,
  creditCard,
  ssn,
  bankAccount,
  privateKey,
  medicalId,
  pii,
  custom,
}

class ClipPayload extends Equatable {
  final String mimeType;
  final Uint8List? bytes;
  final String? text;
  final String? blobPath; // path into content-addressable blob store

  const ClipPayload({
    required this.mimeType,
    this.bytes,
    this.text,
    this.blobPath,
  });

  @override
  List<Object?> get props => [mimeType, text, blobPath];
}

class ClipMetadata extends Equatable {
  final String? ocrText;
  final List<String> aiTags;
  final String? sourceApp;
  final String? sourceBundleId;
  final String contentHash; // SHA-256 of primary payload
  final Float32List? embedding; // 384-dim semantic vector
  final String? language;
  final String? codeLanguage;
  final String? colorHex;
  final String? pageTitle; // for URLs
  final String? cleanedUrl; // URL after Clean Room
  final Map<String, String> exifData;

  const ClipMetadata({
    this.ocrText,
    this.aiTags = const [],
    this.sourceApp,
    this.sourceBundleId,
    required this.contentHash,
    this.embedding,
    this.language,
    this.codeLanguage,
    this.colorHex,
    this.pageTitle,
    this.cleanedUrl,
    this.exifData = const {},
  });

  ClipMetadata copyWith({
    String? ocrText,
    List<String>? aiTags,
    String? sourceApp,
    String? sourceBundleId,
    String? contentHash,
    Float32List? embedding,
    String? language,
    String? codeLanguage,
    String? colorHex,
    String? pageTitle,
    String? cleanedUrl,
    Map<String, String>? exifData,
  }) {
    return ClipMetadata(
      ocrText: ocrText ?? this.ocrText,
      aiTags: aiTags ?? this.aiTags,
      sourceApp: sourceApp ?? this.sourceApp,
      sourceBundleId: sourceBundleId ?? this.sourceBundleId,
      contentHash: contentHash ?? this.contentHash,
      embedding: embedding ?? this.embedding,
      language: language ?? this.language,
      codeLanguage: codeLanguage ?? this.codeLanguage,
      colorHex: colorHex ?? this.colorHex,
      pageTitle: pageTitle ?? this.pageTitle,
      cleanedUrl: cleanedUrl ?? this.cleanedUrl,
      exifData: exifData ?? this.exifData,
    );
  }

  @override
  List<Object?> get props => [ocrText, aiTags, contentHash, language, codeLanguage, colorHex];
}

class ClipFlags extends Equatable {
  final bool pinned;
  final bool cleaned; // Clean Room was applied
  final bool isChunkParent;
  final bool isChunkChild;
  final bool markedNotSensitive;
  final bool teleportBlocked;

  const ClipFlags({
    this.pinned = false,
    this.cleaned = false,
    this.isChunkParent = false,
    this.isChunkChild = false,
    this.markedNotSensitive = false,
    this.teleportBlocked = false,
  });

  ClipFlags copyWith({
    bool? pinned,
    bool? cleaned,
    bool? isChunkParent,
    bool? isChunkChild,
    bool? markedNotSensitive,
    bool? teleportBlocked,
  }) {
    return ClipFlags(
      pinned: pinned ?? this.pinned,
      cleaned: cleaned ?? this.cleaned,
      isChunkParent: isChunkParent ?? this.isChunkParent,
      isChunkChild: isChunkChild ?? this.isChunkChild,
      markedNotSensitive: markedNotSensitive ?? this.markedNotSensitive,
      teleportBlocked: teleportBlocked ?? this.teleportBlocked,
    );
  }

  @override
  List<Object?> get props => [pinned, cleaned, isChunkParent, isChunkChild, markedNotSensitive, teleportBlocked];
}

class ChunkGroupRef extends Equatable {
  final String parentId;
  final int segmentIndex;
  final int totalSegments;
  final String strategy;

  const ChunkGroupRef({
    required this.parentId,
    required this.segmentIndex,
    required this.totalSegments,
    required this.strategy,
  });

  @override
  List<Object?> get props => [parentId, segmentIndex, totalSegments];
}

class ClipRecord extends Equatable {
  final String id;
  final DateTime capturedAt;
  final ClipContentType contentType;
  final List<ClipPayload> payloads;
  final ClipMetadata metadata;
  final ClipFlags flags;
  final ClipSensitivityCategory sensitivityCategory;
  final DateTime? ttlExpiry; // null = no expiry
  final ChunkGroupRef? chunkGroup;

  // Convenience: primary text from payloads
  String get primaryText {
    for (final p in payloads) {
      if (p.text != null) return p.text!;
    }
    return '';
  }

  // Preview text (truncated)
  String get preview {
    final t = primaryText;
    if (t.isEmpty) return '[${contentType.name}]';
    return t.length > 200 ? '${t.substring(0, 200)}…' : t;
  }

  bool get isSensitive => sensitivityCategory != ClipSensitivityCategory.none;

  bool get isExpired => ttlExpiry != null && DateTime.now().isAfter(ttlExpiry!);

  Duration? get ttlRemaining {
    if (ttlExpiry == null) return null;
    final rem = ttlExpiry!.difference(DateTime.now());
    return rem.isNegative ? Duration.zero : rem;
  }

  const ClipRecord({
    required this.id,
    required this.capturedAt,
    required this.contentType,
    required this.payloads,
    required this.metadata,
    required this.flags,
    this.sensitivityCategory = ClipSensitivityCategory.none,
    this.ttlExpiry,
    this.chunkGroup,
  });

  factory ClipRecord.create({
    required ClipContentType contentType,
    required List<ClipPayload> payloads,
    required ClipMetadata metadata,
    ClipFlags flags = const ClipFlags(),
    ClipSensitivityCategory sensitivityCategory = ClipSensitivityCategory.none,
    DateTime? ttlExpiry,
    ChunkGroupRef? chunkGroup,
  }) {
    return ClipRecord(
      id: const Uuid().v4(),
      capturedAt: DateTime.now(),
      contentType: contentType,
      payloads: payloads,
      metadata: metadata,
      flags: flags,
      sensitivityCategory: sensitivityCategory,
      ttlExpiry: ttlExpiry,
      chunkGroup: chunkGroup,
    );
  }

  ClipRecord copyWith({
    ClipContentType? contentType,
    List<ClipPayload>? payloads,
    ClipMetadata? metadata,
    ClipFlags? flags,
    ClipSensitivityCategory? sensitivityCategory,
    DateTime? ttlExpiry,
    ChunkGroupRef? chunkGroup,
  }) {
    return ClipRecord(
      id: id,
      capturedAt: capturedAt,
      contentType: contentType ?? this.contentType,
      payloads: payloads ?? this.payloads,
      metadata: metadata ?? this.metadata,
      flags: flags ?? this.flags,
      sensitivityCategory: sensitivityCategory ?? this.sensitivityCategory,
      ttlExpiry: ttlExpiry ?? this.ttlExpiry,
      chunkGroup: chunkGroup ?? this.chunkGroup,
    );
  }

  @override
  List<Object?> get props => [id, capturedAt, contentType, sensitivityCategory, ttlExpiry];
}
