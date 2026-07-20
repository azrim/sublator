// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the AppDatabase process singleton. Production opens a file inside the
/// app support directory via [NativeDatabase] (loads `sqlite3.dll` on Windows).
/// Tests override this provider with an in-memory or temp-file database.

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

/// Owns the AppDatabase process singleton. Production opens a file inside the
/// app support directory via [NativeDatabase] (loads `sqlite3.dll` on Windows).
/// Tests override this provider with an in-memory or temp-file database.

final class AppDatabaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppDatabase>,
          AppDatabase,
          FutureOr<AppDatabase>
        >
    with $FutureModifier<AppDatabase>, $FutureProvider<AppDatabase> {
  /// Owns the AppDatabase process singleton. Production opens a file inside the
  /// app support directory via [NativeDatabase] (loads `sqlite3.dll` on Windows).
  /// Tests override this provider with an in-memory or temp-file database.
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $FutureProviderElement<AppDatabase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AppDatabase> create(Ref ref) {
    return appDatabase(ref);
  }
}

String _$appDatabaseHash() => r'b81ccb9592eee0b296a735e6527134702c29eb08';
