// ignore_for_file: lines_longer_than_80_chars
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:subtitle_translator/models/app_database.dart';
import 'package:subtitle_translator/services/credential_service.dart';
import 'package:subtitle_translator/services/glossary_service.dart';
import 'package:subtitle_translator/services/settings_service.dart';
import 'package:subtitle_translator/services/system_prompt_service.dart';

// --- flutter_secure_storage MethodChannel mock --------------------------------
//
// The platform interface uses channel 'plugins.it_nomads.com/flutter_secure_storage'
// and passes arguments as { 'key': String, 'value': String, 'options': Map }.
// We mock the four methods the CredentialService exercises.

const _secureChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
final Map<String, String> _mockStore = <String, String>{};

Future<Object?> _secureHandler(MethodCall call) async {
  final args = (call.arguments as Map?)?.cast<String, Object?>();
  switch (call.method) {
    case 'write':
      _mockStore[args!['key'] as String] = args['value'] as String;
      return null;
    case 'read':
      return _mockStore[(args!['key'] as String)];
    case 'delete':
      _mockStore.remove(args!['key'] as String);
      return null;
    case 'containsKey':
      return _mockStore.containsKey(args!['key'] as String);
    case 'readAll':
      return _mockStore;
    case 'deleteAll':
      _mockStore.clear();
      return null;
  }
  return null;
}

// --- Helpers ------------------------------------------------------------------

AppDatabase _memoryDb() => AppDatabase(NativeDatabase.memory());

AppDatabase _fileDb(File f) => AppDatabase(NativeDatabase(f));

File _freshTempDbFile(String slug) {
  final path = p.join(
    Directory.systemTemp.path,
    'sublator_test_${slug}_${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  return f;
}

Future<void> _pumpStreams({Duration d = const Duration(milliseconds: 50)}) =>
    Future<void>.delayed(d);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _mockStore.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, _secureHandler);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, null);
  });

  // ===========================================================================
  // SettingsService
  // ===========================================================================
  group('SettingsService', () {
    test('save/load language pair', () async {
      final db = _memoryDb();
      addTearDown(db.close);
      final svc = SettingsService(db);

      expect(await svc.getSourceLang(), SettingsService.defaultSourceLang);
      expect(await svc.getTargetLang(), SettingsService.defaultTargetLang);

      await svc.setLanguagePair('fr', 'de');
      expect(await svc.getSourceLang(), 'fr');
      expect(await svc.getTargetLang(), 'de');

      // Round-trip through a fresh DB instance pointing at the same in-memory
      // store would not survive; only file-backed DBs persist. So we just
      // assert the write is reflected via the same service.
    });

    test('save/load model preferences', () async {
      final db = _memoryDb();
      addTearDown(db.close);
      final svc = SettingsService(db);

      expect(await svc.getPrimaryModel(), SettingsService.defaultPrimaryModel);
      expect(await svc.getFallbackModel(), SettingsService.defaultFallbackModel);

      await svc.setModels(primary: 'gpt-4o', fallback: 'claude-3.5');
      expect(await svc.getPrimaryModel(), 'gpt-4o');
      expect(await svc.getFallbackModel(), 'claude-3.5');
    });

    test('save/load active system prompt id', () async {
      final db = _memoryDb();
      addTearDown(db.close);
      final svc = SettingsService(db);

      expect(await svc.getActivePromptId(), isNull);

      await svc.setActivePromptId(42);
      expect(await svc.getActivePromptId(), 42);

      await svc.setActivePromptId(7);
      expect(await svc.getActivePromptId(), 7);
    });

    test('reactive stream fires on update', () async {
      final db = _memoryDb();
      addTearDown(db.close);
      final svc = SettingsService(db);

      final emissions = <Setting?>[];
      final sub = svc.watchKey(SettingsService.kSourceLang).listen(emissions.add);

      // Let the initial emission (null — row does not exist yet) land.
      await _pumpStreams();
      expect(emissions, hasLength(greaterThanOrEqualTo(1)));
      expect(emissions.last, isNull);

      // Mutate: should cause a new emission with the written value.
      await svc.setLanguagePair('en', 'es');
      await _pumpStreams();

      expect(emissions.last?.value, 'en');

      // Second mutation: confirm stream keeps firing.
      await svc.setLanguagePair('ja', 'ko');
      await _pumpStreams();
      expect(emissions.last?.value, 'ja');

      await sub.cancel();
    });

    test('ensureDefaults writes defaults only for missing keys', () async {
      final db = _memoryDb();
      addTearDown(db.close);
      final svc = SettingsService(db);

      // Pre-seed one setting; ensureDefaults must not overwrite it.
      await svc.setLanguagePair('fr', 'de');

      await svc.ensureDefaults();

      expect(await svc.getSourceLang(), 'fr'); // preserved
      expect(await svc.getTargetLang(), 'de'); // preserved
      expect(await svc.getPrimaryModel(), SettingsService.defaultPrimaryModel);
      expect(await svc.getFallbackModel(), SettingsService.defaultFallbackModel);
    });

    test(
      'file deleted between save and load → service recreates defaults',
      () async {
        final file = _freshTempDbFile('defaults');
        final path = file.path;

        // Save non-default settings.
        var db = _fileDb(file);
        var svc = SettingsService(db);
        await svc.setLanguagePair('fr', 'de');
        await svc.setModels(primary: 'gpt-4', fallback: 'claude');
        await db.close();

        expect(File(path).existsSync(), isTrue);

        // Destroy the file.
        File(path).deleteSync();

        // Reopen: empty DB → ensureDefaults populates defaults.
        db = _fileDb(File(path));
        svc = SettingsService(db);
        await svc.ensureDefaults();

        expect(await svc.getSourceLang(), SettingsService.defaultSourceLang);
        expect(await svc.getTargetLang(), SettingsService.defaultTargetLang);
        expect(await svc.getPrimaryModel(), SettingsService.defaultPrimaryModel);
        expect(await svc.getFallbackModel(), SettingsService.defaultFallbackModel);

        await db.close();
        if (File(path).existsSync()) File(path).deleteSync();
      },
    );
  });

  // ===========================================================================
  // GlossaryService
  // ===========================================================================
  group('GlossaryService', () {
    test('add / getAll / update / remove round-trip', () async {
      final db = _memoryDb();
      addTearDown(db.close);
      final svc = GlossaryService(db);

      final id1 = await svc.add(source: 'hello', target: 'hola');
      final id2 = await svc.add(
        source: 'world',
        target: 'mundo',
        caseSensitive: true,
      );
      expect(id1, isPositive);
      expect(id2, greaterThan(id1));

      final all = await svc.getAll();
      expect(all.length, 2);
      expect(all.first.source, 'hello');
      expect(all.last.caseSensitive, isTrue);

      final updated = all.first.copyWith(target: 'bonjour', caseSensitive: true);
      await svc.update(updated);
      final afterUpdate = await svc.getAll();
      expect(
        afterUpdate.firstWhere((e) => e.id == updated.id).target,
        'bonjour',
      );

      await svc.remove(id2);
      expect((await svc.getAll()).length, 1);
    });

    test('toMap collapses to source→target', () async {
      final db = _memoryDb();
      addTearDown(db.close);
      final svc = GlossaryService(db);

      await svc.add(source: 'cat', target: 'gato');
      await svc.add(source: 'dog', target: 'perro');

      final m = await svc.toMap();
      expect(m, {'cat': 'gato', 'dog': 'perro'});
    });
  });

  // ===========================================================================
  // SystemPromptService
  // ===========================================================================
  group('SystemPromptService', () {
    test('ensureDefault inserts the default prompt and activates it', () async {
      final db = _memoryDb();
      addTearDown(db.close);
      final svc = SystemPromptService(db);

      expect(await svc.getAll(), isEmpty);

      final active = await svc.ensureDefault();
      expect(active.name, SystemPromptService.defaultName);
      expect(active.content, SystemPromptService.defaultContent);
      expect(active.isActive, isTrue);

      // Idempotent: second call must not insert a duplicate.
      await svc.ensureDefault();
      expect((await svc.getAll()).length, 1);
    });

    test('default content contains the spec-required clauses', () {
      // Guards against accidental edits — core requirements that must survive refactors.
      final c = SystemPromptService.defaultContent;
      expect(c, contains('{sourceLanguage}'));
      expect(c, contains('{targetLanguage}'));
      expect(c, contains('{braces}'));
      expect(c, contains('{cpl}'));
      expect(c, contains('ONLY'));
    });

    test('substitute fills {sourceLanguage}, {targetLanguage} and {cpl}', () {
      final s = SystemPromptService.substitute(
        SystemPromptService.defaultContent,
        sourceLanguage: 'English',
        targetLanguage: 'Spanish',
        cpl: 42,
      );
      expect(s, contains('from English to Spanish'));
      expect(s, contains('Hard limit: 42 characters per line'));
      // {braces} stays literal — it's meta-text for the model.
      expect(s, contains('{braces}'));
      expect(s, isNot(contains('{targetLanguage}')));
      expect(s, isNot(contains('{sourceLanguage}')));
      expect(s, isNot(contains('{cpl}')));
    });

    test('setActive deactivates prior active prompt', () async {
      final db = _memoryDb();
      addTearDown(db.close);
      final svc = SystemPromptService(db);

      final id1 = await svc.insert(name: 'A', content: 'aaa');
      final id2 = await svc.insert(name: 'B', content: 'bbb');
      await svc.setActive(id1);
      expect((await svc.getActive())?.id, id1);
      await svc.setActive(id2);
      expect((await svc.getActive())?.id, id2);
      // Exactly one row is active.
      final activeRows =
          (await svc.getAll()).where((e) => e.isActive).toList();
      expect(activeRows.length, 1);
    });

    test('update preserves isActive', () async {
      final db = _memoryDb();
      addTearDown(db.close);
      final svc = SystemPromptService(db);

      final id = await svc.insert(name: 'A', content: 'aaa');
      await svc.setActive(id);
      final original = (await svc.getActive())!;

      await svc.update(original.copyWith(content: 'aaa-v2'));
      final after = (await svc.getActive())!;
      expect(after.content, 'aaa-v2');
      expect(after.isActive, isTrue);
    });
  });

  // ===========================================================================
  // CredentialService
  // ===========================================================================
  group('CredentialService', () {
    test('save / read / delete round-trip', () async {
      final svc = CredentialService();
      const key = CredentialService.kZenApiKey;

      expect(await svc.read(key), isNull);

      await svc.save(key, 'secret-value-123');
      expect(await svc.read(key), 'secret-value-123');

      await svc.delete(key);
      expect(await svc.read(key), isNull);
    });

    test('all six allowed keys work', () async {
      final svc = CredentialService();
      await svc.save(CredentialService.kZenApiKey, 'k1');
      await svc.save(CredentialService.kOpenSubtitlesApiKey, 'k2');
      await svc.save(CredentialService.kOpenSubtitlesUsername, 'user');
      await svc.save(CredentialService.kOpenSubtitlesPassword, 'pw');
      await svc.save(CredentialService.kSubdlApiKey, 'k3');
      await svc.save(CredentialService.kSubSourceApiKey, 'k4');

      expect(await svc.read(CredentialService.kZenApiKey), 'k1');
      expect(await svc.read(CredentialService.kOpenSubtitlesApiKey), 'k2');
      expect(await svc.read(CredentialService.kOpenSubtitlesUsername), 'user');
      expect(await svc.read(CredentialService.kOpenSubtitlesPassword), 'pw');
      expect(await svc.read(CredentialService.kSubdlApiKey), 'k3');
      expect(await svc.read(CredentialService.kSubSourceApiKey), 'k4');
    });

    test('unknown key is rejected with ArgumentError', () async {
      final svc = CredentialService();
      expect(
        () => svc.save('not_a_real_key', 'x'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => svc.read('not_a_real_key'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => svc.delete('not_a_real_key'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'plaintext credential is NOT found in Drift DB file',
      () async {
        final file = _freshTempDbFile('plaintext');
        final path = file.path;

        // Put some settings in Drift so the file is non-empty.
        final db = _fileDb(file);
        final settings = SettingsService(db);
        await settings.setLanguagePair('en', 'es');

        // Save a credential — should go ONLY to secure storage (the mock
        // in-memory map), never into Drift.
        final cred = CredentialService();
        const plaintext = 'supersecret-api-key-9f8a7b6c';
        await cred.save(CredentialService.kZenApiKey, plaintext);

        await db.close();

        // Read the DB file and assert the plaintext is nowhere in it.
        final bytes = await File(path).readAsBytes();
        final decoded = utf8.decode(bytes, allowMalformed: true);
        expect(
          decoded.contains(plaintext),
          isFalse,
          reason:
              'Credential plaintext leaked into the Drift DB file. '
              'Credentials must ONLY live in flutter_secure_storage.',
        );

        if (File(path).existsSync()) File(path).deleteSync();
      },
    );

    test(
      'platform failure surfaces as SecureStorageUnavailableException',
      () async {
        // Remove the mock so all calls fall through to MissingPluginException,
        // which the service must translate into a clear error.
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_secureChannel, null);

        final svc = CredentialService();
        expect(
          () => svc.save(CredentialService.kZenApiKey, 'x'),
          throwsA(isA<SecureStorageUnavailableException>()),
        );
      },
    );
  });
}
