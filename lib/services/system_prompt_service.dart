import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/app_database.dart';
import 'app_database_provider.dart';

part 'system_prompt_service.g.dart';

/// CRUD + active-prompt selection for [SystemPrompt]. Inserts a default
/// prompt on first run via [ensureDefault].
class SystemPromptService {
  SystemPromptService(this._db);

  final AppDatabase _db;

  /// Default name shown in any prompt-list UI.
  static const defaultName = 'Default';

  /// Default prompt template. Placeholders `{sourceLanguage}`, `{targetLanguage}`,
  /// `{cpl}`, and `{braces}` are substituted at use time via [substitute].
  /// The `{braces}` token is literal — it tells the model what notation to
  /// preserve, not a substitute target.
  static const defaultContent =
      'You are a professional subtitle translator from {sourceLanguage} to {targetLanguage}.\n'
      'Output ONLY the numbered translations — no commentary, no notes, no preamble, no summary.\n'
      '\n'
      'INPUT FORMAT: Each subtitle is prefixed with its index, e.g. [1] text\n'
      'OUTPUT FORMAT: Return every index on its own line in the same order:\n'
      '[1] translated text\n'
      '[2] translated text\n'
      '\n'
      'COMPLETENESS — MOST IMPORTANT RULE:\n'
      'You MUST translate EVERY entry given to you, from the first to the last.\n'
      'Count the entries before you begin. Do not stop until all are output.\n'
      'If you are running out of space, shorten each translation — never skip an entry.\n'
      'A missing [N] line is a critical failure.\n'
      '\n'
      'PRESERVATION & SPECIAL FORMATS:\n'
      '- Keep text inside {braces} exactly as-is (ASS/SSA positional tags, e.g. {\\an8})\n'
      '- Keep text inside [brackets] exactly as-is (SDH sound effects, e.g. [applause])\n'
      '- Keep text inside (parentheses) exactly as-is (stage directions, e.g. (whispers))\n'
      '- Keep ALL CAPS words as-is for emphasis\n'
      '- Keep proper nouns, names, and brand names as-is\n'
      '- Keep "SPEAKER: text" format — only translate the text part\n'
      '\n'
      'REGISTER & CONSISTENCY:\n'
      '- Pick ONE register and keep it throughout the entire batch\n'
      '- Match the register of the source: casual → casual, formal → formal\n'
      '- Do NOT switch register between adjacent subtitles of the same speaker\n'
      '- Prefer the most natural, colloquial form of {targetLanguage} for dialogue\n'
      '\n'
      'STYLE:\n'
      '- Spoken dialogue: write for the ear, not the eye\n'
      '- Sound natural if read aloud — short, punchy sentences\n'
      '- Convey the same meaning and emotion as the source; avoid word-for-word literal translation\n'
      '- Single-word or interjection inputs → single-word or interjection outputs\n'
      '- No translator notes or context in the output\n'
      '\n'
      'LINE LENGTH & FORMATTING:\n'
      '- Hard limit: {cpl} characters per line\n'
      '- For two-line subtitles, use the literal token \\n to separate lines\n'
      '  e.g. [1] First line\\nSecond line (NOT a real newline character)\n'
      '- Break at natural phrase boundaries, never mid-word\n'
      '- If a translation is too long, rephrase shorter — do not wrap to a third line\n'
      '\n'
      'GLOSSARY:\n'
      'Apply these specific term translations whenever they appear in the source text:\n'
      '{glossary}';

  /// Substitutes the runtime placeholders in a stored template.
  ///
  /// [glossary] entries are formatted as `source → target` lines and injected
  /// into the `{glossary}` placeholder. If [glossary] is empty, the section
  /// falls back to a note that all terms should be translated naturally.
  static String substitute(
    String template, {
    required String sourceLanguage,
    required String targetLanguage,
    required int cpl,
    List<({String source, String target})> glossary = const [],
  }) {
    // When source is 'auto', tell the model to detect the language itself
    // rather than hard-coding a language name that might be wrong.
    final resolvedSource = sourceLanguage == 'auto'
        ? 'the source language (auto-detect)'
        : sourceLanguage;

    final glossaryBlock = glossary.isEmpty
        ? '(none — translate all terms naturally)'
        : glossary.map((g) => '${g.source} → ${g.target}').join('\n');

    return template
        .replaceAll('{sourceLanguage}', resolvedSource)
        .replaceAll('{targetLanguage}', targetLanguage)
        .replaceAll('{cpl}', cpl.toString())
        .replaceAll('{glossary}', glossaryBlock);
  }

  Future<SystemPromptData?> getActive() {
    final q = _db.select(_db.systemPrompt)
      ..where((t) => t.isActive.equals(true));
    return q.getSingleOrNull();
  }

  Future<List<SystemPromptData>> getAll() =>
      _db.select(_db.systemPrompt).get();

  Future<int> insert({required String name, required String content}) {
    return _db.into(_db.systemPrompt).insert(
          SystemPromptCompanion.insert(name: name, content: content),
        );
  }

  Future<void> update(SystemPromptData prompt) {
    return (_db.update(_db.systemPrompt)
          ..where((t) => t.id.equals(prompt.id)))
        .write(SystemPromptCompanion(
      name: Value(prompt.name),
      content: Value(prompt.content),
    ));
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.systemPrompt)..where((t) => t.id.equals(id))).go();

  /// Sets the given prompt as the sole active one. Idempotent: deactivates
  /// all rows, then activates [id]. Runs in a transaction so the table is
  /// never observed with zero active prompts mid-update.
  Future<void> setActive(int id) async {
    await _db.transaction(() async {
      await (_db.update(_db.systemPrompt)
            ..where((t) => t.isActive.equals(true)))
          .write(const SystemPromptCompanion(isActive: Value(false)));
      await (_db.update(_db.systemPrompt)..where((t) => t.id.equals(id)))
          .write(const SystemPromptCompanion(isActive: Value(true)));
    });
  }

  /// Idempotent: returns the active prompt, or inserts+activates the default
  /// if the table is empty. If rows exist but none is active, activates the
  /// first row rather than inserting a duplicate.
  Future<SystemPromptData> ensureDefault() async {
    final active = await getActive();
    if (active != null) return active;
    final all = await getAll();
    if (all.isNotEmpty) {
      // ponytail: data exists but none flagged active; reuse the first.
      await setActive(all.first.id);
      return all.first;
    }
    final id = await insert(name: defaultName, content: defaultContent);
    await setActive(id);
    return (await getActive())!;
  }

  Stream<List<SystemPromptData>> watchAll() =>
      _db.select(_db.systemPrompt).watch();

  Stream<SystemPromptData?> watchActive() {
    final q = _db.select(_db.systemPrompt)
      ..where((t) => t.isActive.equals(true));
    return q.watchSingleOrNull();
  }
}

@riverpod
Future<SystemPromptService> systemPromptService(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return SystemPromptService(db);
}
