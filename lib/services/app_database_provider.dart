import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/app_database.dart';

part 'app_database_provider.g.dart';

/// Owns the AppDatabase process singleton. Production opens a file inside the
/// app support directory via [NativeDatabase] (loads `sqlite3.dll` on Windows).
/// Tests override this provider with an in-memory or temp-file database.
@Riverpod(keepAlive: true)
Future<AppDatabase> appDatabase(Ref ref) async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'sublator.db'));
  final db = AppDatabase(NativeDatabase.createInBackground(file));
  ref.onDispose(db.close);
  return db;
}
