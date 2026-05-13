import 'dart:convert';

import '../../data/models/app_settings.dart';
import '../database/database_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SettingsRepository
// ═══════════════════════════════════════════════════════════════════════════
class SettingsRepository {
  final DatabaseService db;
  AppSettings _current = const AppSettings();

  SettingsRepository({required this.db});

  AppSettings get current => _current;

  Future<void> load() async {
    final json = await db.getSetting('app_settings');
    if (json != null) {
      try {
        _current = AppSettings.fromJson(jsonDecode(json));
      } catch (_) {
        _current = const AppSettings();
      }
    }
  }

  Future<void> save(AppSettings settings) async {
    _current = settings;
    await db.setSetting('app_settings', jsonEncode(settings.toJson()));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SettingsService
// ═══════════════════════════════════════════════════════════════════════════
class SettingsService {
  final SettingsRepository _repo;

  SettingsService(this._repo);

  AppSettings get current => _repo.current;

  Future<void> update(AppSettings settings) async {
    await _repo.save(settings);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PlatformChannelService  (stub — real impl is in native code)
// ═══════════════════════════════════════════════════════════════════════════
class PlatformChannelService {
  /// Returns the display name of the currently focused application.
  Future<String> getActiveWindowApp() async => 'Unknown';

  /// Windows: write text directly to clipboard bypassing monitor re-trigger.
  Future<void> writeToClipboardSilent(String text) async {}

  /// Read all available clipboard formats.
  Future<List<String>> getAvailableFormats() async => [];
}
