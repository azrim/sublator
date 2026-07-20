// ponytail: tests cover rendering and drag-event wiring only. Platform-channel
// interactions (FilePicker, secure storage, http) are intentionally NOT tested
// here — they belong to integration tests with mocked bindings. Add when
// end-to-end flow validation becomes necessary.

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

import 'package:subtitle_translator/views/home_page.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    builder: (context, child) => FTheme(
      data: FTheme.neutral.light.desktop,
      child: FToaster(child: child!),
    ),
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomePage', () {
    testWidgets('renders with ForUI theme without errors', (tester) async {
      await tester.pumpWidget(_wrap(const HomePage()));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(FScaffold), findsOneWidget);
      expect(find.byType(FTheme), findsWidgets);
      // No exceptions thrown → implicit pass.
    });

    testWidgets('"Open File" button is visible', (tester) async {
      await tester.pumpWidget(_wrap(const HomePage()));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final openFile = find.text('Open File');
      expect(openFile, findsOneWidget);
      expect(
        find.ancestor(of: openFile, matching: find.byType(FButton)),
        findsOneWidget,
      );
    });

    testWidgets('"Search Subtitles" button is visible', (tester) async {
      await tester.pumpWidget(_wrap(const HomePage()));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Search Subtitles'), findsOneWidget);
    });

    testWidgets('DropTarget is present and accepts drag-entered events',
        (tester) async {
      await tester.pumpWidget(_wrap(const HomePage()));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final dropTargetFinder = find.byType(DropTarget);
      expect(dropTargetFinder, findsOneWidget);

      // Drag feedback overlay should be absent until a drag enters.
      expect(find.text('Drop subtitle file to load'), findsNothing);

      // Simulate the DropTarget's onDragEntered callback directly via State.
      // desktop_drop does not expose a public testing API; reaching into the
      //widget tree via the DropTarget widget verifies the wiring.
      final dropTarget = tester.widget<DropTarget>(dropTargetFinder);
      expect(dropTarget.onDragEntered, isNotNull);
      expect(dropTarget.onDragExited, isNotNull);
      expect(dropTarget.onDragDone, isNotNull);

      // Fire onDragEntered to confirm dragging UI state is shown.
      dropTarget.onDragEntered!(
        DropEventDetails(
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pump();

      expect(find.text('Drop subtitle file to load'), findsOneWidget);

      // Fire onDragExited to confirm the dragging overlay is cleared.
      dropTarget.onDragExited!(
        DropEventDetails(
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pump();

      expect(find.text('Drop subtitle file to load'), findsNothing);
    });
  });
}
