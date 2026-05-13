import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class AppSettings extends Equatable {
  // Storage
  final int maxSlots;
  final int maxTextSizeMb;
  final int maxImageSizeMb;
  final int maxFileCacheSizeMb;
  final bool encryptDatabase;

  // Ghost Layer
  final bool ghostLayerEnabled;
  final int ghostDefaultTtlSeconds;
  final bool detectPasswords;
  final bool detectCreditCards;
  final bool detectSsn;
  final bool detectApiKeys;
  final bool detectPrivateKeys;
  final bool detectBankAccounts;
  final bool detectMedicalIds;
  final List<String> customSensitivePatterns;

  // Clean Room
  final bool cleanRoomEnabled;
  final bool cleanRoomMode; // true=auto, false=manual prompt
  final bool stripExifGps;
  final bool stripAllExif;
  final bool stripDocumentMetadata;
  final bool stripZeroWidthChars;
  final bool resolveRedirects;

  // Chunking
  final bool autoChunkEnabled;
  final int chunkThresholdChars;
  final int chunkTargetChars;
  final String defaultChunkStrategy; // paragraph | sentence | line | csv | json
  final int chunkPasteTimeoutSeconds;

  // Search
  final bool semanticSearchEnabled;
  final bool ocrEnabled;
  final double bm25Weight;
  final double vectorWeight;

  // Teleport
  final bool teleportEnabled;
  final String teleportSendMode; // push | offer | sync
  final bool teleportBlockSensitive;
  final String deviceDisplayName;

  // Stack Mode
  final bool stackCycleMode;

  // UI
  final ThemeMode themeMode;
  final bool compactDensity;
  final bool reduceMotion;
  final bool highContrast;

  // Shortcuts (stored as string codes)
  final String shortcutOpenPanel;
  final String shortcutStackToggle;
  final String shortcutScratchpad;

  const AppSettings({
    this.maxSlots = 200,
    this.maxTextSizeMb = 50,
    this.maxImageSizeMb = 50,
    this.maxFileCacheSizeMb = 100,
    this.encryptDatabase = true,

    this.ghostLayerEnabled = true,
    this.ghostDefaultTtlSeconds = 60,
    this.detectPasswords = true,
    this.detectCreditCards = true,
    this.detectSsn = true,
    this.detectApiKeys = true,
    this.detectPrivateKeys = true,
    this.detectBankAccounts = true,
    this.detectMedicalIds = true,
    this.customSensitivePatterns = const [],

    this.cleanRoomEnabled = true,
    this.cleanRoomMode = false, // manual by default
    this.stripExifGps = true,
    this.stripAllExif = false,
    this.stripDocumentMetadata = true,
    this.stripZeroWidthChars = true,
    this.resolveRedirects = true,

    this.autoChunkEnabled = true,
    this.chunkThresholdChars = 50000,
    this.chunkTargetChars = 5000,
    this.defaultChunkStrategy = 'paragraph',
    this.chunkPasteTimeoutSeconds = 30,

    this.semanticSearchEnabled = true,
    this.ocrEnabled = true,
    this.bm25Weight = 0.4,
    this.vectorWeight = 0.6,

    this.teleportEnabled = true,
    this.teleportSendMode = 'offer',
    this.teleportBlockSensitive = true,
    this.deviceDisplayName = 'My Device',

    this.stackCycleMode = false,

    this.themeMode = ThemeMode.dark,
    this.compactDensity = false,
    this.reduceMotion = false,
    this.highContrast = false,

    this.shortcutOpenPanel = 'ctrl+shift+v',
    this.shortcutStackToggle = 'ctrl+shift+s',
    this.shortcutScratchpad = 'ctrl+shift+n',
  });

  AppSettings copyWith({
    int? maxSlots,
    int? maxTextSizeMb,
    int? maxImageSizeMb,
    int? maxFileCacheSizeMb,
    bool? encryptDatabase,
    bool? ghostLayerEnabled,
    int? ghostDefaultTtlSeconds,
    bool? detectPasswords,
    bool? detectCreditCards,
    bool? detectSsn,
    bool? detectApiKeys,
    bool? detectPrivateKeys,
    bool? detectBankAccounts,
    bool? detectMedicalIds,
    List<String>? customSensitivePatterns,
    bool? cleanRoomEnabled,
    bool? cleanRoomMode,
    bool? stripExifGps,
    bool? stripAllExif,
    bool? stripDocumentMetadata,
    bool? stripZeroWidthChars,
    bool? resolveRedirects,
    bool? autoChunkEnabled,
    int? chunkThresholdChars,
    int? chunkTargetChars,
    String? defaultChunkStrategy,
    int? chunkPasteTimeoutSeconds,
    bool? semanticSearchEnabled,
    bool? ocrEnabled,
    double? bm25Weight,
    double? vectorWeight,
    bool? teleportEnabled,
    String? teleportSendMode,
    bool? teleportBlockSensitive,
    String? deviceDisplayName,
    bool? stackCycleMode,
    ThemeMode? themeMode,
    bool? compactDensity,
    bool? reduceMotion,
    bool? highContrast,
    String? shortcutOpenPanel,
    String? shortcutStackToggle,
    String? shortcutScratchpad,
  }) {
    return AppSettings(
      maxSlots: maxSlots ?? this.maxSlots,
      maxTextSizeMb: maxTextSizeMb ?? this.maxTextSizeMb,
      maxImageSizeMb: maxImageSizeMb ?? this.maxImageSizeMb,
      maxFileCacheSizeMb: maxFileCacheSizeMb ?? this.maxFileCacheSizeMb,
      encryptDatabase: encryptDatabase ?? this.encryptDatabase,
      ghostLayerEnabled: ghostLayerEnabled ?? this.ghostLayerEnabled,
      ghostDefaultTtlSeconds: ghostDefaultTtlSeconds ?? this.ghostDefaultTtlSeconds,
      detectPasswords: detectPasswords ?? this.detectPasswords,
      detectCreditCards: detectCreditCards ?? this.detectCreditCards,
      detectSsn: detectSsn ?? this.detectSsn,
      detectApiKeys: detectApiKeys ?? this.detectApiKeys,
      detectPrivateKeys: detectPrivateKeys ?? this.detectPrivateKeys,
      detectBankAccounts: detectBankAccounts ?? this.detectBankAccounts,
      detectMedicalIds: detectMedicalIds ?? this.detectMedicalIds,
      customSensitivePatterns: customSensitivePatterns ?? this.customSensitivePatterns,
      cleanRoomEnabled: cleanRoomEnabled ?? this.cleanRoomEnabled,
      cleanRoomMode: cleanRoomMode ?? this.cleanRoomMode,
      stripExifGps: stripExifGps ?? this.stripExifGps,
      stripAllExif: stripAllExif ?? this.stripAllExif,
      stripDocumentMetadata: stripDocumentMetadata ?? this.stripDocumentMetadata,
      stripZeroWidthChars: stripZeroWidthChars ?? this.stripZeroWidthChars,
      resolveRedirects: resolveRedirects ?? this.resolveRedirects,
      autoChunkEnabled: autoChunkEnabled ?? this.autoChunkEnabled,
      chunkThresholdChars: chunkThresholdChars ?? this.chunkThresholdChars,
      chunkTargetChars: chunkTargetChars ?? this.chunkTargetChars,
      defaultChunkStrategy: defaultChunkStrategy ?? this.defaultChunkStrategy,
      chunkPasteTimeoutSeconds: chunkPasteTimeoutSeconds ?? this.chunkPasteTimeoutSeconds,
      semanticSearchEnabled: semanticSearchEnabled ?? this.semanticSearchEnabled,
      ocrEnabled: ocrEnabled ?? this.ocrEnabled,
      bm25Weight: bm25Weight ?? this.bm25Weight,
      vectorWeight: vectorWeight ?? this.vectorWeight,
      teleportEnabled: teleportEnabled ?? this.teleportEnabled,
      teleportSendMode: teleportSendMode ?? this.teleportSendMode,
      teleportBlockSensitive: teleportBlockSensitive ?? this.teleportBlockSensitive,
      deviceDisplayName: deviceDisplayName ?? this.deviceDisplayName,
      stackCycleMode: stackCycleMode ?? this.stackCycleMode,
      themeMode: themeMode ?? this.themeMode,
      compactDensity: compactDensity ?? this.compactDensity,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      highContrast: highContrast ?? this.highContrast,
      shortcutOpenPanel: shortcutOpenPanel ?? this.shortcutOpenPanel,
      shortcutStackToggle: shortcutStackToggle ?? this.shortcutStackToggle,
      shortcutScratchpad: shortcutScratchpad ?? this.shortcutScratchpad,
    );
  }

  Map<String, dynamic> toJson() => {
    'maxSlots': maxSlots,
    'maxTextSizeMb': maxTextSizeMb,
    'maxImageSizeMb': maxImageSizeMb,
    'maxFileCacheSizeMb': maxFileCacheSizeMb,
    'encryptDatabase': encryptDatabase,
    'ghostLayerEnabled': ghostLayerEnabled,
    'ghostDefaultTtlSeconds': ghostDefaultTtlSeconds,
    'detectPasswords': detectPasswords,
    'detectCreditCards': detectCreditCards,
    'detectSsn': detectSsn,
    'detectApiKeys': detectApiKeys,
    'detectPrivateKeys': detectPrivateKeys,
    'detectBankAccounts': detectBankAccounts,
    'detectMedicalIds': detectMedicalIds,
    'customSensitivePatterns': customSensitivePatterns,
    'cleanRoomEnabled': cleanRoomEnabled,
    'cleanRoomMode': cleanRoomMode,
    'stripExifGps': stripExifGps,
    'stripAllExif': stripAllExif,
    'stripDocumentMetadata': stripDocumentMetadata,
    'stripZeroWidthChars': stripZeroWidthChars,
    'resolveRedirects': resolveRedirects,
    'autoChunkEnabled': autoChunkEnabled,
    'chunkThresholdChars': chunkThresholdChars,
    'chunkTargetChars': chunkTargetChars,
    'defaultChunkStrategy': defaultChunkStrategy,
    'chunkPasteTimeoutSeconds': chunkPasteTimeoutSeconds,
    'semanticSearchEnabled': semanticSearchEnabled,
    'ocrEnabled': ocrEnabled,
    'bm25Weight': bm25Weight,
    'vectorWeight': vectorWeight,
    'teleportEnabled': teleportEnabled,
    'teleportSendMode': teleportSendMode,
    'teleportBlockSensitive': teleportBlockSensitive,
    'deviceDisplayName': deviceDisplayName,
    'stackCycleMode': stackCycleMode,
    'themeMode': themeMode.index,
    'compactDensity': compactDensity,
    'reduceMotion': reduceMotion,
    'highContrast': highContrast,
    'shortcutOpenPanel': shortcutOpenPanel,
    'shortcutStackToggle': shortcutStackToggle,
    'shortcutScratchpad': shortcutScratchpad,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    maxSlots: j['maxSlots'] as int? ?? 200,
    maxTextSizeMb: j['maxTextSizeMb'] as int? ?? 50,
    maxImageSizeMb: j['maxImageSizeMb'] as int? ?? 50,
    maxFileCacheSizeMb: j['maxFileCacheSizeMb'] as int? ?? 100,
    encryptDatabase: j['encryptDatabase'] as bool? ?? true,
    ghostLayerEnabled: j['ghostLayerEnabled'] as bool? ?? true,
    ghostDefaultTtlSeconds: j['ghostDefaultTtlSeconds'] as int? ?? 60,
    detectPasswords: j['detectPasswords'] as bool? ?? true,
    detectCreditCards: j['detectCreditCards'] as bool? ?? true,
    detectSsn: j['detectSsn'] as bool? ?? true,
    detectApiKeys: j['detectApiKeys'] as bool? ?? true,
    detectPrivateKeys: j['detectPrivateKeys'] as bool? ?? true,
    detectBankAccounts: j['detectBankAccounts'] as bool? ?? true,
    detectMedicalIds: j['detectMedicalIds'] as bool? ?? true,
    customSensitivePatterns: List<String>.from(j['customSensitivePatterns'] ?? []),
    cleanRoomEnabled: j['cleanRoomEnabled'] as bool? ?? true,
    cleanRoomMode: j['cleanRoomMode'] as bool? ?? false,
    stripExifGps: j['stripExifGps'] as bool? ?? true,
    stripAllExif: j['stripAllExif'] as bool? ?? false,
    stripDocumentMetadata: j['stripDocumentMetadata'] as bool? ?? true,
    stripZeroWidthChars: j['stripZeroWidthChars'] as bool? ?? true,
    resolveRedirects: j['resolveRedirects'] as bool? ?? true,
    autoChunkEnabled: j['autoChunkEnabled'] as bool? ?? true,
    chunkThresholdChars: j['chunkThresholdChars'] as int? ?? 50000,
    chunkTargetChars: j['chunkTargetChars'] as int? ?? 5000,
    defaultChunkStrategy: j['defaultChunkStrategy'] as String? ?? 'paragraph',
    chunkPasteTimeoutSeconds: j['chunkPasteTimeoutSeconds'] as int? ?? 30,
    semanticSearchEnabled: j['semanticSearchEnabled'] as bool? ?? true,
    ocrEnabled: j['ocrEnabled'] as bool? ?? true,
    bm25Weight: (j['bm25Weight'] as num?)?.toDouble() ?? 0.4,
    vectorWeight: (j['vectorWeight'] as num?)?.toDouble() ?? 0.6,
    teleportEnabled: j['teleportEnabled'] as bool? ?? true,
    teleportSendMode: j['teleportSendMode'] as String? ?? 'offer',
    teleportBlockSensitive: j['teleportBlockSensitive'] as bool? ?? true,
    deviceDisplayName: j['deviceDisplayName'] as String? ?? 'My Device',
    stackCycleMode: j['stackCycleMode'] as bool? ?? false,
    themeMode: ThemeMode.values[j['themeMode'] as int? ?? 2],
    compactDensity: j['compactDensity'] as bool? ?? false,
    reduceMotion: j['reduceMotion'] as bool? ?? false,
    highContrast: j['highContrast'] as bool? ?? false,
    shortcutOpenPanel: j['shortcutOpenPanel'] as String? ?? 'ctrl+shift+v',
    shortcutStackToggle: j['shortcutStackToggle'] as String? ?? 'ctrl+shift+s',
    shortcutScratchpad: j['shortcutScratchpad'] as String? ?? 'ctrl+shift+n',
  );

  @override
  List<Object?> get props => [maxSlots, ghostLayerEnabled, cleanRoomEnabled, themeMode];
}
