import 'package:drift/drift.dart';

part 'app_database.g.dart';

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class GlossaryEntry extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get source => text()();
  TextColumn get target => text()();
  // ponytail: BoolColumn stores as INTEGER in SQLite; matches spec literally.
  BoolColumn get caseSensitive => boolean().withDefault(const Constant(false))();
}

class SystemPrompt extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get content => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
}

class TranslationHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fileName => text()();
  TextColumn get sourceLanguage => text()();
  TextColumn get targetLanguage => text()();
  TextColumn get status => text()(); // 'done' or 'failed'
  TextColumn get originalContent => text()();
  TextColumn get translatedContent => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(
  tables: [Settings, GlossaryEntry, SystemPrompt, TranslationHistory],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(translationHistory);
          }
        },
      );
}
