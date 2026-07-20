import 'dart:ui' show Offset, Size;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/app_database.dart';
import 'app_database_provider.dart';

part 'settings_service.g.dart';

/// Key/value-backed settings. Each setting is a single row in [Settings].
/// Reactive consumers watch [watchKey] / [watchAll].
class SettingsService {
  SettingsService(this._db);

  final AppDatabase _db;

  // --- Setting keys --------------------------------------------------------
  static const kSourceLang = 'source_lang';
  static const kTargetLang = 'target_lang';
  static const kActivePromptId = 'active_prompt_id';
  static const kPrimaryModel = 'primary_model';
  static const kFallbackModel = 'fallback_model';
  static const kThinkingEnabled = 'thinking_enabled';

  // --- Defaults ------------------------------------------------------------
  static const defaultSourceLang = 'auto';
  static const defaultTargetLang = 'es';
  static const defaultPrimaryModel = 'deepseek-v4-flash-free';
  static const defaultFallbackModel = 'mimo-v2.5-free';

  // --- Language pair -------------------------------------------------------
  Future<String> getSourceLang() async =>
      (await _read(kSourceLang)) ?? defaultSourceLang;

  Future<String> getTargetLang() async =>
      (await _read(kTargetLang)) ?? defaultTargetLang;

  Future<void> setLanguagePair(String source, String target) async {
    await _write(kSourceLang, source);
    await _write(kTargetLang, target);
  }

  // --- Active system prompt id --------------------------------------------
  Future<int?> getActivePromptId() async {
    final v = await _read(kActivePromptId);
    return v == null ? null : int.tryParse(v);
  }

  Future<void> setActivePromptId(int id) =>
      _write(kActivePromptId, id.toString());

  // --- Model preferences ---------------------------------------------------
  Future<String> getPrimaryModel() async =>
      (await _read(kPrimaryModel)) ?? defaultPrimaryModel;

  Future<String> getFallbackModel() async =>
      (await _read(kFallbackModel)) ?? defaultFallbackModel;

  Future<void> setModels({required String primary, required String fallback}) async {
    await _write(kPrimaryModel, primary);
    await _write(kFallbackModel, fallback);
  }

  // --- Thinking mode -------------------------------------------------------
  Future<bool> getThinkingEnabled() async =>
      (await _read(kThinkingEnabled)) == 'true';

  Future<void> setThinkingEnabled(bool enabled) async =>
      _write(kThinkingEnabled, enabled.toString());

  // --- Storage paths -------------------------------------------------------
  static const kDownloadLocation = 'download_location';
  static const kExportLocation = 'export_location';
  static const kAlwaysAskLocation = 'always_ask_location';

  Future<String> getDownloadLocation() async =>
      (await _read(kDownloadLocation)) ?? '';

  Future<void> setDownloadLocation(String path) async =>
      _write(kDownloadLocation, path);

  Future<String> getExportLocation() async =>
      (await _read(kExportLocation)) ?? '';

  Future<void> setExportLocation(String path) async =>
      _write(kExportLocation, path);

  Future<bool> getAlwaysAskLocation() async =>
      (await _read(kAlwaysAskLocation)) == 'true';

  Future<void> setAlwaysAskLocation(bool value) async =>
      _write(kAlwaysAskLocation, value.toString());

  // --- Window state (persisted on close, restored on start) ----------------
  // ponytail: one key, CSV "x,y,w,h". Simpler than 4 keys + 4 accessors; upgrade
  // to a dedicated WindowState table only if multiple displays need tracking.
  static const kWindowState = 'window_state';
  static (Offset, Size) get _defaultWindow =>
      (Offset.zero, const Size(1200, 800));

  Future<(Offset, Size)> getWindowState() async {
    final raw = await _read(kWindowState);
    if (raw == null) return _defaultWindow;
    final p = raw.split(',');
    if (p.length != 4) return _defaultWindow;
    final x = double.tryParse(p[0]) ?? _defaultWindow.$1.dx;
    final y = double.tryParse(p[1]) ?? _defaultWindow.$1.dy;
    final w = double.tryParse(p[2]) ?? _defaultWindow.$2.width;
    final h = double.tryParse(p[3]) ?? _defaultWindow.$2.height;
    return (Offset(x, y), Size(w, h));
  }

  Future<void> setWindowState(Offset position, Size size) =>
      _write(kWindowState, '${position.dx},${position.dy},${size.width},${size.height}');

  // --- Defaults bootstrap --------------------------------------------------
  /// Idempotent: writes defaults only for keys that are absent. Called on app
  /// start; tests rely on this to recreate state after the DB file is deleted.
  Future<void> ensureDefaults() async {
    if (await _read(kSourceLang) == null) {
      await _write(kSourceLang, defaultSourceLang);
    }
    if (await _read(kTargetLang) == null) {
      await _write(kTargetLang, defaultTargetLang);
    }
    if (await _read(kPrimaryModel) == null) {
      await _write(kPrimaryModel, defaultPrimaryModel);
    }
    if (await _read(kFallbackModel) == null) {
      await _write(kFallbackModel, defaultFallbackModel);
    }
    // active_prompt_id is intentionally NOT defaulted here; SystemPromptService
    // owns prompt lifecycle and will set it via setActivePromptId once it
    // inserts the default prompt.
  }

  // --- Reactive queries ----------------------------------------------------
  Stream<Setting?> watchKey(String key) {
    final q = _db.select(_db.settings)..where((t) => t.key.equals(key));
    return q.watchSingleOrNull();
  }

  Stream<List<Setting>> watchAll() => _db.select(_db.settings).watch();

  // --- Internals -----------------------------------------------------------
  Future<String?> _read(String key) async {
    final q = _db.select(_db.settings)..where((t) => t.key.equals(key));
    final row = await q.getSingleOrNull();
    return row?.value;
  }

  Future<void> _write(String key, String value) async {
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(key: key, value: value),
        );
  }
}

@riverpod
Future<SettingsService> settingsService(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return SettingsService(db);
}
