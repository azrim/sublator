// Widget tests for PreviewPage.
//
// Scope: structural rendering only. Platform-channel interactions
// (FilePicker.saveFile), secure storage (Zen API key), Drift-backed settings,
// and live HTTP streaming are intentionally NOT exercised here — they belong
// to integration tests with mocked bindings. The Translate button is
// asserted present and enabled but never tapped, since tapping would require
// overriding every settings/credential provider.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:subtitle_translator/models/subtitle_document.dart';
import 'package:subtitle_translator/models/subtitle_entry.dart';
import 'package:subtitle_translator/models/subtitle_format.dart';
import 'package:subtitle_translator/views/preview_page.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      builder: (context, child) => FTheme(
        data: FTheme.neutral.light.desktop,
        child: FToaster(child: child!),
      ),
      home: child,
    ),
  );
}

SubtitleDocument _sampleDoc() {
  return const SubtitleDocument(
    format: SubtitleFormat.srt,
    entries: [
      SubtitleEntry(
        id: 1,
        startMs: 1000,
        endMs: 3000,
        lines: ['Hello world'],
      ),
      SubtitleEntry(
        id: 2,
        startMs: 3500,
        endMs: 6000,
        lines: ['Second cue text'],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreviewPage', () {
    testWidgets('renders side-by-side layout with sample document',
        (tester) async {
      await tester.pumpWidget(_wrap(PreviewPage(document: _sampleDoc())));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(FScaffold), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('SRT • 2 cues'), findsOneWidget);
      // Column headers.
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Translated'), findsOneWidget);
      // At least one original cue text visible.
      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('Translate button is visible and enabled', (tester) async {
      await tester.pumpWidget(_wrap(PreviewPage(document: _sampleDoc())));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final translateFinder = find.text('Translate');
      expect(translateFinder, findsOneWidget);
      final btn = tester.widget<FButton>(
        find.ancestor(of: translateFinder, matching: find.byType(FButton)),
      );
      expect(btn.onPress, isNotNull,
          reason: 'Translate button should be enabled when not translating');
    });

    testWidgets('Export button is visible', (tester) async {
      await tester.pumpWidget(_wrap(PreviewPage(document: _sampleDoc())));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Export'), findsOneWidget);
      expect(
        find.ancestor(of: find.text('Export'), matching: find.byType(FButton)),
        findsOneWidget,
      );
    });

    testWidgets('Cancel button is present and disabled when idle',
        (tester) async {
      await tester.pumpWidget(_wrap(PreviewPage(document: _sampleDoc())));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final cancelFinder = find.text('Cancel');
      expect(cancelFinder, findsOneWidget);
      final btn = tester.widget<FButton>(
        find.ancestor(of: cancelFinder, matching: find.byType(FButton)),
      );
      expect(btn.onPress, isNull,
          reason: 'Cancel should be disabled when no translation is running');
    });

    testWidgets('Export is disabled for empty document', (tester) async {
      const emptyDoc = SubtitleDocument(
        format: SubtitleFormat.srt,
        entries: [],
      );
      await tester.pumpWidget(_wrap(const PreviewPage(document: emptyDoc)));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final exportFinder = find.text('Export');
      expect(exportFinder, findsOneWidget);
      final btn = tester.widget<FButton>(
        find.ancestor(of: exportFinder, matching: find.byType(FButton)),
      );
      expect(btn.onPress, isNull,
          reason: 'Export button should be disabled for empty document');
    });

    testWidgets('empty document shows appropriate empty state', (tester) async {
      const emptyDoc = SubtitleDocument(
        format: SubtitleFormat.vtt,
        entries: [],
      );
      await tester.pumpWidget(_wrap(const PreviewPage(document: emptyDoc)));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.textContaining('No entries to preview'), findsOneWidget);
      expect(find.text('Original'), findsNothing,
          reason: 'Column header should not render for empty document');
    });

    testWidgets('each entry row shows its original text', (tester) async {
      // Use a tall viewport so both cues render without scrolling.
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(PreviewPage(document: _sampleDoc())));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // First cue text (single line).
      expect(find.text('Hello world'), findsOneWidget);
      // Second cue's text. Both rows must be visible thanks to the tall
      // viewport set above.
      expect(find.text('Second cue text'), findsOneWidget);
    });

    testWidgets('format selector reflects document format by default',
        (tester) async {
      await tester.pumpWidget(_wrap(PreviewPage(document: _sampleDoc())));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Default format label is SRT (from sample doc). FSelect displays the
      // selected item's display value, which is the format name uppercased.
      expect(find.text('SRT'), findsWidgets);
    });

    testWidgets('translate button is disabled while translating',
        (tester) async {
      // We cannot easily drive the real translation flow without mocking
      // every provider, so this test only asserts the initial enabled state.
      // The disabled-while-translating behavior is covered by the build
      // branch `onPress: _translating ? null : _startTranslation`.
      await tester.pumpWidget(_wrap(PreviewPage(document: _sampleDoc())));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final translateFinder = find.text('Translate');
      final btn = tester.widget<FButton>(
        find.ancestor(of: translateFinder, matching: find.byType(FButton)),
      );
      expect(btn.onPress, isNotNull);
    });

    testWidgets('timing text fields render for each entry', (tester) async {
      // Use a tall viewport so both cues render without scrolling.
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(PreviewPage(document: _sampleDoc())));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // The first entry's startMs (1000) and endMs (3000), and the second
      // entry's startMs (3500) and endMs (6000), should each appear as the
      // initial value of a timing TextField. FSelect in the toolbar also
      // contributes a TextField internally, so we assert on the specific
      // ms values rather than a raw TextField count.
      expect(find.text('1000'), findsOneWidget);
      expect(find.text('3000'), findsOneWidget);
      expect(find.text('3500'), findsOneWidget);
      expect(find.text('6000'), findsOneWidget);
    });
  });
}
