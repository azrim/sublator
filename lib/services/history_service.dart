import 'package:drift/drift.dart';

import '../models/app_database.dart';

/// CRUD for [TranslationHistory]. Stores original + translated content
/// so the history page can show side-by-side comparison.
class HistoryService {
  HistoryService(this._db);

  final AppDatabase _db;

  /// Insert a completed translation into history.
  Future<int> add({
    required String fileName,
    required String sourceLanguage,
    required String targetLanguage,
    required String status,
    required String originalContent,
    required String translatedContent,
  }) {
    return _db.into(_db.translationHistory).insert(
          TranslationHistoryCompanion.insert(
            fileName: fileName,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            status: status,
            originalContent: originalContent,
            translatedContent: translatedContent,
            createdAt: DateTime.now(),
          ),
        );
  }

  /// All history entries, newest first.
  Future<List<TranslationHistoryData>> getAll() {
    return (_db.select(_db.translationHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Watch all history entries (reactive).
  Stream<List<TranslationHistoryData>> watchAll() {
    return (_db.select(_db.translationHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Delete a single history entry by id.
  Future<int> delete(int id) {
    return (_db.delete(_db.translationHistory)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  /// Clear all history.
  Future<int> clearAll() {
    return _db.delete(_db.translationHistory).go();
  }
}
