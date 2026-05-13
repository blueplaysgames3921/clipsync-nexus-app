# ClipSync Nexus

Advanced clipboard management for high-volume data handling. A Flutter application that compiles natively to Android APK and Windows EXE from a single Dart codebase.

---

## Overview

ClipSync Nexus replaces the single-slot OS clipboard with a persistent, intelligent, and encrypted data layer. It captures everything — plain text, rich text, images, files, URLs, source code — stores up to 200 items with full formatting fidelity, and provides a suite of power-user tools built around that data.

The application runs entirely offline. No accounts, no cloud sync, no telemetry. All data stays on-device in an encrypted local database.

---

## Features

### Clipboard History — 200 Slots

Every copy is captured automatically in the background via a native foreground service on Android or a Win32 clipboard format listener on Windows. Items are stored in an AES-256 encrypted SQLite database with WAL mode enabled. Binary payloads like images are kept in a content-addressable blob store keyed by SHA-256 hash, so identical content is stored only once.

Each slot preserves all formats the source application placed on the clipboard simultaneously — plain text, HTML, RTF, image bytes, and file paths are all retained. The history panel uses lazy loading and virtual scrolling to remain responsive at full capacity.

### Smart Chunking Engine

When captured content exceeds configurable thresholds (default: 50,000 characters for plain text), the engine automatically segments it using a strategy matched to the detected content type.

Prose and documents split at paragraph boundaries, falling back to sentence boundaries for dense text. Source code splits at logical line boundaries with bracket-depth tracking, ensuring the engine never cuts inside a function body or multi-line string. CSV files include the header row in every chunk. JSON and XML split at tree-node boundaries so every chunk is a valid fragment. Markdown splits at top-level headings. Legal text splits at Article and Section markers.

After segmentation, a sequence-paste protocol manages delivery. After each paste with the standard shortcut, the application detects that the clipboard was read and automatically loads the next chunk. A non-intrusive HUD overlay shows progress throughout.

### Ghost Layer — Sensitive Data Auto-Deletion

A persistent background subsystem monitors every captured item for sensitive content and automatically purges matching items after a configurable TTL (default: 60 seconds).

Detection uses Shannon entropy analysis for high-entropy strings like API keys and tokens, Luhn algorithm validation for credit card numbers, and regex pattern matching for SSNs, IBANs, PEM private keys, password key-value pairs, and additional categories. OCR-extracted text from images is also scanned, so credentials visible in screenshots are caught.

Detected items display a live countdown bar in the history list. The user can extend the TTL, mark an item as not sensitive, or purge it immediately. Deletion is cryptographic — payload bytes are overwritten before the database row is removed.

### Clean Room

Applied to captured URLs and text to strip tracking artifacts before storage.

For URLs, the engine removes over 50 known tracking parameters including utm_source, utm_medium, fbclid, gclid, msclkid, ttclid, and others from a ClearURLs-compatible blocklist. Redirect URLs from shorteners and email trackers are unwrapped via HTTP HEAD to recover the destination. The original URL is always preserved alongside the cleaned version.

For images, EXIF GPS location data is stripped. For text content, zero-width Unicode characters used for document fingerprinting are removed. Clean Room operates in manual mode by default, showing a diff of what was removed when a URL is selected. An auto mode applies cleaning to every captured URL without prompting.

### Stack Mode

An operational mode that transforms the clipboard into a LIFO queue. When active, every copy pushes to a queue. Every paste with the standard shortcut (Ctrl+V) consumes the next item without requiring any UI interaction between pastes.

Designed for repetitive data migration: filling form fields sequentially, moving data between applications field by field, or pasting a prepared sequence into a spreadsheet. An optional cycle mode wraps back to the first item when the queue is exhausted. The queue is displayed as a reorderable list.

### Scratchpad

A persistent staging area for assembling multiple clipboard items into a single merged output. Items are sent from the history panel via the context menu and appear as individually editable blocks. Blocks can be reordered by dragging. The separator between blocks when merging is configurable. Up to 10 named Scratchpad sessions persist across restarts. The merged result is pushed back to clipboard history as a new item.

### Pipelines — 37 Transformations

One-click content transformations surfaced contextually based on the detected content type of the selected item.

Case and text: UPPERCASE, lowercase, Title Case, camelCase, snake_case, kebab-case, PascalCase, Slugify, ROT13, Reverse Text, Sort Lines, Deduplicate Lines, Trim Whitespace, Remove Blank Lines.

Encode and decode: Base64 encode, Base64 decode, URL percent-encode, URL decode, HTML entity encode, HTML entity decode.

Code tools: JSON Beautify, JSON Minify, Strip HTML Tags, Markdown to HTML, CSV to JSON, JSON to CSV.

Extraction: pull all email addresses, all URLs, or all numbers from any text block.

Color: HEX to RGB, RGB to HEX, all formats at once including CSS output.

Timestamps: Unix to ISO 8601, ISO 8601 to Unix, Unix to human-readable local time.

Statistics: word count, character count, line count, sentence count.

AI on-device via Ollama: Summarize and Translate. These require Ollama installed locally with llama3.2:1b. Integration stubs with commented-out code are in pipelines_service.dart.

### Semantic Search

Hybrid search combining BM25 keyword relevance with vector cosine similarity. Scores combine as BM25 weight 0.4 plus vector weight 0.6, configurable in Settings. The search bar supports boolean operators AND, OR, NOT, and field specifiers such as type:code, from:Xcode, and before:2026-04. Results update as you type with match highlighting.

### Teleport — P2P Local Network Sync

Encrypted peer-to-peer clipboard transfer over the local network with no cloud servers, no port forwarding, and no external accounts.

Devices discover each other via mDNS (service type _clipsyncteleport._tcp) and typically appear within one second. Initial pairing uses a Short Authentication String protocol: both devices display the same 6-digit code derived from an ECDH key exchange, which the user confirms verbally before trusting. After pairing, trust persists and no re-pairing is needed.

All transfers use TLS 1.3 with mutual certificate authentication using Ed25519 identity keypairs generated at first launch and stored in the platform keychain. There is no external certificate authority.

Three send modes: Push sends directly to the peer's clipboard. Offer sends a notification the peer can accept or decline. Sync establishes bidirectional synchronization filtered by content type. Ghost Layer items are blocked from Teleport by default.

### OCR — Image Text Extraction

On-device text extraction from captured images. Android uses Google ML Kit supporting Latin, CJK, Arabic, Hebrew, Devanagari, and Cyrillic scripts. Windows uses Tesseract 5 supporting over 100 languages. Extracted text is indexed for search and displayed in the detail panel. Sensitive patterns in extracted text are detected by the Ghost Layer.

---

## Project Structure

```
clipsync_nexus/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── database/database_service.dart
│   │   └── services/
│   │       ├── clipboard_monitor_service.dart
│   │       ├── ghost_layer_service.dart
│   │       ├── chunk_engine_service.dart
│   │       ├── clean_room_service.dart
│   │       ├── classifier_service.dart
│   │       ├── ocr_service.dart
│   │       ├── teleport_service.dart
│   │       └── settings_service.dart
│   ├── data/
│   │   ├── models/
│   │   │   ├── clip_record.dart
│   │   │   └── app_settings.dart
│   │   └── repositories/
│   │       ├── clip_repository.dart
│   │       └── settings_repository.dart
│   ├── features/
│   │   ├── all_blocs.dart
│   │   ├── all_views.dart
│   │   ├── clipboard/
│   │   │   ├── bloc/clipboard_bloc.dart
│   │   │   └── widgets/
│   │   │       ├── main_shell.dart
│   │   │       ├── clipboard_view.dart
│   │   │       ├── clip_card.dart
│   │   │       └── clip_detail_panel.dart
│   │   ├── stack_mode/
│   │   ├── scratchpad/
│   │   ├── chunking/
│   │   ├── ghost_layer/
│   │   ├── teleport/
│   │   ├── pipelines/pipelines_service.dart
│   │   ├── search/
│   │   └── settings/
│   └── shared/theme/app_theme.dart
├── android/
│   └── app/src/main/
│       ├── kotlin/com/clipsync/nexus/
│       │   ├── MainActivity.kt
│       │   └── ClipboardMonitorService.kt
│       ├── AndroidManifest.xml
│       └── res/xml/
│           ├── network_security_config.xml
│           └── data_extraction_rules.xml
└── windows/
    ├── clipboard_plugin.cpp
    ├── clipboard_plugin.h
    ├── CMakeLists.txt
    ├── installer.iss
    └── runner/main.cpp
```

**main.dart** bootstraps the application, initialises all services in dependency order, and mounts all BLoC providers at the root.

**database_service.dart** manages the SQLite connection with WAL mode, FTS5 virtual table, and content-addressable blob store. The secureDelete method overwrites payload bytes before removing rows.

**clipboard_monitor_service.dart** runs the full capture pipeline on every clipboard change: classify, OCR, Clean Room, Ghost Layer detection, database insert, and embedding generation. A suppressNextCapture flag prevents re-capturing programmatic writes made by the paste operation.

**ghost_layer_service.dart** runs a one-second sweep timer, fetches expired items, and cryptographically deletes them. Uses Shannon entropy via dart:math log, Luhn algorithm, and eight regex categories for detection.

**chunk_engine_service.dart** implements seven segmentation strategies and the ChunkSession state machine that tracks sequence-paste progress.

**clean_room_service.dart** implements three-pass URL cleaning, EXIF GPS stripping via the image package, and zero-width character removal.

**teleport_service.dart** handles mDNS broadcasting and discovery via the nsd package, SAS code generation via HMAC-SHA256, and runs a local Shelf HTTPS server as the receive endpoint.

**all_blocs.dart** contains all eight BLoC classes with all imports at the top of the file. Dart requires all import statements at the top of a compilation unit; this barrel pattern satisfies that requirement while keeping related code together.

**all_views.dart** contains all seven feature view widgets by the same rationale.

**app_theme.dart** defines dark and light ThemeData objects and an AppColors ThemeExtension giving all widgets typed access to design tokens via context.colors.

---

## Building

### Requirements

For all platforms: Flutter SDK 3.22.0 or later from flutter.dev. Dart SDK 3.3.0 or later is bundled with Flutter.

For Android: Android Studio Hedgehog 2023.1.1 or later, Android SDK Platform 34 or later, Java JDK 17 or later.

For Windows: Visual Studio 2022 Community or higher with the Desktop development with C++ workload. Windows SDK 10.0.22621 or later is included with that workload.

### Setup

```bash
git clone https://github.com/your-org/clipsync_nexus.git
cd clipsync_nexus
flutter pub get
flutter doctor -v
```

Download JetBrains Mono from jetbrains.com/lp/mono and place the font files at:

```
assets/fonts/JetBrainsMono-Regular.ttf
assets/fonts/JetBrainsMono-Medium.ttf
assets/fonts/JetBrainsMono-Bold.ttf
```

### Android

```bash
# Debug
flutter build apk --debug

# Release split by ABI (recommended)
flutter build apk --release --split-per-abi

# Single universal release APK
flutter build apk --release --obfuscate --split-debug-info=build/debug-info

# Play Store App Bundle
flutter build appbundle --release
```

To sign release builds, create android/key.properties:

```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/path/to/your/keystore.jks
```

Generate a keystore:

```bash
keytool -genkey -v -keystore ~/clipsync-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Windows

```bash
# Debug
flutter build windows --debug

# Release
flutter build windows --release --obfuscate --split-debug-info=build/debug-info
```

Output is in build\windows\x64\runner\Release\. Zip the entire Release folder for distribution.

Optional installer via Inno Setup 6 (jrsoftware.org):

```bash
iscc windows\installer.iss
```

### Enabling AI Pipelines (Optional)

```bash
ollama pull llama3.2:1b        # Summarize and Translate (~1.3 GB)
ollama pull nomic-embed-text   # Semantic vector search (~274 MB)
```

Then follow the inline comments in lib/features/pipelines/pipelines_service.dart inside the _summarize and _translate methods to uncomment the LangChain integration code. Do the same in lib/core/services/clipboard_monitor_service.dart inside _generateEmbeddingAsync.

---

## Permissions

### Android

FOREGROUND_SERVICE is used for background clipboard monitoring and is granted automatically. POST_NOTIFICATIONS is required for Ghost Layer alerts and chunk HUD progress; the system prompts the user on Android 13 and later. INTERNET and ACCESS_WIFI_STATE are required for Teleport. CHANGE_WIFI_MULTICAST_STATE is required for mDNS peer discovery and is granted automatically. CAMERA is optional.

### Windows

No elevated permissions required. The application runs as a standard user process.

---

## Settings Reference

| Setting | Default | Description |
|---|---|---|
| maxSlots | 200 | History ring buffer capacity (50–1000) |
| encryptDatabase | true | AES-256 encryption of the SQLite database |
| ghostLayerEnabled | true | Enable automatic sensitive data detection |
| ghostDefaultTtlSeconds | 60 | Countdown before purge, 10 to 600 seconds |
| detectApiKeys | true | Shannon entropy and prefix pattern detection |
| detectCreditCards | true | Luhn algorithm validation |
| detectSsn | true | US Social Security Number pattern |
| detectPrivateKeys | true | PEM header detection |
| detectBankAccounts | true | IBAN checksum validation |
| detectPasswords | true | Password key-value pair pattern |
| cleanRoomEnabled | true | Enable tracking parameter removal |
| cleanRoomMode | false | false = manual prompt, true = automatic |
| stripExifGps | true | Remove GPS data from images |
| stripZeroWidthChars | true | Remove Unicode fingerprinting characters |
| resolveRedirects | true | Unwrap short URLs and redirect trackers |
| autoChunkEnabled | true | Enable automatic large content segmentation |
| chunkThresholdChars | 50000 | Characters before chunking triggers |
| chunkTargetChars | 5000 | Target size of each produced segment |
| semanticSearchEnabled | true | Enable vector similarity search |
| ocrEnabled | true | Enable on-device image text extraction |
| teleportEnabled | true | Enable P2P local network sync |
| teleportSendMode | offer | push, offer, or sync |
| teleportBlockSensitive | true | Block Ghost Layer items from Teleport |
| stackCycleMode | false | Wrap stack queue after last item |
| themeMode | dark | dark, light, or system |

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Ctrl+Shift+V | Open clipboard history panel |
| Ctrl+Shift+S | Toggle Stack Mode |
| Ctrl+Shift+N | Open Scratchpad |
| Escape | Dismiss modal or HUD |

All shortcuts are remappable in Settings.

---

## Security

The SQLite database is encrypted at rest with AES-256. The encryption key is stored in Android Keystore or Windows DPAPI and never written to disk in plaintext.

Ghost Layer deletions write over payload bytes in the blob store before removing the database row. SQLite WAL free pages are zeroed on checkpoint.

Teleport uses Ed25519 keypairs generated at first launch. All transfers use TLS 1.3 with mutual authentication. There is no external certificate authority.

The application makes no connections to external servers. The only outbound network activity is Teleport P2P transfers on the local network and optional URL redirect resolution for Clean Room, both of which can be disabled in Settings.

The Android manifest sets allowBackup to false. The data_extraction_rules.xml file excludes the clipboard database and blob store from Android cloud backup and device transfer.

---

## Troubleshooting

**Clipboard not captured on Android.** The foreground service must be running. Look for the persistent ClipSync Nexus notification. On MIUI, HyperOS, or ColorOS, go to Battery Settings and explicitly enable autostart for the application.

**Teleport peers not appearing.** Both devices must be on the same subnet. Corporate and university networks commonly block mDNS traffic on UDP port 5353. Switch to a personal mobile hotspot to test, or ask your network administrator to enable multicast forwarding on the VLAN.

**Windows clipboard monitor not triggering.** Check Windows Event Viewer under Windows Logs > Application for errors from clipsync_nexus.exe. Some antivirus software blocks applications from registering clipboard format listeners. Add an exception for the application directory. Kill any orphaned clipsync_nexus.exe processes in Task Manager before relaunching.

**Database is locked on Windows.** Open Task Manager, find any clipsync_nexus.exe processes, and end them. Then relaunch the application.

**AI pipelines show placeholder text.** Ollama is not running or the model has not been pulled. Run ollama pull llama3.2:1b in a terminal and confirm Ollama is running with ollama list. Then follow the setup instructions in the Enabling AI Pipelines section above.

**Shannon entropy incorrectly flagging content as sensitive.** The threshold of 4.5 bits per character is defined in the _isHighEntropy method in ghost_layer_service.dart. Reduce it to lower sensitivity, or use the Ghost Layer panel to mark specific items as Not Sensitive.

---

## Bugs Fixed Before Release

Mid-file import statements in all_blocs.dart and all_views.dart were moved to the top of each file. Dart requires all import directives at the top of a compilation unit and treats mid-file imports as compile errors.

The _toWords helper in pipelines_service.dart used replaceAll with a regex backreference in the replacement string. Dart's replaceAll does not support backreferences. The method was rewritten using replaceAllMapped.

The _mdToHtml method used m[1] subscript notation on a RegExpMatch object. Dart's RegExpMatch does not support subscript access. All instances were replaced with m.group(1).

The Shannon entropy calculation in ghost_layer_service.dart used an incorrect hardcoded approximation of log base 2. It was replaced with dart:math log divided by dart:math ln2.

The _onPaste handler in ClipboardBloc fetched the full clip payload but never wrote it to the OS clipboard. The implementation was completed using Clipboard.setData.

The suppressNextCapture method was called by ClipboardBloc but did not exist in ClipboardMonitorService. The method and a backing boolean field were added and the flag is checked at the top of both the poll loop and the native callback handler.

The _hexToHsl method in clip_detail_panel.dart returned a placeholder string. It was implemented with proper RGB to HSL conversion.

The SingleActivator for the Escape key in main_shell.dart had a trailing comma inside the constructor call. The comma was removed.

The getCallingPackage method was called from within a Kotlin Service context in ClipboardMonitorService.kt. This method is a Binder API not available in that context and was replaced with an empty string.

The getRunningTasks method was called in MainActivity.kt to determine the foreground application. This API is restricted on Android 11 and later. It was replaced with applicationContext.packageName.

A stub class SettingsBloc at the bottom of clipboard_view.dart shadowed the real SettingsBloc from the imported file. The stub was removed.

TeleportView used a _stubClip method that constructed a ClipRecord with an empty ID to pass to the send action. This was replaced with a lookup of the currently selected clip from ClipboardBloc state.

The pubspec.yaml file listed packages that do not exist on pub.dev or were redundant: fts5_database, dart_nsd, pasteboard, flutter_background_service, context_menus, super_tooltip, cached_network_image, watcher, markdown, html, xml, and csv. All were removed.

---

## Roadmap

- v1.1 — Wire nomic-embed-text embeddings for semantic search and complete LangChain Summarize and Translate implementations
- v1.2 — macOS support via NSPasteboard and XPC background service; Scratchpad export to .docx, .md, and .pdf
- v1.3 — Application Profiles storing per-app chunk size presets keyed by bundle ID; community pipeline pack installer
- v1.4 — Teleport Sync mode with bidirectional real-time transfer and conflict resolution
- v2.0 — Browser extension for one-click Clean Room applied at the point of copy

---

## License

MIT. See LICENSE.
