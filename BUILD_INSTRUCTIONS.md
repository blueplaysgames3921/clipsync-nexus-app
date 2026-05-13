# ClipSync Nexus — Build Instructions

## Prerequisites

### All platforms
```
Flutter SDK >= 3.22.0   https://docs.flutter.dev/get-started/install
Dart SDK >= 3.3.0       (bundled with Flutter)
Git
```

### Android build
```
Android Studio (Hedgehog 2023.1.1+)  OR  command-line tools
Android SDK Platform 34+
Android NDK 27.0+
Java JDK 17+
```

### Windows build
```
Visual Studio 2022 (Community or higher)
  ✓ Desktop development with C++ workload
  ✓ MSVC v143 toolchain
  ✓ Windows 11 SDK (10.0.22621.0)
CMake 3.14+  (bundled with VS 2022)
```

---

## 1. Clone and setup

```bash
git clone https://github.com/your-org/clipsync_nexus.git
cd clipsync_nexus

# Install all Dart/Flutter dependencies
flutter pub get

# Verify environment
flutter doctor -v
```

---

## 2. Font assets

Download JetBrains Mono from https://www.jetbrains.com/lp/mono/
and place the TTF files in `assets/fonts/`:

```
assets/fonts/JetBrainsMono-Regular.ttf
assets/fonts/JetBrainsMono-Medium.ttf
assets/fonts/JetBrainsMono-Bold.ttf
```

---

## 3. Build for Android

### Debug APK (fastest, for testing)
```bash
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

### Release APK (single file, all ABIs)
```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Split APKs per ABI (smaller download sizes)
```bash
flutter build apk --release --split-per-abi
# Outputs:
#   app-arm64-v8a-release.apk   (most modern phones)
#   app-armeabi-v7a-release.apk (older 32-bit)
#   app-x86_64-release.apk      (emulators)
```

### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Signing for release
Create `android/key.properties`:
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/path/to/your/keystore.jks
```

Generate keystore:
```bash
keytool -genkey -v -keystore ~/clipsync-upload-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Then add to `android/app/build.gradle`:
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

---

## 4. Build for Windows

### Debug (development)
```bash
flutter build windows --debug
# Output: build\windows\x64\runner\Debug\clipsync_nexus.exe
```

### Release (distributable)
```bash
flutter build windows --release --obfuscate --split-debug-info=build/debug-info
# Output: build\windows\x64\runner\Release\clipsync_nexus.exe
```

The Release folder contains all required DLLs and assets — zip the
entire directory for distribution.

### Create an MSIX installer (Windows Store / sideload)
```bash
# Install msix package
flutter pub add --dev msix

# Add to pubspec.yaml under flutter:
#   msix_config:
#     display_name: ClipSync Nexus
#     publisher_display_name: Your Name
#     identity_name: com.clipsync.nexus
#     msix_version: 1.0.0.0
#     logo_path: assets/icons/icon.png
#     capabilities: runFullTrust,internetClient,privateNetworkClientServer

flutter pub run msix:create
```

### Create an Inno Setup installer (traditional .exe installer)
Install Inno Setup 6 from https://jrsoftware.org/isinfo.php  
Then use the provided `windows/installer.iss` script:
```bash
iscc windows\installer.iss
# Output: build\windows\ClipSyncNexus_Setup_1.0.0.exe
```

---

## 5. Required permissions — Android

The app requests at runtime:
- `POST_NOTIFICATIONS` — Ghost Layer alerts, chunk HUD  
- `CAMERA` — optional, for OCR on camera images  
- `FOREGROUND_SERVICE` — granted automatically  

Clipboard and network permissions are granted automatically (declared in manifest).

---

## 6. First-run configuration

On first launch the app will:
1. Generate a device identity keypair (stored in Android Keystore / Windows DPAPI)
2. Create the encrypted SQLite database in app support directory
3. Start the foreground clipboard monitor service (Android) or background watcher thread (Windows)
4. Begin mDNS broadcasting for Teleport

No internet connection is required. All data stays on-device.

---

## 7. Development workflow

```bash
# Run on connected Android device
flutter run -d android

# Run on Windows desktop
flutter run -d windows

# Run all tests
flutter test

# Analyze for lint issues
flutter analyze

# Watch and rebuild
flutter run --hot
```

---

## 8. Project structure reference

```
clipsync_nexus/
├── lib/
│   ├── main.dart                         # Entry point, DI, BLoC providers
│   ├── core/
│   │   ├── database/
│   │   │   └── database_service.dart     # SQLite + WAL + blob store
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
│   │   │   ├── clip_record.dart          # Canonical ClipRecord schema
│   │   │   └── app_settings.dart
│   │   └── repositories/
│   │       ├── clip_repository.dart      # All DB operations
│   │       └── settings_repository.dart
│   ├── features/
│   │   ├── clipboard/                    # History + detail panel
│   │   ├── stack_mode/                   # LIFO queue mode
│   │   ├── scratchpad/                   # Snippet assembly
│   │   ├── chunking/                     # Sequence-paste engine
│   │   ├── ghost_layer/                  # Sensitive data TTL
│   │   ├── teleport/                     # P2P sync
│   │   ├── pipelines/                    # Content transformations
│   │   ├── search/                       # FTS5 + semantic search
│   │   └── settings/                     # App configuration
│   └── shared/
│       └── theme/
│           └── app_theme.dart            # Dark/light themes + AppColors
├── android/
│   └── app/src/main/kotlin/com/clipsync/nexus/
│       ├── MainActivity.kt               # Flutter entry + channel setup
│       └── ClipboardMonitorService.kt    # Android background monitor
└── windows/
    ├── clipboard_plugin.cpp              # Win32 clipboard + window detection
    ├── clipboard_plugin.h
    ├── CMakeLists.txt
    └── runner/
        └── main.cpp                      # Windows entry point
```

---

## 9. Key dependencies requiring native setup

| Dependency | Setup needed |
|---|---|
| `google_mlkit_text_recognition` | Android only — auto-downloaded model (~5 MB) |
| `flutter_tesseract_ocr` | Windows — install Tesseract 5 via `winget install UB-Mannheim.TesseractOCR` |
| `nsd` (mDNS) | Android requires `CHANGE_WIFI_MULTICAST_STATE` permission |
| `sqflite_common_ffi` | Windows — SQLite DLL bundled automatically |
| `flutter_secure_storage` | Android Keystore / Windows DPAPI — no setup needed |
| `langchain_ollama` | Optional — install Ollama and pull `llama3.2:1b` for AI pipelines |

### Optional: Ollama for AI Pipelines (Summarize / Translate)
```bash
# Install Ollama: https://ollama.com
ollama pull llama3.2:1b      # ~1.3 GB — fast, on-device
ollama pull nomic-embed-text # ~274 MB — for semantic search embeddings
```

---

## 10. Troubleshooting

**Android: "INSTALL_FAILED_USER_RESTRICTED" on clipboard**  
→ Android 10+ restricts background clipboard reads. The foreground service bypasses this. Ensure the service is started before any clipboard read.

**Windows: Clipboard monitor not firing**  
→ `AddClipboardFormatListener` requires the watcher window to have a valid `HWND`. Ensure `StartWatcher()` is called after Flutter engine initialises.

**SQLite "database is locked" on Windows**  
→ WAL mode is set in `_onOpen`. Ensure only one process opens the DB. Kill any zombie `clipsync_nexus.exe` processes.

**mDNS peers not discovered**  
→ Ensure devices are on the same subnet. Some corporate Wi-Fi blocks mDNS (port 5353 UDP). Use a personal hotspot or check router multicast settings.

**Build error: "flutter_secure_storage not found"**  
→ Run `flutter pub get` then `flutter clean && flutter build`.
