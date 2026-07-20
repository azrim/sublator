// Tests for the app shell: ForUI theme mounting, sidebar navigation, and
// window_manager configuration.
//
// Platform-channel mocking:
//   - window_manager: all calls return safe defaults so AppShell's listener
//     registration, setPreventClose, and the Drift-backed restore path can
//     run without crashing. getPosition/getSize return a fixed rect.
//   - flutter_secure_storage: in-memory map mirroring storage_test.dart.
//
// Drift: appDatabaseProvider is overridden with an in-memory NativeDatabase
// so the settings/prompt/glossary services resolve synchronously.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:subtitle_translator/main.dart';
import 'package:subtitle_translator/models/app_database.dart';
import 'package:subtitle_translator/services/app_database_provider.dart';

// --- window_manager MethodChannel mock --------------------------------------

const _wmChannel = MethodChannel('window_manager');

// Captured args of the last setBounds call (used to assert window size).
Map<String, dynamic>? lastSetBoundsArgs;

Future<Object?> _wmHandler(MethodCall call) async {
  switch (call.method) {
    case 'ensureInitialized':
    case 'waitUntilReadyToShow':
    case 'setPreventClose':
    case 'show':
    case 'focus':
    case 'destroy':
    case 'setBounds':
    case 'setMinimumSize':
    case 'setMaximumSize':
    case 'setAlignment':
    case 'setTitleBarStyle':
    case 'setBackgroundColor':
    case 'setSkipTaskbar':
    case 'setAlwaysOnTop':
    case 'setFullScreen':
    case 'setTitle':
      if (call.method == 'setBounds') {
        lastSetBoundsArgs = (call.arguments as Map?)?.cast<String, dynamic>();
      }
      return null;
    case 'getBounds':
      // Default 1200x800 at (0,0); matches defaultWindowOptions.size.
      return {'x': 0.0, 'y': 0.0, 'width': 1200.0, 'height': 800.0};
    case 'isFullScreen':
      return false;
    case 'isMaximized':
      return false;
    case 'isMinimized':
      return false;
  }
  return null;
}

// --- flutter_secure_storage MethodChannel mock ------------------------------

const _secureChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
final Map<String, String> _mockSecureStore = <String, String>{};

Future<Object?> _secureHandler(MethodCall call) async {
  final args = (call.arguments as Map?)?.cast<String, Object?>();
  switch (call.method) {
    case 'write':
      _mockSecureStore[args!['key'] as String] = args['value'] as String;
      return null;
    case 'read':
      return _mockSecureStore[(args!['key'] as String)];
    case 'delete':
      _mockSecureStore.remove(args!['key'] as String);
      return null;
    case 'containsKey':
      return _mockSecureStore.containsKey(args!['key'] as String);
    case 'readAll':
      return _mockSecureStore;
    case 'deleteAll':
      _mockSecureStore.clear();
      return null;
  }
  return null;
}

// --- Helpers -----------------------------------------------------------------

AppDatabase _memoryDb() => AppDatabase(NativeDatabase.memory());

// Wrap with a per-test in-memory DB. Closing it via [addTearDown] inside the
// test body (not in [tearDown]) is required: Drift's StreamQueryStore uses
// Timer.run to delay stream cleanup, and the test framework asserts no
// timers are pending *before* top-level tearDown runs.
Widget _wrapWithDb(Widget child, AppDatabase db) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWith((ref) async => db),
    ],
    child: MaterialApp(
      builder: (context, child) => FTheme(
        data: FTheme.neutral.light.desktop,
        child: FToaster(child: child!),
      ),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _mockSecureStore.clear();
    lastSetBoundsArgs = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_wmChannel, _wmHandler);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, _secureHandler);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_wmChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, null);
  });

  group('defaultWindowOptions', () {
    test('specifies 1200x800 default size', () {
      expect(defaultWindowOptions.size, const Size(1200, 800));
    });

    test('specifies 800x600 minimum size', () {
      expect(defaultWindowOptions.minimumSize, const Size(800, 600));
    });

    test('centers the window on first run', () {
      expect(defaultWindowOptions.center, isTrue);
    });

    test('hides the native title bar (custom-drawn)', () {
      expect(defaultWindowOptions.titleBarStyle, TitleBarStyle.hidden);
    });
  });

  group('AppShell', () {
    testWidgets('renders with ForUI theme without errors', (tester) async {
      final db = _memoryDb();
      await tester.pumpWidget(_wrapWithDb(const AppShell(), db));
      // Allow services + first frame + IndexedStack to settle.
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(FScaffold), findsWidgets);
      expect(find.byType(FSidebar), findsOneWidget);
      expect(find.byType(FTheme), findsWidgets);

      // Drift's StreamQueryStore leaves Timer.run callbacks pending after
      // stream subscriptions end; pump + close lets them drain before the
      // framework's no-pending-timers assertion fires.
      await db.close();
      await tester.pumpAndSettle();
    });

    testWidgets('sidebar contains Home and Settings items', (tester) async {
      final db = _memoryDb();
      await tester.pumpWidget(_wrapWithDb(const AppShell(), db));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      await db.close();
      await tester.pumpAndSettle();
    });

    testWidgets('starts on the Home page', (tester) async {
      final db = _memoryDb();
      await tester.pumpWidget(_wrapWithDb(const AppShell(), db));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // HomePage renders its hero icon + buttons.
      expect(find.text('Subtitle Translator'), findsOneWidget);
      expect(find.text('Open File'), findsOneWidget);

      await db.close();
      await tester.pumpAndSettle();
    });

    testWidgets('tapping Settings navigates to SettingsPage', (tester) async {
      final db = _memoryDb();
      await tester.pumpWidget(_wrapWithDb(const AppShell(), db));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Sanity check: Settings-only content not visible before tap.
      expect(find.text('API Keys'), findsNothing);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // SettingsPage FTabs header + tab labels.
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('API Keys'), findsWidgets);
      expect(find.text('Languages'), findsWidgets);
      expect(find.text('Models'), findsWidgets);
      expect(find.text('Prompt'), findsWidgets);
      expect(find.text('Glossary'), findsWidgets);
      expect(find.text('Storage'), findsWidgets);

      await db.close();
      await tester.pumpAndSettle();
    });

    testWidgets('tapping Home returns to the Home page', (tester) async {
      final db = _memoryDb();
      await tester.pumpWidget(_wrapWithDb(const AppShell(), db));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('Subtitle Translator'), findsOneWidget);
      expect(find.text('Open File'), findsOneWidget);

      await db.close();
      await tester.pumpAndSettle();
    });

    testWidgets('window_manager channel received setPreventClose=true',
        (tester) async {
      // Track setPreventClose args via a dedicated spy.
      bool? preventCloseSeen;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_wmChannel, (call) async {
        if (call.method == 'setPreventClose') {
          preventCloseSeen = (call.arguments as Map)['isPreventClose'] as bool;
        }
        return _wmHandler(call);
      });

      final db = _memoryDb();
      await tester.pumpWidget(_wrapWithDb(const AppShell(), db));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(preventCloseSeen, isTrue);

      await db.close();
      await tester.pumpAndSettle();
    });
  });
}
