/// Subtitle writers: format-agnostic interface shared by SRT / VTT / SUB / ASS
/// writers. The domain models live in `lib/models/` (Task 2) and are imported
/// as-is — writers only add serialization logic.
library;

import '../../models/subtitle_document.dart';
import '../../models/subtitle_entry.dart';

/// Contract for format-specific subtitle writers.
///
/// Implementations serialize a [SubtitleDocument] to a format-specific
/// string. Empty documents produce an empty string.
abstract class SubtitleWriter {
  const SubtitleWriter();

  String write(SubtitleDocument doc);
}

/// Resolves the text a writer should emit for a cue: the translated text when
/// present, otherwise the original lines joined by `\n`. Centralised here so
/// every writer and the overflow post-processor agree on precedence.
String effectiveText(SubtitleEntry e) =>
    e.translatedText ?? e.lines.join('\n');
