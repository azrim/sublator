import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/app_database.dart';
import 'app_database_provider.dart';

part 'glossary_service.g.dart';

/// Default glossary entries: Japanese honorifics and common kept-as-is terms.
/// Seed these on first run so users start with sensible defaults for
/// Japanese-source subtitle projects.
const kDefaultGlossary = [
  // -- Honorific suffixes (keep as romaji) ----------------------------------
  (source: '-san',    target: '-san',    caseSensitive: false), // polite
  (source: '-kun',    target: '-kun',    caseSensitive: false), // familiar male
  (source: '-chan',   target: '-chan',   caseSensitive: false), // affectionate
  (source: '-sama',   target: '-sama',   caseSensitive: false), // highly formal
  (source: '-dono',   target: '-dono',   caseSensitive: false), // archaic formal
  // -- Standalone titles (often incorrectly translated) --------------------
  (source: 'senpai',  target: 'senpai',  caseSensitive: false), // senior/upperclassman
  (source: 'sensei',  target: 'sensei',  caseSensitive: false), // teacher / doctor
  (source: 'kouhai',  target: 'kouhai',  caseSensitive: false), // junior
  // -- Kinship terms kept in romaji in anime subs ---------------------------
  (source: 'nii-san', target: 'nii-san', caseSensitive: false), // older brother
  (source: 'nee-san', target: 'nee-san', caseSensitive: false), // older sister
  (source: 'nii-chan', target: 'nii-chan', caseSensitive: false),
  (source: 'nee-chan', target: 'nee-chan', caseSensitive: false),
  (source: 'oji-san', target: 'oji-san', caseSensitive: false), // uncle / middle-aged man
  (source: 'oba-san', target: 'oba-san', caseSensitive: false), // aunt / middle-aged woman
];

/// CRUD + JSON import/export for [GlossaryEntry]. [toMap] is async because it
/// reads from Drift; callers can cache if they need a sync lookup.
class GlossaryService {
  GlossaryService(this._db);

  final AppDatabase _db;

  Future<int> add({
    required String source,
    required String target,
    bool caseSensitive = false,
  }) {
    return _db.into(_db.glossaryEntry).insert(
          GlossaryEntryCompanion.insert(
            source: source,
            target: target,
            caseSensitive: Value(caseSensitive),
          ),
        );
  }

  Future<void> update(GlossaryEntryData entry) {
    return (_db.update(_db.glossaryEntry)
          ..where((t) => t.id.equals(entry.id)))
        .write(GlossaryEntryCompanion(
      source: Value(entry.source),
      target: Value(entry.target),
      caseSensitive: Value(entry.caseSensitive),
    ));
  }

  Future<void> remove(int id) =>
      (_db.delete(_db.glossaryEntry)..where((t) => t.id.equals(id))).go();

  Future<List<GlossaryEntryData>> getAll() =>
      _db.select(_db.glossaryEntry).get();

  Stream<List<GlossaryEntryData>> watchAll() =>
      _db.select(_db.glossaryEntry).watch();

  /// Returns source -> target. Duplicate sources collapse to last-write-wins
  /// (ponytail: simpler than returning a list; upgrade if collisions matter).
  Future<Map<String, String>> toMap() async {
    final entries = await getAll();
    return {for (final e in entries) e.source: e.target};
  }

  /// Picks a save path via FilePicker and writes the glossary as JSON.
  /// Returns the chosen path, or null if the user cancelled.
  Future<String?> exportJson() async {
    final entries = await getAll();
    final json = jsonEncode([
      for (final e in entries)
        {
          'source': e.source,
          'target': e.target,
          'caseSensitive': e.caseSensitive,
        },
    ]);
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export glossary',
      fileName: 'glossary.json',
      bytes: Uint8List.fromList(utf8.encode(json)),
    );
    return path;
  }

  /// Picks a JSON file via FilePicker and inserts all entries in a single
  /// batched transaction. Returns the count inserted, or 0 if cancelled.
  /// Throws FormatException on malformed JSON or schema mismatch.
  Future<int> importJson() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Import glossary',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (result == null || result.files.isEmpty) return 0;
    final path = result.files.single.path;
    if (path == null) return 0;
    final bytes = await File(path).readAsBytes();
    final list = jsonDecode(utf8.decode(bytes)) as List<dynamic>;
    final companions = <GlossaryEntryCompanion>[];
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      companions.add(
        GlossaryEntryCompanion.insert(
          source: m['source'] as String,
          target: m['target'] as String,
          caseSensitive: Value((m['caseSensitive'] as bool?) ?? false),
        ),
      );
    }
    await _db.batch((b) {
      for (final c in companions) {
        b.insert(_db.glossaryEntry, c);
      }
    });
    return companions.length;
  }

  /// Inserts [kDefaultGlossary] entries only when the glossary table is empty
  /// (first run). Safe to call on every startup — it is a no-op if entries
  /// already exist.
  Future<void> seedDefaults() async {
    final existing = await getAll();
    if (existing.isNotEmpty) return;
    await _insertDefaults();
  }

  /// Clears all entries and re-inserts [kDefaultGlossary]. Used by the
  /// "Reset to defaults" button in the Glossary tab.
  Future<void> resetToDefaults() async {
    await _db.delete(_db.glossaryEntry).go();
    await _insertDefaults();
  }

  Future<void> _insertDefaults() {
    return _db.batch((b) {
      for (final entry in kDefaultGlossary) {
        b.insert(
          _db.glossaryEntry,
          GlossaryEntryCompanion.insert(
            source: entry.source,
            target: entry.target,
            caseSensitive: Value(entry.caseSensitive),
          ),
        );
      }
    });
  }
}

@riverpod
Future<GlossaryService> glossaryService(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  final svc = GlossaryService(db);
  // Seed default honorifics on first run (no-op if glossary is non-empty).
  await svc.seedDefaults();
  return svc;
}
