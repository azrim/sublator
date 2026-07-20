import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'subtitle_document.dart';

// ponytail: explicit NotifierProvider instead of @riverpod codegen. Avoids
// running build_runner (which could clobber other agents' in-flight .g.dart
// files). Convert to `@riverpod class ActiveDocument` later if consistency
// matters; the public API (provider name + .state setter) is identical.

/// Holds the currently loaded [SubtitleDocument] for the Editor section.
/// Null when no file is loaded (Home is shown).
///
/// Set by [HomePage] when a file is loaded; AppShell watches this to surface
/// the Editor sidebar item and swap the IndexedStack.
class ActiveDocumentNotifier extends Notifier<SubtitleDocument?> {
  @override
  SubtitleDocument? build() => null;

  // ponytail: public setter because Riverpod 3 annotates Notifier.state as
  // @protected — external `.state =` triggers invalid_use_of_protected_member.
  // `set` is the one-line idiomatic escape hatch. Replace with a domain
  // method (setDocument/clear) if coordinated updates ever matter.
  void set(SubtitleDocument? value) => state = value;
}

final activeDocumentProvider =
    NotifierProvider<ActiveDocumentNotifier, SubtitleDocument?>(
  ActiveDocumentNotifier.new,
);

/// Display name of the loaded file (basename, no directory) shown in the
/// sidebar Editor item. Empty string until a file is loaded.
class ActiveFileNameNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final activeFileNameProvider =
    NotifierProvider<ActiveFileNameNotifier, String>(
  ActiveFileNameNotifier.new,
);
